/*
 * Verifies the Ed25519 signature of a signed server envelope (docs/SERVER.md §3 "Signatures").
 * Crypto Architecture Kit: createAsyKeyGenerator('Ed25519').convertKey(spkiDer, null) and createVerify('Ed25519')
 * with init(pubKey) + verify(data, sig), all Promise-based (Ed25519 sign/verify since API 11, below our API 20
 * minimum; doc API参考/安全/Crypto_Architecture_Kit_加解密算法框架服务/ArkTS_API/.../js-apis-cryptoframework,
 * createVerify algName "Ed25519 11+"; FAQ faqs-crypto-architecture-34: an OpenSSL/Node Ed25519 public key is
 * base64 DER SPKI and must be base64-decoded, not utf-8-encoded, before convertKey).
 * Ed25519 is single-shot: the whole message goes to verify() (no update()).
 * The verifier is behind an interface so a test or another algorithm can replace it.
 * Fails closed: an empty or malformed key, or any crypto error, means "not verified".
 */
import { cryptoFramework } from '@kit.CryptoArchitectureKit';
import { util } from '@kit.ArkTS';
import { Log } from '../../app/Log';
import { LogEvents } from '../../app/LogEvents';

export interface SignatureVerifier {
  /** True only when `sig` is a valid signature of utf8(`message`). Never rejects. */
  verify(message: string, sig: number[]): Promise<boolean>;
  /** False when no public key is configured (everything is rejected). */
  configured(): boolean;
}

export class Ed25519Verifier implements SignatureVerifier {
  private readonly spkiB64: string;
  private key: Promise<cryptoFramework.PubKey | undefined> | undefined = undefined;

  constructor(spkiB64: string) {
    this.spkiB64 = spkiB64.trim();
  }

  configured(): boolean {
    return this.spkiB64.length > 0;
  }

  async verify(message: string, sig: number[]): Promise<boolean> {
    if (!this.configured()) {
      Log.w(LogEvents.REMOTE, 'event=verify result=rejected reason=no_public_key');
      return false;
    }
    try {
      const pub = await this.pubKey();
      if (pub === undefined) {
        return false;
      }
      const verifier = cryptoFramework.createVerify('Ed25519');
      await verifier.init(pub);
      const data: cryptoFramework.DataBlob = { data: new util.TextEncoder().encodeInto(message) };
      const sigBlob: cryptoFramework.DataBlob = { data: new Uint8Array(sig) };
      const ok = await verifier.verify(data, sigBlob);
      if (!ok) {
        Log.w(LogEvents.REMOTE, 'event=verify result=bad_signature');
      }
      return ok;
    } catch (e) {
      Log.e(LogEvents.REMOTE, `event=verify result=error ${Log.errKv(e as Object)}`);
      return false;
    }
  }

  private pubKey(): Promise<cryptoFramework.PubKey | undefined> {
    if (this.key === undefined) {
      this.key = this.loadKey();
    }
    return this.key;
  }

  private async loadKey(): Promise<cryptoFramework.PubKey | undefined> {
    try {
      const der = new util.Base64Helper().decodeSync(this.spkiB64);
      const gen = cryptoFramework.createAsyKeyGenerator('Ed25519');
      const pair = await gen.convertKey({ data: der }, null);
      return pair.pubKey;
    } catch (e) {
      Log.e(LogEvents.REMOTE, `event=verify result=bad_public_key ${Log.errKv(e as Object)}`);
      return undefined;
    }
  }
}

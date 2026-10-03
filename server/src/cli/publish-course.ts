// npm run publish-course -- --course krakow --pack <packDir> --audio <data/course/<id>/audio> --data <DATA_DIR>
//                           [--seed seed] [--key-file .keys/signing-private.pem] [--city Kraków]
//                           [--system-lines ../scripts/voice/system-lines.mjs]
// Signing key: SIGNING_PRIVATE_KEY (PEM, env) if set, else --key-file (default .keys/signing-private.pem from
// `npm run keygen`). Never prints the key.
import { readFileSync } from 'node:fs';
import { resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { createPublicKey } from 'node:crypto';
import { loadPrivateKey, publicKeyForms } from '../canonical.js';
import { publishCourse } from '../publish.js';

const CITY: Record<string, string> = { krakow: 'Kraków' };

async function main(argv: string[]): Promise<number> {
  const o: Record<string, string> = {};
  for (let i = 0; i < argv.length; i++) {
    const a = String(argv[i]);
    if (!a.startsWith('--') || i + 1 >= argv.length) {
      console.error(`publish-course: bad argument ${a}`);
      return 2;
    }
    o[a.slice(2)] = String(argv[++i]);
  }
  for (const req of ['course', 'pack', 'audio', 'data']) {
    if (!o[req]) {
      console.error(`publish-course: --${req} is required`);
      return 2;
    }
  }
  const pem = process.env.SIGNING_PRIVATE_KEY && process.env.SIGNING_PRIVATE_KEY.trim().length > 0 ?
    process.env.SIGNING_PRIVATE_KEY.replace(/\\n/g, '\n') :
    readFileSync(resolve(o['key-file'] ?? '.keys/signing-private.pem'), 'utf8');
  const privateKey = loadPrivateKey(pem);
  const courseId = String(o.course);
  const systemLinesPath = o['system-lines'] ? resolve(o['system-lines']) :
    fileURLToPath(new URL('../../../scripts/voice/system-lines.mjs', import.meta.url));
  const r = await publishCourse({
    courseId,
    packDir: resolve(String(o.pack)),
    audioDir: resolve(String(o.audio)),
    dataDir: resolve(String(o.data)),
    seedDir: o.seed ? resolve(o.seed) : undefined,
    privateKey,
    systemLinesPath,
    city: o.city ?? CITY[courseId] ?? courseId,
    log: (s) => console.log(`publish-course: ${s}`)
  });
  console.log(`publish-course: blobs written ${r.blobsWritten}, shipped clips pre-seeded in tts-index ${r.shippedIndexed}`);
  if (r.clipsNotAllowed > 0) {
    console.warn(`publish-course: WARNING ${r.clipsNotAllowed} shipped clips are not in the allowed set ` +
      '(their text no longer matches the pack / system lines)');
  }
  console.log(`publish-course: catalog entry ${JSON.stringify(r.summary)}`);
  console.log(`publish-course: signed with public key ${publicKeyForms(createPublicKey(privateKey)).raw}`);
  return 0;
}

main(process.argv.slice(2)).then((c) => process.exit(c), (e: unknown) => {
  console.error(`publish-course: ${e instanceof Error ? e.message : String(e)}`);
  process.exit(1);
});

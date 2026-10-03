/*
 * RemoteVoice: a SpeechPort decorator around NarrationPlayer that adds step 2 of the voice fallback chain
 * (docs/SERVER.md §2): a sentence with no pre-rendered clip in the downloaded course is asked from the server
 * (POST /v1/tts) when Settings "Online studio voice" is on and the server is reachable, within a 2.5 s budget.
 *
 * - The decision is the pure core/remote/VoiceChain.decideVoice; the response is judged by judgeRemote: the
 *   X-Text-Sha256 header must equal sha256(utf8(text)) computed here, else the audio is dropped.
 * - Accepted audio is cached forever in filesDir/tts/<sha>.mp3 (a later replay, or the next tour, plays it offline:
 *   src=remote_cache) and played through NarrationPlayer's ClipPlayer like a pre-rendered clip ("Studio voice").
 * - prefetch(n+1) also prefetches its studio line, so the next sentence usually starts without waiting.
 * - Timeout / 429 / offline / mismatch: the sentence goes on as before (built-in voice "Fallback voice", or text for
 *   Polish). A network failure or 5xx skips the server for 60 s, a 429 (daily budget) for 10 min, so an offline
 *   walk never waits 2.5 s per sentence. BASE_URL '' (RemoteConfig) = never any request.
 * - While a sentence waits for the server (at most 2.5 s) nothing is spoken; stopNow/pause/resume/speak keep their
 *   SpeechPort meaning (a newer speak() or stopNow() cancels the wait; pause holds it).
 * Logs: REMOTE_TTS result=... reason=... sha=<12> ms=... cache=hit|miss; NarrationPlayer's NARR_AUDIO line says
 * src=remote|remote_cache|tts|text with the reason.
 */
import { SpeechCapabilities, SpeechListener, SpeechPort, Utterance } from '../../contracts/Ports';
import { Lang } from '../../contracts/Model';
import { Log } from '../../app/Log';
import { LogEvents } from '../../app/LogEvents';
import { RemoteConfig } from '../../app/RemoteConfig';
import { shortSha } from '../../core/speech/ClipSelection';
import {
  ChainInput, ChainStep, decideVoice, judgeRemote, RemoteVerdict, ServerState, serverStateText, VoiceSrc
} from '../../core/remote/VoiceChain';
import { TTS_MAX_TEXT_CHARS } from '../../core/remote/ServerApi';
import { FileStore } from '../remote/FileStore';
import { RemoteClient } from '../remote/RemoteClient';
import { LocalAudio, NarrationPlayer, RuntimeClip, RuntimeClipSource } from './NarrationPlayer';

const SHA_FILE_RE: RegExp = new RegExp('^([a-f0-9]{64})\\.mp3$');

class Fetched {
  file: string = '';
  reason: string = '';
}

class Plan {
  step: ChainStep | undefined = undefined;   // undefined: the local clips or the user's choice decide
  sha: string = '';
}

export class RemoteVoice implements SpeechPort, RuntimeClipSource {
  private readonly inner: NarrationPlayer;
  private readonly client: RemoteClient;
  private readonly dirOf: () => string;
  private readonly courseIdOf: () => string;
  private toggle: boolean = true;
  private cached: Set<string> = new Set<string>();
  private cacheLoad: Promise<void> | undefined = undefined;
  private results: Map<string, Fetched> = new Map<string, Fetched>();
  private inflight: Map<string, Promise<void>> = new Map<string, Promise<void>>();
  private refused: Set<string> = new Set<string>();   // 403 not_allowed: never asked again (SERVER.md §3.1)
  private offlineUntil: number = 0;
  private budgetUntil: number = 0;
  private state: ServerState = ServerState.OFFLINE;
  private stateKnown: boolean = false;
  private pending: Utterance | undefined = undefined;
  private seq: number = 0;
  private paused: boolean = false;

  constructor(inner: NarrationPlayer, client: RemoteClient, dirOf: () => string, courseIdOf: () => string) {
    this.inner = inner;
    this.client = client;
    this.dirOf = dirOf;
    this.courseIdOf = courseIdOf;
    inner.setRuntimeClipSource(this);
  }

  // ---------- settings / HUD ----------

  setOnlineVoice(on: boolean): void {
    if (on !== this.toggle) {
      Log.i(LogEvents.SETTINGS, `key=onlineStudioVoice value=${on}`);
    }
    this.toggle = on;
  }

  onlineVoice(): boolean {
    return this.toggle;
  }

  serverState(): ServerState {
    if (!this.client.enabled()) {
      return ServerState.DISABLED;
    }
    const now = Date.now();
    if (now < this.budgetUntil) {
      return ServerState.BUDGET;
    }
    if (now < this.offlineUntil) {
      return ServerState.OFFLINE;
    }
    return this.state;
  }

  /** HUD Server row text: 'server online · online voice on · 12 lines cached'. */
  hudText(): string {
    const s = this.serverState();
    if (s === ServerState.DISABLED) {
      return serverStateText(s);
    }
    const known = this.stateKnown || s !== ServerState.OFFLINE ? serverStateText(s) : 'server not reached yet';
    return `${known} · online voice ${this.toggle ? 'on' : 'off'} · ${this.cached.size} lines cached`;
  }

  /** GET /healthz once at start-up, so the HUD state is real. Never rejects. */
  probe(): void {
    if (!this.client.enabled()) {
      return;
    }
    this.client.health().then((ok: boolean) => {
      this.stateKnown = true;
      this.state = ok ? ServerState.ONLINE : ServerState.OFFLINE;
      if (!ok) {
        this.offlineUntil = Date.now() + 15000;   // a short back-off: the first sentences use the fallback at once
      }
    });
  }

  // ---------- SpeechPort ----------

  init(): Promise<SpeechCapabilities> {
    this.loadCache();
    return this.inner.init();
  }

  setListener(l: SpeechListener): void {
    this.inner.setListener(l);
  }

  speak(u: Utterance): void {
    try {
      this.seq++;
      this.pending = undefined;
      const plan = this.plan(u);
      const step = plan.step;
      if (step === undefined || step.src !== VoiceSrc.REMOTE || this.results.has(plan.sha)) {
        this.inner.speak(u);
        return;
      }
      // Wait (at most the budget) for the studio line; the old sentence stops now, as a preempt would.
      if (this.inner.isSpeaking() || this.inner.isPaused()) {
        this.inner.stopNow();
      }
      const mySeq = this.seq;
      this.pending = u;
      this.fetch(u, plan.sha).then(() => {
        if (this.seq !== mySeq || this.pending !== u) {
          return;   // a newer speak() or stopNow() won
        }
        this.pending = undefined;
        this.inner.speak(u);
        if (this.paused) {
          this.inner.pause();
        }
      });
    } catch (e) {
      Log.e(LogEvents.UNCAUGHT, `where=RemoteVoice.speak ${Log.errKv(e as Object)}`);
      this.inner.speak(u);
    }
  }

  prefetch(u: Utterance): void {
    try {
      const plan = this.plan(u);
      const step = plan.step;
      if (step === undefined || step.src !== VoiceSrc.REMOTE || this.results.has(plan.sha)) {
        this.inner.prefetch(u);
        return;
      }
      const mySeq = this.seq;
      this.fetch(u, plan.sha).then(() => {
        if (this.seq === mySeq && this.pending !== u) {
          this.inner.prefetch(u);   // now with its studio line (or the fallback when the server failed)
        }
      });
    } catch (e) {
      Log.e(LogEvents.UNCAUGHT, `where=RemoteVoice.prefetch ${Log.errKv(e as Object)}`);
      this.inner.prefetch(u);
    }
  }

  stopNow(): void {
    this.seq++;
    this.pending = undefined;
    this.paused = false;
    this.inner.stopNow();
  }

  pause(): void {
    this.paused = true;
    if (this.pending === undefined) {
      this.inner.pause();
    }
  }

  resume(): void {
    this.paused = false;
    if (this.pending === undefined) {
      this.inner.resume();
    }
  }

  isSpeaking(): boolean {
    return (this.pending !== undefined && !this.paused) || this.inner.isSpeaking();
  }

  // ---------- RuntimeClipSource (called by NarrationPlayer for a sentence without a clip) ----------

  lookup(u: Utterance, sha: string): RuntimeClip | undefined {
    const rc = new RuntimeClip();
    const got = this.results.get(sha);
    if (got !== undefined) {
      if (got.file === '') {
        this.results.delete(sha);   // a failure is reported once; a replay asks again
        rc.reason = got.reason;
        return rc;
      }
      if (this.toggle) {
        rc.file = got.file;
        rc.src = VoiceSrc.REMOTE;   // rendered by the server in this session (from disk = remote_cache below)
        rc.reason = got.reason;
        return rc;
      }
    }
    const step = this.decide(u, sha, false);
    rc.reason = step.reason;
    if (step.src === VoiceSrc.REMOTE_CACHE) {
      rc.file = this.cachePath(sha);
      rc.src = VoiceSrc.REMOTE_CACHE;
    } else if (step.src === VoiceSrc.REMOTE) {
      rc.reason = 'not_fetched';
    }
    return rc;
  }

  onClipFailed(sha: string, file: string): void {
    Log.w(LogEvents.REMOTE_TTS, `event=cache_bad sha=${shortSha(sha)} action=delete`);
    this.cached.delete(sha);
    this.results.delete(sha);
    FileStore.remove(file);
  }

  // ---------- internals ----------

  /** The chain step for `u` (undefined when the local clips or the user's choice decide) and its text sha. */
  private plan(u: Utterance): Plan {
    const out = new Plan();
    if (!this.client.enabled()) {
      return out;
    }
    const local: LocalAudio = this.inner.localAudio(u);
    out.sha = local.sha;
    if (!local.clip && !local.optOut) {
      out.step = this.decide(u, local.sha, local.platformText);
    }
    return out;
  }

  private decide(u: Utterance, sha: string, platformText: boolean): ChainStep {
    if (this.refused.has(sha) && !this.cached.has(sha)) {
      const s = new ChainStep();
      s.src = platformText ? VoiceSrc.TEXT : VoiceSrc.TTS;
      s.fallback = s.src;
      s.reason = 'not_allowed';
      return s;
    }
    const i = new ChainInput();
    i.localClip = false;
    i.userOptOut = false;
    i.cached = this.cached.has(sha);
    i.toggleOn = this.toggle;
    i.serverConfigured = this.client.enabled();
    i.courseKnown = this.courseIdOf() !== '';
    i.textSendable = u.text.length > 0 && u.text.length <= TTS_MAX_TEXT_CHARS &&
      (u.lang === Lang.EN || u.lang === Lang.PL || u.lang === Lang.ZH);
    i.offlineUntilMs = this.offlineUntil;
    i.budgetUntilMs = this.budgetUntil;
    i.nowMs = Date.now();
    i.platformText = platformText;
    return decideVoice(i);
  }

  private cacheDir(): string {
    const d = this.dirOf();
    return d === '' ? '' : `${d}/tts`;
  }

  private cachePath(sha: string): string {
    return `${this.cacheDir()}/${sha}.mp3`;
  }

  private loadCache(): void {
    if (this.cacheLoad !== undefined || this.cacheDir() === '') {
      return;
    }
    this.cacheLoad = FileStore.list(this.cacheDir()).then((names: string[]) => {
      for (const n of names) {
        const m = SHA_FILE_RE.exec(n);
        if (m !== null) {
          this.cached.add(m[1]);
        }
      }
      Log.i(LogEvents.REMOTE_TTS, `event=cache_load lines=${this.cached.size}`);
    }).catch((e: Object) => {
      Log.w(LogEvents.REMOTE_TTS, `event=cache_load_fail ${Log.errKv(e)}`);
    });
  }

  /** POST /v1/tts once per sha at a time; stores the outcome in `results`. Never rejects. */
  private fetch(u: Utterance, sha: string): Promise<void> {
    const running = this.inflight.get(sha);
    if (running !== undefined) {
      return running;
    }
    const courseId = this.courseIdOf();
    const p = this.client.tts(courseId, u.lang, u.text, RemoteConfig.TTS_BUDGET_MS).then(async (res) => {
      const v: RemoteVerdict = judgeRemote(res.result, sha, RemoteConfig.TTS_BUDGET_MS);
      const now = Date.now();
      this.stateKnown = true;
      this.state = v.server;
      if (v.offlineForMs > 0) {
        this.offlineUntil = now + v.offlineForMs;
      }
      if (v.budgetForMs > 0) {
        this.budgetUntil = now + v.budgetForMs;
      }
      if (v.neverRetry) {
        this.refused.add(sha);
      }
      const f = new Fetched();
      if (v.accept && res.audio !== undefined && this.cacheDir() !== '') {
        const path = this.cachePath(sha);
        if (await FileStore.writeBytes(path, res.audio)) {
          this.cached.add(sha);
          f.file = path;
          f.reason = `server_ok x_cache=${res.cacheHeader || 'n/a'}`;
        } else {
          f.reason = 'cache_write_failed';
        }
      } else {
        f.reason = v.reason;
      }
      this.results.set(sha, f);
      Log.i(LogEvents.REMOTE_TTS, `result=${f.file !== '' ? 'ok' : 'fallback'} reason=${f.reason} sha=${shortSha(sha)}` +
        ` lang=${u.lang} course=${courseId} status=${res.result.status} ms=${res.result.elapsedMs}` +
        ` bytes=${res.result.bytes} server=${v.server}`);
    }).catch((e: Object) => {
      const f = new Fetched();
      f.reason = 'exception';
      this.results.set(sha, f);
      Log.e(LogEvents.REMOTE_TTS, `result=fallback reason=exception ${Log.errKv(e)}`);
    }).finally(() => {
      this.inflight.delete(sha);
    });
    this.inflight.set(sha, p);
    return p;
  }

  // ---------- extras passed through (NarrationPlayer API used by AppContainer / TourController) ----------

  narration(): NarrationPlayer {
    return this.inner;
  }
}

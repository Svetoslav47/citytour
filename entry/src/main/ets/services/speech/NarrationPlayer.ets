/*
 * SpeechPort implementation: one utterance (sentence) in flight, the next one prefetched (ARCHITECTURE §2.5,
 * PLAN §0.4, task A4).
 *
 * Per utterance, VoiceManager.plan(u.lang) decides the voice:
 *   voice -> TtsEngines.speak(playType 0) streams PCM into PcmPlayer (our AudioRenderer, AUDIOBOOK usage);
 *            UTT_START when the first bytes reach the renderer, UTT_DONE after the buffer drains (end is ours,
 *            RISKS a7: onComplete fires once, type 0 = synthesis finished).
 *   text  -> no audio; start/done fire on a reading-time timer, so the tour keeps its pace (Polish, text-only).
 * prefetch(n+1) synthesizes into a parked PCM segment while n plays; speak(n+1) then starts instantly.
 * speak() while another utterance is in flight preempts it (logged), so a double tap never overlaps audio.
 * If the planned engine cannot be created (en-US/8 on the emulator: 1002300005) the voice is marked failed and the
 * utterance is re-planned once (-> zh fallback or text-only), so no sentence is lost.
 * AppConfig.USE_SYSTEM_PLAYBACK = true switches to playType 1 (the kit plays it; RISKS T7 emergency fallback):
 *   pause = engine.stop(), resume = re-speak the sentence.
 * Every platform call is guarded; every wait has a timeout (synthesis SYNTH_TIMEOUT_MS, playback watchdog).
 * TTS keeps the [pN] pause markup; captions strip it (VoicePolicy.stripPauseMarkup).
 * A10 (ARCHITECTURE §9 rows 9/12/13):
 *   - init() waits (bounded by ENGINE_CREATE_TIMEOUT_MS) for the engine English would use, so a createEngine
 *     failure is known before the tour is planned and the plan is already the fallback (zh voice or text only).
 *   - Audio focus interrupts (PAUSE/STOP/RESUME) and the headphones going away are passed on to an
 *     AudioEventListener (AppContainer -> TourController), so the engine pauses the tour, shows the issue and
 *     replays the interrupted sentence on RESUME. This is a services-side hook: the SpeechPort contract is
 *     unchanged. Without a listener the player still pauses/resumes itself as before.
 */
import { Lang } from '../../contracts/Model';
import { SpeechCapabilities, SpeechListener, SpeechPort, Utterance, VoicePlan } from '../../contracts/Ports';
import { estimateReadingMs, pcmDurationMs, SPEECH_MODE_TEXT } from '../../core/speech/VoicePolicy';
import { AppConfig } from '../../app/AppConfig';
import { Log } from '../../app/Log';
import { LogEvents } from '../../app/LogEvents';
import { PcmPlayer, PcmPlayerListener } from '../audio/PcmPlayer';
import { TtsEngines, TtsErr, TtsRequestHandler } from './TtsEngines';
import { VoiceManager } from './VoiceManager';

export const SYNTH_TIMEOUT_MS: number = 15000;
export const WATCHDOG_MARGIN_MS: number = 4000;
const MAX_TEXT_CHARS: number = 9000; // the kit rejects > 10000 chars with 1002300001

// audio.InterruptHint values (kept as numbers so this file needs no AudioKit import).
const HINT_RESUME: number = 1;
const HINT_PAUSE: number = 2;
const HINT_STOP: number = 3;
// audio.AudioStreamDeviceChangeReason.REASON_OLD_DEVICE_UNAVAILABLE (headphones unplugged).
const REASON_OLD_DEVICE_UNAVAILABLE: number = 2;

/** §9 rows 12/13 hook (not part of SpeechPort). hint: 'PAUSE' | 'STOP' | 'RESUME'. */
export interface AudioEventListener {
  onInterrupt: (hint: string) => void;
  onRouteLost: (devices: string) => void;
}

/** audio.InterruptHint number -> the engine's hint name; '' for hints the engine ignores (DUCK, UNDUCK, MUTE). */
export function interruptHintName(hint: number): string {
  if (hint === HINT_PAUSE) {
    return 'PAUSE';
  }
  if (hint === HINT_STOP) {
    return 'STOP';
  }
  if (hint === HINT_RESUME) {
    return 'RESUME';
  }
  return '';
}

/** Persona voice parameters (Persona.voice in the pack); defaults = kit defaults. */
export interface VoiceTuning {
  speed: number;
  pitch: number;
  volume: number;
}

class Job {
  u: Utterance;
  plan: VoicePlan;
  segId: string;
  reqId: string = '';
  replanned: boolean = false;
  synthStarted: boolean = false;
  synthDone: boolean = false;
  started: boolean = false;
  finished: boolean = false;
  t0: number = 0;          // speak() time (UTT latency / duration)
  synthT0: number = 0;     // synthesis request time
  synthTimer: number = -1;
  watchdog: number = -1;
  textTimer: number = -1;
  textRemainingMs: number = 0;
  textStartedAt: number = 0;

  constructor(u: Utterance, plan: VoicePlan, segId: string) {
    this.u = u;
    this.plan = plan;
    this.segId = segId;
  }

  isText(): boolean {
    return this.plan.speechMode === SPEECH_MODE_TEXT;
  }
}

export class NarrationPlayer implements SpeechPort {
  private voice: VoiceManager;
  private engines: TtsEngines;
  private pcm: PcmPlayer;
  private systemPlayback: boolean;
  private listener: SpeechListener | undefined = undefined;
  private audioListener: AudioEventListener | undefined = undefined;
  private current: Job | undefined = undefined;
  private prefetched: Job | undefined = undefined;
  private paused: boolean = false;
  private segSeq: number = 0;
  private tuning: VoiceTuning = { speed: 1, pitch: 1, volume: 1 };

  constructor(voice: VoiceManager, engines: TtsEngines, pcm: PcmPlayer,
    systemPlayback: boolean = AppConfig.USE_SYSTEM_PLAYBACK) {
    this.voice = voice;
    this.engines = engines;
    this.pcm = pcm;
    this.systemPlayback = systemPlayback;
    const pl: PcmPlayerListener = {
      onSegmentStart: (id: string) => this.onSegmentStart(id),
      onSegmentDone: (id: string, bytes: number) => this.onSegmentDone(id, bytes),
      onInterrupt: (hint: number, force: number) => this.onInterrupt(hint, force),
      onRouteChange: (reason: number, devices: string) => this.onRouteChange(reason, devices),
      onRendererError: (id: string, code: number, where: string) => this.onRendererError(id, code, where)
    };
    this.pcm.setListener(pl);
  }

  // ---------- SpeechPort ----------

  /**
   * listVoices, then warm up the renderer and the engine English would use, waiting for that engine (bounded by
   * TtsEngines' create timeout) so a failure re-plans before the tour does (§9 row 9). Never rejects.
   */
  init(): Promise<SpeechCapabilities> {
    const t0 = Date.now();
    return this.voice.capabilities().then((caps: SpeechCapabilities): Promise<SpeechCapabilities> => {
      const p = this.voice.plan(Lang.EN);
      Log.i(LogEvents.TTS_INIT, `event=speech_init mode=${this.systemPlayback ? 'system_playType1' : 'pcm_playType0'}` +
        ` en_label=${p.label} ms=${Date.now() - t0}`);
      if (!this.systemPlayback) {
        this.pcm.warmUp();
      }
      if (p.engineLocale === '') {
        return Promise.resolve(caps);
      }
      return this.engines.get(p.engineLocale, p.person).then((): SpeechCapabilities => caps)
        .catch((e: Object): SpeechCapabilities => {
          const code = this.engines.failure(p.engineLocale, p.person);
          if (code !== 0) {
            this.voice.markEngineFailed(p.engineLocale, p.person, code); // a timeout is not cached as a failure
            Log.e(LogEvents.TTS_INIT_FAIL, `lang=en engine=${p.engineLocale}/${p.person} code=${code} ` +
              `action=replan where=NarrationPlayer.init`);
          }
          return this.voice.lastCaps();
        });
    }).catch((e: Object) => {
      Log.e(LogEvents.TTS_INIT_FAIL, `where=NarrationPlayer.init ${Log.errKv(e)}`);
      return this.voice.lastCaps();
    });
  }

  /** §9 rows 12/13: who hears about audio interrupts and headphone loss (AppContainer wires the TourController). */
  setAudioEventListener(l: AudioEventListener | undefined): void {
    this.audioListener = l;
  }

  setListener(l: SpeechListener): void {
    this.listener = l;
  }

  setTuning(t: VoiceTuning): void {
    this.tuning = t;
  }

  speak(u: Utterance): void {
    try {
      this.speakInternal(u);
    } catch (e) {
      Log.e(LogEvents.UNCAUGHT, `where=NarrationPlayer.speak id=${u.id} ${Log.errKv(e as Object)}`);
      this.emitError(u.id, TtsErr.THREW);
    }
  }

  prefetch(u: Utterance): void {
    try {
      if (this.systemPlayback) {
        return; // playType 1 cannot park audio
      }
      if (this.current !== undefined && this.current.u.id === u.id) {
        return;
      }
      if (this.prefetched !== undefined) {
        if (this.prefetched.u.id === u.id) {
          return;
        }
        this.discard(this.prefetched, 'prefetch_replaced');
        this.prefetched = undefined;
      }
      const job = this.newJob(u);
      this.prefetched = job;
      if (!job.isText()) {
        this.startSynth(job);
      }
      Log.d(LogEvents.STORY_QUEUE, `event=prefetch id=${u.id} label=${job.plan.label}`);
    } catch (e) {
      Log.e(LogEvents.UNCAUGHT, `where=NarrationPlayer.prefetch id=${u.id} ${Log.errKv(e as Object)}`);
    }
  }

  stopNow(): void {
    try {
      const had = this.current !== undefined || this.prefetched !== undefined;
      if (this.current !== undefined) {
        Log.i(LogEvents.UTT_DONE, `id=${this.current.u.id} result=stopped`);
        this.discard(this.current, 'stop');
        this.current = undefined;
      }
      if (this.prefetched !== undefined) {
        this.discard(this.prefetched, 'stop');
        this.prefetched = undefined;
      }
      if (had) {
        this.engines.stopAll();
      }
      this.pcm.clear();
      this.paused = false;
    } catch (e) {
      Log.e(LogEvents.UNCAUGHT, `where=NarrationPlayer.stopNow ${Log.errKv(e as Object)}`);
    }
  }

  pause(): void {
    if (this.paused) {
      return;
    }
    this.paused = true;
    const j = this.current;
    try {
      if (j === undefined) {
        return;
      }
      this.clearWatchdog(j);
      if (j.isText()) {
        if (j.textTimer >= 0) {
          clearTimeout(j.textTimer);
          j.textTimer = -1;
          j.textRemainingMs = Math.max(0, j.textRemainingMs - (Date.now() - j.textStartedAt));
        }
      } else if (this.systemPlayback) {
        this.engines.forget(j.reqId);
        this.engines.stop(j.plan.engineLocale, j.plan.person);
      } else {
        this.pcm.pause();
      }
      Log.i(LogEvents.STORY_QUEUE, `event=pause id=${j.u.id}`);
    } catch (e) {
      Log.e(LogEvents.UNCAUGHT, `where=NarrationPlayer.pause ${Log.errKv(e as Object)}`);
    }
  }

  /** Resumes the current sentence from its start (a mid-word resume sounds broken). */
  resume(): void {
    if (!this.paused) {
      return;
    }
    this.paused = false;
    const j = this.current;
    try {
      if (j === undefined) {
        return;
      }
      Log.i(LogEvents.STORY_QUEUE, `event=resume id=${j.u.id}`);
      if (j.isText()) {
        this.armTextTimer(j, j.textRemainingMs);
      } else if (this.systemPlayback) {
        j.synthStarted = false;
        j.synthDone = false;
        this.startSynth(j);
      } else {
        this.pcm.resume(true);
        if (j.synthDone) {
          this.armWatchdog(j);
        }
      }
    } catch (e) {
      Log.e(LogEvents.UNCAUGHT, `where=NarrationPlayer.resume ${Log.errKv(e as Object)}`);
    }
  }

  isSpeaking(): boolean {
    return this.current !== undefined && !this.paused;
  }

  // ---------- extras ----------

  isPaused(): boolean {
    return this.paused;
  }

  currentPlan(): VoicePlan | undefined {
    return this.current !== undefined ? this.current.plan : undefined;
  }

  dispose(): void {
    this.stopNow();
    this.pcm.release();
    this.engines.shutdownAll();
  }

  // ---------- internals ----------

  private newJob(u: Utterance): Job {
    this.segSeq++;
    return new Job(u, this.voice.plan(u.lang), `${u.id}~${this.segSeq}`);
  }

  private speakInternal(u: Utterance): void {
    if (this.current !== undefined) {
      if (this.current.u.id === u.id && !this.current.finished) {
        Log.w(LogEvents.STORY_QUEUE, `event=speak_ignored_same id=${u.id}`);
        return;
      }
      Log.i(LogEvents.UTT_DONE, `id=${this.current.u.id} result=preempted by=${u.id}`);
      const old = this.current;
      this.current = undefined;
      const engineBusy = !old.isText() && !old.synthDone;
      this.discard(old, 'preempt');
      if (engineBusy) {
        // engine.stop() also kills a queued prefetch on that engine: rebuild it below if needed.
        this.engines.stop(old.plan.engineLocale, old.plan.person);
        if (this.prefetched !== undefined && !this.prefetched.synthDone) {
          this.discard(this.prefetched, 'engine_stopped');
          this.prefetched = undefined;
        }
      }
    }
    this.paused = false;
    let job: Job;
    if (this.prefetched !== undefined && this.prefetched.u.id === u.id) {
      job = this.prefetched;
      this.prefetched = undefined;
    } else {
      if (this.prefetched !== undefined) {
        this.discard(this.prefetched, 'prefetch_miss');
        this.prefetched = undefined;
      }
      job = this.newJob(u);
    }
    this.current = job;
    job.t0 = Date.now();
    if (job.isText()) {
      this.startText(job);
      return;
    }
    if (!job.synthStarted) {
      this.startSynth(job);
    }
    if (!this.systemPlayback) {
      this.pcm.play(job.segId);
      if (job.synthDone) {
        this.armWatchdog(job);
      }
    }
  }

  private startText(job: Job): void {
    job.started = true;
    const ms = estimateReadingMs(job.u.text);
    Log.i(LogEvents.UTT_START, `id=${job.u.id} item=${job.u.itemId} lang=${job.u.lang} mode=text label=${job.plan.label}` +
      ` readMs=${ms}`);
    this.emitStart(job.u.id);
    job.textRemainingMs = ms;
    if (!this.paused) {
      this.armTextTimer(job, ms);
    }
  }

  private armTextTimer(job: Job, ms: number): void {
    job.textStartedAt = Date.now();
    job.textTimer = setTimeout(() => {
      job.textTimer = -1;
      this.complete(job, 0);
    }, Math.max(0, ms));
  }

  private startSynth(job: Job): void {
    const p = job.plan;
    let text = job.u.text;
    if (text.length > MAX_TEXT_CHARS) {
      Log.w(LogEvents.TTS_ERR, `id=${job.u.id} code=too_long chars=${text.length} truncated_to=${MAX_TEXT_CHARS}`);
      text = text.substring(0, MAX_TEXT_CHARS);
    }
    job.synthStarted = true;
    job.synthDone = false;
    job.synthT0 = Date.now();
    job.reqId = this.engines.newRequestId(`${job.u.itemId}#${job.u.id}`);
    if (!this.systemPlayback) {
      this.pcm.open(job.segId);
    }
    const extra: Record<string, Object> = {
      'queueMode': 0, 'speed': this.tuning.speed, 'pitch': this.tuning.pitch, 'volume': this.tuning.volume,
      'languageContext': p.languageContext !== '' ? p.languageContext : p.engineLocale, 'audioType': 'pcm',
      'playType': this.systemPlayback ? 1 : 0
    };
    const reqId = job.reqId;
    const h: TtsRequestHandler = {
      onStart: (rate: number, ch: number) => {
        if (job.reqId !== reqId) {
          return;
        }
        if (ch !== 1 && ch !== undefined) {
          this.pcm.setChannels(ch);
        }
        if (this.systemPlayback && this.current === job && !job.started) {
          job.started = true;
          this.logStart(job, -1);
          this.emitStart(job.u.id);
        }
      },
      onData: (audio: ArrayBuffer, seq: number) => {
        if (job.reqId === reqId && !this.systemPlayback) {
          this.pcm.append(job.segId, audio, seq);
        }
      },
      onComplete: (type: number) => {
        if (job.reqId !== reqId) {
          return;
        }
        if (type === 0) {
          job.synthDone = true;
          this.clearSynthTimer(job);
          Log.d(LogEvents.TTS_INIT, `event=synth_done id=${job.u.id} bytes=${this.pcm.bytesOf(job.segId)}` +
            ` ms=${Date.now() - job.synthT0}`);
          if (!this.systemPlayback) {
            this.pcm.finish(job.segId);
            if (this.current === job) {
              this.armWatchdog(job);
            }
          } else if (this.current === job) {
            this.armWatchdog(job);
          }
        } else if (this.systemPlayback && this.current === job) {
          this.engines.forget(reqId);
          this.complete(job, 0);
        }
      },
      onStop: () => {
        // stop() was ours (preempt/pause/stop): nothing to report
      },
      onError: (code: number, msg: string) => {
        if (job.reqId !== reqId) {
          return;
        }
        this.onSynthError(job, code, msg);
      }
    };
    job.synthTimer = setTimeout(() => {
      job.synthTimer = -1;
      if (job.reqId === reqId && !job.synthDone && (this.current === job || this.prefetched === job)) {
        this.engines.forget(reqId);
        this.onSynthError(job, TtsErr.TIMEOUT, `no audio within ${SYNTH_TIMEOUT_MS}ms`);
      }
    }, SYNTH_TIMEOUT_MS);
    Log.d(LogEvents.STORY_QUEUE, `event=synth id=${job.u.id} engine=${p.engineLocale}/${p.person}` +
      ` ctx=${p.languageContext} chars=${text.length}`);
    this.engines.speak(p.engineLocale, p.person, text, reqId, extra, h);
  }

  private onSynthError(job: Job, code: number, msg: string): void {
    this.clearSynthTimer(job);
    const p = job.plan;
    const engineMissing = this.engines.failure(p.engineLocale, p.person) !== 0;
    Log.e(LogEvents.TTS_ERR, `id=${job.u.id} code=${code} msg=${msg} engine=${p.engineLocale}/${p.person}` +
      ` engine_failed=${engineMissing}`);
    if (engineMissing) {
      this.voice.markEngineFailed(p.engineLocale, p.person, code);
    }
    // Re-plan once: a missing engine falls back to the zh voice or to text-only, so the sentence is not lost.
    if (engineMissing && !job.replanned && (this.current === job || this.prefetched === job)) {
      const np = this.voice.plan(job.u.lang);
      if (np.engineLocale !== p.engineLocale || np.speechMode !== p.speechMode) {
        Log.w(LogEvents.NARR_FALLBACK, `id=${job.u.id} from=${p.label} to=${np.label} reason=engine_${code}`);
        this.pcm.drop(job.segId);
        job.replanned = true;
        job.plan = np;
        this.segSeq++;
        job.segId = `${job.u.id}~${this.segSeq}`;
        job.reqId = '';
        job.synthStarted = false;
        if (this.current === job) {
          if (np.speechMode === SPEECH_MODE_TEXT) {
            this.startText(job);
          } else {
            this.startSynth(job);
            if (!this.systemPlayback) {
              this.pcm.play(job.segId);
            }
          }
        } else if (np.speechMode !== SPEECH_MODE_TEXT) {
          this.startSynth(job);
        }
        return;
      }
    }
    if (this.current === job) {
      this.complete(job, code);
    } else if (this.prefetched === job) {
      // speak() of this utterance will start a fresh attempt
      this.discard(job, 'prefetch_failed');
      this.prefetched = undefined;
    }
  }

  private onSegmentStart(segId: string): void {
    const j = this.current;
    if (j === undefined || j.segId !== segId || j.started) {
      return;
    }
    j.started = true;
    this.logStart(j, Date.now() - j.t0);
    this.emitStart(j.u.id);
  }

  private onSegmentDone(segId: string, bytes: number): void {
    const j = this.current;
    if (j === undefined || j.segId !== segId) {
      return;
    }
    this.complete(j, 0, bytes);
  }

  private logStart(j: Job, latencyMs: number): void {
    Log.i(LogEvents.UTT_START, `id=${j.u.id} item=${j.u.itemId} lang=${j.u.lang} mode=voice` +
      ` engine=${j.plan.engineLocale}/${j.plan.person} ctx=${j.plan.languageContext} label=${j.plan.label}` +
      ` latencyMs=${latencyMs}`);
  }

  /** code 0 = done; otherwise an error. Exactly once per job. */
  private complete(job: Job, code: number, knownBytes: number = -1): void {
    if (job.finished) {
      return;
    }
    job.finished = true;
    const bytes = knownBytes >= 0 ? knownBytes : this.pcm.bytesOf(job.segId);
    this.clearSynthTimer(job);
    this.clearWatchdog(job);
    if (job.textTimer >= 0) {
      clearTimeout(job.textTimer);
      job.textTimer = -1;
    }
    if (this.current === job) {
      this.current = undefined;
    }
    this.engines.forget(job.reqId);
    if (!this.systemPlayback) {
      this.pcm.drop(job.segId);
    }
    if (code === 0) {
      Log.i(LogEvents.UTT_DONE, `id=${job.u.id} item=${job.u.itemId} result=ok ms=${Date.now() - job.t0}` +
        ` label=${job.plan.label}${bytes > 0 ? ` audioMs=${pcmDurationMs(bytes)}` : ''}`);
      if (!job.started) {
        this.emitStart(job.u.id);
      }
      this.emitDone(job.u.id);
    } else {
      Log.e(LogEvents.UTT_DONE, `id=${job.u.id} item=${job.u.itemId} result=error code=${code}`);
      this.emitError(job.u.id, code);
    }
  }

  /** Cancels a job without reporting it (preempt / stop / prefetch replaced). */
  private discard(job: Job, why: string): void {
    job.finished = true;
    this.clearSynthTimer(job);
    this.clearWatchdog(job);
    if (job.textTimer >= 0) {
      clearTimeout(job.textTimer);
      job.textTimer = -1;
    }
    this.engines.forget(job.reqId);
    this.pcm.drop(job.segId);
    Log.d(LogEvents.STORY_QUEUE, `event=discard id=${job.u.id} why=${why}`);
  }

  /** Playback must end within the audio length + margin; otherwise finish it anyway (never hang the tour). */
  private armWatchdog(job: Job): void {
    this.clearWatchdog(job);
    const audioMs = this.systemPlayback ? estimateReadingMs(job.u.text) * 2 : pcmDurationMs(this.pcm.bytesOf(job.segId));
    const ms = audioMs + WATCHDOG_MARGIN_MS;
    job.watchdog = setTimeout(() => {
      job.watchdog = -1;
      if (this.current === job && !job.finished && !this.paused) {
        Log.w(LogEvents.TTS_ERR, `id=${job.u.id} code=${TtsErr.WATCHDOG} msg=playback end not seen after ${ms}ms`);
        this.complete(job, 0);
      }
    }, ms);
  }

  private clearWatchdog(job: Job): void {
    if (job.watchdog >= 0) {
      clearTimeout(job.watchdog);
      job.watchdog = -1;
    }
  }

  private clearSynthTimer(job: Job): void {
    if (job.synthTimer >= 0) {
      clearTimeout(job.synthTimer);
      job.synthTimer = -1;
    }
  }

  private onInterrupt(hint: number, force: number): void {
    try {
      if (hint === HINT_PAUSE || hint === HINT_STOP) {
        this.pause();
      } else if (hint === HINT_RESUME) {
        this.resume();
      }
      // DUCK / UNDUCK / MUTE: the system handles them; PcmPlayer already logged AUDIO_INTERRUPT.
      const name = interruptHintName(hint);
      const l = this.audioListener;
      if (name !== '' && l !== undefined) {
        l.onInterrupt(name);             // the tour pauses (stopNow) and replays the sentence on RESUME
      }
    } catch (e) {
      Log.e(LogEvents.UNCAUGHT, `where=NarrationPlayer.onInterrupt hint=${hint} ${Log.errKv(e as Object)}`);
    }
  }

  private onRouteChange(reason: number, devices: string): void {
    try {
      if (reason !== REASON_OLD_DEVICE_UNAVAILABLE) {
        return;
      }
      Log.i(LogEvents.AUDIO_ROUTE, `event=headphones_removed action=pause devices=${devices}` +
        ` speaking=${this.current !== undefined}`);
      if (this.current !== undefined) {
        this.pause();
      }
      const l = this.audioListener;
      if (l !== undefined) {
        l.onRouteLost(devices);          // also when idle: the next story must not start on the loudspeaker
      }
    } catch (e) {
      Log.e(LogEvents.UNCAUGHT, `where=NarrationPlayer.onRouteChange ${Log.errKv(e as Object)}`);
    }
  }

  private onRendererError(segId: string, code: number, where: string): void {
    const j = this.current;
    Log.e(LogEvents.TTS_ERR, `code=${TtsErr.RENDERER} renderer_code=${code} where=${where}`);
    if (j !== undefined && j.segId === segId) {
      this.complete(j, TtsErr.RENDERER);
    }
  }

  private emitStart(id: string): void {
    try {
      this.listener?.onUtteranceStart(id);
    } catch (e) {
      Log.e(LogEvents.UNCAUGHT, `where=listener.onUtteranceStart ${Log.errKv(e as Object)}`);
    }
  }

  private emitDone(id: string): void {
    try {
      this.listener?.onUtteranceDone(id);
    } catch (e) {
      Log.e(LogEvents.UNCAUGHT, `where=listener.onUtteranceDone ${Log.errKv(e as Object)}`);
    }
  }

  private emitError(id: string, code: number): void {
    try {
      this.listener?.onUtteranceError(id, code);
    } catch (e) {
      Log.e(LogEvents.UNCAUGHT, `where=listener.onUtteranceError ${Log.errKv(e as Object)}`);
    }
  }
}

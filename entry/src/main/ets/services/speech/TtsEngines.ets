/*
 * Core Speech Kit engines (docs/ARCHITECTURE.md §2.5, task A4). One lazily created engine per (locale, person),
 * kept alive for the app's lifetime (AppContainer), so a page going away never kills it (FAQ faqs-core-speech-1).
 *
 * - createEngine(params): Promise, online:1 (offline only), extraParams style/locate/name/isBackStage.
 *   `name` is fixed and unique per engine ("citytour-zh" / "citytour-en"): the docs forbid random names and a
 *   shared name lets shutdown() of one engine kill the other. isBackStage:true allows background speech.
 * - One SpeakListener per engine routes callbacks to the handler registered for each requestId. Each requestId
 *   is used once (VERIFIED, RISKS); late callbacks for a forgotten id are ignored.
 * - A failed createEngine is remembered per engine (en-US/8 fails with 1002300005 on the emulator, RISKS a4), so
 *   we do not retry it for every sentence; clearFailure() after a successful download.
 * - listVoices / downloadVoice wrappers with explicit timeouts.
 * Docs: API参考/Core_Speech_Kit_基础语音服务/ArkTS_API/textToSpeech_文本转语音/hms-ai-texttospeech
 *   (createEngine/speak/stop/isBusy/shutdown since 4.1.0(11); listVoices, downloadVoice, onData since 5.1.1(19):
 *   all at or below our minimum API 20, so no canIUse guard is needed). No permission is listed for
 *   downloadVoice, and the model download is done by the system service, so we do not request INTERNET.
 */
import { textToSpeech } from '@kit.CoreSpeechKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { AppConfig } from '../../app/AppConfig';
import { Log } from '../../app/Log';
import { LogEvents } from 'common';

/** Our own error codes (negative, so they never collide with the kit's 1002300xxx codes). */
export class TtsErr {
  static readonly TIMEOUT: number = -2;
  static readonly ENGINE_UNAVAILABLE: number = -3;
  static readonly THREW: number = -4;
  static readonly RENDERER: number = -5;
  static readonly WATCHDOG: number = -6;
  /** Kit: createEngine failed because the voice model is not on the device (RISKS a4). */
  static readonly KIT_ENGINE_CREATE: number = 1002300005;
  /** Kit: downloadVoice failed (RISKS a5). */
  static readonly KIT_DL_FAILED: number = 1002300008;
  /** Kit: the voice is already downloaded, which counts as success. */
  static readonly KIT_DL_ALREADY: number = 1002300010;
}

export const ENGINE_CREATE_TIMEOUT_MS: number = 6000;
export const LIST_VOICES_TIMEOUT_MS: number = 5000;
export const DOWNLOAD_TIMEOUT_MS: number = 300000; // the system dialog waits for the user

/** Per-request callbacks; NarrationPlayer implements one per synthesis. */
export interface TtsRequestHandler {
  onStart: (sampleRate: number, channels: number) => void;
  onData: (audio: ArrayBuffer, sequence: number) => void;
  onComplete: (type: number) => void;   // 0 = synthesis finished, 1 = playback finished (playType 1 only)
  onStop: () => void;
  onError: (code: number, message: string) => void;
}

export interface DownloadCallbacks {
  onStart: () => void;
  onProgress: (pct: number) => void;
  onComplete: () => void;
  onCancel: () => void;
  onError: (code: number, message: string) => void;
}

class EngineSlot {
  engine: textToSpeech.TextToSpeechEngine | undefined = undefined;
  creating: Promise<textToSpeech.TextToSpeechEngine> | undefined = undefined;
  failCode: number = 0;
  failMsg: string = '';
}

export function errCode(e: Object | undefined | null): number {
  if (e === undefined || e === null) {
    return -1;
  }
  const c = (e as BusinessError).code;
  return typeof c === 'number' ? c : -1;
}

export function errMsg(e: Object | undefined | null): string {
  if (e === undefined || e === null) {
    return 'unknown';
  }
  const m = (e as BusinessError).message;
  return typeof m === 'string' ? m : 'unknown';
}

/** Rejects with {code: TtsErr.TIMEOUT} if p does not settle within ms. */
export function withTimeout<T>(p: Promise<T>, ms: number, what: string): Promise<T> {
  return new Promise<T>((resolve, reject) => {
    let settled = false;
    const t = setTimeout(() => {
      if (!settled) {
        settled = true;
        const err: BusinessError = { code: TtsErr.TIMEOUT, message: `${what} timeout ${ms}ms`, name: 'Timeout' };
        reject(err);
      }
    }, ms);
    p.then((v: T) => {
      if (!settled) {
        settled = true;
        clearTimeout(t);
        resolve(v);
      }
    }).catch((e: Object) => {
      if (!settled) {
        settled = true;
        clearTimeout(t);
        reject(e);
      }
    });
  });
}

export class TtsEngines {
  private slots: Map<string, EngineSlot> = new Map<string, EngineSlot>();
  private handlers: Map<string, TtsRequestHandler> = new Map<string, TtsRequestHandler>();
  private seq: number = 0;

  static key(locale: string, person: number): string {
    return `${locale}/${person}`;
  }

  /** Unique per call: "<tag>#<ms>#<n>" (requestIds may be used only once). */
  newRequestId(tag: string): string {
    this.seq++;
    return `${tag}#${Date.now()}#${this.seq}`;
  }

  /** 0 when the engine has not failed (or was never tried). */
  failure(locale: string, person: number): number {
    const s = this.slots.get(TtsEngines.key(locale, person));
    return s !== undefined ? s.failCode : 0;
  }

  clearFailure(locale: string, person: number): void {
    const s = this.slots.get(TtsEngines.key(locale, person));
    if (s !== undefined && s.engine === undefined) {
      this.slots.delete(TtsEngines.key(locale, person));
    }
  }

  isReady(locale: string, person: number): boolean {
    const s = this.slots.get(TtsEngines.key(locale, person));
    return s !== undefined && s.engine !== undefined;
  }

  /** Lazily creates the engine; resolves the cached one; rejects (code) on failure or timeout. */
  get(locale: string, person: number): Promise<textToSpeech.TextToSpeechEngine> {
    const k = TtsEngines.key(locale, person);
    let slot = this.slots.get(k);
    if (slot === undefined) {
      slot = new EngineSlot();
      this.slots.set(k, slot);
    }
    const s: EngineSlot = slot;
    if (s.engine !== undefined) {
      return Promise.resolve(s.engine);
    }
    if (s.failCode !== 0) {
      const err: BusinessError = { code: s.failCode, message: `cached failure ${s.failMsg}`, name: 'EngineFailed' };
      return Promise.reject(err);
    }
    if (s.creating === undefined) {
      s.creating = this.create(k, locale, person, s);
    }
    // The timeout only bounds this caller's wait: a late engine is still stored (no leaked instance, max 3 per device).
    return withTimeout<textToSpeech.TextToSpeechEngine>(s.creating, ENGINE_CREATE_TIMEOUT_MS, 'createEngine');
  }

  private create(k: string, locale: string, person: number, s: EngineSlot): Promise<textToSpeech.TextToSpeechEngine> {
    const name = `${locale.toLowerCase().startsWith('zh') ? 'citytour-zh' : 'citytour-en'}-${person}`;
    const extra: Record<string, Object> = {
      'style': 'interaction-broadcast', 'locate': 'CN', 'name': name, 'isBackStage': true
    };
    const params: textToSpeech.CreateEngineParams = { language: locale, person: person, online: 1, extraParams: extra };
    const t0 = Date.now();
    let created: Promise<textToSpeech.TextToSpeechEngine>;
    if (AppConfig.DEBUG_FAIL_TTS_INIT) {
      // §9 row 9 demo: the same rejection the emulator gives for a missing voice model (RISKS a4).
      const sim: BusinessError = {
        code: TtsErr.KIT_ENGINE_CREATE, message: 'simulated src=debug (AppConfig.DEBUG_FAIL_TTS_INIT)', name: 'Debug'
      };
      created = Promise.reject(sim);
    } else {
      try {
        created = textToSpeech.createEngine(params);
      } catch (e) {
        created = Promise.reject(e);
      }
    }
    return created.then((eng: textToSpeech.TextToSpeechEngine) => {
      s.creating = undefined;
      try {
        eng.setListener(this.listenerFor(k));
      } catch (e) {
        Log.w(LogEvents.TTS_ERR, `where=setListener engine=${k} ${Log.errKv(e as Object)}`);
      }
      s.engine = eng;
      Log.i(LogEvents.TTS_INIT, `engine=${k} name=${name} ms=${Date.now() - t0} backstage=true`);
      return eng;
    }).catch((e: Object) => {
      s.creating = undefined;
      s.failCode = errCode(e);
      s.failMsg = errMsg(e);
      Log.e(LogEvents.TTS_INIT_FAIL, `engine=${k} code=${s.failCode} msg=${s.failMsg} ms=${Date.now() - t0}`);
      return Promise.reject(e);
    });
  }

  /**
   * Starts one synthesis. Never throws: every failure (engine missing, speak threw) arrives as h.onError.
   * extraParams follow SpeakParams (playType, queueMode, speed, pitch, volume, languageContext, audioType).
   */
  speak(locale: string, person: number, text: string, requestId: string, extra: Record<string, Object>,
    h: TtsRequestHandler): void {
    this.handlers.set(requestId, h);
    this.get(locale, person).then((eng: textToSpeech.TextToSpeechEngine) => {
      if (!this.handlers.has(requestId)) {
        return; // cancelled while the engine was being created
      }
      const sp: textToSpeech.SpeakParams = { requestId: requestId, extraParams: extra };
      try {
        eng.speak(text, sp);
      } catch (e) {
        this.fail(requestId, errCode(e as Object) !== -1 ? errCode(e as Object) : TtsErr.THREW, errMsg(e as Object));
      }
    }).catch((e: Object) => {
      this.fail(requestId, errCode(e) !== -1 ? errCode(e) : TtsErr.ENGINE_UNAVAILABLE, errMsg(e));
    });
  }

  /** Stop callbacks for this request reaching anyone (the engine may still call back; ignored). */
  forget(requestId: string): void {
    this.handlers.delete(requestId);
  }

  /** engine.stop(): ends synthesis and playback of everything queued on that engine. */
  stop(locale: string, person: number): void {
    const s = this.slots.get(TtsEngines.key(locale, person));
    if (s === undefined || s.engine === undefined) {
      return;
    }
    try {
      s.engine.stop();
    } catch (e) {
      Log.w(LogEvents.TTS_ERR, `where=stop engine=${TtsEngines.key(locale, person)} ${Log.errKv(e as Object)}`);
    }
  }

  stopAll(): void {
    this.slots.forEach((s: EngineSlot, k: string) => {
      if (s.engine !== undefined) {
        try {
          s.engine.stop();
        } catch (e) {
          Log.w(LogEvents.TTS_ERR, `where=stopAll engine=${k} ${Log.errKv(e as Object)}`);
        }
      }
    });
  }

  shutdownAll(): void {
    this.handlers.clear();
    this.slots.forEach((s: EngineSlot, k: string) => {
      if (s.engine !== undefined) {
        try {
          s.engine.shutdown();
        } catch (e) {
          Log.w(LogEvents.TTS_ERR, `where=shutdown engine=${k} ${Log.errKv(e as Object)}`);
        }
      }
    });
    this.slots.clear();
  }

  /** listVoices({online:1}) with a timeout. Rejects with the kit error or TIMEOUT. */
  listVoices(): Promise<textToSpeech.VoiceInfo[]> {
    let p: Promise<textToSpeech.VoiceInfo[]>;
    try {
      const q: textToSpeech.VoiceQuery = { requestId: this.newRequestId('voices'), online: 1 };
      p = textToSpeech.listVoices(q);
    } catch (e) {
      p = Promise.reject(e);
    }
    return withTimeout<textToSpeech.VoiceInfo[]>(p, LIST_VOICES_TIMEOUT_MS, 'listVoices');
  }

  /**
   * downloadVoice: shows the system "Download language package?" dialog. Callbacks fire at most once for the
   * terminal events (complete / cancel / error / timeout).
   */
  downloadVoice(locale: string, person: number, cb: DownloadCallbacks): void {
    let done = false;
    let timer: number = -1;
    const finish = (): boolean => {
      if (done) {
        return false;
      }
      done = true;
      clearTimeout(timer);
      return true;
    };
    timer = setTimeout(() => {
      if (finish()) {
        cb.onError(TtsErr.TIMEOUT, `downloadVoice timeout ${DOWNLOAD_TIMEOUT_MS}ms`);
      }
    }, DOWNLOAD_TIMEOUT_MS);
    const d: textToSpeech.VoiceDownload = {
      requestId: this.newRequestId('dl'), language: locale, person: person, style: 'interaction-broadcast'
    };
    try {
      textToSpeech.downloadVoice(d, (e: BusinessError, resp: textToSpeech.DownloadResponse) => {
        if (e) {
          if (finish()) {
            cb.onError(errCode(e), errMsg(e));
          }
          return;
        }
        if (resp === undefined || resp === null) {
          if (finish()) {
            cb.onError(-1, 'downloadResponse is null');
          }
          return;
        }
        try {
          resp.on('start', (info: string) => {
            if (!done) {
              cb.onStart();
            }
          });
          resp.on('progress', (schedule: string) => {
            const pct = Number.parseFloat(schedule);
            if (!done && !Number.isNaN(pct)) {
              cb.onProgress(pct);
            }
          });
          resp.on('complete', (v: textToSpeech.VoiceInfo) => {
            if (finish()) {
              cb.onComplete();
            }
          });
          resp.on('cancel', (info: string) => {
            if (finish()) {
              cb.onCancel();
            }
          });
          resp.on('error', (x: BusinessError) => {
            if (finish()) {
              cb.onError(errCode(x), errMsg(x));
            }
          });
        } catch (ex) {
          if (finish()) {
            cb.onError(errCode(ex as Object), errMsg(ex as Object));
          }
        }
      });
    } catch (e) {
      if (finish()) {
        cb.onError(errCode(e as Object), errMsg(e as Object));
      }
    }
  }

  private fail(requestId: string, code: number, msg: string): void {
    const h = this.handlers.get(requestId);
    this.handlers.delete(requestId);
    if (h !== undefined) {
      try {
        h.onError(code, msg);
      } catch (e) {
        Log.e(LogEvents.UNCAUGHT, `where=TtsEngines.fail ${Log.errKv(e as Object)}`);
      }
    }
  }

  private listenerFor(engineKey: string): textToSpeech.SpeakListener {
    const l: textToSpeech.SpeakListener = {
      onStart: (id: string, r: textToSpeech.StartResponse) => {
        const h = this.handlers.get(id);
        if (h !== undefined) {
          h.onStart(r.sampleRate, r.audioChannel);
        }
      },
      onData: (id: string, audio: ArrayBuffer, r: textToSpeech.SynthesisResponse) => {
        const h = this.handlers.get(id);
        if (h !== undefined) {
          h.onData(audio, r.sequence);
        }
      },
      onComplete: (id: string, r: textToSpeech.CompleteResponse) => {
        const h = this.handlers.get(id);
        if (h !== undefined) {
          h.onComplete(r.type);
        }
      },
      onStop: (id: string, r: textToSpeech.StopResponse) => {
        const h = this.handlers.get(id);
        if (h !== undefined) {
          this.handlers.delete(id);
          h.onStop();
        }
      },
      onError: (id: string, code: number, msg: string) => {
        const h = this.handlers.get(id);
        if (h !== undefined) {
          this.handlers.delete(id);
          h.onError(code, msg);
        } else {
          Log.w(LogEvents.TTS_ERR, `engine=${engineKey} req=unknown code=${code} msg=${msg}`);
        }
      }
    };
    return l;
  }
}

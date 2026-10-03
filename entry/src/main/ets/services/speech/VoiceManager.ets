/*
 * VoicePort implementation (docs/PLAN.md §0.4, ARCHITECTURE §2.5 "Voice availability", task A4).
 *
 * - capabilities(): listVoices({online:1}) -> SpeechCapabilities via the pure capsFromVoices (GA -> DOWNLOADABLE).
 *   Logs VOICE_STATUS. A listVoices failure/timeout gives ERROR (the zh voice is then still tried).
 * - plan(textLang): pure resolveVoicePlan(textLang, strategy, caps) + a VOICE_PLAN log line for every decision.
 * - downloadEnglish(): the real downloadVoice path for Laura (en-US/8). 1002300010 (already downloaded) counts as
 *   success; 1002300008 (failed, what the emulator returns, RISKS a5) logs VOICE_DL_FAIL and the plan stays on the
 *   fallback. After a success we re-query listVoices, so the next plan resolves to NATIVE automatically.
 * - markEngineFailed(): a voice that listVoices calls INSTALLED but whose createEngine fails is downgraded, so the
 *   next plan falls back instead of failing every sentence.
 * The default strategy comes from AppConfig.DEFAULT_EN_VOICE_STRATEGY (AUTO_NATIVE_THEN_ZH, user decision); gate G1
 * can flip it there or at runtime via setStrategy() (Settings B9 / DevPanel).
 * Docs: API参考/Core_Speech_Kit_基础语音服务/ArkTS_API/textToSpeech_文本转语音/hms-ai-texttospeech
 */
import { textToSpeech } from '@kit.CoreSpeechKit';
import { Lang } from '../../contracts/Model';
import { EnVoiceStrategy, VoiceLabel, VoiceLang } from '../../contracts/Settings';
import { SpeechCapabilities, VoicePlan, VoicePort, VoiceState } from '../../contracts/Ports';
import {
  capsFromVoices, DEFAULT_FALLBACK_EN_CONTEXT, EN_LOCALE, EN_PERSON, planLogKv, resolveVoicePlan, stateTag,
  VoiceEntry, VoicePolicyOptions, ZH_LOCALE
} from '../../core/speech/VoicePolicy';
import { AppConfig } from '../../app/AppConfig';
import { Log } from '../../app/Log';
import { LogEvents } from '../../app/LogEvents';
import { DownloadCallbacks, errCode, errMsg, TtsEngines, TtsErr } from './TtsEngines';

export class VoiceManager implements VoicePort {
  private engines: TtsEngines;
  private caps: SpeechCapabilities = { en: VoiceState.ERROR, zh: VoiceState.ERROR };
  private capsKnown: boolean = false;
  private querying: Promise<SpeechCapabilities> | undefined = undefined;
  private strategyValue: EnVoiceStrategy = AppConfig.DEFAULT_EN_VOICE_STRATEGY;
  private voiceLangValue: VoiceLang | undefined = undefined;
  private fallbackCtx: string = DEFAULT_FALLBACK_EN_CONTEXT;
  private enEngineFail: number = 0;
  private zhEngineFail: number = 0;
  private downloading: boolean = false;
  private lastDlCode: number = 0;

  constructor(engines: TtsEngines) {
    this.engines = engines;
  }

  // ---------- VoicePort ----------

  /** Cached after the first successful query; refresh(true) forces a new listVoices. Never rejects. */
  capabilities(): Promise<SpeechCapabilities> {
    if (this.capsKnown) {
      return Promise.resolve(this.effectiveCaps());
    }
    return this.refresh();
  }

  plan(textLang: Lang): VoicePlan {
    const opts: VoicePolicyOptions = { voiceLang: this.voiceLangValue, fallbackEnContext: this.fallbackCtx };
    let p: VoicePlan;
    try {
      p = resolveVoicePlan(textLang, this.strategyValue, this.effectiveCaps(), opts);
    } catch (e) {
      Log.e(LogEvents.UNCAUGHT, `where=VoiceManager.plan ${Log.errKv(e as Object)}`);
      const t: VoicePlan = {
        textLang: textLang, speechMode: 'text', engineLocale: '', person: 0, languageContext: '',
        label: VoiceLabel.TEXT_ONLY_PLATFORM, reason: 'policy_threw'
      };
      p = t;
    }
    Log.i(LogEvents.VOICE_PLAN, `${planLogKv(p)} caps_known=${this.capsKnown}`);
    return p;
  }

  downloadEnglish(onProgress: (pct: number) => void): Promise<boolean> {
    if (this.downloading) {
      Log.w(LogEvents.VOICE_DL_FAIL, 'code=busy msg=download already running');
      return Promise.resolve(false);
    }
    if (this.caps.en === VoiceState.INSTALLED && this.enEngineFail === 0) {
      Log.i(LogEvents.VOICE_STATUS, 'event=download_skipped en=INSTALLED');
      return Promise.resolve(true);
    }
    this.downloading = true;
    Log.i(LogEvents.VOICE_STATUS, `event=download_start lang=${EN_LOCALE} person=${EN_PERSON}`);
    return new Promise<boolean>((resolve) => {
      const cb: DownloadCallbacks = {
        onStart: () => {
          Log.i(LogEvents.VOICE_STATUS, 'event=download_started');
        },
        onProgress: (pct: number) => {
          try {
            onProgress(pct);
          } catch (e) {
            Log.w(LogEvents.UNCAUGHT, `where=downloadEnglish.onProgress ${Log.errKv(e as Object)}`);
          }
        },
        onComplete: () => {
          this.lastDlCode = 0;
          this.afterDownloadOk('complete').then(() => resolve(true));
        },
        onCancel: () => {
          this.downloading = false;
          this.lastDlCode = -7;
          Log.w(LogEvents.VOICE_DL_FAIL, 'code=cancelled msg=user cancelled the download dialog');
          this.plan(Lang.EN);
          resolve(false);
        },
        onError: (code: number, msg: string) => {
          if (code === TtsErr.KIT_DL_ALREADY) {
            this.lastDlCode = 0;
            this.afterDownloadOk('already_downloaded').then(() => resolve(true));
            return;
          }
          this.downloading = false;
          this.lastDlCode = code;
          Log.e(LogEvents.VOICE_DL_FAIL, `code=${code} msg=${msg}`);
          this.plan(Lang.EN); // logs that the plan stays on the fallback
          resolve(false);
        }
      };
      this.engines.downloadVoice(EN_LOCALE, EN_PERSON, cb);
    });
  }

  setStrategy(s: EnVoiceStrategy): void {
    if (s === this.strategyValue) {
      return;
    }
    Log.i(LogEvents.SETTINGS, `key=enVoiceStrategy from=${this.strategyValue} to=${s}`);
    this.strategyValue = s;
  }

  // ---------- extras (Settings B9, Onboarding A12, DevPanel) ----------

  strategy(): EnVoiceStrategy {
    return this.strategyValue;
  }

  setVoiceLang(v: VoiceLang | undefined): void {
    this.voiceLangValue = v;
  }

  /** languageContext for the zh voice reading English: 'en-US' (default) or 'zh-CN' (G1 A/B). */
  setFallbackEnContext(ctx: string): void {
    this.fallbackCtx = ctx === ZH_LOCALE ? ZH_LOCALE : EN_LOCALE;
    Log.i(LogEvents.SETTINGS, `key=fallbackEnContext to=${this.fallbackCtx}`);
  }

  fallbackEnContext(): string {
    return this.fallbackCtx;
  }

  lastCaps(): SpeechCapabilities {
    return this.effectiveCaps();
  }

  isDownloading(): boolean {
    return this.downloading;
  }

  /** 0 = no failure yet / success, else the last download error code (1002300008 on the emulator). */
  lastDownloadCode(): number {
    return this.lastDlCode;
  }

  /** Called by NarrationPlayer when createEngine fails for a voice the plan picked. */
  markEngineFailed(locale: string, person: number, code: number): void {
    if (locale === EN_LOCALE) {
      this.enEngineFail = code !== 0 ? code : -1;
    } else {
      this.zhEngineFail = code !== 0 ? code : -1;
    }
    const c = this.effectiveCaps();
    Log.w(LogEvents.VOICE_STATUS,
      `event=engine_failed engine=${locale}/${person} code=${code} en=${stateTag(c.en)} zh=${stateTag(c.zh)}`);
  }

  /** listVoices now (also after a download). Never rejects. */
  refresh(): Promise<SpeechCapabilities> {
    if (this.querying !== undefined) {
      return this.querying;
    }
    const t0 = Date.now();
    this.querying = this.engines.listVoices().then((voices: textToSpeech.VoiceInfo[]) => {
      const entries: VoiceEntry[] = [];
      const desc: string[] = [];
      for (const v of voices) {
        const e: VoiceEntry = { language: v.language, person: v.person, status: v.status };
        entries.push(e);
        desc.push(`${v.language}/${v.person}/${v.status !== undefined ? v.status : '?'}`);
      }
      this.caps = capsFromVoices(entries);
      this.capsKnown = true;
      this.querying = undefined;
      const c = this.effectiveCaps();
      Log.i(LogEvents.VOICE_STATUS, `en=${stateTag(c.en)} zh=${stateTag(c.zh)} src=listVoices ms=${Date.now() - t0}` +
        ` voices=${desc.join(',')}`);
      return c;
    }).catch((e: Object) => {
      this.querying = undefined;
      this.caps = { en: VoiceState.ERROR, zh: VoiceState.ERROR };
      Log.e(LogEvents.VOICE_STATUS, `en=ERROR zh=ERROR src=listVoices code=${errCode(e)} msg=${errMsg(e)}`);
      return this.effectiveCaps();
    });
    return this.querying;
  }

  private effectiveCaps(): SpeechCapabilities {
    const c: SpeechCapabilities = {
      en: this.enEngineFail !== 0 && this.caps.en === VoiceState.INSTALLED ? VoiceState.ERROR : this.caps.en,
      zh: this.zhEngineFail !== 0 ? VoiceState.UNAVAILABLE : this.caps.zh
    };
    return c;
  }

  private afterDownloadOk(how: string): Promise<void> {
    this.enEngineFail = 0;
    this.engines.clearFailure(EN_LOCALE, EN_PERSON);
    Log.i(LogEvents.VOICE_STATUS, `event=download_ok how=${how}`);
    return this.refresh().then(() => {
      this.downloading = false;
      this.plan(Lang.EN);
    });
  }
}

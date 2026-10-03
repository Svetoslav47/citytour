/*
 * Build-time switches. One place to flip a strategy without touching feature code (PLAN §0.4).
 */
import { EnVoiceStrategy } from '../contracts/Settings';

export class AppConfig {
  static readonly APP_VERSION: string = '1.0.0'; // keep equal to AppScope/app.json5 versionName

  /** User decision 2026-10-03: Laura if installed, else the zh-CN voice reads English ("Fallback voice"). */
  static readonly DEFAULT_EN_VOICE_STRATEGY: EnVoiceStrategy = EnVoiceStrategy.AUTO_NATIVE_THEN_ZH;

  /** Emergency switch (RISKS T7): true = TTS playType 1 (system playback) instead of our PCM AudioRenderer. */
  static readonly USE_SYSTEM_PLAYBACK: boolean = false;

  /** Demo walk replay speed multiplier (1 | 2 | 4 | 8). */
  static readonly DEMO_DEFAULT_SPEED: number = 4;

  /** ScriptedTourControl (the UI fake) advances one snapshot every this many ms at speed 1. */
  static readonly SCRIPTED_STEP_MS: number = 2000;

  /** Launch parameter that opens the developer page: `aa start ... --ps page dev`. */
  static readonly LAUNCH_PARAM_PAGE: string = 'page';
  static readonly LAUNCH_PAGE_DEV: string = 'dev';
}

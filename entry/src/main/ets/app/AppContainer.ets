/*
 * Composition root (docs/ARCHITECTURE.md §1.2 lifecycle, §12.1). EntryAbility calls init() in onCreate and
 * shutdown() in onDestroy. init() builds services but starts nothing. ViewModels read the getters only.
 * T0 wiring: tourControl() = ScriptedTourControl (SIMULATED) until A7; voice() and permissions() return
 * safe stubs until A4 / A5. UIAbilityContext: doc 开发指南/Ability_Kit_程序框架服务/应用模型/应用组件/UIAbility组件/
 * 启动应用内的UIAbility组件/uiability-intra-device-interaction.
 */
import { common } from '@kit.AbilityKit';
import { Lang } from '../contracts/Model';
import { EnVoiceStrategy, VoiceLabel } from '../contracts/Settings';
import {
  Clock, LoggerPort, PackRepository, PermissionPort, PermissionState, SpeechCapabilities, TourControl, VoicePlan,
  VoicePort, VoiceState
} from '../contracts/Ports';
import { PackFactory } from '../services/pack/PackFactory';
import { ScriptedTourControl } from '../services/tour/ScriptedTourControl';
import { AppConfig } from './AppConfig';
import { SystemClock } from './Clock';
import { HilogLogger, Log } from './Log';
import { LogEvents } from './LogEvents';

/** Until A4: no engine, text only, honest label. */
class StubVoicePort implements VoicePort {
  private strategy: EnVoiceStrategy = AppConfig.DEFAULT_EN_VOICE_STRATEGY;

  capabilities(): Promise<SpeechCapabilities> {
    const caps: SpeechCapabilities = { en: VoiceState.UNAVAILABLE, zh: VoiceState.UNAVAILABLE };
    return Promise.resolve(caps);
  }

  plan(textLang: Lang): VoicePlan {
    const p: VoicePlan = {
      textLang: textLang, speechMode: 'text', engineLocale: '', person: 0, languageContext: '',
      label: VoiceLabel.TEXT_ONLY_PLATFORM, reason: `stub strategy=${this.strategy}`
    };
    return p;
  }

  downloadEnglish(onProgress: (pct: number) => void): Promise<boolean> {
    return Promise.resolve(false);
  }

  setStrategy(s: EnVoiceStrategy): void {
    this.strategy = s;
  }
}

/** Until A5: reports UNKNOWN and never opens a dialog. */
class StubPermissionPort implements PermissionPort {
  locationState(): Promise<PermissionState> {
    return Promise.resolve(PermissionState.UNKNOWN);
  }

  requestLocation(): Promise<PermissionState> {
    return Promise.resolve(PermissionState.UNKNOWN);
  }

  openLocationSettings(): Promise<PermissionState> {
    return Promise.resolve(PermissionState.UNKNOWN);
  }

  isLocationSwitchOn(): boolean {
    return false;
  }

  requestLocationSwitch(): Promise<boolean> {
    return Promise.resolve(false);
  }
}

export class AppContainer {
  private static ctx: common.UIAbilityContext | undefined = undefined;
  private static clockImpl: Clock = new SystemClock();
  private static loggerImpl: LoggerPort = new HilogLogger();
  private static packImpl: PackRepository | undefined = undefined;
  private static tourImpl: ScriptedTourControl | undefined = undefined;
  private static voiceImpl: VoicePort | undefined = undefined;
  private static permImpl: PermissionPort | undefined = undefined;

  /** Idempotent. Builds services; starts nothing. */
  static init(ctx: common.UIAbilityContext): void {
    if (AppContainer.ctx !== undefined) {
      return;
    }
    AppContainer.ctx = ctx;
    try {
      AppContainer.packImpl = PackFactory.create();
      AppContainer.tourImpl = new ScriptedTourControl();
      AppContainer.voiceImpl = new StubVoicePort();
      AppContainer.permImpl = new StubPermissionPort();
    } catch (e) {
      Log.e(LogEvents.UNCAUGHT, `where=AppContainer.init ${Log.errKv(e as Object)}`);
    }
  }

  static shutdown(): void {
    try {
      if (AppContainer.tourImpl !== undefined) {
        AppContainer.tourImpl.dispose();
      }
    } catch (e) {
      Log.e(LogEvents.UNCAUGHT, `where=AppContainer.shutdown ${Log.errKv(e as Object)}`);
    }
    AppContainer.tourImpl = undefined;
    AppContainer.packImpl = undefined;
    AppContainer.voiceImpl = undefined;
    AppContainer.permImpl = undefined;
    AppContainer.ctx = undefined;
  }

  static isReady(): boolean {
    return AppContainer.ctx !== undefined;
  }

  static context(): common.UIAbilityContext | undefined {
    return AppContainer.ctx;
  }

  static clock(): Clock {
    return AppContainer.clockImpl;
  }

  static logger(): LoggerPort {
    return AppContainer.loggerImpl;
  }

  static packKind(): string {
    return PackFactory.kind();
  }

  static tourControl(): TourControl {
    if (AppContainer.tourImpl === undefined) {
      AppContainer.tourImpl = new ScriptedTourControl();
    }
    return AppContainer.tourImpl;
  }

  static packRepository(): PackRepository {
    if (AppContainer.packImpl === undefined) {
      AppContainer.packImpl = PackFactory.create();
    }
    return AppContainer.packImpl;
  }

  static voice(): VoicePort {
    if (AppContainer.voiceImpl === undefined) {
      AppContainer.voiceImpl = new StubVoicePort();
    }
    return AppContainer.voiceImpl;
  }

  static permissions(): PermissionPort {
    if (AppContainer.permImpl === undefined) {
      AppContainer.permImpl = new StubPermissionPort();
    }
    return AppContainer.permImpl;
  }
}

/*
 * Composition root (docs/ARCHITECTURE.md §1.2 lifecycle, §12.1). EntryAbility calls init() in onCreate and
 * shutdown() in onDestroy. init() builds services but starts nothing. ViewModels read the getters only.
 * A5 wiring: permissions() = PermissionService (location permission + switch), realLocation() = RealLocationSource
 * (Location Kit), demoWalk() = DemoWalkSource (SIMULATED track replay). Built in init(), started by their users.
 * A7 wiring: tourControl() = TourController (engine + Planner + speech + background() + mediaSession() +
 * realLocation()/demoWalk() + permissions()). DemoWalkSource reaches the controller's DemoControls through
 * DemoWalkControls. Notifier/haptics (A8) are not merged yet: provided as `undefined`, which the controller treats
 * as a logged no-op. ScriptedTourControl stays for UI previews (scriptedTourControl()).
 * A4 wiring: voice() = VoiceManager (listVoices/downloadVoice + pure VoicePolicy), speech() = NarrationPlayer
 * (TTS playType 0 -> PcmPlayer AudioRenderer). Both share one TtsEngines, so each engine exists once per app.
 * A6 wiring: background() = BackgroundRunner (one continuous task ['location','audioPlayback']; it stops speech
 * before stopping the task, as the continuous-task guide requires), mediaSession() = MediaSessionService (AVSession
 * 'audio'). Both are constructed lazily and only touch the platform when start()/init() is called. shutdown()
 * stops the task and destroys the session.
 * UIAbilityContext: doc 开发指南/Ability_Kit_程序框架服务/应用模型/应用组件/UIAbility组件/
 * 启动应用内的UIAbility组件/uiability-intra-device-interaction.
 */
import { common } from '@kit.AbilityKit';
import {
  BackgroundPort, Clock, FixSource, HapticsPort, LocationSource, LoggerPort, MediaSessionPort, NotifierPort,
  PackRepository, PermissionPort, PermissionState, SpeechPort, TourControl, VoicePort
} from '../contracts/Ports';
import { PcmPlayer } from '../services/audio/PcmPlayer';
import { BackgroundRunner } from '../services/background/BackgroundRunner';
import { MediaSessionService } from '../services/media/MediaSessionService';
import { DemoWalkSource } from '../services/location/DemoWalkSource';
import { PermissionService } from '../services/location/PermissionService';
import { RealLocationSource } from '../services/location/RealLocationSource';
import { PackFactory } from '../services/pack/PackFactory';
import { NarrationPlayer } from '../services/speech/NarrationPlayer';
import { TtsEngines } from '../services/speech/TtsEngines';
import { VoiceManager } from '../services/speech/VoiceManager';
import { ScriptedTourControl } from '../services/tour/ScriptedTourControl';
import { DemoControls, TourController, TourControllerDeps } from '../services/tour/TourController';
import { SystemClock, SystemScheduler } from './Clock';
import { HilogLogger, Log } from './Log';
import { LogEvents } from './LogEvents';

/** Before init() (no UIAbilityContext): reports UNKNOWN and never opens a dialog. */
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

/** TourController's DemoControls over the A5 DemoWalkSource (ArkTS has no structural typing). */
class DemoWalkControls implements DemoControls {
  private readonly src: DemoWalkSource;

  constructor(src: DemoWalkSource) {
    this.src = src;
  }

  wraps(s: DemoWalkSource): boolean {
    return this.src === s;
  }

  setSpeed(mult: number): void {
    this.src.setSpeed(mult);
  }

  jumpToNextStop(): void {
    this.src.jumpToNextStop();
  }

  setHoldPredicate(p: () => boolean): void {
    this.src.setHoldPredicate(p);
  }

  isHolding(): boolean {
    return this.src.isHolding();
  }

  rewind(): void {
    this.src.rewind();
  }
}

export class AppContainer {
  private static ctx: common.UIAbilityContext | undefined = undefined;
  private static clockImpl: Clock = new SystemClock();
  private static loggerImpl: LoggerPort = new HilogLogger();
  private static packImpl: PackRepository | undefined = undefined;
  private static tourImpl: TourController | undefined = undefined;
  private static scriptedImpl: ScriptedTourControl | undefined = undefined;
  private static voiceImpl: VoiceManager | undefined = undefined;
  private static speechImpl: NarrationPlayer | undefined = undefined;
  private static permImpl: PermissionPort | undefined = undefined;
  private static bgImpl: BackgroundRunner | undefined = undefined;
  private static avsImpl: MediaSessionService | undefined = undefined;
  private static realLocImpl: RealLocationSource | undefined = undefined;
  private static demoImpl: DemoWalkSource | undefined = undefined;
  private static demoCtlImpl: DemoWalkControls | undefined = undefined;

  /** Idempotent. Builds services; starts nothing. */
  static init(ctx: common.UIAbilityContext): void {
    if (AppContainer.ctx !== undefined) {
      return;
    }
    AppContainer.ctx = ctx;
    try {
      AppContainer.packImpl = PackFactory.create();
      AppContainer.buildSpeech();
      AppContainer.permImpl = new PermissionService(ctx);
      AppContainer.realLocImpl = new RealLocationSource(AppContainer.permImpl);
      AppContainer.demoImpl = new DemoWalkSource(ctx);
      AppContainer.tourImpl = AppContainer.buildTour();
    } catch (e) {
      Log.e(LogEvents.UNCAUGHT, `where=AppContainer.init ${Log.errKv(e as Object)}`);
    }
  }

  static shutdown(): void {
    // The tour first (A7: stops sources and TICK, stops its task and AVSession), then anything a DevPanel button
    // started outside a tour. Stop the continuous task (it stops speech first) and destroy the AVSession; both are
    // async, best effort.
    try {
      if (AppContainer.tourImpl !== undefined) {
        AppContainer.tourImpl.shutdown();
      }
    } catch (e) {
      Log.e(LogEvents.UNCAUGHT, `where=AppContainer.shutdown.tour ${Log.errKv(e as Object)}`);
    }
    try {
      if (AppContainer.bgImpl !== undefined && AppContainer.bgImpl.isRunning()) {
        AppContainer.bgImpl.stop().catch((e: Object) => {
          Log.e(LogEvents.UNCAUGHT, `where=AppContainer.shutdown.bg ${Log.errKv(e)}`);
        });
      }
      if (AppContainer.avsImpl !== undefined) {
        AppContainer.avsImpl.destroy().catch((e: Object) => {
          Log.e(LogEvents.UNCAUGHT, `where=AppContainer.shutdown.avs ${Log.errKv(e)}`);
        });
      }
    } catch (e) {
      Log.e(LogEvents.UNCAUGHT, `where=AppContainer.shutdown.platform ${Log.errKv(e as Object)}`);
    }
    try {
      if (AppContainer.scriptedImpl !== undefined) {
        AppContainer.scriptedImpl.dispose();
      }
      if (AppContainer.speechImpl !== undefined) {
        AppContainer.speechImpl.dispose();
      }
      if (AppContainer.realLocImpl !== undefined) {
        AppContainer.realLocImpl.stop();
      }
      if (AppContainer.demoImpl !== undefined) {
        AppContainer.demoImpl.stop();
      }
    } catch (e) {
      Log.e(LogEvents.UNCAUGHT, `where=AppContainer.shutdown ${Log.errKv(e as Object)}`);
    }
    AppContainer.tourImpl = undefined;
    AppContainer.scriptedImpl = undefined;
    AppContainer.packImpl = undefined;
    AppContainer.voiceImpl = undefined;
    AppContainer.speechImpl = undefined;
    AppContainer.permImpl = undefined;
    AppContainer.bgImpl = undefined;
    AppContainer.avsImpl = undefined;
    AppContainer.realLocImpl = undefined;
    AppContainer.demoImpl = undefined;
    AppContainer.demoCtlImpl = undefined;
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
    return AppContainer.tourController();
  }

  /** Concrete TourController for DevPanel extras (options, isRunning). */
  static tourController(): TourController {
    if (AppContainer.tourImpl === undefined) {
      AppContainer.tourImpl = AppContainer.buildTour();
    }
    return AppContainer.tourImpl;
  }

  /** SIMULATED canned snapshots for UI previews and page development (T0). Not used by the app flow. */
  static scriptedTourControl(): TourControl {
    if (AppContainer.scriptedImpl === undefined) {
      AppContainer.scriptedImpl = new ScriptedTourControl();
    }
    return AppContainer.scriptedImpl;
  }

  /** Constructs only: the controller touches no platform API before plan()/start(). */
  private static buildTour(): TourController {
    const deps: TourControllerDeps = {
      pack: AppContainer.packRepository(),
      speech: AppContainer.narration(),
      voice: AppContainer.voiceManager(),
      log: AppContainer.loggerImpl,
      clock: AppContainer.clockImpl,
      scheduler: new SystemScheduler(),
      sourceFor: (kind: FixSource): LocationSource | undefined => AppContainer.locationSource(kind),
      demoControls: (): DemoControls | undefined => AppContainer.demoControls(),
      background: (): BackgroundPort | undefined => AppContainer.background(),
      media: (): MediaSessionPort | undefined => AppContainer.mediaSession(),
      notifier: (): NotifierPort | undefined => undefined,              // A8
      haptics: (): HapticsPort | undefined => undefined,                // A8
      permissions: (): PermissionPort | undefined => AppContainer.permissions()
    };
    return new TourController(deps);
  }

  /** The LocationSource for a kind: RealLocationSource (Location Kit) or the SIMULATED DemoWalkSource. */
  static locationSource(kind: FixSource): LocationSource | undefined {
    return kind === FixSource.DEMO ? AppContainer.demoWalk() : AppContainer.realLocation();
  }

  private static demoControls(): DemoControls | undefined {
    const d: DemoWalkSource | undefined = AppContainer.demoWalk();
    if (d === undefined) {
      return undefined;
    }
    if (AppContainer.demoCtlImpl === undefined || !AppContainer.demoCtlImpl.wraps(d)) {
      AppContainer.demoCtlImpl = new DemoWalkControls(d);
    }
    return AppContainer.demoCtlImpl;
  }

  static packRepository(): PackRepository {
    if (AppContainer.packImpl === undefined) {
      AppContainer.packImpl = PackFactory.create();
    }
    return AppContainer.packImpl;
  }

  static voice(): VoicePort {
    return AppContainer.voiceManager();
  }

  /** The SpeechPort (one utterance in flight, prefetch n+1). Call init() once before the first speak(). */
  static speech(): SpeechPort {
    return AppContainer.narration();
  }

  /** Concrete VoiceManager for Settings/Onboarding/DevPanel extras (strategy(), lastCaps(), fallback context). */
  static voiceManager(): VoiceManager {
    if (AppContainer.voiceImpl === undefined) {
      AppContainer.buildSpeech();
    }
    return AppContainer.voiceImpl as VoiceManager;
  }

  static narration(): NarrationPlayer {
    if (AppContainer.speechImpl === undefined) {
      AppContainer.buildSpeech();
    }
    return AppContainer.speechImpl as NarrationPlayer;
  }

  /** Constructs only (no platform call): engines and the renderer are created lazily on first use. */
  private static buildSpeech(): void {
    const engines = new TtsEngines();
    const vm = new VoiceManager(engines);
    AppContainer.voiceImpl = vm;
    AppContainer.speechImpl = new NarrationPlayer(vm, engines, new PcmPlayer());
  }

  static permissions(): PermissionPort {
    if (AppContainer.permImpl === undefined) {
      AppContainer.permImpl = AppContainer.ctx !== undefined ? new PermissionService(AppContainer.ctx) :
        new StubPermissionPort();
    }
    return AppContainer.permImpl;
  }

  static background(): BackgroundPort {
    return AppContainer.backgroundRunner();
  }

  /** Concrete BackgroundRunner for the DevPanel / HUD extras (lastIssueLine()). */
  static backgroundRunner(): BackgroundRunner {
    if (AppContainer.bgImpl === undefined) {
      AppContainer.bgImpl = new BackgroundRunner(() => AppContainer.context(), () => {
        if (AppContainer.speechImpl !== undefined) {
          AppContainer.speechImpl.stopNow();
        }
      });
    }
    return AppContainer.bgImpl;
  }

  static mediaSession(): MediaSessionPort {
    return AppContainer.mediaSessionService();
  }

  /** Concrete MediaSessionService for the DevPanel extras (lastCommandLine()). */
  static mediaSessionService(): MediaSessionService {
    if (AppContainer.avsImpl === undefined) {
      AppContainer.avsImpl = new MediaSessionService(() => AppContainer.context());
    }
    return AppContainer.avsImpl;
  }

  /** Location Kit source (asks for the permission and the location switch on start()). */
  static realLocation(): RealLocationSource {
    if (AppContainer.realLocImpl === undefined) {
      AppContainer.realLocImpl = new RealLocationSource(AppContainer.permissions());
    }
    return AppContainer.realLocImpl;
  }

  /** SIMULATED Demo walk source. Undefined before init() (it needs the context to read the rawfile track). */
  static demoWalk(): DemoWalkSource | undefined {
    if (AppContainer.demoImpl === undefined && AppContainer.ctx !== undefined) {
      AppContainer.demoImpl = new DemoWalkSource(AppContainer.ctx);
    }
    return AppContainer.demoImpl;
  }
}

/*
 * Composition root (docs/ARCHITECTURE.md §1.2 lifecycle, §12.1). EntryAbility calls init() in onCreate and
 * shutdown() in onDestroy. init() builds services but starts nothing. ViewModels read the getters only.
 * A5 wiring: permissions() = PermissionService (location permission + switch), realLocation() = RealLocationSource
 * (Location Kit), demoWalk() = DemoWalkSource (SIMULATED track replay). Built in init(), started by their users.
 * A7 wiring: tourControl() = TourController (engine + Planner + speech + background() + mediaSession() +
 * realLocation()/demoWalk() + permissions()). DemoWalkSource reaches the controller's DemoControls through
 * DemoWalkControls. ScriptedTourControl stays for UI previews (scriptedTourControl()).
 * A8 wiring: notifier() = TourNotifier (Notification Kit, id 1001 next-stop / text-only arrival notification; it
 * subscribes to the controller's snapshots for the 50 m refresh and the cancel at tour end), haptics() = Haptics
 * (vibrator preset with isSupportEffectSync check, timed fallback). shutdown() cancels the notification.
 * A4 wiring: voice() = VoiceManager (listVoices/downloadVoice + pure VoicePolicy), speech() = NarrationPlayer
 * (TTS playType 0 -> PcmPlayer AudioRenderer). Both share one TtsEngines, so each engine exists once per app.
 * A13 wiring: NarrationPlayer also gets a ClipPlayer (AVPlayer over rawfile/audio clips, ElevenLabs pre-rendered
 * at build time); with no rawfile/audio/manifest.json every sentence uses the TTS path as before.
 * A6 wiring: background() = BackgroundRunner (one continuous task ['location','audioPlayback']; it stops speech
 * before stopping the task, as the continuous-task guide requires), mediaSession() = MediaSessionService (AVSession
 * 'audio'). Both are constructed lazily and only touch the platform when start()/init() is called. shutdown()
 * stops the task and destroys the session.
 * A10 wiring (ARCHITECTURE §9): NarrationPlayer's audio interrupts / headphone loss go to the TourController
 * (rows 12/13, a services-side hook, no SpeechPort change); the controller's keepScreenOn goes to
 * window.setWindowKeepScreenOn on the last window (row 14; API 9, doc API参考/ArkUI_方舟UI框架/ArkTS_API/窗口管理/
 * ohos_window_窗口_/Interface_Window/arkts-apis-window-window, getLastWindow: .../Functions/arkts-apis-window-f,
 * FAQ faqs-arkui-1366: only effective in the foreground, reset it when the scene ends); AppConfig.DEBUG_CORRUPT_PACK
 * swaps in CorruptPackRepository (row 17 demo).
 * UIAbilityContext: doc 开发指南/Ability_Kit_程序框架服务/应用模型/应用组件/UIAbility组件/
 * 启动应用内的UIAbility组件/uiability-intra-device-interaction.
 */
import { common } from '@kit.AbilityKit';
import { window } from '@kit.ArkUI';
import {
  BackgroundPort, Clock, FixSource, HapticsPort, LocationSource, LoggerPort, MediaSessionPort, NotifierPort,
  PackRepository, PermissionPort, PermissionState, SpeechPort, TourControl, VoicePort
} from '../contracts/Ports';
import { PcmPlayer } from '../services/audio/PcmPlayer';
import { ClipPlayer } from '../services/audio/ClipPlayer';
import { BackgroundRunner } from '../services/background/BackgroundRunner';
import { MediaSessionService } from '../services/media/MediaSessionService';
import { DemoWalkSource } from '../services/location/DemoWalkSource';
import { PermissionService } from '../services/location/PermissionService';
import { RealLocationSource } from '../services/location/RealLocationSource';
import { PackFactory } from '../services/pack/PackFactory';
import { CorruptPackRepository } from '../services/debug/CorruptPackRepository';
import { AudioEventListener, NarrationPlayer } from '../services/speech/NarrationPlayer';
import { TtsEngines } from '../services/speech/TtsEngines';
import { VoiceManager } from '../services/speech/VoiceManager';
import { TourNotifier } from '../services/notify/TourNotifier';
import { Haptics } from '../services/haptics/Haptics';
import { ScriptedTourControl } from '../services/tour/ScriptedTourControl';
import { DemoControls, TourController, TourControllerDeps } from '../services/tour/TourController';
import { Lang } from '../contracts/Model';
import { SystemClock, SystemScheduler } from './Clock';
import { AppConfig } from './AppConfig';
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
  private static notifierImpl: TourNotifier | undefined = undefined;
  private static hapticsImpl: Haptics | undefined = undefined;

  /** Idempotent. Builds services; starts nothing. */
  static init(ctx: common.UIAbilityContext): void {
    if (AppContainer.ctx !== undefined) {
      return;
    }
    AppContainer.ctx = ctx;
    try {
      AppContainer.packImpl = AppContainer.makePack();
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
      if (AppContainer.notifierImpl !== undefined) {
        AppContainer.notifierImpl.shutdown().catch((e: Object) => {
          Log.e(LogEvents.UNCAUGHT, `where=AppContainer.shutdown.notifier ${Log.errKv(e)}`);
        });
      }
    } catch (e) {
      Log.e(LogEvents.UNCAUGHT, `where=AppContainer.shutdown.notifier ${Log.errKv(e as Object)}`);
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
    AppContainer.notifierImpl = undefined;
    AppContainer.hapticsImpl = undefined;
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
    return AppConfig.DEBUG_CORRUPT_PACK ? 'corrupt-debug' : PackFactory.kind();
  }

  /** The real pack, or the §9 row 17 fault (AppConfig.DEBUG_CORRUPT_PACK, false in git). */
  private static makePack(): PackRepository {
    if (AppConfig.DEBUG_CORRUPT_PACK) {
      Log.w(LogEvents.PACK_ERR, 'file=pois.json reason=parse src=debug action=inject flag=DEBUG_CORRUPT_PACK');
      return new CorruptPackRepository(AppContainer.loggerImpl);
    }
    return PackFactory.create();
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
      notifier: (): NotifierPort | undefined => AppContainer.notifier(),
      haptics: (): HapticsPort | undefined => AppContainer.haptics(),
      permissions: (): PermissionPort | undefined => AppContainer.permissions(),
      keepScreenOn: (on: boolean) => AppContainer.keepScreenOn(on)
    };
    const ctrl: TourController = new TourController(deps);
    AppContainer.tourNotifier().attach(ctrl, (): Lang => ctrl.options().lang);
    // §9 rows 12/13: the speech service reports audio focus loss and headphone removal to the tour.
    const audioEvents: AudioEventListener = {
      onInterrupt: (hint: string) => ctrl.onAudioInterrupt(hint),
      onRouteLost: (devices: string) => ctrl.onAudioRouteLost(devices)
    };
    AppContainer.narration().setAudioEventListener(audioEvents);
    return ctrl;
  }

  static notifier(): NotifierPort {
    return AppContainer.tourNotifier();
  }

  /** Concrete TourNotifier: requestEnable() for Onboarding (A12); attach() is done by buildTour(). */
  static tourNotifier(): TourNotifier {
    if (AppContainer.notifierImpl === undefined) {
      AppContainer.notifierImpl = new TourNotifier(() => AppContainer.context());
    }
    return AppContainer.notifierImpl;
  }

  static haptics(): HapticsPort {
    if (AppContainer.hapticsImpl === undefined) {
      AppContainer.hapticsImpl = new Haptics();
    }
    return AppContainer.hapticsImpl;
  }

  /** §9 row 14: keep the screen on while the tour runs without its continuous task. Best effort, never throws. */
  static keepScreenOn(on: boolean): void {
    const ctx = AppContainer.ctx;
    if (ctx === undefined) {
      return;
    }
    try {
      window.getLastWindow(ctx).then((w: window.Window) => w.setWindowKeepScreenOn(on)).then(() => {
        Log.i(LogEvents.SETTINGS, `keepScreenOn=${on} ok=1`);
      }).catch((e: Object) => {
        Log.w(LogEvents.UNCAUGHT, `where=AppContainer.keepScreenOn on=${on} ${Log.errKv(e)}`);
      });
    } catch (e) {
      Log.w(LogEvents.UNCAUGHT, `where=AppContainer.keepScreenOn on=${on} ${Log.errKv(e as Object)}`);
    }
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
      AppContainer.packImpl = AppContainer.makePack();
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
    // A13: ClipPlayer plays pre-rendered sentence clips (rawfile/audio, AVPlayer) when the manifest matches.
    AppContainer.speechImpl = new NarrationPlayer(vm, engines, new PcmPlayer(), AppConfig.USE_SYSTEM_PLAYBACK,
      new ClipPlayer(() => AppContainer.context()));
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

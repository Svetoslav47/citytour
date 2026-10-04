/*
 * The watch's composition root (docs/research/WATCH.md §4): the shared TourController (common HAR, the same class
 * the phone runs) with the watch's adapters:
 *   pack        WatchPackRepository   rawfile/watch/royal-route (no narrations)
 *   speech      WatchVoice            text only: wearables have no TTS
 *   location    RealLocationSource    Location Kit (+ PermissionService), or
 *               DemoWalkSource        the SIMULATED Demo walk replay (same track as the phone)
 *   haptics     WatchHaptics          the four-cue language
 * Not wired yet (the controller treats them as absent ports): continuous task, AVSession, notifications.
 */
import { common } from '@kit.AbilityKit';
import { window } from '@kit.ArkUI';
import {
  DemoControls, EngineSnapshot, FixSource, HapticsPort, LocationSource, PermissionPort, RelDir, SystemClock,
  SystemScheduler, TourController, TourControllerDeps, TourOptions
} from 'common';
import { HilogLogger, Log } from './Log';
import { WatchConfig } from './WatchConfig';
import { WatchPackRepository } from '../services/WatchPackRepository';
import { WatchVoice } from '../services/WatchVoice';
import { WatchHaptics } from '../services/WatchHaptics';
import { DemoWalkSource } from '../services/location/DemoWalkSource';
import { PermissionService } from '../services/location/PermissionService';
import { RealLocationSource } from '../services/location/RealLocationSource';

/** TourController's DemoControls over the watch's DemoWalkSource. */
class WatchDemoControls implements DemoControls {
  private readonly src: DemoWalkSource;

  constructor(src: DemoWalkSource) {
    this.src = src;
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

export class WatchContainer {
  private static ctrl: TourController | undefined = undefined;
  private static hapticsImpl: WatchHaptics | undefined = undefined;
  private static packImpl: WatchPackRepository | undefined = undefined;
  private static mainWindow: window.Window | undefined = undefined;

  /** Builds everything; touches no platform API until a tour is planned. Call once from WatchAbility.onCreate. */
  static init(ctx: common.UIAbilityContext): void {
    if (WatchContainer.ctrl !== undefined) {
      return;
    }
    const perms: PermissionService = new PermissionService(ctx);
    const real: RealLocationSource = new RealLocationSource(perms);
    const demo: DemoWalkSource = new DemoWalkSource(ctx);
    const demoCtl: WatchDemoControls = new WatchDemoControls(demo);
    const voice: WatchVoice = new WatchVoice();
    const haptics: WatchHaptics = new WatchHaptics((): RelDir | undefined => WatchContainer.arrivalDir());
    WatchContainer.hapticsImpl = haptics;
    const pack: WatchPackRepository = new WatchPackRepository(ctx, WatchConfig.PACK_DIR);
    WatchContainer.packImpl = pack;
    const deps: TourControllerDeps = {
      pack: pack,
      speech: voice,
      voice: voice,
      log: new HilogLogger(),
      clock: new SystemClock(),
      scheduler: new SystemScheduler(),
      sourceFor: (kind: FixSource): LocationSource | undefined => kind === FixSource.DEMO ? demo : real,
      demoControls: (): DemoControls | undefined => demoCtl,
      background: () => undefined,
      media: () => undefined,
      notifier: () => undefined,
      haptics: (): HapticsPort | undefined => haptics,
      permissions: (): PermissionPort | undefined => perms
    };
    const ctrl: TourController = new TourController(deps);
    const o: TourOptions = new TourOptions();
    o.demoSpeed = WatchConfig.DEMO_DEFAULT_SPEED;
    ctrl.setOptions(o);
    WatchContainer.ctrl = ctrl;
  }

  static attachWindow(w: window.Window | undefined): void {
    WatchContainer.mainWindow = w;
  }

  /**
   * Keeps the glance visible while a tour runs. A watch turns its screen off after a few seconds and then shows the
   * watch face, so a raised wrist would not show the next stop. Huawei's watch guidance allows keep-screen-on for
   * navigation only (docs/research/WATCH.md §2): on while walking, off on the start and finished screens.
   */
  static keepScreenOn(on: boolean): void {
    const w: window.Window | undefined = WatchContainer.mainWindow;
    if (w === undefined) {
      Log.w('WATCH_SCREEN', `keepOn=${on} ok=0 reason=no_window`);
      return;
    }
    try {
      w.setWindowKeepScreenOn(on).then(() => {
        Log.i('WATCH_SCREEN', `keepOn=${on} ok=1`);
      }).catch((e: Object) => {
        Log.w('WATCH_SCREEN', `keepOn=${on} ok=0 ${Log.errKv(e)}`);
      });
    } catch (e) {
      Log.w('WATCH_SCREEN', `keepOn=${on} ok=0 ${Log.errKv(e as Object)}`);
    }
  }

  static tour(): TourController | undefined {
    return WatchContainer.ctrl;
  }

  static pack(): WatchPackRepository | undefined {
    return WatchContainer.packImpl;
  }

  /** Ends the running tour (the controller logs and stops the sources). */
  static endTour(): void {
    if (WatchContainer.ctrl !== undefined) {
      Log.i('WATCH_TOUR', 'action=end');
      WatchContainer.ctrl.end();
    }
    if (WatchContainer.hapticsImpl !== undefined) {
      WatchContainer.hapticsImpl.cancel();
    }
  }

  static haptics(): WatchHaptics | undefined {
    return WatchContainer.hapticsImpl;
  }

  /** Plans and starts the watch tour on the given source (DEMO = SIMULATED). */
  static async startTour(kind: FixSource): Promise<void> {
    const ctrl: TourController | undefined = WatchContainer.ctrl;
    if (ctrl === undefined) {
      return;
    }
    try {
      Log.i('WATCH_TOUR', `action=start source=${kind}`);
      await ctrl.setSource(kind);
      if (kind === FixSource.DEMO) {
        ctrl.setDemoSpeed(WatchConfig.DEMO_DEFAULT_SPEED);
      }
      await ctrl.plan(WatchConfig.TOUR_ID, 0);
      await ctrl.start();
    } catch (e) {
      Log.e('WATCH_TOUR', `action=start source=${kind} ok=0 ${Log.errKv(e as Object)}`);
    }
  }

  static shutdown(): void {
    if (WatchContainer.hapticsImpl !== undefined) {
      WatchContainer.hapticsImpl.cancel();
    }
    if (WatchContainer.ctrl !== undefined) {
      WatchContainer.ctrl.shutdown();
      WatchContainer.ctrl = undefined;
    }
  }

  /** The side of the stop being arrived at: the snapshot's next-stop relative direction. */
  private static arrivalDir(): RelDir | undefined {
    const ctrl: TourController | undefined = WatchContainer.ctrl;
    if (ctrl === undefined) {
      return undefined;
    }
    const s: EngineSnapshot = ctrl.current();
    return s.next !== undefined ? s.next.relDir : undefined;
  }
}

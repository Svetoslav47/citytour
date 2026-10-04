/*
 * Safe areas (issue #63, DESIGN §3 + §4.5). The window is laid out edge to edge (setWindowLayoutFullScreen(true)),
 * so backgrounds and the map surfaces reach under the transparent status bar and navigation indicator, and every
 * screen pads its content and controls by the avoid areas held here. One central source of truth:
 * - SafeAreaWatcher (EntryAbility) reads window.getWindowAvoidArea once and again on every 'avoidAreaChange'
 *   (rotation, split screen / floating window, fold state) and writes vp values into SafeArea.
 * - SafeArea is an @ObservedV2 object shared through AppStorageV2, so pages re-layout when the insets change.
 * Docs: 开发指南/ArkUI_方舟UI框架/UI开发_ArkTS声明式开发范式/组件布局/开发应用沉浸式效果/arkts-develop-apply-immersive-effects
 * ("窗口全屏布局方案": setWindowLayoutFullScreen + getWindowAvoidArea + on('avoidAreaChange') + padding) and
 * 最佳实践/多设备界面开发/多设备窗口形态/窗口沉浸式/bpta-multi-device-window-immersive (TYPE_SYSTEM for the status
 * bar, TYPE_NAVIGATION_INDICATOR for the bottom navigation indicator, TYPE_CUTOUT for the camera cutout).
 */
import { AppStorageV2, display, window } from '@kit.ArkUI';
import { BusinessError } from '@kit.BasicServicesKit';
import { Log } from '../app/Log';
import { LogEvents } from 'common';

const SAFE_AREA_KEY: string = 'safeArea';

/** Current avoid-area insets of the main window, in vp. 0 when there is nothing to avoid on that edge. */
@ObservedV2
export class SafeArea {
  /** Status bar (and a top cutout). */
  @Trace top: number = 0;
  /** Navigation indicator (gesture bar) or three-button navigation bar. */
  @Trace bottom: number = 0;
  /** Side insets, e.g. the cutout or the navigation bar in landscape. */
  @Trace left: number = 0;
  @Trace right: number = 0;

  private static fallback: SafeArea | undefined = undefined;

  /** The one shared instance (AppStorageV2 key 'safeArea'). */
  static get(): SafeArea {
    const s = AppStorageV2.connect(SafeArea, SAFE_AREA_KEY, () => new SafeArea());
    if (s !== undefined) {
      return s;
    }
    if (SafeArea.fallback === undefined) {
      SafeArea.fallback = new SafeArea();
    }
    return SafeArea.fallback;
  }
}

/** Binds the main window to SafeArea: edge-to-edge layout, initial avoid areas, live updates. */
export class SafeAreaWatcher {
  private win: window.Window | undefined = undefined;
  private readonly onAvoidAreaChange = (opts: window.AvoidAreaOptions): void => {
    this.refresh(`change type=${opts.type}`);
  };

  attach(win: window.Window): void {
    this.detach();
    this.win = win;
    try {
      win.setWindowLayoutFullScreen(true).then(() => {
        this.refresh('fullscreen');
      }).catch((err: BusinessError) => {
        Log.e(LogEvents.UNCAUGHT, `where=SafeAreaWatcher.setWindowLayoutFullScreen code=${err.code}`);
      });
      win.on('avoidAreaChange', this.onAvoidAreaChange);
    } catch (e) {
      Log.e(LogEvents.UNCAUGHT, `where=SafeAreaWatcher.attach ${Log.errKv(e as Object)}`);
    }
    this.refresh('attach');
  }

  detach(): void {
    if (this.win === undefined) {
      return;
    }
    try {
      this.win.off('avoidAreaChange', this.onAvoidAreaChange);
    } catch (e) {
      Log.w(LogEvents.UNCAUGHT, `where=SafeAreaWatcher.detach ${Log.errKv(e as Object)}`);
    }
    this.win = undefined;
  }

  /** Re-reads all relevant avoid areas (cheap, synchronous) and publishes them in vp. */
  refresh(reason: string): void {
    const win = this.win;
    if (win === undefined) {
      return;
    }
    try {
      const sys = win.getWindowAvoidArea(window.AvoidAreaType.TYPE_SYSTEM);
      const nav = win.getWindowAvoidArea(window.AvoidAreaType.TYPE_NAVIGATION_INDICATOR);
      const cut = win.getWindowAvoidArea(window.AvoidAreaType.TYPE_CUTOUT);
      const density = this.density(win);
      const sa = SafeArea.get();
      const top = Math.max(sys.topRect.height, cut.topRect.height) / density;
      const bottom = Math.max(sys.bottomRect.height, nav.bottomRect.height, cut.bottomRect.height) / density;
      const left = Math.max(sys.leftRect.width, cut.leftRect.width) / density;
      const right = Math.max(sys.rightRect.width, cut.rightRect.width) / density;
      if (sa.top !== top || sa.bottom !== bottom || sa.left !== left || sa.right !== right) {
        sa.top = top;
        sa.bottom = bottom;
        sa.left = left;
        sa.right = right;
        Log.i(LogEvents.APP_PAGE, `safeArea top=${top.toFixed(1)} bottom=${bottom.toFixed(1)} ` +
          `left=${left.toFixed(1)} right=${right.toFixed(1)} reason=${reason}`);
      }
    } catch (e) {
      Log.e(LogEvents.UNCAUGHT, `where=SafeAreaWatcher.refresh ${Log.errKv(e as Object)}`);
    }
  }

  /** px per vp of the display the window is on (avoid areas are reported in px). */
  private density(win: window.Window): number {
    try {
      const d = display.getDisplayByIdSync(win.getWindowProperties().displayId ?? 0).densityPixels;
      if (d > 0) {
        return d;
      }
    } catch (e) {
      // fall through to the default display
    }
    try {
      const d = display.getDefaultDisplaySync().densityPixels;
      return d > 0 ? d : 1;
    } catch (e) {
      return 1;
    }
  }
}

/*
 * EntryAbility: lifecycle wiring only (docs/ARCHITECTURE.md §1.2).
 * - onCreate: AppContainer.init (builds services, starts nothing), log APP_START.
 * - Launch parameter `page=dev` (`aa start ... --ps page dev`) loads pages/DevPanel instead of pages/Index,
 *   on cold start (onWindowStageCreate) and hot start (onNewWant). Pattern from doc
 *   开发指南/Ability_Kit_程序框架服务/应用模型/应用组件/UIAbility组件/启动应用内的UIAbility组件/
 *   uiability-intra-device-interaction ("启动UIAbility的指定页面").
 * - onBackground does nothing to the tour; onDestroy calls AppContainer.shutdown().
 * - Safe areas (issue #63): onWindowStageCreate makes the main window edge to edge and starts SafeAreaWatcher
 *   (getWindowAvoidArea + on('avoidAreaChange') -> SafeArea in AppStorageV2); every page pads by those insets.
 */
import { AbilityConstant, ConfigurationConstant, UIAbility, Want } from '@kit.AbilityKit';
import { window } from '@kit.ArkUI';
import { AppConfig } from '../app/AppConfig';
import { AppContainer } from '../app/AppContainer';
import { Log } from '../app/Log';
import { LogEvents } from '../app/LogEvents';
import { SafeAreaWatcher } from '../viewmodel/SafeArea';

const PAGE_INDEX: string = 'pages/Index';
const PAGE_DEV: string = 'pages/DevPanel';

function pageForWant(want: Want | undefined): string {
  try {
    const params = want?.parameters;
    if (params !== undefined) {
      const v = params[AppConfig.LAUNCH_PARAM_PAGE];
      if (typeof v === 'string' && v === AppConfig.LAUNCH_PAGE_DEV) {
        return PAGE_DEV;
      }
    }
  } catch (e) {
    Log.w(LogEvents.UNCAUGHT, `where=EntryAbility.pageForWant ${Log.errKv(e as Object)}`);
  }
  return PAGE_INDEX;
}

export default class EntryAbility extends UIAbility {
  private launchPage: string = PAGE_INDEX;
  private currentPage: string = '';
  private stage: window.WindowStage | undefined = undefined;
  private readonly safeArea: SafeAreaWatcher = new SafeAreaWatcher();

  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    try {
      this.context.getApplicationContext().setColorMode(ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET);
    } catch (err) {
      Log.e(LogEvents.UNCAUGHT, `where=EntryAbility.setColorMode ${Log.errKv(err as Object)}`);
    }
    AppContainer.init(this.context);
    this.launchPage = pageForWant(want);
    Log.i(LogEvents.APP_START,
      `ver=${AppConfig.APP_VERSION} pack=none packKind=${AppContainer.packKind()} page=${this.launchPage}`);
  }

  onNewWant(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    const page = pageForWant(want);
    if (page !== this.currentPage && this.stage !== undefined) {
      this.loadPage(this.stage, page);
    }
  }

  onDestroy(): void {
    Log.i(LogEvents.APP_STOP, 'reason=onDestroy');
    AppContainer.shutdown();
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    this.stage = windowStage;
    try {
      this.safeArea.attach(windowStage.getMainWindowSync());
    } catch (e) {
      Log.e(LogEvents.UNCAUGHT, `where=EntryAbility.safeArea ${Log.errKv(e as Object)}`);
    }
    this.loadPage(windowStage, this.launchPage);
  }

  onWindowStageDestroy(): void {
    this.safeArea.detach();
    this.stage = undefined;
  }

  onForeground(): void {
    Log.i(LogEvents.APP_FG, '');
  }

  onBackground(): void {
    // The tour keeps running in the background (continuous task, A6).
    Log.i(LogEvents.APP_BG, '');
  }

  private loadPage(windowStage: window.WindowStage, page: string): void {
    try {
      windowStage.loadContent(page, (err) => {
        if (err && err.code) {
          Log.e(LogEvents.UNCAUGHT, `where=EntryAbility.loadContent page=${page} code=${err.code}`);
          return;
        }
        this.currentPage = page;
        Log.i(LogEvents.APP_PAGE, `page=${page}`);
      });
    } catch (e) {
      Log.e(LogEvents.UNCAUGHT, `where=EntryAbility.loadPage page=${page} ${Log.errKv(e as Object)}`);
    }
  }
}

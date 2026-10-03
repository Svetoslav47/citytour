/*
 * App-wide UI state (B4): the navigation stack, the offline pack load state, the text language and the
 * tour-flow view model. One instance per app (AppViewModel.get()). Views talk to view models only; view models
 * reach services through AppContainer getters (ARCHITECTURE §1.2).
 * Navigation: Navigation + NavPathStack + navDestination builder (doc: ts-basic-components-navigation).
 */
import { i18n } from '@kit.LocalizationKit';
import { AppIssue, IssueCode, IssueSeverity } from '../contracts/EngineTypes';
import { Lang } from '../contracts/Model';
import { PackLoadResult } from '../contracts/Ports';
import { AppConfig } from '../app/AppConfig';
import { AppContainer } from '../app/AppContainer';
import { Log } from '../app/Log';
import { LogEvents } from '../app/LogEvents';
import { withTimeout } from './Async';
import { TourPlanViewModel } from './TourPlanViewModel';

export class Routes {
  static readonly TOUR_DETAIL: string = 'TourDetail';
  static readonly ROUTE_READY: string = 'RouteReady';
  static readonly NOW_WALKING: string = 'NowWalking';
}

export enum PackState { LOADING = 'loading', READY = 'ready', ERROR = 'error' }

const PACK_LOAD_TIMEOUT_MS: number = 10000;

@ObservedV2
export class AppViewModel {
  private static inst: AppViewModel | undefined = undefined;

  static get(): AppViewModel {
    if (AppViewModel.inst === undefined) {
      AppViewModel.inst = new AppViewModel();
    }
    return AppViewModel.inst;
  }

  readonly stack: NavPathStack = new NavPathStack();
  @Trace packState: PackState = PackState.LOADING;
  @Trace packIssues: AppIssue[] = [];
  /** Language of narration text and place names. B9/B10 bind it to UserSettings.textLang. */
  @Trace textLang: Lang = Lang.EN;
  /** Demo walk replay speed last applied to TourControl (TourControl has no getter for it). */
  @Trace demoSpeed: number = AppConfig.DEMO_DEFAULT_SPEED;
  /** One flow at a time: Tour detail -> Route ready -> Before you go. */
  @Trace tourPlan: TourPlanViewModel = new TourPlanViewModel();
  private loadStarted: boolean = false;

  /**
   * The UI exists in English, Polish and Chinese only. On any other system language (the emulator image we
   * test on is set to Arabic) the English fallback strings would be laid out right-to-left with localised
   * digits, so the app pins its own language to English. i18n.System.setAppPreferredLanguage (API 11+, doc
   * js-apis-i18n). B10's in-app language switch uses the same call.
   */
  applySupportedUiLanguage(): void {
    try {
      const sys = i18n.System.getSystemLanguage();
      const l = sys.toLowerCase();
      if (!(l.startsWith('en') || l.startsWith('pl') || l.startsWith('zh'))) {
        i18n.System.setAppPreferredLanguage('en-US');
        Log.i(LogEvents.SETTINGS, `uiLang=en reason=unsupported_system_lang sys=${sys}`);
      }
    } catch (e) {
      Log.e(LogEvents.UNCAUGHT, `where=AppViewModel.applySupportedUiLanguage ${Log.errKv(e as Object)}`);
    }
  }

  /** Loads the bundled pack once (local, no network). Never throws. */
  async loadPack(): Promise<void> {
    if (this.loadStarted) {
      return;
    }
    this.loadStarted = true;
    this.packState = PackState.LOADING;
    const failed: PackLoadResult = {
      ok: false,
      issues: [this.issue(IssueCode.PACK_ERR, 'load timeout or exception')]
    };
    const res = await withTimeout(AppContainer.packRepository().load(), PACK_LOAD_TIMEOUT_MS, failed, 'pack.load');
    this.packIssues = res.issues;
    this.packState = res.ok ? PackState.READY : PackState.ERROR;
    if (!res.ok) {
      Log.e(LogEvents.PACK_ERR, `where=ui issues=${res.issues.length}`);
    }
  }

  openTour(tourId: string): void {
    this.tourPlan = new TourPlanViewModel();
    this.push(Routes.TOUR_DETAIL, tourId);
  }

  openRouteReady(): void {
    this.push(Routes.ROUTE_READY, this.tourPlan.tourId);
  }

  /** Now Walking always sits directly on Home, so back from it returns Home and the tour keeps running. */
  openNowWalking(): void {
    try {
      this.stack.clear(false);
    } catch (e) {
      Log.e(LogEvents.UNCAUGHT, `where=AppViewModel.openNowWalking ${Log.errKv(e as Object)}`);
    }
    this.push(Routes.NOW_WALKING, '');
  }

  back(): void {
    try {
      this.stack.pop();
    } catch (e) {
      Log.e(LogEvents.UNCAUGHT, `where=AppViewModel.back ${Log.errKv(e as Object)}`);
    }
  }

  private push(name: string, param: string): void {
    try {
      this.stack.pushPath(new NavPathInfo(name, param));
      Log.i(LogEvents.APP_PAGE, `page=${name} param=${param}`);
    } catch (e) {
      Log.e(LogEvents.UNCAUGHT, `where=AppViewModel.push page=${name} ${Log.errKv(e as Object)}`);
    }
  }

  private issue(code: IssueCode, detail: string): AppIssue {
    const i: AppIssue = { code: code, severity: IssueSeverity.BLOCKING, detail: detail };
    return i;
  }
}

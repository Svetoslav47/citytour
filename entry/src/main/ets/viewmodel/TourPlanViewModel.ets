/*
 * Tour flow view model (B4): Tour detail -> location gate (Flow D) -> Route ready (plan) -> Before you go -> start.
 * Pages own navigation; this class only reports outcomes (true = go on). All service calls have timeouts.
 * Services: AppContainer.packRepository(), tourControl(), permissions(), voice() (ARCHITECTURE §12.2).
 */
import { TourPlan } from '../contracts/EngineTypes';
import { Lang } from '../contracts/Model';
import { FixSource, PermissionState } from '../contracts/Ports';
import { VoiceLabel } from '../contracts/Settings';
import { AppContainer } from '../app/AppContainer';
import { Log } from '../app/Log';
import { LogEvents } from '../app/LogEvents';
import { MapData } from '../contracts/Model';
import { PreviewPoint } from '../views/common/RoutePreview';
import { MapOverlay } from '../views/map/MapRenderer';
import { MapCache, overlayBounds, previewOverlay } from './MapViewModel';
import { StopRow } from '../views/common/StopList';
import { withTimeout } from './Async';
import { CoverModel } from './CoverModel';
import { SettingsViewModel } from './SettingsViewModel';
import { localName } from './Format';
import {
  findTour, legMetres, listedMetres, personaName, poiName, previewPoints, safeRoutes, sourceSummary, stopRows
} from './PackView';

/** Flow D banners on Tour detail. */
export enum LocBanner { NONE = 'none', DENIED = 'denied', APPROX = 'approx', SWITCH_OFF = 'switchOff' }

export class OrderRow {
  order: number;
  poiId: string;
  name: string;
  legToNextM: number;   // 0 = last stop or unknown

  constructor(order: number, poiId: string, name: string, legToNextM: number) {
    this.order = order;
    this.poiId = poiId;
    this.name = name;
    this.legToNextM = legToNextM;
  }
}

const PERM_STATE_TIMEOUT_MS: number = 5000;
const PERM_DIALOG_TIMEOUT_MS: number = 120000;   // the user may take a while to answer a system dialog
const CONTROL_TIMEOUT_MS: number = 8000;
/** DESIGN §3.4: only claim a saving the user can notice. */
const MIN_SAVING_TO_SHOW_M: number = 50;
const PLANNER_ALGOS: string[] = ['heldkarp', 'orienteering', 'nn2opt'];
/** X1 "Time available" options in minutes; 0 = all stops (user decision: the whole tour is ~54 min with stories). */
export const BUDGET_OPTIONS_MIN: number[] = [0, 30, 45];

@ObservedV2
export class TourPlanViewModel {
  @Trace tourId: string = '';
  @Trace found: boolean = false;
  @Trace textLang: Lang = Lang.EN;
  @Trace title: string = '';
  @Trace summary: string = '';
  @Trace guideName: string = '';
  @Trace stops: StopRow[] = [];
  @Trace preview: PreviewPoint[] = [];
  @Trace map: MapData | undefined = undefined;
  @Trace scene: MapOverlay = new MapOverlay();
  @Trace sceneBounds: number[] = [];
  @Trace orderScene: MapOverlay = new MapOverlay();
  @Trace orderBounds: number[] = [];
  @Trace listedM: number = 0;
  @Trace estMinutes: number = 0;
  @Trace sourcesCount: number = 0;
  @Trace allReviewed: boolean = false;
  @Trace aiDrafted: boolean = false;
  @Trace voiceLabel: VoiceLabel = VoiceLabel.TEXT_ONLY_PLATFORM;
  /** Tour detail hero: the active course's cover photo (the map preview stays as the hero when it has none). */
  @Trace cover: CoverModel = new CoverModel();

  // Location gate (Tour detail)
  @Trace locBanner: LocBanner = LocBanner.NONE;
  @Trace checking: boolean = false;
  @Trace demo: boolean = false;

  // Route ready
  @Trace planning: boolean = false;
  @Trace plan: TourPlan | undefined = undefined;
  @Trace planFailed: boolean = false;
  @Trace showOrder: boolean = false;
  @Trace orderRows: OrderRow[] = [];
  @Trace orderPreview: PreviewPoint[] = [];
  /** X1: time available in minutes, 0 = all stops (exact orienteering when > 0). */
  @Trace budgetMin: number = 0;

  // Before you go
  @Trace showSheet: boolean = false;
  @Trace starting: boolean = false;
  @Trace startFailed: boolean = false;
  /** The SIMULATED Demo walk is offered for a course whose pack ships a demo track (CourseRules.demoWalkOffered). */
  @Trace demoOffered: boolean = false;
  private pendingStart: boolean = false;
  private personaId: string = '';

  load(tourId: string, lang: Lang): void {
    this.textLang = lang;
    this.demoOffered = AppContainer.demoWalkOffered();
    const pack = AppContainer.packRepository();
    const tour = findTour(pack, tourId);
    if (tour === undefined) {
      this.found = false;
      this.tourId = tourId;
      Log.w(LogEvents.PACK_ERR, `where=TourPlanViewModel.load tour=${tourId} reason=not_found`);
      return;
    }
    const ids = tour.stops.map((s) => s.poiId);
    this.tourId = tour.id;
    this.personaId = tour.personaId;
    this.title = localName(tour.titles, lang);
    this.summary = localName(tour.summaries, lang);
    this.guideName = personaName(pack, tour.personaId, lang);
    this.stops = stopRows(pack, ids, tour.personaId, lang);
    this.preview = previewPoints(pack, ids);
    this.map = MapCache.detailMap();
    this.scene = previewOverlay(ids, lang);
    this.sceneBounds = overlayBounds(this.scene) ?? [];
    this.listedM = listedMetres(pack, ids);
    this.estMinutes = tour.estMinutes;
    const src = sourceSummary(pack, ids, tour.personaId, lang);
    this.sourcesCount = src.count;
    this.allReviewed = src.allReviewed;
    this.aiDrafted = src.aiDrafted;
    try {
      this.voiceLabel = AppContainer.voiceManager().storyPlan(lang).label;   // A13: "Studio voice" with clips
    } catch (e) {
      this.voiceLabel = VoiceLabel.TEXT_ONLY_PLATFORM;
      Log.e(LogEvents.UNCAUGHT, `where=TourPlanViewModel.voicePlan ${Log.errKv(e as Object)}`);
    }
    this.found = true;
    let courseId = '';
    try {
      courseId = AppContainer.courses().activeId();
    } catch (e) {
      courseId = '';
    }
    this.cover.load(courseId, true);
  }

  /**
   * "Start tour": precise location granted and the system switch on -> real location source, go on (true).
   * Otherwise show the matching Flow D banner and stay (false). Never blocks: the banner offers the Demo walk.
   */
  async startTour(): Promise<boolean> {
    if (this.checking) {
      return false;
    }
    this.checking = true;
    this.locBanner = LocBanner.NONE;
    try {
      // B9: Settings > Demo walk is on => the SIMULATED source at the saved speed, no location gate.
      if (SettingsViewModel.settings().useDemoWalk && AppContainer.demoWalkOffered()) {
        const ok = await SettingsViewModel.applySource('startTour');
        this.demo = true;
        Log.i(LogEvents.LOC_SOURCE, `kind=demo where=tourDetail reason=settings ok=${ok}`);
        return true;
      }
      const perms = AppContainer.permissions();
      let st = await withTimeout(perms.locationState(), PERM_STATE_TIMEOUT_MS, PermissionState.UNKNOWN,
        'perm.locationState');
      if (st !== PermissionState.GRANTED) {
        st = await withTimeout(perms.requestLocation(), PERM_DIALOG_TIMEOUT_MS, PermissionState.UNKNOWN,
          'perm.requestLocation');
      }
      return await this.afterPermission(st);
    } finally {
      this.checking = false;
    }
  }

  /** Banner action "Allow location": the system's second-chance sheet (requestPermissionOnSetting). */
  async allowLocation(): Promise<boolean> {
    if (this.checking) {
      return false;
    }
    this.checking = true;
    try {
      const st = await withTimeout(AppContainer.permissions().openLocationSettings(), PERM_DIALOG_TIMEOUT_MS,
        PermissionState.UNKNOWN, 'perm.openLocationSettings');
      return await this.afterPermission(st);
    } finally {
      this.checking = false;
    }
  }

  /** Banner action "Turn on" for the system location switch (requestGlobalSwitch). */
  async turnOnLocationSwitch(): Promise<boolean> {
    if (this.checking) {
      return false;
    }
    this.checking = true;
    try {
      const on = await withTimeout(AppContainer.permissions().requestLocationSwitch(), PERM_DIALOG_TIMEOUT_MS, false,
        'perm.requestLocationSwitch');
      if (!on) {
        this.locBanner = LocBanner.SWITCH_OFF;
        return false;
      }
      return await this.useRealSource();
    } finally {
      this.checking = false;
    }
  }

  /** Banner action "Try a demo walk instead": the SIMULATED source, clearly labelled from here on. */
  async useDemo(): Promise<boolean> {
    if (!AppContainer.demoWalkOffered()) {
      return false;
    }
    const ok = await withTimeout(AppContainer.tourControl().setSource(FixSource.DEMO).then((): boolean => true),
      CONTROL_TIMEOUT_MS, false, 'tour.setSource.demo');
    this.demo = true;
    this.locBanner = LocBanner.NONE;
    Log.i(LogEvents.LOC_SOURCE, `kind=demo where=tourDetail ok=${ok}`);
    return true;
  }

  /** X1: pick a time budget and re-plan (the latest choice wins if a plan is already running). */
  setBudget(min: number): void {
    if (min === this.budgetMin && this.plan !== undefined) {
      return;
    }
    this.budgetMin = min;
    Log.i(LogEvents.ROUTE_PLAN, `where=routeReady action=budget budgetMin=${min} src=ui`);
    this.planRoute();
  }

  /** Route ready: plan with the controller (Held-Karp, or exact orienteering under a time budget). */
  async planRoute(): Promise<void> {
    if (this.planning || this.tourId === '') {
      return;
    }
    this.planning = true;
    this.planFailed = false;
    const budget = this.budgetMin;
    const p = await withTimeout<TourPlan | undefined>(AppContainer.tourControl().plan(this.tourId, budget),
      CONTROL_TIMEOUT_MS, undefined, 'tour.plan');
    this.planning = false;
    if (budget !== this.budgetMin) {
      this.planRoute();              // the user changed the budget while this plan ran
      return;
    }
    if (p === undefined || p.order.length === 0) {
      this.planFailed = true;
      this.plan = undefined;
      Log.w(LogEvents.ROUTE_PLAN, `where=routeReady budgetMin=${budget} result=empty`);
      return;
    }
    Log.i(LogEvents.ROUTE_PLAN, `where=routeReady budgetMin=${budget} chosen=${p.order.length}/${this.stops.length} ` +
      `algo=${p.algo} exact=${p.exact} walkM=${Math.round(p.walkM)} costS=${Math.round(p.costS)} ms=${p.ms}`);
    const pack = AppContainer.packRepository();
    const routes = safeRoutes(pack);
    this.orderRows = p.order.map((id: string, i: number) => {
      let leg = 0;
      if (i < p.order.length - 1) {
        leg = i < p.legs.length && p.legs[i].distanceM > 0 ? p.legs[i].distanceM : legMetres(routes, id, p.order[i + 1]);
      }
      return new OrderRow(i + 1, id, poiName(pack, id, this.textLang), leg);
    });
    this.orderPreview = previewPoints(pack, p.order);
    this.orderScene = previewOverlay(p.order, this.textLang);
    this.orderBounds = overlayBounds(this.orderScene) ?? [];
    this.plan = p;
  }

  /** Name of the first stop in walking order ('' if unknown). */
  firstStopName(): string {
    return this.orderRows.length > 0 ? this.orderRows[0].name : '';
  }

  /** True when the plan comes from a real planner and saved a noticeable distance (full tour only). */
  showSaving(): boolean {
    return this.plan !== undefined && this.budgetMin === 0 && this.isRealPlanner() &&
      this.plan.savedM >= MIN_SAVING_TO_SHOW_M;
  }

  /** True when a real planner confirmed the listed order is (near) optimal (full tour only). */
  showListedOptimal(): boolean {
    return this.plan !== undefined && this.budgetMin === 0 && this.isRealPlanner() && this.plan.exact &&
      this.plan.savedM < MIN_SAVING_TO_SHOW_M;
  }

  /** X1: a time budget is set and the plan answers it ("Best k of n stops"). */
  showBudgetResult(): boolean {
    return this.plan !== undefined && this.budgetMin > 0 && this.isRealPlanner();
  }

  chosenStops(): number {
    return this.plan === undefined ? 0 : this.plan.order.length;
  }

  isRealPlanner(): boolean {
    return this.plan !== undefined && PLANNER_ALGOS.indexOf(this.plan.algo) >= 0;
  }

  /** Walking + dwell minutes from the plan; falls back to the tour estimate. */
  withStoriesMinutes(): number {
    if (this.plan !== undefined && this.plan.costS > 0) {
      return this.plan.costS / 60;
    }
    return this.estMinutes;
  }

  walkMinutes(): number {
    if (this.plan === undefined || this.plan.walkM <= 0) {
      return 0;
    }
    return this.plan.walkM / 1.3 / 60;   // 1.3 m/s, the walking speed the engine assumes
  }

  begin(): void {
    this.startFailed = false;
    this.showSheet = true;
  }

  /** "Start walking": close the sheet first; the start happens in onSheetGone so no sheet outlives the page. */
  startWalking(): void {
    this.pendingStart = true;
    this.showSheet = false;
  }

  /** Called from the sheet's onDisappear. Resolves true when the tour started and Now Walking should open. */
  async onSheetGone(): Promise<boolean> {
    this.showSheet = false;
    if (!this.pendingStart) {
      return false;
    }
    this.pendingStart = false;
    this.starting = true;
    const ok = await withTimeout(AppContainer.tourControl().start().then((): boolean => true), CONTROL_TIMEOUT_MS,
      false, 'tour.start');
    this.starting = false;
    this.startFailed = !ok;
    return ok;
  }

  private async afterPermission(st: PermissionState): Promise<boolean> {
    if (st === PermissionState.APPROX_ONLY) {
      this.locBanner = LocBanner.APPROX;
      Log.w(LogEvents.PERM_APPROX_ONLY, 'where=tourDetail');
      return false;
    }
    if (st !== PermissionState.GRANTED) {
      this.locBanner = LocBanner.DENIED;
      Log.w(LogEvents.PERM_DENIED, `where=tourDetail state=${st}`);
      return false;
    }
    let switchOn = false;
    try {
      switchOn = AppContainer.permissions().isLocationSwitchOn();
    } catch (e) {
      Log.e(LogEvents.UNCAUGHT, `where=TourPlanViewModel.isLocationSwitchOn ${Log.errKv(e as Object)}`);
    }
    if (!switchOn) {
      this.locBanner = LocBanner.SWITCH_OFF;
      Log.w(LogEvents.LOC_SWITCH_OFF, 'where=tourDetail');
      return false;
    }
    return await this.useRealSource();
  }

  private async useRealSource(): Promise<boolean> {
    await withTimeout(AppContainer.tourControl().setSource(FixSource.REAL).then((): boolean => true),
      CONTROL_TIMEOUT_MS, false, 'tour.setSource.real');
    this.demo = false;
    this.locBanner = LocBanner.NONE;
    return true;
  }
}

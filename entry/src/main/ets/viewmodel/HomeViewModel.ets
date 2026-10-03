/*
 * Home view model (B4, DESIGN §3.2): the tour card from the pack, the "Now walking" continue card from the
 * TourControl snapshots, and the one-tap "Try a demo walk" (SIMULATED source, x8, plan, start), offered only while
 * the active course ships a SIMULATED track in its pack (demo-walk.json; CourseRules.demoWalkOffered).
 */
import { EngineSnapshot, TourPhase } from '../contracts/EngineTypes';
import { Lang } from '../contracts/Model';
import { FixSource } from '../contracts/Ports';
import { AppContainer } from '../app/AppContainer';
import { Log } from '../app/Log';
import { LogEvents } from '../app/LogEvents';
import { MapData } from '../contracts/Model';
import { PreviewPoint } from '../views/common/RoutePreview';
import { AppViewModel } from './AppViewModel';
import { CoverModel } from './CoverModel';
import { MapOverlay } from '../views/map/MapRenderer';
import { MapCache, overlayBounds, previewOverlay } from './MapViewModel';
import { withTimeout } from './Async';
import { localName } from './Format';
import { findTour, listedMetres, personaName, poiName, previewPoints } from './PackView';

const CONTROL_TIMEOUT_MS: number = 8000;
const DEMO_HOME_SPEED: number = 8;   // PLAN B4: the Home shortcut runs the Demo walk at x8

@ObservedV2
export class HomeViewModel {
  @Trace hasTour: boolean = false;
  @Trace tourId: string = '';
  @Trace title: string = '';
  @Trace firstStop: string = '';
  @Trace lastStop: string = '';
  @Trace stopCount: number = 0;
  @Trace listedM: number = 0;
  @Trace estMinutes: number = 0;
  @Trace guideName: string = '';
  @Trace placesCount: number = 0;
  @Trace preview: PreviewPoint[] = [];
  @Trace map: MapData | undefined = undefined;
  @Trace mapScene: MapOverlay = new MapOverlay();
  @Trace mapBounds: number[] = [];
  @Trace snap: EngineSnapshot | undefined = undefined;
  @Trace currentStopName: string = '';
  @Trace startingDemo: boolean = false;
  @Trace demoFailed: boolean = false;
  @Trace demoOffered: boolean = false;
  /** The active course's cover photo (falls back to the map preview when it has none). */
  @Trace cover: CoverModel = new CoverModel();
  private lang: Lang = Lang.EN;
  private unsubscribe: (() => void) | undefined = undefined;

  /** Reads the tour card from the loaded pack. */
  refresh(lang: Lang): void {
    this.lang = lang;
    const pack = AppContainer.packRepository();
    this.demoOffered = AppContainer.demoWalkOffered();
    const tour = findTour(pack, '');
    if (tour === undefined) {
      this.hasTour = false;
      this.tourId = '';
      this.placesCount = 0;
      return;
    }
    const ids = tour.stops.map((s) => s.poiId);
    this.tourId = tour.id;
    this.title = localName(tour.titles, lang);
    this.firstStop = ids.length > 0 ? poiName(pack, ids[0], lang) : '';
    this.lastStop = ids.length > 0 ? poiName(pack, ids[ids.length - 1], lang) : '';
    this.stopCount = ids.length;
    this.listedM = listedMetres(pack, ids);
    this.estMinutes = tour.estMinutes;
    this.guideName = personaName(pack, tour.personaId, lang);
    this.preview = previewPoints(pack, ids);
    this.map = MapCache.detailMap();
    this.mapScene = previewOverlay(ids, lang);
    this.mapBounds = overlayBounds(this.mapScene) ?? [];
    try {
      this.placesCount = pack.pois().length;
    } catch (e) {
      this.placesCount = 0;
    }
    this.hasTour = true;
    let courseId = '';
    try {
      courseId = AppContainer.courses().activeId();
    } catch (e) {
      courseId = '';
    }
    this.cover.load(courseId, true);
  }

  attach(): void {
    if (this.unsubscribe !== undefined) {
      return;
    }
    try {
      this.unsubscribe = AppContainer.tourControl().subscribe((s: EngineSnapshot) => this.onSnapshot(s));
    } catch (e) {
      Log.e(LogEvents.UNCAUGHT, `where=HomeViewModel.attach ${Log.errKv(e as Object)}`);
    }
  }

  detach(): void {
    if (this.unsubscribe !== undefined) {
      try {
        this.unsubscribe();
      } catch (e) {
        Log.e(LogEvents.UNCAUGHT, `where=HomeViewModel.detach ${Log.errKv(e as Object)}`);
      }
      this.unsubscribe = undefined;
    }
  }

  /** SERVER.md §6: the "More courses" entry exists only when a course server is configured. */
  coursesEnabled(): boolean {
    try {
      return AppContainer.courses().serverEnabled();
    } catch (e) {
      return false;
    }
  }

  /** A tour is running (or paused) and can be reopened. */
  sessionActive(): boolean {
    const s = this.snap;
    return s !== undefined && (s.phase === TourPhase.WALKING || s.phase === TourPhase.APPROACHING ||
      s.phase === TourPhase.AT_STOP);
  }

  /** 1-based number of the stop being walked to or visited. */
  currentStopNumber(): number {
    const s = this.snap;
    if (s === undefined || s.stops.length === 0) {
      return 0;
    }
    return Math.min(s.stops.length, s.currentStopIdx + 1);
  }

  totalStops(): number {
    return this.snap === undefined ? 0 : this.snap.stops.length;
  }

  progressPct(): number {
    const total = this.totalStops();
    return total === 0 ? 0 : Math.round(100 * (this.currentStopNumber() - 1) / total);
  }

  isDemo(): boolean {
    return this.snap !== undefined && this.snap.source === FixSource.DEMO;
  }

  /** Home "Try a demo walk": SIMULATED source at x8, plan, start. Resolves true when Now Walking should open. */
  async tryDemoWalk(): Promise<boolean> {
    if (this.startingDemo || this.tourId === '' || !AppContainer.demoWalkOffered()) {
      return false;
    }
    this.startingDemo = true;
    this.demoFailed = false;
    try {
      const tc = AppContainer.tourControl();
      await withTimeout(tc.setSource(FixSource.DEMO).then((): boolean => true), CONTROL_TIMEOUT_MS, false,
        'tour.setSource.demo');
      tc.setDemoSpeed(DEMO_HOME_SPEED);
      AppViewModel.get().demoSpeed = DEMO_HOME_SPEED;
      Log.i(LogEvents.LOC_SOURCE, `kind=demo where=home speed=${DEMO_HOME_SPEED}`);
      const planned = await withTimeout(tc.plan(this.tourId, 0).then((): boolean => true), CONTROL_TIMEOUT_MS, false,
        'tour.plan');
      const started = planned && await withTimeout(tc.start().then((): boolean => true), CONTROL_TIMEOUT_MS, false,
        'tour.start');
      this.demoFailed = !started;
      return started;
    } catch (e) {
      Log.e(LogEvents.UNCAUGHT, `where=HomeViewModel.tryDemoWalk ${Log.errKv(e as Object)}`);
      this.demoFailed = true;
      return false;
    } finally {
      this.startingDemo = false;
    }
  }

  endTour(): void {
    try {
      AppContainer.tourControl().end();
    } catch (e) {
      Log.e(LogEvents.UNCAUGHT, `where=HomeViewModel.endTour ${Log.errKv(e as Object)}`);
    }
  }

  private onSnapshot(s: EngineSnapshot): void {
    this.snap = s;
    const idx = s.currentStopIdx;
    const id = idx >= 0 && idx < s.stops.length ? s.stops[idx].poiId : '';
    this.currentStopName = id === '' ? '' : poiName(AppContainer.packRepository(), id, this.lang);
  }
}

/*
 * TourController (task A7): the real TourControl. It hosts the pure TourEngine reducer and executes its effects
 * through the services, in order. Sources: docs/ARCHITECTURE.md §1.2 (lifecycle: lives in AppContainer, survives
 * screen lock and page changes, shutdown() on EntryAbility.onDestroy), §4 (engine, effects), §5 (location sources,
 * one pipeline, the real source keeps running in demo mode), §9 rows 4/5/8/14/15/17 (no fix, fix lost, out of
 * area, background/AVSession failures, pack errors), §10 (log events); docs/PLAN.md task A7.
 *
 * Flow:
 *   plan(tourId, budgetMin): pack.load() once (PACK_LOAD) -> speech.init() (voice caps) -> VoicePlan for the text
 *     language -> origin = latest fix (§9 row 8: > 5 km outside the pack bbox => LOC_OUT_OF_AREA, plan from the
 *     tour's start instead) -> core/route/Planner -> TourEngine.init + START_PLANNING + PLAN_READY.
 *   start(): BackgroundPort.start (continuous task) -> MediaSessionPort.init -> location source(s) -> TICK at 1 Hz
 *     -> START_TOUR. FIX_TIMEOUT after 25 s without a fix of the active source.
 *   Every engine event goes through dispatch(): events raised while effects run (speech callbacks fire
 *   synchronously in text mode or on errors) are queued, so reduce() is never re-entered.
 *
 * Effects: SPEAK -> SpeechPort.speak (+ prefetch of the predicted next sentence); STOP_SPEECH(false) -> stopNow,
 * STOP_SPEECH(true) -> nothing (the in-flight sentence finishes, the engine already dropped the rest);
 * SET_MEDIA_META/STATE -> MediaSessionPort; NOTIFY_NEXT -> NotifierPort; HAPTIC -> HapticsPort; REQUEST_REPLAN ->
 * Planner from the current fix; LOG -> LoggerPort (app/Log.ets). A port that is not wired yet (A5/A6/A8 not
 * merged) is a no-op with one log line per tour and effect type.
 *
 * One text-only pacer (A3 note): in text mode the engine paces captions on TICK and emits no SPEAK, so
 * NarrationPlayer's own reading timer is never used by a tour.
 * The reducer updates the state in place (A3 note): this class keeps exactly one TourState per tour.
 * The snapshot's platform fields are filled here (A3 note); snapshots are published at most every 250 ms.
 * Pure TypeScript/ArkTS: no @kit import, so the local unit tests can drive it with fake ports
 * (entry/src/test/TourController.test.ets). Platform calls are all behind ports and wrapped in try/catch + .catch.
 */
import {
  Announcement, AppIssue, Effect, EffectType, EngineEvent, EngineEventType, EngineSnapshot, IssueCode, IssueSeverity,
  MediaPlayState, PlatformStatus, SignalQuality, StopStatus, TourPhase, TourPlan
} from '../../contracts/EngineTypes';
import {
  BackgroundListener, BackgroundPort, Clock, Fix, FixSource, HapticsPort, LocationSource, LoggerPort, MediaCommand,
  MediaSessionPort, NotifierPort, PackLoadResult, PackRepository, PermissionPort, PermissionState, SnapshotListener,
  SpeechListener, SpeechPort, TourControl, Utterance, VoicePlan, VoicePort
} from '../../contracts/Ports';
import { LatLng, Lang, Narration, NarrationLength, PackManifest, Poi, Tour, TourStop } from '../../contracts/Model';
import { VoiceLabel } from '../../contracts/Settings';
import { StepResult, TourEngine, TourInput, TourState } from '../../core/tour/TourEngine';
import { TourConfig } from '../../core/tour/TourConfig';
import { CityPack, PlanInputs, buildCostInputs, plan as planRoute } from '../../core/route/Planner';
import { haversineM } from '../../core/geo/GeoMath';
import { LogEvents } from '../../app/LogEvents';
import { Scheduler } from '../../app/Clock';

/** No fix from the active source for this long => FIX_TIMEOUT (§9 row 5). */
export const FIX_TIMEOUT_MS: number = 25000;
/** No fix at all this long after start => LOC_NOFIX (§9 row 4). */
export const NO_FIRST_FIX_MS: number = 30000;
/** Engine clock (TICK) period. */
export const TICK_MS: number = 1000;
/** Snapshot publisher throttle: at most 4 Hz. */
export const SNAPSHOT_MIN_INTERVAL_MS: number = 250;
/** §9 row 8: an origin this far outside the pack bbox is "far from Kraków". */
export const OUT_OF_AREA_KM: number = 5;
/** A fix older than this is not used as the planning origin. */
export const ORIGIN_MAX_AGE_MS: number = 120000;
/** plan() waits this long for a first fix of an already running source before planning without an origin. */
export const ORIGIN_WAIT_MS: number = 3000;
/** Upper bound for a platform start (continuous task, AVSession), so start() can never hang. */
export const PLATFORM_START_TIMEOUT_MS: number = 5000;
/** Demo walk speeds (PLAN A5). */
export const DEMO_SPEEDS: number[] = [1, 2, 4, 8];
/** At most this many ROUTE_FALLBACK lines per plan (the rest is summarised). */
const MAX_FALLBACK_LINES: number = 12;

/**
 * Demo walk extras the controller needs from DemoWalkSource (A5). Not a shared contract: AppContainer adapts the
 * concrete source to it. Labelled "Demo assist" in the UI.
 */
export interface DemoControls {
  setSpeed(mult: number): void;
  jumpToNextStop(): void;
  /** While it returns true the demo walk holds at a stop (re-emits jittered hold fixes). */
  setHoldPredicate(p: () => boolean): void;
}

/** Everything the controller talks to. Optional services return undefined until their task is merged. */
export interface TourControllerDeps {
  pack: PackRepository;
  speech: SpeechPort;
  voice: VoicePort;
  log: LoggerPort;
  clock: Clock;
  scheduler: Scheduler;
  sourceFor: (kind: FixSource) => LocationSource | undefined;
  demoControls: () => DemoControls | undefined;
  background: () => BackgroundPort | undefined;
  media: () => MediaSessionPort | undefined;
  notifier: () => NotifierPort | undefined;
  haptics: () => HapticsPort | undefined;
  permissions: () => PermissionPort | undefined;
}

/** Tour settings the controller applies at plan() time (UserSettings once B9 lands). */
export class TourOptions {
  lang: Lang = Lang.EN;
  adaptiveLength: boolean = true;
  spokenDirections: boolean = true;
  demoSpeed: number = 4;
  config: TourConfig | undefined = undefined;
}

// ---------------------------------------------------------------- pure helpers (unit-tested)

/** Kilometres from (lat, lng) to the bbox [minLat, minLng, maxLat, maxLng]; 0 inside; NaN for a bad bbox. */
export function kmOutsideBbox(lat: number, lng: number, bbox: number[]): number {
  if (bbox.length < 4 || !Number.isFinite(lat) || !Number.isFinite(lng)) {
    return Number.NaN;
  }
  const cLat: number = Math.min(Math.max(lat, bbox[0]), bbox[2]);
  const cLng: number = Math.min(Math.max(lng, bbox[1]), bbox[3]);
  if (cLat === lat && cLng === lng) {
    return 0;
  }
  return haversineM(lat, lng, cLat, cLng) / 1000;
}

/** The nearest supported demo speed (1 | 2 | 4 | 8). */
export function normalizeDemoSpeed(mult: number): number {
  if (!Number.isFinite(mult)) {
    return 4;
  }
  let best: number = DEMO_SPEEDS[0];
  for (const s of DEMO_SPEEDS) {
    if (Math.abs(s - mult) < Math.abs(best - mult)) {
      best = s;
    }
  }
  return best;
}

/**
 * The id AnnouncementQueue.next() will give the sentence after `u` in the same item: `<sentenceId>#<seq + 1>`.
 * Returns '' if `u.id` has no `#<seq>` suffix. A wrong guess only costs a discarded prefetch.
 */
export function predictNextUtteranceId(currentId: string, nextSentenceId: string): string {
  const hash: number = currentId.lastIndexOf('#');
  if (hash < 0) {
    return '';
  }
  const seq: number = parseInt(currentId.substring(hash + 1), 10);
  if (!Number.isFinite(seq)) {
    return '';
  }
  return `${nextSentenceId}#${seq + 1}`;
}

/** Open (not yet visited) stops of a running tour, in the current planned order. */
export function openStopIds(st: TourState): string[] {
  const out: string[] = [];
  for (const s of st.stops) {
    if (s.status === StopStatus.PENDING || s.status === StopStatus.APPROACHING) {
      out.push(s.poiId);
    }
  }
  return out;
}

function invalidOrigin(): LatLng {
  const o: LatLng = { lat: Number.NaN, lng: Number.NaN };
  return o;
}

function emptyPlan(tourId: string, algo: string): TourPlan {
  const p: TourPlan = {
    tourId: tourId, order: [], costS: 0, walkM: 0, savedM: 0, exact: false, algo: algo, ms: 0, budgetS: 0, legs: []
  };
  return p;
}

function errText(e: Object | undefined | null): string {
  if (e === undefined || e === null) {
    return 'msg=unknown';
  }
  try {
    const m: string | undefined = (e as Error).message;
    return `msg=${m !== undefined ? m : JSON.stringify(e)}`;
  } catch (x) {
    return 'msg=unprintable';
  }
}

/** Log codes the engine emits that are warnings (everything else is info). */
const WARN_CODES: string[] = [
  LogEvents.LOC_POOR, LogEvents.LOC_LOST, LogEvents.TTS_ERR, LogEvents.BG_CANCEL, LogEvents.NARR_FALLBACK,
  LogEvents.PACK_DROP, LogEvents.AUDIO_ROUTE, LogEvents.QUEUE_EXPIRED
];

// ---------------------------------------------------------------- listeners (classes: ArkTS object literals
// cannot carry methods for these interfaces safely)

class SpeechBridge implements SpeechListener {
  private owner: TourController;
  private gen: number;

  constructor(owner: TourController, gen: number) {
    this.owner = owner;
    this.gen = gen;
  }

  onUtteranceStart(id: string): void {
    this.owner.onSpeechEvent(this.gen, EngineEventType.UTTERANCE_STARTED, id, 0);
  }

  onUtteranceDone(id: string): void {
    this.owner.onSpeechEvent(this.gen, EngineEventType.UTTERANCE_DONE, id, 0);
  }

  onUtteranceError(id: string, code: number): void {
    this.owner.onSpeechEvent(this.gen, EngineEventType.UTTERANCE_FAILED, id, code);
  }
}

class BackgroundBridge implements BackgroundListener {
  private owner: TourController;

  constructor(owner: TourController) {
    this.owner = owner;
  }

  onCancelled(reason: string): void {
    this.owner.onBackgroundCancelled(reason);
  }

  onSuspended(reason: string): void {
    this.owner.onBackgroundSuspended(reason);
  }
}

// ---------------------------------------------------------------- the controller

export class TourController implements TourControl {
  private readonly deps: TourControllerDeps;
  private opts: TourOptions = new TourOptions();
  private state: TourState | undefined = undefined;
  private tour: Tour | undefined = undefined;
  private lastPlan: TourPlan | undefined = undefined;
  private voicePlan: VoicePlan | undefined = undefined;
  private packBbox: number[] = [];
  private packLoaded: boolean = false;
  private sourceKind: FixSource = FixSource.REAL;
  private activeSource: LocationSource | undefined = undefined;
  private shadowSource: LocationSource | undefined = undefined;
  private listeners: SnapshotListener[] = [];
  private pending: EngineEvent[] = [];
  private dispatching: boolean = false;
  private running: boolean = false;          // a tour session holds sources, TICK and the platform
  private generation: number = 0;            // bumps on every start/teardown: late callbacks of old sessions are ignored
  private tickId: number = -1;
  private publishTimer: number = -1;
  private lastPublishMs: number = Number.NEGATIVE_INFINITY;
  private startedAtMs: number = Number.NaN;
  private lastActiveFixMs: number = Number.NaN;
  private timeoutSent: boolean = false;
  private noFixLogged: boolean = false;
  private latestFix: Fix | undefined = undefined;
  private latestFixAtMs: number = Number.NaN;
  private realAccuracyM: number = Number.NaN;
  private ctrlIssues: AppIssue[] = [];
  private noopLogged: Set<string> = new Set<string>();
  private narrLogged: Set<string> = new Set<string>();
  private bgUp: boolean = false;
  private avsUp: boolean = false;

  constructor(deps: TourControllerDeps) {
    this.deps = deps;
  }

  // ================================================================ TourControl

  plan(tourId: string, budgetMin: number): Promise<TourPlan> {
    return this.planInternal(tourId, budgetMin).catch((e: Object) => {
      this.deps.log.error(LogEvents.UNCAUGHT, `where=TourController.plan ${errText(e)}`);
      this.addIssue(IssueCode.UNCAUGHT, IssueSeverity.WARN, 'plan');
      this.schedulePublish();
      return emptyPlan(tourId, 'none');
    });
  }

  start(): Promise<void> {
    return this.startInternal().catch((e: Object) => {
      this.deps.log.error(LogEvents.UNCAUGHT, `where=TourController.start ${errText(e)}`);
      this.addIssue(IssueCode.UNCAUGHT, IssueSeverity.WARN, 'start');
      this.schedulePublish();
    });
  }

  pause(): void {
    this.userEvent(EngineEventType.USER_PAUSE);
  }

  resume(): void {
    this.userEvent(EngineEventType.USER_RESUME);
  }

  skip(): void {
    this.userEvent(EngineEventType.USER_SKIP);
  }

  replay(): void {
    this.userEvent(EngineEventType.USER_REPLAY);
  }

  more(): void {
    this.userEvent(EngineEventType.USER_MORE);
  }

  end(): void {
    this.userEvent(EngineEventType.USER_END);
    if (this.running) {
      this.teardown('user_end');       // USER_END from READY/IDLE does not go through the phase check
    }
  }

  setSource(kind: FixSource): Promise<void> {
    try {
      if (kind === this.sourceKind) {
        return Promise.resolve();
      }
      this.deps.log.info(LogEvents.LOC_SOURCE, `kind=${kind} action=select from=${this.sourceKind}`);
      this.sourceKind = kind;
      if (this.running) {
        this.stopSources();
        this.startSources();
      } else {
        this.rebuildReadyEngine();       // the welcome line says "simulated walk" only for DEMO
      }
      this.schedulePublish();
    } catch (e) {
      this.deps.log.error(LogEvents.UNCAUGHT, `where=TourController.setSource ${errText(e as Object)}`);
    }
    return Promise.resolve();
  }

  subscribe(l: SnapshotListener): () => void {
    this.listeners.push(l);
    this.safeNotify(l, this.current());
    return () => {
      this.listeners = this.listeners.filter((x: SnapshotListener) => x !== l);
    };
  }

  current(): EngineSnapshot {
    const st: TourState | undefined = this.state;
    let s: EngineSnapshot;
    try {
      s = st === undefined ? this.idleSnapshot() : TourEngine.snapshot(st);
    } catch (e) {
      this.deps.log.error(LogEvents.UNCAUGHT, `where=TourEngine.snapshot ${errText(e as Object)}`);
      s = this.idleSnapshot();
    }
    s.platform = this.platformStatus(st);
    if (st === undefined) {
      s.source = this.sourceKind;
    }
    if (this.ctrlIssues.length > 0) {
      s.issues = s.issues.concat(this.ctrlIssues);
    }
    return s;
  }

  setDemoSpeed(mult: number): void {
    const m: number = normalizeDemoSpeed(mult);
    this.opts.demoSpeed = m;
    const dc: DemoControls | undefined = this.demo();
    if (dc === undefined) {
      this.noop('demo', LogEvents.LOC_SOURCE, `kind=demo action=speed x=${m} noop=no_demo_source`);
      return;
    }
    try {
      dc.setSpeed(m);
      this.deps.log.info(LogEvents.LOC_SOURCE, `kind=demo action=speed x=${m}`);
    } catch (e) {
      this.deps.log.error(LogEvents.UNCAUGHT, `where=DemoControls.setSpeed ${errText(e as Object)}`);
    }
  }

  demoJumpToNext(): void {
    const dc: DemoControls | undefined = this.demo();
    if (dc === undefined) {
      this.noop('demo', LogEvents.LOC_SOURCE, 'kind=demo action=jump noop=no_demo_source');
      return;
    }
    try {
      dc.jumpToNextStop();
      this.deps.log.info(LogEvents.LOC_SOURCE, 'kind=demo action=jump');
    } catch (e) {
      this.deps.log.error(LogEvents.UNCAUGHT, `where=DemoControls.jumpToNextStop ${errText(e as Object)}`);
    }
  }

  // ================================================================ extras

  /** Applied at the next plan(). */
  setOptions(o: TourOptions): void {
    this.opts = o;
  }

  options(): TourOptions {
    return this.opts;
  }

  sourceKindSelected(): FixSource {
    return this.sourceKind;
  }

  isRunning(): boolean {
    return this.running;
  }

  /** EntryAbility.onDestroy (via AppContainer.shutdown): stop everything, no new speech, keep no timers. */
  shutdown(): void {
    try {
      if (this.running) {
        this.teardown('shutdown');
      }
      this.deps.scheduler.cancel(this.publishTimer);
      this.publishTimer = -1;
      this.listeners = [];
    } catch (e) {
      this.deps.log.error(LogEvents.UNCAUGHT, `where=TourController.shutdown ${errText(e as Object)}`);
    }
  }

  /** Same as shutdown() (the name AppContainer used for ScriptedTourControl). */
  dispose(): void {
    this.shutdown();
  }

  // ================================================================ callbacks (public for the bridge classes)

  onSpeechEvent(gen: number, type: EngineEventType, id: string, code: number): void {
    if (gen !== this.generation || !this.running) {
      return;                            // a late callback from a torn-down tour (or another speech user)
    }
    const ev: EngineEvent = { type: type, nowMs: this.deps.clock.nowMs(), utteranceId: id, code: code };
    this.dispatch(ev);
  }

  onBackgroundCancelled(reason: string): void {
    this.bgUp = false;
    this.addIssue(IssueCode.BG_FAIL, IssueSeverity.WARN, `cancelled ${reason}`);
    if (this.running) {
      const ev: EngineEvent = { type: EngineEventType.BG_CANCELLED, nowMs: this.deps.clock.nowMs(), reason: reason };
      this.dispatch(ev);
    }
  }

  onBackgroundSuspended(reason: string): void {
    this.deps.log.warn(LogEvents.BG_SUSPEND, `reason=${reason} where=controller`);
    this.addIssue(IssueCode.BG_FAIL, IssueSeverity.WARN, `suspended ${reason}`);
    this.schedulePublish();
  }

  onMediaCommand(cmd: MediaCommand): void {
    switch (cmd) {
      case MediaCommand.PLAY:
        this.resume();
        break;
      case MediaCommand.NEXT:
        this.skip();
        break;
      case MediaCommand.PREVIOUS:
        this.replay();
        break;
      case MediaCommand.FAVORITE:
        this.more();
        break;
      default:
        this.pause();                    // PAUSE and STOP: never end a tour from the lock screen
        break;
    }
  }

  // ================================================================ planning

  private async planInternal(tourId: string, budgetMin: number): Promise<TourPlan> {
    if (this.running) {
      this.deps.log.info(LogEvents.STATE, `from=${this.phase()} to=idle ev=PLAN_AGAIN`);
      this.teardown('plan_again');
    }
    this.ctrlIssues = [];
    this.state = undefined;
    this.schedulePublish();

    const loaded: boolean = await this.ensurePack();
    if (!loaded) {
      return emptyPlan(tourId, 'none');
    }
    const tour: Tour | undefined = this.findTour(tourId);
    if (tour === undefined) {
      this.deps.log.error(LogEvents.PACK_ERR, `file=tours.json reason=no_tour requested=${tourId}`);
      this.addIssue(IssueCode.PACK_ERR, IssueSeverity.BLOCKING, 'no tour');
      return emptyPlan(tourId, 'none');
    }
    try {
      await this.deps.speech.init();     // never rejects (A4); warms the engine English uses
    } catch (e) {
      this.deps.log.error(LogEvents.TTS_INIT_FAIL, `where=TourController.plan ${errText(e as Object)}`);
    }
    await this.waitForOrigin();
    const vp: VoicePlan = this.resolveVoice();
    const origin: LatLng = this.planningOrigin();
    const p: TourPlan = this.solve(tour, tour.stops.map((s: TourStop) => s.poiId), origin, budgetMin > 0 ? budgetMin * 60 : 0);
    this.tour = tour;
    this.voicePlan = vp;
    this.lastPlan = p;
    this.buildEngine(tour, vp, p);
    this.publishNow();
    return p;
  }

  private async ensurePack(): Promise<boolean> {
    if (this.packLoaded) {
      return true;
    }
    const t0: number = this.deps.clock.nowMs();
    let r: PackLoadResult;
    try {
      r = await this.deps.pack.load();
    } catch (e) {
      this.deps.log.error(LogEvents.PACK_ERR, `file=pack reason=load_threw ${errText(e as Object)}`);
      this.addIssue(IssueCode.PACK_ERR, IssueSeverity.BLOCKING, 'load');
      return false;
    }
    if (!r.ok) {
      this.deps.log.error(LogEvents.PACK_ERR, `file=pack reason=not_ok issues=${r.issues.length}`);
      for (const i of r.issues) {
        this.ctrlIssues.push(i);
      }
      if (r.issues.length === 0) {
        this.addIssue(IssueCode.PACK_ERR, IssueSeverity.BLOCKING, 'load');
      }
      return false;
    }
    this.packLoaded = true;
    const m: PackManifest | undefined = r.manifest;
    this.packBbox = m !== undefined ? m.bbox : [];
    const narr: number = m !== undefined ? m.counts.narrations_en + m.counts.narrations_pl + m.counts.narrations_zh : 0;
    this.deps.log.info(LogEvents.PACK_LOAD, `ms=${this.deps.clock.nowMs() - t0} pack=${m !== undefined ? m.packId : ''} ` +
      `pois=${this.deps.pack.pois().length} narr=${narr} legs=${this.deps.pack.routes().legs.length} ` +
      `tours=${this.deps.pack.tours().length}`);
    return true;
  }

  private findTour(tourId: string): Tour | undefined {
    const tours: Tour[] = this.deps.pack.tours();
    for (const t of tours) {
      if (t.id === tourId) {
        return t;
      }
    }
    if (tours.length > 0) {
      this.deps.log.warn(LogEvents.ROUTE_FALLBACK, `reason=unknown_tour requested=${tourId} used=${tours[0].id}`);
      return tours[0];
    }
    return undefined;
  }

  private resolveVoice(): VoicePlan {
    try {
      return this.deps.voice.plan(this.opts.lang);
    } catch (e) {
      this.deps.log.error(LogEvents.UNCAUGHT, `where=VoicePort.plan ${errText(e as Object)}`);
      const t: VoicePlan = {
        textLang: this.opts.lang, speechMode: 'text', engineLocale: '', person: 0, languageContext: '',
        label: VoiceLabel.TEXT_ONLY_PLATFORM, reason: 'voice_plan_threw'
      };
      return t;
    }
  }

  /** If a source is already running but has not delivered a fix yet, give it ORIGIN_WAIT_MS. */
  private waitForOrigin(): Promise<void> {
    const src: LocationSource | undefined = this.shadowSource !== undefined ? this.shadowSource : this.activeSource;
    if (this.latestFix !== undefined || src === undefined || !src.isRunning()) {
      return Promise.resolve();
    }
    return new Promise<void>((resolve) => {
      this.deps.scheduler.after(ORIGIN_WAIT_MS, () => resolve());
    });
  }

  /** §9 row 8: the latest fix, unless it is stale or > 5 km outside the pack (then the tour's own start). */
  private planningOrigin(): LatLng {
    const f: Fix | undefined = this.latestFix;
    if (f === undefined || this.deps.clock.nowMs() - this.latestFixAtMs > ORIGIN_MAX_AGE_MS) {
      return invalidOrigin();
    }
    const km: number = kmOutsideBbox(f.lat, f.lng, this.packBbox);
    if (Number.isFinite(km) && km > OUT_OF_AREA_KM) {
      this.deps.log.info(LogEvents.LOC_OUT_OF_AREA, `km=${Math.round(km)} src=${f.source} action=plan_from_tour_start`);
      this.addIssue(IssueCode.LOC_OUT_OF_AREA, IssueSeverity.INFO, `km=${Math.round(km)}`);
      return invalidOrigin();
    }
    const o: LatLng = { lat: f.lat, lng: f.lng };
    return o;
  }

  private tourPois(tour: Tour): Poi[] {
    const out: Poi[] = [];
    for (const s of tour.stops) {
      const p: Poi | undefined = this.deps.pack.poi(s.poiId);
      if (p !== undefined) {
        out.push(p);
      }
    }
    return out;
  }

  private solve(tour: Tour, remaining: string[], origin: LatLng, budgetS: number): TourPlan {
    const pack: CityPack = { pois: this.tourPois(tour), routes: this.deps.pack.routes() };
    const inputs: PlanInputs = buildCostInputs(pack, tour, remaining, origin);
    const n: number = inputs.estimatedPairs.length;
    for (let i = 0; i < Math.min(n, MAX_FALLBACK_LINES); i++) {
      this.deps.log.warn(LogEvents.ROUTE_FALLBACK, `pair=${inputs.estimatedPairs[i].replace('>', ',')} est=haversine`);
    }
    if (n > MAX_FALLBACK_LINES) {
      this.deps.log.warn(LogEvents.ROUTE_FALLBACK, `pairs=${n} shown=${MAX_FALLBACK_LINES}`);
    }
    if (inputs.droppedIds.length > 0) {
      this.deps.log.warn(LogEvents.PACK_DROP, `file=tour n=${inputs.droppedIds.length} first=${inputs.droppedIds[0]}`);
    }
    return planRoute(inputs, budgetS);
  }

  private buildEngine(tour: Tour, vp: VoicePlan, p: TourPlan): void {
    const lang: Lang = this.opts.lang;
    const personaId: string = tour.personaId;
    const input: TourInput = {
      tour: tour, pois: this.tourPois(tour), lang: lang, personaId: personaId,
      narration: (poiId: string, len: NarrationLength) => this.narrationFor(poiId, personaId, lang, len),
      voice: vp, adaptiveLength: this.opts.adaptiveLength, spokenDirections: this.opts.spokenDirections,
      source: this.sourceKind
    };
    this.state = TourEngine.init(input, this.opts.config !== undefined ? this.opts.config : new TourConfig());
    this.dispatchType(EngineEventType.START_PLANNING);
    if (p.order.length === 0) {
      const ev: EngineEvent = {
        type: EngineEventType.PLAN_FAILED, nowMs: this.deps.clock.nowMs(), code: -1, reason: 'empty_plan'
      };
      this.dispatch(ev);
      return;
    }
    const ev: EngineEvent = { type: EngineEventType.PLAN_READY, nowMs: this.deps.clock.nowMs(), plan: p };
    this.dispatch(ev);
  }

  /** setSource() between plan() and start(): rebuild the READY engine so the welcome line matches the source. */
  private rebuildReadyEngine(): void {
    const st: TourState | undefined = this.state;
    if (st === undefined || st.phase !== TourPhase.READY || this.tour === undefined || this.voicePlan === undefined ||
      this.lastPlan === undefined) {
      return;
    }
    this.buildEngine(this.tour, this.voicePlan, this.lastPlan);
  }

  private narrationFor(poiId: string, personaId: string, lang: Lang, len: NarrationLength): Narration | undefined {
    let n: Narration | undefined = undefined;
    try {
      n = this.deps.pack.narration(poiId, personaId, lang, len);
    } catch (e) {
      this.deps.log.error(LogEvents.UNCAUGHT, `where=PackRepository.narration poi=${poiId} ${errText(e as Object)}`);
      return undefined;
    }
    const key: string = `${poiId}:${len}`;
    if (n !== undefined && !this.narrLogged.has(key)) {
      this.narrLogged.add(key);
      this.deps.log.info(LogEvents.NARR_SOURCE, `poi=${poiId} len=${len} lang=${n.lang} tier=${n.tier} ` +
        `sources=${n.sources.length} sentences=${n.sentences.length}`);
    }
    return n;
  }

  private replan(): void {
    const st: TourState | undefined = this.state;
    const tour: Tour | undefined = this.tour;
    if (st === undefined || tour === undefined) {
      return;
    }
    const remaining: string[] = openStopIds(st);
    if (remaining.length === 0) {
      return;
    }
    const f: Fix | undefined = st.lastFix;
    let origin: LatLng = invalidOrigin();
    if (f !== undefined) {
      origin = { lat: f.lat, lng: f.lng };
    }
    const p: TourPlan = this.solve(tour, remaining, origin, 0);
    this.lastPlan = p;
    const ev: EngineEvent = { type: EngineEventType.PLAN_READY, nowMs: this.deps.clock.nowMs(), plan: p };
    this.dispatch(ev);
  }

  // ================================================================ start / stop

  private async startInternal(): Promise<void> {
    if (this.state === undefined || this.phase() === TourPhase.IDLE || this.phase() === TourPhase.FINISHED ||
      this.phase() === TourPhase.ABORTED) {
      const tours: Tour[] = this.packLoaded ? this.deps.pack.tours() : [];
      await this.planInternal(this.tour !== undefined ? this.tour.id : (tours.length > 0 ? tours[0].id : ''), 0);
    }
    if (this.phase() !== TourPhase.READY) {
      this.deps.log.warn(LogEvents.STATE, `from=${this.phase()} to=${this.phase()} ev=START_TOUR ignored=not_ready`);
      return;
    }
    if (this.running) {
      return;
    }
    this.generation++;
    const gen: number = this.generation;
    this.running = true;
    this.noopLogged.clear();
    this.timeoutSent = false;
    this.noFixLogged = false;
    this.deps.speech.setListener(new SpeechBridge(this, gen));
    await this.startPlatform(gen);
    if (gen !== this.generation) {
      return;                            // ended while the platform was starting
    }
    this.startedAtMs = this.deps.clock.nowMs();
    this.lastActiveFixMs = Number.NaN;
    this.startSources();
    this.tickId = this.deps.scheduler.every(TICK_MS, () => this.onTick(gen));
    this.dispatchType(EngineEventType.START_TOUR);
  }

  /** Continuous task, then AVSession. Each failure is logged, shown as an issue, and the tour goes on. */
  private async startPlatform(gen: number): Promise<void> {
    const bg: BackgroundPort | undefined = this.safeGet(this.deps.background, 'background');
    if (bg === undefined) {
      this.noop('bg', LogEvents.BG_START, 'modes=location,audioPlayback noop=no_service');
    } else {
      try {
        bg.setListener(new BackgroundBridge(this));
        this.bgUp = await this.withTimeout<boolean>(bg.start(), PLATFORM_START_TIMEOUT_MS, false);
        if (!this.bgUp) {
          this.deps.log.error(LogEvents.BG_FAIL, 'where=controller result=false');
          this.addIssue(IssueCode.BG_FAIL, IssueSeverity.WARN, 'continuous task not running');
        }
      } catch (e) {
        this.bgUp = false;
        this.deps.log.error(LogEvents.BG_FAIL, `where=controller ${errText(e as Object)}`);
        this.addIssue(IssueCode.BG_FAIL, IssueSeverity.WARN, 'continuous task failed');
      }
    }
    if (gen !== this.generation) {
      return;
    }
    const media: MediaSessionPort | undefined = this.safeGet(this.deps.media, 'media');
    if (media === undefined) {
      this.noop('avs', LogEvents.AVS_META, 'noop=no_service');
      return;
    }
    try {
      this.avsUp = await this.withTimeout<boolean>(media.init((cmd: MediaCommand) => this.onMediaCommand(cmd)),
        PLATFORM_START_TIMEOUT_MS, false);
      if (!this.avsUp) {
        this.deps.log.error(LogEvents.AVS_FAIL, 'where=controller result=false');
        this.addIssue(IssueCode.AVS_FAIL, IssueSeverity.INFO, 'lock-screen controls unavailable');
      }
    } catch (e) {
      this.avsUp = false;
      this.deps.log.error(LogEvents.AVS_FAIL, `where=controller ${errText(e as Object)}`);
      this.addIssue(IssueCode.AVS_FAIL, IssueSeverity.INFO, 'lock-screen controls unavailable');
    }
  }

  private startSources(): void {
    const gen: number = this.generation;
    const kind: FixSource = this.sourceKind;
    const src: LocationSource | undefined = this.safeGet<LocationSource>(() => this.deps.sourceFor(kind), 'source');
    if (src === undefined) {
      this.deps.log.warn(LogEvents.LOC_SOURCE, `kind=${kind} available=false noop=no_source`);
      this.addIssue(IssueCode.LOC_UNAVAILABLE, IssueSeverity.WARN, `no ${kind} source`);
    } else {
      this.activeSource = src;
      if (kind === FixSource.DEMO) {
        this.wireDemo();
      }
      this.deps.log.info(LogEvents.LOC_SOURCE, `kind=${kind} role=active`);
      this.startSource(src, kind, gen, true);
    }
    if (kind === FixSource.DEMO) {
      this.startShadowReal(gen);
    }
  }

  private wireDemo(): void {
    const dc: DemoControls | undefined = this.demo();
    if (dc === undefined) {
      return;
    }
    try {
      dc.setHoldPredicate(() => this.storyActive());
      dc.setSpeed(this.opts.demoSpeed);
    } catch (e) {
      this.deps.log.error(LogEvents.UNCAUGHT, `where=TourController.wireDemo ${errText(e as Object)}`);
    }
  }

  /** §5: in demo mode the real source keeps running, so the HUD can show "Real GPS: ±xx m". Never asks. */
  private startShadowReal(gen: number): void {
    const real: LocationSource | undefined = this.safeGet<LocationSource>(
      () => this.deps.sourceFor(FixSource.REAL), 'source');
    if (real === undefined || real === this.activeSource) {
      return;
    }
    const perms: PermissionPort | undefined = this.safeGet(this.deps.permissions, 'permissions');
    if (perms === undefined) {
      return;
    }
    perms.locationState().then((ps: PermissionState) => {
      if (gen !== this.generation || ps !== PermissionState.GRANTED || real.isRunning()) {
        return;
      }
      this.shadowSource = real;
      this.deps.log.info(LogEvents.LOC_SOURCE, 'kind=real role=shadow');
      this.startSource(real, FixSource.REAL, gen, false);
    }).catch((e: Object) => {
      this.deps.log.warn(LogEvents.LOC_ERR, `where=shadow_real_permission ${errText(e)}`);
    });
  }

  private startSource(src: LocationSource, kind: FixSource, gen: number, active: boolean): void {
    try {
      src.start((fix: Fix) => this.onSourceFix(gen, kind, active, fix),
        (code: number, msg: string) => this.onSourceError(gen, kind, code, msg)).catch((e: Object) => {
        this.onSourceError(gen, kind, -1, errText(e));
      });
    } catch (e) {
      this.onSourceError(gen, kind, -1, errText(e as Object));
    }
  }

  private stopSources(): void {
    const srcs: (LocationSource | undefined)[] = [this.activeSource, this.shadowSource];
    for (const s of srcs) {
      if (s !== undefined) {
        try {
          s.stop();
        } catch (e) {
          this.deps.log.error(LogEvents.UNCAUGHT, `where=LocationSource.stop kind=${s.kind} ${errText(e as Object)}`);
        }
      }
    }
    this.activeSource = undefined;
    this.shadowSource = undefined;
  }

  /** Stops the session's sources, TICK and the platform. The engine state stays readable (FINISHED/ABORTED). */
  private teardown(why: string): void {
    this.running = false;
    this.generation++;
    this.deps.scheduler.cancel(this.tickId);
    this.tickId = -1;
    this.stopSources();
    const bg: BackgroundPort | undefined = this.safeGet(this.deps.background, 'background');
    if (bg !== undefined && this.bgUp) {
      try {
        bg.stop().catch((e: Object) => {
          this.deps.log.error(LogEvents.BG_FAIL, `where=controller.stop ${errText(e)}`);
        });
      } catch (e) {
        this.deps.log.error(LogEvents.BG_FAIL, `where=controller.stop ${errText(e as Object)}`);
      }
    }
    this.bgUp = false;
    const media: MediaSessionPort | undefined = this.safeGet(this.deps.media, 'media');
    if (media !== undefined && this.avsUp) {
      try {
        media.destroy().catch((e: Object) => {
          this.deps.log.error(LogEvents.AVS_FAIL, `where=controller.destroy ${errText(e)}`);
        });
      } catch (e) {
        this.deps.log.error(LogEvents.AVS_FAIL, `where=controller.destroy ${errText(e as Object)}`);
      }
    }
    this.avsUp = false;
    this.deps.log.info(LogEvents.STATE, `from=${this.phase()} to=${this.phase()} ev=TEARDOWN why=${why}`);
    this.schedulePublish();
  }

  // ================================================================ location and clock

  private onSourceFix(gen: number, kind: FixSource, active: boolean, fix: Fix): void {
    if (gen !== this.generation) {
      return;
    }
    const now: number = this.deps.clock.nowMs();
    if (kind === FixSource.REAL) {
      this.realAccuracyM = fix.accuracyM;
    }
    this.latestFix = fix;
    this.latestFixAtMs = now;
    if (!active || this.state === undefined) {
      this.schedulePublish();
      return;
    }
    this.lastActiveFixMs = now;
    this.timeoutSent = false;
    const ev: EngineEvent = { type: EngineEventType.FIX, nowMs: now, fix: fix };
    this.dispatch(ev);
  }

  private onSourceError(gen: number, kind: FixSource, code: number, msg: string): void {
    if (gen !== this.generation) {
      return;
    }
    this.deps.log.warn(LogEvents.LOC_ERR, `src=${kind} code=${code} ${msg.startsWith('msg=') ? msg : 'msg=' + msg}`);
    if (kind === this.sourceKind) {
      this.addIssue(IssueCode.LOC_UNAVAILABLE, IssueSeverity.WARN, `${kind} code=${code}`);
      this.schedulePublish();
    }
  }

  private onTick(gen: number): void {
    if (gen !== this.generation || !this.running) {
      return;
    }
    const now: number = this.deps.clock.nowMs();
    const since: number = Number.isFinite(this.lastActiveFixMs) ? this.lastActiveFixMs : this.startedAtMs;
    if (!Number.isFinite(this.lastActiveFixMs) && !this.noFixLogged && now - this.startedAtMs >= NO_FIRST_FIX_MS) {
      this.noFixLogged = true;
      this.deps.log.warn(LogEvents.LOC_NOFIX, `secs=${Math.round((now - this.startedAtMs) / 1000)} src=${this.sourceKind}`);
      this.addIssue(IssueCode.LOC_NOFIX, IssueSeverity.WARN, `src=${this.sourceKind}`);
    }
    if (!this.timeoutSent && Number.isFinite(since) && now - since > FIX_TIMEOUT_MS) {
      this.timeoutSent = true;
      this.dispatchType(EngineEventType.FIX_TIMEOUT);
    }
    this.dispatchType(EngineEventType.TICK);
  }

  // ================================================================ dispatch and effects

  private userEvent(type: EngineEventType): void {
    if (this.state === undefined) {
      return;
    }
    this.dispatchType(type);
  }

  private dispatchType(type: EngineEventType): void {
    const ev: EngineEvent = { type: type, nowMs: this.deps.clock.nowMs() };
    this.dispatch(ev);
  }

  /** Runs the reducer for `ev` and every event raised while its effects execute, in arrival order. */
  private dispatch(ev: EngineEvent): void {
    this.pending.push(ev);
    if (this.dispatching) {
      return;
    }
    this.dispatching = true;
    try {
      while (this.pending.length > 0) {
        const e: EngineEvent = this.pending.shift() as EngineEvent;
        const st: TourState | undefined = this.state;
        if (st === undefined) {
          continue;
        }
        let r: StepResult;
        try {
          r = TourEngine.reduce(st, e);
        } catch (err) {
          this.deps.log.error(LogEvents.UNCAUGHT, `where=TourEngine.reduce ev=${e.type} ${errText(err as Object)}`);
          continue;
        }
        this.state = r.state;
        for (const fx of r.effects) {
          this.execute(fx);
        }
      }
    } finally {
      this.dispatching = false;
    }
    this.afterDispatch();
  }

  private afterDispatch(): void {
    const st: TourState | undefined = this.state;
    if (this.running && st !== undefined) {
      const idle: boolean = !st.queue.isBusy() && st.queue.size() === 0;
      if (st.phase === TourPhase.ABORTED || (st.phase === TourPhase.FINISHED && idle)) {
        this.teardown(st.phase === TourPhase.ABORTED ? 'aborted' : 'finished');
      }
    }
    this.schedulePublish();
  }

  private execute(fx: Effect): void {
    try {
      switch (fx.type) {
        case EffectType.SPEAK:
          if (fx.utterance !== undefined) {
            this.deps.speech.speak(fx.utterance);
            this.prefetchAfter(fx.utterance);
          }
          break;
        case EffectType.STOP_SPEECH:
          if (fx.afterCurrent !== true) {
            this.deps.speech.stopNow();
          }
          break;
        case EffectType.SET_MEDIA_META:
          this.mediaMeta(fx);
          break;
        case EffectType.SET_MEDIA_STATE:
          this.mediaState(fx.playState);
          break;
        case EffectType.NOTIFY_NEXT:
          this.notifyNext(fx);
          break;
        case EffectType.HAPTIC:
          this.haptic(fx);
          break;
        case EffectType.REQUEST_REPLAN:
          this.replan();
          break;
        case EffectType.PERSIST_PROGRESS:
          break;                         // nothing is persisted in v1 (no task owns tour resume)
        case EffectType.LOG:
          this.engineLog(fx.logCode === undefined ? 'ENGINE' : fx.logCode, fx.logKv === undefined ? '' : fx.logKv);
          break;
        default:
          break;
      }
    } catch (e) {
      this.deps.log.error(LogEvents.UNCAUGHT, `where=TourController.execute fx=${fx.type} ${errText(e as Object)}`);
    }
  }

  private engineLog(code: string, kv: string): void {
    if (WARN_CODES.indexOf(code) >= 0) {
      this.deps.log.warn(code, kv);
    } else {
      this.deps.log.info(code, kv);
    }
  }

  /** Prefetch the next sentence of the same item while this one plays (A4: ~90 ms gap instead of synthesis time). */
  private prefetchAfter(u: Utterance): void {
    const st: TourState | undefined = this.state;
    if (st === undefined) {
      return;
    }
    const item: Announcement | undefined = st.queue.currentItem();
    if (item === undefined || item.cursor + 1 >= item.utterances.length) {
      return;
    }
    const src: Utterance = item.utterances[item.cursor + 1];
    const id: string = predictNextUtteranceId(u.id, src.id);
    if (id.length === 0) {
      return;
    }
    const next: Utterance = { id: id, itemId: src.itemId, text: src.text, lang: src.lang, personaId: src.personaId };
    this.deps.speech.prefetch(next);
  }

  private mediaMeta(fx: Effect): void {
    const media: MediaSessionPort | undefined = this.safeGet(this.deps.media, 'media');
    if (fx.meta === undefined) {
      return;
    }
    if (media === undefined || !this.avsUp) {
      this.noop('meta', LogEvents.AVS_META, `title="${fx.meta.title}" noop=no_session`);
      return;
    }
    media.setMeta(fx.meta);
  }

  private mediaState(s: MediaPlayState | undefined): void {
    const media: MediaSessionPort | undefined = this.safeGet(this.deps.media, 'media');
    if (s === undefined) {
      return;
    }
    if (media === undefined || !this.avsUp) {
      this.noop('state', LogEvents.AVS_META, `state=${s} noop=no_session`);
      return;
    }
    media.setState(s);
  }

  private notifyNext(fx: Effect): void {
    if (fx.notice === undefined) {
      return;
    }
    const n: NotifierPort | undefined = this.safeGet(this.deps.notifier, 'notifier');
    if (n === undefined) {
      this.noop('notify', LogEvents.NOTIF_PUBLISH, `poi=${fx.notice.poiId} d=${fx.notice.distanceM} noop=no_service`);
      return;
    }
    n.publishNext(fx.notice).catch((e: Object) => {
      this.deps.log.warn(LogEvents.NOTIF_DENIED, `where=publishNext ${errText(e)}`);
    });
  }

  private haptic(fx: Effect): void {
    if (fx.haptic === undefined) {
      return;
    }
    const h: HapticsPort | undefined = this.safeGet(this.deps.haptics, 'haptics');
    if (h === undefined) {
      this.noop(`haptic:${fx.haptic}`, LogEvents.HAPTIC, `kind=${fx.haptic} noop=no_service`);
      return;
    }
    h.play(fx.haptic);
  }

  // ================================================================ snapshot

  private storyActive(): boolean {
    const st: TourState | undefined = this.state;
    return st !== undefined && st.phase === TourPhase.AT_STOP && st.activeIdx >= 0;
  }

  private platformStatus(st: TourState | undefined): PlatformStatus {
    let bgRunning: boolean = false;
    let avsActive: boolean = false;
    try {
      const bg: BackgroundPort | undefined = this.deps.background();
      bgRunning = bg !== undefined && bg.isRunning();
      const media: MediaSessionPort | undefined = this.deps.media();
      avsActive = media !== undefined && media.isActive();
    } catch (e) {
      // status only; never fail a snapshot
    }
    const vp: VoicePlan | undefined = this.voicePlan;
    const textOnly: boolean = st !== undefined ? st.speechText : (vp === undefined || vp.speechMode === 'text');
    const p: PlatformStatus = {
      bgRunning: bgRunning, avsActive: avsActive,
      ttsEngine: textOnly || vp === undefined ? 'none' : `${vp.engineLocale}/${vp.person}`,
      sourceKind: this.sourceKind, realGpsAccuracyM: this.realAccuracyM,
      demoHold: this.running && this.sourceKind === FixSource.DEMO && this.storyActive()
    };
    return p;
  }

  private idleSnapshot(): EngineSnapshot {
    const vp: VoicePlan | undefined = this.voicePlan;
    const s: EngineSnapshot = {
      phase: TourPhase.IDLE, tourId: this.tour !== undefined ? this.tour.id : '', stops: [], currentStopIdx: -1,
      signal: SignalQuality.GOOD, offRoute: false, paused: false,
      speechText: vp !== undefined && vp.speechMode === 'text', plannedOrder: [], walkedM: 0, remainingM: 0,
      issues: [], voiceLabel: vp !== undefined ? vp.label : VoiceLabel.FALLBACK_ZH_READS_EN, source: this.sourceKind,
      platform: this.platformStatus(undefined)
    };
    return s;
  }

  private schedulePublish(): void {
    if (this.publishTimer >= 0 || this.listeners.length === 0) {
      return;
    }
    const wait: number = this.lastPublishMs + SNAPSHOT_MIN_INTERVAL_MS - this.deps.clock.nowMs();
    if (wait <= 0) {
      this.publishNow();
      return;
    }
    this.publishTimer = this.deps.scheduler.after(wait, () => {
      this.publishTimer = -1;
      this.publishNow();
    });
  }

  private publishNow(): void {
    if (this.publishTimer >= 0) {
      this.deps.scheduler.cancel(this.publishTimer);
      this.publishTimer = -1;
    }
    this.lastPublishMs = this.deps.clock.nowMs();
    if (this.listeners.length === 0) {
      return;
    }
    const s: EngineSnapshot = this.current();
    for (const l of this.listeners) {
      this.safeNotify(l, s);
    }
  }

  private safeNotify(l: SnapshotListener, s: EngineSnapshot): void {
    try {
      l(s);
    } catch (e) {
      this.deps.log.error(LogEvents.UNCAUGHT, `where=SnapshotListener ${errText(e as Object)}`);
    }
  }

  // ================================================================ small helpers

  private phase(): TourPhase {
    return this.state === undefined ? TourPhase.IDLE : this.state.phase;
  }

  private demo(): DemoControls | undefined {
    return this.safeGet(this.deps.demoControls, 'demo');
  }

  private safeGet<T>(f: () => T | undefined, what: string): T | undefined {
    try {
      return f();
    } catch (e) {
      this.deps.log.error(LogEvents.UNCAUGHT, `where=TourController.get ${what} ${errText(e as Object)}`);
      return undefined;
    }
  }

  /** One log line per tour and key for an effect whose service is not wired yet. */
  private noop(key: string, event: string, kv: string): void {
    if (this.noopLogged.has(key)) {
      return;
    }
    this.noopLogged.add(key);
    this.deps.log.info(event, kv);
  }

  private addIssue(code: IssueCode, severity: IssueSeverity, detail: string): void {
    for (const i of this.ctrlIssues) {
      if (i.code === code) {
        i.severity = severity;
        i.detail = detail;
        return;
      }
    }
    const issue: AppIssue = { code: code, severity: severity, detail: detail };
    this.ctrlIssues.push(issue);
  }

  /** Resolves with `fallback` if `p` has not settled after `ms`; a later rejection is swallowed. */
  private withTimeout<T>(p: Promise<T>, ms: number, fallback: T): Promise<T> {
    return new Promise<T>((resolve) => {
      let settled: boolean = false;
      const id: number = this.deps.scheduler.after(ms, () => {
        if (!settled) {
          settled = true;
          this.deps.log.warn(LogEvents.UNCAUGHT, `where=TourController.withTimeout ms=${ms}`);
          resolve(fallback);
        }
      });
      p.then((v: T) => {
        if (!settled) {
          settled = true;
          this.deps.scheduler.cancel(id);
          resolve(v);
        }
      }).catch((e: Object) => {
        if (!settled) {
          settled = true;
          this.deps.scheduler.cancel(id);
          this.deps.log.error(LogEvents.UNCAUGHT, `where=TourController.withTimeout ${errText(e)}`);
          resolve(fallback);
        }
      });
    });
  }
}

/*
 * The tour engine as a reducer: TourEngine.reduce(state, event) => { state, effects } (task A3).
 * Sources: docs/ARCHITECTURE.md §4.1 (state machine and orthogonal flags), §4.2 (events and effects,
 * contracts/EngineTypes.ets), §4.3 (triggers, teaser vs full, a stop auto-spoken once per tour), §4.4 (queue),
 * §4.5 (relDir in the arrival line), §9 rows 5/6/11/12/13/14 (GPS lost, poor accuracy, TTS errors,
 * audio interrupt, route lost, background cancelled), §10 (log codes); DESIGN §5.3/§5.5.
 *
 * Contract with the caller (TourController, A7):
 *   - The reducer never calls a service. It returns effects; the controller executes them in order.
 *   - Time comes only from event.nowMs, so a replayed event list gives the same effects.
 *   - The state is owned by the caller's loop: reduce() updates it in place and returns it (ArkTS has no
 *     cheap structural copy, and the A1 FixFilter/CourseEstimator inside it are stateful classes).
 *     Never feed an old state object twice.
 *   - Sentence = utterance: SPEAK is emitted for one sentence at a time, the next one only after
 *     UTTERANCE_DONE (or UTTERANCE_FAILED) of the in-flight one. In text-only mode no SPEAK is emitted;
 *     the caption advances on TICK after max(2.5 s, words / 2.6 per s).
 *
 * Flow per stop: arrival (2-fix debounced ENTER) => HAPTIC(arrive) + SET_MEDIA_META + one P2 item
 * [arrival line, look clause, teaser...]; when it ends, FULL is queued if the user lingers (TriggerPolicy),
 * else the stop is TEASER_ONLY (STORY_SKIP_MOVING); when the stop is done the next-stop line (P2),
 * NOTIFY_NEXT and SET_MEDIA_META follow, or the finish line + HAPTIC(finish) after the last stop.
 * Only an open stop (PENDING or APPROACHING) can fire, and while one stop's story plays no other stop
 * fires, so St Mary's / Cloth Hall cannot ping-pong. While paused, fixes still update the position and
 * arrivals are queued, but no sentence starts.
 * Pure: no platform imports.
 */
import {
  Announcement, AnnouncementKind, AppIssue, Effect, EffectType, EngineEvent, EngineEventType, EngineSnapshot,
  HapticKind, IssueCode, IssueSeverity, MediaMeta, MediaPlayState, NextInfo, NextNotice, NowPlaying, PlatformStatus,
  Priority, RelDir, SignalQuality, StopProgress, StopStatus, TourPhase, TourPlan, UserPos
} from '../../contracts/EngineTypes';
import { Fix, FixSource, Utterance, VoicePlan } from '../../contracts/Ports';
import { ContentTier, Lang, Narration, NarrationLength, Poi, Tour, TourStop, ViewHint } from '../../contracts/Model';
import { VoiceLabel } from '../../contracts/Settings';
import { AnnouncementQueue, QueueAdvance, expiryFor, readingTimeMs } from './AnnouncementQueue';
import {
  StopTrigger, StoryLength, TriggerSample, TriggerVerdict, decideStoryLength, evaluateTrigger
} from './TriggerPolicy';
import { TourConfig } from './TourConfig';
import { FilteredFix, FixFilter } from '../geo/FixFilter';
import { CourseEstimate, CourseEstimator, CourseSource } from '../geo/CourseEstimator';
import { bearingDeg, haversineM, relDir } from '../geo/GeoMath';
import { KRAKOW_PROJECTION, Projection } from '../geo/Projection';
import {
  approachSentence, arrivalSentences, finishSentences, gpsLostSentence, localized, nextStopSentence,
  welcomeSentences
} from '../content/Phrases';

/** Log codes used in LOG effects (same strings as app/LogEvents.ets; core/ may not import app/). */
export class EngineLog {
  static readonly STATE: string = 'STATE';
  static readonly TOUR_CONFIG: string = 'TOUR_CONFIG';
  static readonly ROUTE_PLAN: string = 'ROUTE_PLAN';
  static readonly REPLAN: string = 'REPLAN';
  static readonly PACK_DROP: string = 'PACK_DROP';
  static readonly POI_APPROACH: string = 'POI_APPROACH';
  static readonly POI_ENTER: string = 'POI_ENTER';
  static readonly POI_EXIT: string = 'POI_EXIT';
  static readonly STORY_QUEUE: string = 'STORY_QUEUE';
  static readonly STORY_START: string = 'STORY_START';
  static readonly STORY_END: string = 'STORY_END';
  static readonly STORY_SKIP_MOVING: string = 'STORY_SKIP_MOVING';
  static readonly NARR_FALLBACK: string = 'NARR_FALLBACK';
  static readonly QUEUE_EXPIRED: string = 'QUEUE_EXPIRED';
  static readonly LOC_POOR: string = 'LOC_POOR';
  static readonly LOC_LOST: string = 'LOC_LOST';
  static readonly LOC_BACK: string = 'LOC_BACK';
  static readonly TTS_ERR: string = 'TTS_ERR';
  static readonly AUDIO_INTERRUPT: string = 'AUDIO_INTERRUPT';
  static readonly AUDIO_ROUTE: string = 'AUDIO_ROUTE';
  static readonly BG_CANCEL: string = 'BG_CANCEL';
}

/** Narration lookup (PackRepository.narration bound to the persona and text language; validated + fallback). */
export type NarrationFn = (poiId: string, length: NarrationLength) => Narration | undefined;

/** Everything the engine needs from the pack and the settings, fixed for one tour. */
export interface TourInput {
  tour: Tour;
  pois: Poi[];                 // at least the tour's stops
  lang: Lang;                  // text language of narration and phrases
  personaId: string;
  narration: NarrationFn;
  voice: VoicePlan;            // speechMode 'voice' | 'text' and the honesty label
  adaptiveLength: boolean;     // UserSettings.adaptiveLength (teaser if walking past)
  spokenDirections: boolean;   // UserSettings.spokenDirections; false = gate G9 fallback (no left/right)
  source: FixSource;           // active location source at start (DEMO => SIMULATED welcome line)
  projection?: Projection;     // defaults to the Kraków pack projection
}

export enum StopStage { NONE = 'none', TEASER = 'teaser', FULL = 'full', DONE = 'done' }

/** One stop of the planned order, with its geofence. */
export class StopRuntime {
  readonly poiId: string;
  readonly name: string;
  readonly lat: number;
  readonly lng: number;
  readonly view: ViewHint | undefined;
  readonly approachRadiusM: number;
  order: number;
  status: StopStatus = StopStatus.PENDING;
  trigger: StopTrigger;

  constructor(poi: Poi, name: string, order: number, triggerRadiusM: number, approachRadiusM: number) {
    this.poiId = poi.id;
    this.name = name;
    this.lat = poi.lat;
    this.lng = poi.lng;
    this.view = poi.view;
    this.order = order;
    this.approachRadiusM = approachRadiusM;
    this.trigger = new StopTrigger(poi.id, triggerRadiusM);
  }
}

export interface StepResult {
  state: TourState;
  effects: Effect[];
}

function unknownCourse(): CourseEstimate {
  const c: CourseEstimate = { courseDeg: Number.NaN, source: CourseSource.UNKNOWN, known: false };
  return c;
}

/** The engine state. Created by TourEngine.init, advanced only by TourEngine.reduce. */
export class TourState {
  readonly input: TourInput;
  readonly cfg: TourConfig;
  readonly projection: Projection;
  phase: TourPhase = TourPhase.IDLE;
  plan: TourPlan | undefined = undefined;
  stops: StopRuntime[] = [];
  targetIdx: number = -1;          // next planned open stop
  activeIdx: number = -1;          // stop whose story is playing (AT_STOP)
  lastStopIdx: number = -1;        // most recently finished stop (USER_MORE / USER_REPLAY while walking)
  stage: StopStage = StopStage.NONE;
  storyItemId: string = '';        // queue item that drives the AT_STOP sub-state
  userAskedMore: boolean = false;
  paused: boolean = false;
  pausedByAudio: boolean = false;  // §9 row 12: paused by an audio interrupt, so its RESUME hint may resume
  speechText: boolean;
  voiceLabel: VoiceLabel;
  signal: SignalQuality = SignalQuality.GOOD;
  source: FixSource;
  lastFix: Fix | undefined = undefined;
  course: CourseEstimate = unknownCourse();
  speedMedianMps: number = Number.NaN;
  filter: FixFilter = new FixFilter();
  courseEstimator: CourseEstimator = new CourseEstimator();
  queue: AnnouncementQueue = new AnnouncementQueue();
  itemSeq: number = 0;
  itemTier: Map<string, ContentTier> = new Map<string, ContentTier>();
  textDueMs: number = Number.NaN;
  walkedM: number = 0;
  trackLat: number = Number.NaN;
  trackLng: number = Number.NaN;
  approachFarSinceMs: number = Number.NaN;
  gpsEpisode: number = 0;
  lastPoorLogMs: number = Number.NEGATIVE_INFINITY;
  ttsErrorStreak: number = 0;
  issues: AppIssue[] = [];
  nowMs: number = 0;

  constructor(input: TourInput, cfg: TourConfig) {
    this.input = input;
    this.cfg = cfg;
    this.projection = input.projection !== undefined ? input.projection : KRAKOW_PROJECTION;
    this.speechText = input.voice.speechMode === 'text';
    this.voiceLabel = input.voice.label;
    this.source = input.source;
  }
}

// ---------------------------------------------------------------- effects

class Fx {
  list: Effect[] = [];

  speak(u: Utterance): void {
    const e: Effect = { type: EffectType.SPEAK, utterance: u };
    this.list.push(e);
  }

  stopSpeech(afterCurrent: boolean): void {
    const e: Effect = { type: EffectType.STOP_SPEECH, afterCurrent: afterCurrent };
    this.list.push(e);
  }

  meta(m: MediaMeta): void {
    const e: Effect = { type: EffectType.SET_MEDIA_META, meta: m };
    this.list.push(e);
  }

  mediaState(s: MediaPlayState): void {
    const e: Effect = { type: EffectType.SET_MEDIA_STATE, playState: s };
    this.list.push(e);
  }

  notify(n: NextNotice): void {
    const e: Effect = { type: EffectType.NOTIFY_NEXT, notice: n };
    this.list.push(e);
  }

  haptic(k: HapticKind): void {
    const e: Effect = { type: EffectType.HAPTIC, haptic: k };
    this.list.push(e);
  }

  persist(): void {
    const e: Effect = { type: EffectType.PERSIST_PROGRESS };
    this.list.push(e);
  }

  log(code: string, kv: string): void {
    const e: Effect = { type: EffectType.LOG, logCode: code, logKv: kv };
    this.list.push(e);
  }
}

// ---------------------------------------------------------------- helpers

function isTouring(p: TourPhase): boolean {
  return p === TourPhase.WALKING || p === TourPhase.APPROACHING || p === TourPhase.AT_STOP;
}

function isOpen(s: StopStatus): boolean {
  return s === StopStatus.PENDING || s === StopStatus.APPROACHING;
}

function firstOpen(st: TourState): number {
  for (let i = 0; i < st.stops.length; i++) {
    if (isOpen(st.stops[i].status)) {
      return i;
    }
  }
  return -1;
}

function r1(n: number): string {
  return Number.isFinite(n) ? `${Math.round(n)}` : 'NaN';
}

function setPhase(st: TourState, fx: Fx, to: TourPhase, ev: string, stopId: string): void {
  if (st.phase === to) {
    return;
  }
  fx.log(EngineLog.STATE, `from=${st.phase} to=${to} ev=${ev}` + (stopId.length > 0 ? ` stop=${stopId}` : ''));
  st.phase = to;
}

function addIssue(st: TourState, code: IssueCode, severity: IssueSeverity, detail: string): void {
  for (const i of st.issues) {
    if (i.code === code) {
      i.severity = severity;
      i.detail = detail;
      return;
    }
  }
  const issue: AppIssue = { code: code, severity: severity, detail: detail };
  st.issues.push(issue);
}

function removeIssue(st: TourState, code: IssueCode): void {
  st.issues = st.issues.filter((i: AppIssue) => i.code !== code);
}

function tourTitle(st: TourState): string {
  return localized(st.input.tour.titles, st.input.lang);
}

function distanceTo(st: TourState, s: StopRuntime): number {
  const f: Fix | undefined = st.lastFix;
  return f === undefined ? Number.NaN : haversineM(f.lat, f.lng, s.lat, s.lng);
}

function relDirTo(st: TourState, s: StopRuntime, d: number): RelDir {
  const f: Fix | undefined = st.lastFix;
  if (f === undefined) {
    return RelDir.HERE;
  }
  return relDir(bearingDeg(f.lat, f.lng, s.lat, s.lng), st.course.courseDeg, d);
}

function emitMeta(st: TourState, fx: Fx, title: string): void {
  const m: MediaMeta = {
    title: title, artist: tourTitle(st), voiceLabel: st.voiceLabel, demo: st.source === FixSource.DEMO
  };
  fx.meta(m);
}

function findPoi(st: TourState, id: string): Poi | undefined {
  for (const p of st.input.pois) {
    if (p.id === id) {
      return p;
    }
  }
  return undefined;
}

function findTourStop(st: TourState, id: string): TourStop | undefined {
  for (const s of st.input.tour.stops) {
    if (s.poiId === id) {
      return s;
    }
  }
  return undefined;
}

function narrationOf(st: TourState, poiId: string, len: NarrationLength): Narration | undefined {
  const n: Narration | undefined = st.input.narration(poiId, len);
  return n !== undefined && n.sentences.length > 0 ? n : undefined;
}

/** Builds the queue item and logs STORY_QUEUE. Returns the item id, or '' if the queue refused it. */
function enqueue(st: TourState, fx: Fx, priority: Priority, kind: AnnouncementKind, poiId: string,
  sentences: string[], dedupeKey: string, tier: ContentTier): string {
  st.itemSeq++;
  const id: string = `it${st.itemSeq}`;
  const us: Utterance[] = [];
  for (let i = 0; i < sentences.length; i++) {
    const u: Utterance = {
      id: `${id}.${i}`, itemId: id, text: sentences[i], lang: st.input.lang, personaId: st.input.personaId
    };
    us.push(u);
  }
  const a: Announcement = {
    id: id, priority: priority, kind: kind, poiId: poiId, utterances: us, cursor: 0,
    expiresAtMs: expiryFor(priority, st.nowMs, st.cfg), dedupeKey: dedupeKey
  };
  if (!st.queue.enqueue(a)) {
    return '';
  }
  st.itemTier.set(id, tier);
  fx.log(EngineLog.STORY_QUEUE, `id=${id} prio=P${priority} kind=${kind} poi=${poiId} n=${us.length}`);
  return id;
}

function expireQueue(st: TourState, fx: Fx): void {
  for (const a of st.queue.expire(st.nowMs)) {
    st.itemTier.delete(a.id);
    fx.log(EngineLog.QUEUE_EXPIRED, `id=${a.id} prio=P${a.priority} kind=${a.kind} key=${a.dedupeKey}`);
  }
}

/** Starts the next sentence if nothing is in flight and the tour is not paused. */
function pump(st: TourState, fx: Fx): void {
  if (st.paused || st.queue.isBusy()) {
    return;
  }
  expireQueue(st, fx);
  const u: Utterance | undefined = st.queue.next();
  if (u === undefined) {
    return;
  }
  const item: Announcement | undefined = st.queue.currentItem();
  if (item !== undefined && item.cursor === 0) {
    const tier: ContentTier | undefined = st.itemTier.get(item.id);
    fx.log(EngineLog.STORY_START, `id=${item.id} poi=${item.poiId === undefined ? '' : item.poiId} kind=${item.kind} ` +
      `tier=${tier === undefined ? '' : tier} lang=${st.input.lang} mode=${st.speechText ? 'text' : 'voice'}`);
  }
  if (st.speechText) {
    st.textDueMs = st.nowMs + readingTimeMs(u.text, st.cfg);
  } else {
    fx.speak(u);
  }
}

// ---------------------------------------------------------------- planning

function buildStops(st: TourState, fx: Fx, order: string[]): StopRuntime[] {
  const out: StopRuntime[] = [];
  for (const id of order) {
    const poi: Poi | undefined = findPoi(st, id);
    if (poi === undefined) {
      fx.log(EngineLog.PACK_DROP, `file=plan poi=${id} reason=unknown_poi`);
      continue;
    }
    const ts: TourStop | undefined = findTourStop(st, id);
    let trigR: number = st.cfg.defaultTriggerRadiusM;
    if (ts !== undefined && ts.triggerRadiusM !== undefined && ts.triggerRadiusM > 0) {
      trigR = ts.triggerRadiusM;
    } else if (poi.triggerRadiusM > 0) {
      trigR = poi.triggerRadiusM;
    }
    let appR: number = st.cfg.approachRadiusM;
    if (ts !== undefined && ts.approachRadiusM !== undefined && ts.approachRadiusM > 0) {
      appR = ts.approachRadiusM;
    }
    appR = Math.max(appR, trigR + 30);   // DESIGN §5.3: approach >= R + 30 m
    out.push(new StopRuntime(poi, localized(poi.names, st.input.lang), out.length, trigR, appR));
  }
  return out;
}

function onPlanReady(st: TourState, fx: Fx, plan: TourPlan): void {
  if (st.phase === TourPhase.PLANNING) {
    st.plan = plan;
    st.stops = buildStops(st, fx, plan.order);
    fx.log(EngineLog.ROUTE_PLAN, `algo=${plan.algo} n=${st.stops.length} costS=${r1(plan.costS)} ` +
      `ms=${r1(plan.ms)} order=${st.stops.map((s: StopRuntime) => s.poiId).join(',')}`);
    if (st.stops.length === 0) {
      setPhase(st, fx, TourPhase.IDLE, EngineEventType.PLAN_READY, '');
      return;
    }
    st.targetIdx = 0;
    setPhase(st, fx, TourPhase.READY, EngineEventType.PLAN_READY, '');
    return;
  }
  if (!isTouring(st.phase)) {
    return;
  }
  // Re-plan mid-tour (A9): keep finished stops in place, reorder the open ones to the new plan.
  st.plan = plan;
  const before: string = st.targetIdx >= 0 ? st.stops[st.targetIdx].poiId : '';
  const done: StopRuntime[] = st.stops.filter((s: StopRuntime) => !isOpen(s.status));
  const open: StopRuntime[] = [];
  for (const id of plan.order) {
    for (const s of st.stops) {
      if (s.poiId === id && isOpen(s.status) && open.indexOf(s) < 0) {
        open.push(s);
      }
    }
  }
  for (const s of st.stops) {            // open stops the new plan forgot stay pending at the end
    if (isOpen(s.status) && open.indexOf(s) < 0) {
      open.push(s);
    }
  }
  const active: StopRuntime | undefined = st.activeIdx >= 0 ? st.stops[st.activeIdx] : undefined;
  const last: StopRuntime | undefined = st.lastStopIdx >= 0 ? st.stops[st.lastStopIdx] : undefined;
  st.stops = done.concat(open);
  for (let i = 0; i < st.stops.length; i++) {
    st.stops[i].order = i;
  }
  st.activeIdx = active === undefined ? -1 : st.stops.indexOf(active);
  st.lastStopIdx = last === undefined ? -1 : st.stops.indexOf(last);
  st.targetIdx = firstOpen(st);
  const after: string = st.targetIdx >= 0 ? st.stops[st.targetIdx].poiId : '';
  if (after !== before) {
    fx.log(EngineLog.REPLAN, `from=${before} to=${after}`);
    if (st.phase === TourPhase.APPROACHING) {
      for (const s of st.stops) {
        if (s.status === StopStatus.APPROACHING) {
          s.status = StopStatus.PENDING;
        }
      }
      setPhase(st, fx, TourPhase.WALKING, EngineEventType.PLAN_READY, after);
    }
    if (st.targetIdx >= 0) {
      notifyNext(st, fx, st.stops[st.targetIdx]);
    }
  }
}

function notifyNext(st: TourState, fx: Fx, s: StopRuntime): void {
  const d: number = distanceTo(st, s);
  const n: NextNotice = {
    poiId: s.poiId, title: s.name, text: nextStopSentence(st.input.lang, s.name, d, st.cfg.walkSpeedMps),
    distanceM: Number.isFinite(d) ? Math.round(d) : -1
  };
  fx.notify(n);
}

function onStartTour(st: TourState, fx: Fx): void {
  if (st.phase !== TourPhase.READY || st.targetIdx < 0) {
    return;
  }
  setPhase(st, fx, TourPhase.WALKING, EngineEventType.START_TOUR, '');
  fx.log(EngineLog.TOUR_CONFIG, st.cfg.toLogKv() + ` adaptive=${st.input.adaptiveLength} ` +
    `directions=${st.input.spokenDirections} lang=${st.input.lang} voice=${st.voiceLabel} src=${st.source}`);
  fx.mediaState(MediaPlayState.PLAY);
  const t: StopRuntime = st.stops[st.targetIdx];
  emitMeta(st, fx, t.name);
  notifyNext(st, fx, t);
  const lines: string[] = welcomeSentences(st.input.lang, tourTitle(st), st.source === FixSource.DEMO);
  lines.push(nextStopSentence(st.input.lang, t.name, distanceTo(st, t), st.cfg.walkSpeedMps));
  enqueue(st, fx, Priority.P2_STORY, AnnouncementKind.SYSTEM, '', lines, 'welcome', ContentTier.REVIEWED_HISTORIAN);
  fx.persist();
}

// ---------------------------------------------------------------- location

function sampleFor(fix: Fix, triggerGrade: boolean, s: StopRuntime): TriggerSample {
  const ts: TriggerSample = {
    tMs: fix.timestampMs, distanceM: haversineM(fix.lat, fix.lng, s.lat, s.lng), accuracyM: fix.accuracyM,
    speedMps: fix.speedMps, triggerGrade: triggerGrade
  };
  return ts;
}

function onFix(st: TourState, fx: Fx, fix: Fix): void {
  const f: FilteredFix = st.filter.accept(fix);
  if (!f.accepted) {
    return;
  }
  st.course = st.courseEstimator.update(fix);
  st.speedMedianMps = f.speedMedianMps;
  st.lastFix = fix;
  st.source = fix.source;

  const wasLost: boolean = st.signal === SignalQuality.LOST;
  if (f.triggerGrade) {
    st.signal = SignalQuality.GOOD;
    removeIssue(st, IssueCode.LOC_POOR);
  } else {
    st.signal = SignalQuality.POOR;
    addIssue(st, IssueCode.LOC_POOR, IssueSeverity.WARN, `acc=${r1(fix.accuracyM)}`);
    if (st.nowMs - st.lastPoorLogMs >= st.cfg.poorLogIntervalMs) {
      st.lastPoorLogMs = st.nowMs;
      fx.log(EngineLog.LOC_POOR, `acc=${r1(fix.accuracyM)} prov=${fix.provider}`);
    }
  }
  if (wasLost) {
    st.gpsEpisode++;
    removeIssue(st, IssueCode.LOC_LOST);
    fx.log(EngineLog.LOC_BACK, `acc=${r1(fix.accuracyM)}`);
  }

  if (!isTouring(st.phase)) {
    return;
  }
  if (f.triggerGrade) {
    if (Number.isFinite(st.trackLat)) {
      const step: number = haversineM(st.trackLat, st.trackLng, fix.lat, fix.lng);
      if (step >= 1) {
        st.walkedM += step;
        st.trackLat = fix.lat;
        st.trackLng = fix.lng;
      }
    } else {
      st.trackLat = fix.lat;
      st.trackLng = fix.lng;
    }
  }

  if (st.phase === TourPhase.AT_STOP) {
    if (st.activeIdx >= 0) {
      const s: StopRuntime = st.stops[st.activeIdx];
      if (evaluateTrigger(s.trigger, sampleFor(fix, f.triggerGrade, s), st.cfg) === TriggerVerdict.EXIT) {
        fx.log(EngineLog.POI_EXIT, `id=${s.poiId} dwell=${r1((st.nowMs - s.trigger.enteredAtMs) / 1000)}`);
      }
    }
  } else {
    checkArrivalAndApproach(st, fx, fix, f.triggerGrade);
  }
  pump(st, fx);
}

function checkArrivalAndApproach(st: TourState, fx: Fx, fix: Fix, triggerGrade: boolean): void {
  let enterIdx: number = -1;
  const entered: number[] = [];
  for (let i = 0; i < st.stops.length; i++) {
    const s: StopRuntime = st.stops[i];
    if (!isOpen(s.status)) {
      continue;
    }
    if (evaluateTrigger(s.trigger, sampleFor(fix, triggerGrade, s), st.cfg) === TriggerVerdict.ENTER) {
      entered.push(i);
      if (enterIdx < 0 || i === st.targetIdx) {
        enterIdx = i;
      }
    }
  }
  for (const i of entered) {
    if (i !== enterIdx) {               // only one arrival per fix; the other may enter again later
      const s: StopRuntime = st.stops[i];
      s.trigger = new StopTrigger(s.poiId, s.trigger.triggerRadiusM);
    }
  }
  if (enterIdx >= 0) {
    arrive(st, fx, enterIdx, fix);
    return;
  }
  if (st.targetIdx < 0 || !triggerGrade) {
    return;
  }
  const t: StopRuntime = st.stops[st.targetIdx];
  const d: number = haversineM(fix.lat, fix.lng, t.lat, t.lng);
  if (st.phase === TourPhase.WALKING) {
    if (d <= t.approachRadiusM && d > t.trigger.triggerRadiusM) {
      t.status = StopStatus.APPROACHING;
      st.approachFarSinceMs = Number.NaN;
      setPhase(st, fx, TourPhase.APPROACHING, EngineEventType.FIX, t.poiId);
      fx.log(EngineLog.POI_APPROACH, `id=${t.poiId} d=${r1(d)}`);
      const line: string = approachSentence(st.input.lang, t.name, relDirTo(st, t, d), d, st.cfg.walkSpeedMps,
        st.input.spokenDirections);
      enqueue(st, fx, Priority.P3_APPROACH, AnnouncementKind.APPROACH, t.poiId, [line], `approach:${t.poiId}`,
        ContentTier.REVIEWED_HISTORIAN);
    }
    return;
  }
  // APPROACHING: back to WALKING after 20 s beyond approachR * 1.3 (passed by / detour)
  if (d > t.approachRadiusM * st.cfg.approachExitFactor) {
    if (!Number.isFinite(st.approachFarSinceMs)) {
      st.approachFarSinceMs = st.nowMs;
    } else if (st.nowMs - st.approachFarSinceMs >= st.cfg.approachExitHoldMs) {
      t.status = StopStatus.PENDING;
      st.approachFarSinceMs = Number.NaN;
      setPhase(st, fx, TourPhase.WALKING, EngineEventType.FIX, t.poiId);
    }
  } else {
    st.approachFarSinceMs = Number.NaN;
  }
}

function arrive(st: TourState, fx: Fx, idx: number, fix: Fix): void {
  const s: StopRuntime = st.stops[idx];
  const d: number = haversineM(fix.lat, fix.lng, s.lat, s.lng);
  s.status = StopStatus.VISITED;        // auto-spoken at most once per tour (TEASER_ONLY may replace it)
  st.activeIdx = idx;
  st.userAskedMore = false;
  st.approachFarSinceMs = Number.NaN;
  st.queue.removeWaiting(`approach:${s.poiId}`);
  setPhase(st, fx, TourPhase.AT_STOP, EngineEventType.FIX, s.poiId);
  fx.log(EngineLog.POI_ENTER, `id=${s.poiId} d=${r1(d)} acc=${r1(fix.accuracyM)} spd=${fix.speedMps.toFixed(1)}`);
  fx.haptic(HapticKind.ARRIVE);
  emitMeta(st, fx, s.name);

  const lines: string[] = arrivalSentences(st.input.lang, s.name, relDirTo(st, s, d), s.view,
    st.input.spokenDirections);
  if (st.speechText) {
    const n: NextNotice = { poiId: s.poiId, title: s.name, text: lines.join(' '), distanceM: Math.round(d) };
    fx.notify(n);
  }
  const teaser: Narration | undefined = narrationOf(st, s.poiId, NarrationLength.TEASER);
  const full: Narration | undefined = narrationOf(st, s.poiId, NarrationLength.FULL);
  let kind: AnnouncementKind = AnnouncementKind.STOP_STORY;
  let tier: ContentTier = ContentTier.NAME_ONLY;
  let stage: StopStage = StopStage.FULL;
  let story: string[] = [];
  if (teaser !== undefined) {
    tier = teaser.tier;
    stage = StopStage.TEASER;
    story = teaser.sentences;
  } else if (full !== undefined) {
    kind = AnnouncementKind.FULL_STORY;
    tier = full.tier;
    story = full.sentences;
  } else {
    fx.log(EngineLog.NARR_FALLBACK, `poi=${s.poiId} lang=${st.input.lang} reason=no_narration tier=name-only`);
  }
  st.stage = stage;
  st.storyItemId = enqueue(st, fx, Priority.P2_STORY, kind, s.poiId, lines.concat(story), `story:${s.poiId}`, tier);
}

function onFixTimeout(st: TourState, fx: Fx): void {
  if (!isTouring(st.phase) || st.signal === SignalQuality.LOST) {
    return;                              // spoken once per lost episode
  }
  st.signal = SignalQuality.LOST;
  const secs: string = st.lastFix === undefined ? 'NaN' : r1((st.nowMs - st.lastFix.timestampMs) / 1000);
  fx.log(EngineLog.LOC_LOST, `secs=${secs}`);
  addIssue(st, IssueCode.LOC_LOST, IssueSeverity.WARN, `secs=${secs}`);
  enqueue(st, fx, Priority.P0_SYSTEM, AnnouncementKind.SYSTEM, '', [gpsLostSentence(st.input.lang)],
    `gps-lost:${st.gpsEpisode}`, ContentTier.REVIEWED_HISTORIAN);
  pump(st, fx);
}

// ---------------------------------------------------------------- speech

/** Event label of the AtStop -> Walking/Finished transitions in STATE logs (§4.1 calls it ITEM_DONE). */
const ITEM_DONE: string = 'ITEM_DONE';

function finishStop(st: TourState, fx: Fx, status: StopStatus): void {
  const s: StopRuntime = st.stops[st.activeIdx];
  s.status = status;
  st.lastStopIdx = st.activeIdx;
  st.activeIdx = -1;
  st.stage = StopStage.DONE;
  st.storyItemId = '';
  st.userAskedMore = false;
  fx.persist();
  const next: number = firstOpen(st);
  st.targetIdx = next;
  if (next < 0) {
    setPhase(st, fx, TourPhase.FINISHED, ITEM_DONE, s.poiId);
    fx.haptic(HapticKind.FINISH);
    emitMeta(st, fx, tourTitle(st));
    enqueue(st, fx, Priority.P2_STORY, AnnouncementKind.SYSTEM, '', finishSentences(st.input.lang), 'finish',
      ContentTier.REVIEWED_HISTORIAN);
    return;
  }
  const t: StopRuntime = st.stops[next];
  setPhase(st, fx, TourPhase.WALKING, ITEM_DONE, s.poiId);
  notifyNext(st, fx, t);
  emitMeta(st, fx, t.name);
  enqueue(st, fx, Priority.P2_STORY, AnnouncementKind.NAV_CUE, t.poiId,
    [nextStopSentence(st.input.lang, t.name, distanceTo(st, t), st.cfg.walkSpeedMps)], `next:${t.poiId}`,
    ContentTier.REVIEWED_HISTORIAN);
}

function onItemFinished(st: TourState, fx: Fx, item: Announcement, skipped: boolean): void {
  st.itemTier.delete(item.id);
  fx.log(EngineLog.STORY_END, `id=${item.id} poi=${item.poiId === undefined ? '' : item.poiId} kind=${item.kind} ` +
    `skipped=${skipped}`);
  if (item.dedupeKey === 'finish') {
    fx.mediaState(MediaPlayState.STOP);
    return;
  }
  if (item.id !== st.storyItemId || st.activeIdx < 0) {
    return;
  }
  const s: StopRuntime = st.stops[st.activeIdx];
  if (skipped || st.stage !== StopStage.TEASER) {
    finishStop(st, fx, StopStatus.VISITED);
    return;
  }
  const len: StoryLength = decideStoryLength(s.trigger, st.speedMedianMps, st.input.adaptiveLength,
    st.userAskedMore, st.cfg);
  const full: Narration | undefined = narrationOf(st, s.poiId, NarrationLength.FULL);
  if (len === StoryLength.FULL && full !== undefined) {
    st.stage = StopStage.FULL;
    st.storyItemId = enqueue(st, fx, Priority.P2_STORY, AnnouncementKind.FULL_STORY, s.poiId, full.sentences,
      `full:${s.poiId}`, full.tier);
    return;
  }
  if (len === StoryLength.TEASER_ONLY) {
    fx.log(EngineLog.STORY_SKIP_MOVING, `poi=${s.poiId} spd=${Number.isFinite(st.speedMedianMps) ?
      st.speedMedianMps.toFixed(1) : 'NaN'} inside=${s.trigger.inside} slowDwellS=${r1(s.trigger.slowDwellMs / 1000)}`);
    finishStop(st, fx, StopStatus.TEASER_ONLY);
    return;
  }
  finishStop(st, fx, StopStatus.VISITED);  // full wanted but none exists
}

function onUtteranceEnd(st: TourState, fx: Fx, id: string, failed: boolean, code: number): void {
  const r: QueueAdvance = st.queue.onDone(id);
  if (!r.matched) {
    return;                              // stale (cut by a pause) or unknown id
  }
  st.textDueMs = Number.NaN;
  if (failed) {
    st.ttsErrorStreak++;
    fx.log(EngineLog.TTS_ERR, `req=${id} code=${code} streak=${st.ttsErrorStreak}`);
    if (st.ttsErrorStreak >= st.cfg.maxConsecutiveTtsErrors && !st.speechText) {
      st.speechText = true;
      st.voiceLabel = VoiceLabel.TEXT_ONLY_PLATFORM;
      addIssue(st, IssueCode.TTS_ERR, IssueSeverity.WARN, `consecutive=${st.ttsErrorStreak}`);
      const cur: StopRuntime | undefined = st.activeIdx >= 0 ? st.stops[st.activeIdx] :
        (st.targetIdx >= 0 ? st.stops[st.targetIdx] : undefined);
      emitMeta(st, fx, cur === undefined ? tourTitle(st) : cur.name);
    }
  } else {
    st.ttsErrorStreak = 0;
  }
  if (r.finished && r.item !== undefined) {
    onItemFinished(st, fx, r.item, false);
  }
  pump(st, fx);
}

function onTick(st: TourState, fx: Fx): void {
  if (st.speechText && Number.isFinite(st.textDueMs) && st.nowMs >= st.textDueMs) {
    const u: Utterance | undefined = st.queue.inFlight();
    if (u !== undefined) {
      onUtteranceEnd(st, fx, u.id, false, 0);
      return;
    }
  }
  expireQueue(st, fx);
  pump(st, fx);
}

// ---------------------------------------------------------------- user and platform

function pauseTour(st: TourState, fx: Fx): void {
  if (st.paused) {
    return;
  }
  st.paused = true;
  st.queue.interrupt();                  // the cut sentence restarts from its beginning on resume
  st.textDueMs = Number.NaN;
  fx.stopSpeech(false);
  fx.mediaState(MediaPlayState.PAUSE);
}

function resumeTour(st: TourState, fx: Fx): void {
  if (!st.paused) {
    return;
  }
  st.paused = false;
  st.pausedByAudio = false;
  removeIssue(st, IssueCode.AUDIO_INTERRUPT);   // §9 rows 12/13: the banner goes with the pause
  removeIssue(st, IssueCode.AUDIO_ROUTE_LOST);
  fx.mediaState(MediaPlayState.PLAY);
  pump(st, fx);
}

function onSkip(st: TourState, fx: Fx): void {
  let item: Announcement | undefined = st.queue.skipCurrent();
  if (item === undefined) {
    const head: Announcement | undefined = st.queue.headItem();    // paused: skip the item waiting to resume
    item = head === undefined ? undefined : st.queue.removeWaiting(head.dedupeKey);
  } else if (st.speechText) {
    st.queue.interrupt();                // no audio to finish: the caption moves on at once
    st.textDueMs = Number.NaN;
  } else {
    fx.stopSpeech(true);
  }
  if (item !== undefined) {
    onItemFinished(st, fx, item, true);
  }
  pump(st, fx);
}

function storyStopIdx(st: TourState): number {
  return st.activeIdx >= 0 ? st.activeIdx : st.lastStopIdx;
}

function onMore(st: TourState, fx: Fx): void {
  if (st.activeIdx >= 0 && st.stage === StopStage.TEASER) {
    st.userAskedMore = true;             // full story after the teaser, whatever the speed
    return;
  }
  const idx: number = storyStopIdx(st);
  if (idx < 0) {
    return;
  }
  const s: StopRuntime = st.stops[idx];
  if (s.status === StopStatus.TEASER_ONLY) {
    const full: Narration | undefined = narrationOf(st, s.poiId, NarrationLength.FULL);
    if (full !== undefined &&
      enqueue(st, fx, Priority.P2_STORY, AnnouncementKind.FULL_STORY, s.poiId, full.sentences, `full:${s.poiId}`,
        full.tier).length > 0) {
      s.status = StopStatus.VISITED;
      pump(st, fx);
      return;
    }
  }
  const deep: Narration | undefined = narrationOf(st, s.poiId, NarrationLength.DEEP);
  if (deep !== undefined) {
    enqueue(st, fx, Priority.P2_STORY, AnnouncementKind.DEEP_STORY, s.poiId, deep.sentences, `deep:${s.poiId}`,
      deep.tier);
  }
  pump(st, fx);
}

function onReplay(st: TourState, fx: Fx): void {
  const idx: number = storyStopIdx(st);
  if (idx < 0) {
    return;
  }
  const s: StopRuntime = st.stops[idx];
  let n: Narration | undefined = narrationOf(st, s.poiId, NarrationLength.FULL);
  if (n === undefined) {
    n = narrationOf(st, s.poiId, NarrationLength.TEASER);
  }
  if (n !== undefined) {
    st.itemSeq++;
    enqueue(st, fx, Priority.P2_STORY, AnnouncementKind.FULL_STORY, s.poiId, n.sentences,
      `replay:${s.poiId}:${st.itemSeq}`, n.tier);
  }
  pump(st, fx);
}

function onEnd(st: TourState, fx: Fx): void {
  if (!isTouring(st.phase) && st.phase !== TourPhase.READY) {
    return;
  }
  st.queue.clear();
  st.itemTier.clear();
  st.paused = false;
  st.textDueMs = Number.NaN;
  st.activeIdx = -1;
  st.storyItemId = '';
  fx.stopSpeech(false);
  fx.mediaState(MediaPlayState.STOP);
  setPhase(st, fx, TourPhase.ABORTED, EngineEventType.USER_END, '');
  fx.persist();
}

/**
 * §9 row 12. PAUSE/STOP pause the tour (the cut sentence replays from its start on resume). RESUME resumes only a
 * pause the interrupt caused: a tour the user paused stays paused. Outside a running tour it is only logged.
 */
function onAudioInterrupt(st: TourState, fx: Fx, hint: string): void {
  const h: string = hint.toUpperCase();
  if (!isTouring(st.phase)) {
    fx.log(EngineLog.AUDIO_INTERRUPT, `hint=${h} action=ignored phase=${st.phase}`);
    return;
  }
  if (h === 'PAUSE' || h === 'STOP') {
    const wasPaused: boolean = st.paused;
    fx.log(EngineLog.AUDIO_INTERRUPT, `hint=${h} action=${wasPaused ? 'already_paused' : 'pause'}`);
    addIssue(st, IssueCode.AUDIO_INTERRUPT, IssueSeverity.INFO, `hint=${h}`);
    if (!wasPaused) {
      pauseTour(st, fx);
      st.pausedByAudio = true;
    }
  } else if (h === 'RESUME') {
    const mine: boolean = st.paused && st.pausedByAudio;
    fx.log(EngineLog.AUDIO_INTERRUPT, `hint=${h} action=${mine ? 'resume' : 'stay_paused'}`);
    if (mine) {
      resumeTour(st, fx);
    } else {
      removeIssue(st, IssueCode.AUDIO_INTERRUPT);
    }
  } else {
    fx.log(EngineLog.AUDIO_INTERRUPT, `hint=${h} action=none`);
  }
}

/** §9 row 13: headphones gone -> pause, never continue on the loudspeaker. Resume is the user's call. */
function onAudioRouteLost(st: TourState, fx: Fx): void {
  if (!isTouring(st.phase)) {
    fx.log(EngineLog.AUDIO_ROUTE, `device=SPEAKER action=ignored phase=${st.phase}`);
    return;
  }
  fx.log(EngineLog.AUDIO_ROUTE, 'device=SPEAKER action=pause');
  addIssue(st, IssueCode.AUDIO_ROUTE_LOST, IssueSeverity.WARN, 'headphones disconnected');
  pauseTour(st, fx);
  st.pausedByAudio = false;          // an interrupt RESUME must not undo this pause
}

// ---------------------------------------------------------------- public API

export class TourEngine {
  /** A fresh IDLE state for one tour. */
  static init(input: TourInput, cfg?: TourConfig): TourState {
    return new TourState(input, cfg !== undefined ? cfg : new TourConfig());
  }

  /** The reducer. Updates `state` in place (see the header) and returns it with the effects to execute. */
  static reduce(state: TourState, ev: EngineEvent): StepResult {
    const st: TourState = state;
    const fx: Fx = new Fx();
    if (Number.isFinite(ev.nowMs) && ev.nowMs > st.nowMs) {
      st.nowMs = ev.nowMs;
    }
    switch (ev.type) {
      case EngineEventType.START_PLANNING:
        if (st.phase === TourPhase.IDLE || st.phase === TourPhase.READY) {
          setPhase(st, fx, TourPhase.PLANNING, ev.type, '');
        }
        break;
      case EngineEventType.PLAN_READY:
        if (ev.plan !== undefined) {
          onPlanReady(st, fx, ev.plan);
        }
        break;
      case EngineEventType.PLAN_FAILED:
        if (st.phase === TourPhase.PLANNING) {
          fx.log(EngineLog.ROUTE_PLAN, `failed code=${ev.code === undefined ? '' : ev.code} ` +
            `reason=${ev.reason === undefined ? '' : ev.reason}`);
          setPhase(st, fx, TourPhase.IDLE, ev.type, '');
        }
        break;
      case EngineEventType.START_TOUR:
        onStartTour(st, fx);
        pump(st, fx);
        break;
      case EngineEventType.FIX:
        if (ev.fix !== undefined) {
          onFix(st, fx, ev.fix);
        }
        break;
      case EngineEventType.FIX_TIMEOUT:
        onFixTimeout(st, fx);
        break;
      case EngineEventType.UTTERANCE_STARTED:
        break;                           // NowPlaying already shows the in-flight sentence
      case EngineEventType.UTTERANCE_DONE:
        onUtteranceEnd(st, fx, ev.utteranceId === undefined ? '' : ev.utteranceId, false, 0);
        break;
      case EngineEventType.UTTERANCE_FAILED:
        onUtteranceEnd(st, fx, ev.utteranceId === undefined ? '' : ev.utteranceId, true,
          ev.code === undefined ? -1 : ev.code);
        break;
      case EngineEventType.USER_PAUSE:
        pauseTour(st, fx);
        st.pausedByAudio = false;        // the user owns this pause now: an interrupt RESUME leaves it alone
        break;
      case EngineEventType.USER_RESUME:
        resumeTour(st, fx);
        break;
      case EngineEventType.USER_SKIP:
        onSkip(st, fx);
        break;
      case EngineEventType.USER_REPLAY:
        onReplay(st, fx);
        break;
      case EngineEventType.USER_MORE:
        onMore(st, fx);
        break;
      case EngineEventType.USER_END:
        onEnd(st, fx);
        break;
      case EngineEventType.AUDIO_INTERRUPT:
        onAudioInterrupt(st, fx, ev.hint === undefined ? '' : ev.hint);
        break;
      case EngineEventType.AUDIO_ROUTE_LOST:
        onAudioRouteLost(st, fx);
        break;
      case EngineEventType.BG_CANCELLED:
        fx.log(EngineLog.BG_CANCEL, `reason=${ev.reason === undefined ? '' : ev.reason}`);
        addIssue(st, IssueCode.BG_FAIL, IssueSeverity.WARN, ev.reason === undefined ? '' : ev.reason);
        break;
      case EngineEventType.TICK:
        onTick(st, fx);
        break;
      default:
        break;
    }
    const out: StepResult = { state: st, effects: fx.list };
    return out;
  }

  /** The EngineSnapshot the UI renders. PlatformStatus is left at defaults; the controller fills it in. */
  static snapshot(st: TourState): EngineSnapshot {
    const stops: StopProgress[] = [];
    for (const s of st.stops) {
      const p: StopProgress = { poiId: s.poiId, order: s.order, status: s.status };
      stops.push(p);
    }
    let next: NextInfo | undefined = undefined;
    if (st.targetIdx >= 0) {
      const t: StopRuntime = st.stops[st.targetIdx];
      const d: number = distanceTo(st, t);
      const f: Fix | undefined = st.lastFix;
      next = {
        poiId: t.poiId, distanceM: d, etaS: Number.isFinite(d) ? d / st.cfg.walkSpeedMps : Number.NaN,
        relDir: relDirTo(st, t, d),
        bearingDeg: f === undefined ? Number.NaN : bearingDeg(f.lat, f.lng, t.lat, t.lng),
        maneuverText: '', maneuverDistM: Number.NaN
      };
    }
    let nowPlaying: NowPlaying | undefined = undefined;
    const item: Announcement | undefined = st.queue.isBusy() ? st.queue.currentItem() :
      (st.paused ? st.queue.headItem() : undefined);
    if (item !== undefined && item.cursor < item.utterances.length) {
      const tier: ContentTier | undefined = st.itemTier.get(item.id);
      nowPlaying = {
        itemId: item.id, poiId: item.poiId === undefined ? '' : item.poiId, kind: item.kind,
        sentenceIndex: item.cursor, sentenceCount: item.utterances.length, caption: item.utterances[item.cursor].text,
        tier: tier === undefined ? ContentTier.NAME_ONLY : tier, lang: st.input.lang
      };
    }
    let user: UserPos | undefined = undefined;
    if (st.lastFix !== undefined) {
      const f: Fix = st.lastFix;
      user = {
        x: st.projection.x(f.lng), y: st.projection.y(f.lat), lat: f.lat, lng: f.lng, accuracyM: f.accuracyM,
        courseDeg: st.course.courseDeg, speedMps: f.speedMps, source: f.source
      };
    }
    let remainingM: number = 0;
    if (st.targetIdx >= 0) {
      const first: number = distanceTo(st, st.stops[st.targetIdx]);
      remainingM = Number.isFinite(first) ? first : 0;
      let prev: StopRuntime = st.stops[st.targetIdx];
      for (let i = st.targetIdx + 1; i < st.stops.length; i++) {
        const s: StopRuntime = st.stops[i];
        if (isOpen(s.status)) {
          remainingM += haversineM(prev.lat, prev.lng, s.lat, s.lng);
          prev = s;
        }
      }
    }
    const platform: PlatformStatus = {
      bgRunning: false, avsActive: false, ttsEngine: 'none', sourceKind: st.source,
      realGpsAccuracyM: st.lastFix !== undefined && st.lastFix.source === FixSource.REAL ? st.lastFix.accuracyM :
        Number.NaN,
      demoHold: false
    };
    const snap: EngineSnapshot = {
      phase: st.phase, tourId: st.input.tour.id, stops: stops,
      currentStopIdx: st.activeIdx >= 0 ? st.activeIdx : st.targetIdx,
      next: next, nowPlaying: nowPlaying, user: user, signal: st.signal, offRoute: false, paused: st.paused,
      speechText: st.speechText, plannedOrder: st.stops.map((s: StopRuntime) => s.poiId),
      walkedM: st.walkedM, remainingM: remainingM, issues: st.issues.slice(), voiceLabel: st.voiceLabel,
      source: st.source, platform: platform
    };
    return snap;
  }
}

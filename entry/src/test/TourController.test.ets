// Suite: TourController.test - module under test: services/tour/TourController (task A7).
// The controller has no @kit import, so it runs here against fake ports: a manual clock + scheduler, a speech fake
// that finishes each sentence after 2 s (or synchronously), a demo and a real location source, background and
// AVSession fakes, and a recording logger.
// Cases: pure helpers (bbox distance, demo speed, utterance id prediction); a full MiniPack demo walk with voice
// (log order PACK_LOAD -> ROUTE_PLAN algo=heldkarp -> LOC_SOURCE kind=demo -> POI_ENTER -> STORY_START ->
// STATE to=finished, teardown of source/background/AVSession, prefetch ids that match what is spoken next);
// out of area (§9 row 8); missing services are one-line no-ops and FIX_TIMEOUT/LOC_NOFIX fire; text-only pacing
// by TICK (no SPEAK); lock-screen pause/play; synchronous speech callbacks (no re-entrant reduce); snapshot
// throttle; end() mid-tour.
import { describe, it, expect } from '@ohos/hypium';
import {
  DemoControls, TourController, TourControllerDeps, kmOutsideBbox, normalizeDemoSpeed,
  predictNextUtteranceId
} from '../main/ets/services/tour/TourController';
import { Scheduler } from '../main/ets/app/Clock';
import {
  AppIssue, EngineSnapshot, IssueCode, MediaMeta, MediaPlayState, TourPhase, TourPlan
} from '../main/ets/contracts/EngineTypes';
import {
  BackgroundListener, BackgroundPort, Clock, Fix, FixListener, FixSource, HapticsPort, LocationErrorListener,
  LocationSource, LoggerPort, MediaCommand, MediaCommandListener, MediaSessionPort, NotifierPort, PackLoadResult,
  PackRepository, PermissionPort, PermissionState, SpeechCapabilities, SpeechListener, SpeechPort, Utterance,
  VoicePlan, VoicePort, VoiceState
} from '../main/ets/contracts/Ports';
import {
  Lang, MapData, Narration, NarrationLength, PackManifest, Persona, Poi, RouteData, SourceRef, Tour
} from '../main/ets/contracts/Model';
import { EnVoiceStrategy, VoiceLabel } from '../main/ets/contracts/Settings';
import {
  MINI_BARBICAN, MINI_CLOTH_HALL, MINI_ST_MARYS, MINI_TOUR_ID, miniNarrations, miniPersona, miniPois, miniRoutes,
  miniTour
} from './fixtures/MiniPack';

const T0: number = 1000000;
const M_PER_DEG_LAT: number = 111195;
const KRAKOW_BBOX: number[] = [50.0525, 19.929, 50.0675, 19.947];
const BEIJING_LAT: number = 40.0;
const BEIJING_LNG: number = 116.0;

// ---------------------------------------------------------------- fakes

class FakeClock implements Clock {
  t: number = T0;

  nowMs(): number {
    return this.t;
  }
}

class Timer {
  id: number;
  at: number;
  period: number;
  fn: () => void;

  constructor(id: number, at: number, period: number, fn: () => void) {
    this.id = id;
    this.at = at;
    this.period = period;
    this.fn = fn;
  }
}

class FakeScheduler implements Scheduler {
  private clock: FakeClock;
  private timers: Timer[] = [];
  private seq: number = 0;

  constructor(clock: FakeClock) {
    this.clock = clock;
  }

  after(ms: number, fn: () => void): number {
    this.seq++;
    this.timers.push(new Timer(this.seq, this.clock.t + Math.max(0, ms), 0, fn));
    return this.seq;
  }

  every(ms: number, fn: () => void): number {
    this.seq++;
    this.timers.push(new Timer(this.seq, this.clock.t + ms, ms, fn));
    return this.seq;
  }

  cancel(id: number): void {
    this.timers = this.timers.filter((t: Timer) => t.id !== id);
  }

  count(): number {
    return this.timers.length;
  }

  /** Fires every timer due within `ms`, in time order, moving the clock along. */
  advance(ms: number): void {
    const end: number = this.clock.t + ms;
    for (let guard = 0; guard < 100000; guard++) {
      let next: Timer | undefined = undefined;
      for (const t of this.timers) {
        if (t.at <= end && (next === undefined || t.at < next.at || (t.at === next.at && t.id < next.id))) {
          next = t;
        }
      }
      if (next === undefined) {
        break;
      }
      const due: Timer = next;
      this.clock.t = Math.max(this.clock.t, due.at);
      if (due.period > 0) {
        due.at += due.period;
      } else {
        this.timers = this.timers.filter((t: Timer) => t.id !== due.id);
      }
      due.fn();
    }
    this.clock.t = end;
  }
}

class FakeLog implements LoggerPort {
  lines: string[] = [];

  info(event: string, kv: string): void {
    this.lines.push(`${event} ${kv}`);
  }

  warn(event: string, kv: string): void {
    this.lines.push(`${event} ${kv}`);
  }

  error(event: string, kv: string): void {
    this.lines.push(`${event} ${kv}`);
  }

  count(prefix: string): number {
    return this.lines.filter((l: string) => l.indexOf(prefix) === 0).length;
  }

  /** Index of the first line at or after `from` that starts with `prefix` and contains `part`; -1 if none. */
  find(prefix: string, part: string, from: number): number {
    for (let i = Math.max(0, from); i < this.lines.length; i++) {
      if (this.lines[i].indexOf(prefix) === 0 && this.lines[i].indexOf(part) >= 0) {
        return i;
      }
    }
    return -1;
  }
}

class FakeSpeech implements SpeechPort {
  listener: SpeechListener | undefined = undefined;
  spoken: string[] = [];
  spokenIds: string[] = [];
  prefetched: string[] = [];
  stops: number = 0;
  inFlight: Utterance | undefined = undefined;
  sync: boolean = false;
  sentenceMs: number = 2000;
  private sched: FakeScheduler;

  constructor(sched: FakeScheduler) {
    this.sched = sched;
  }

  init(): Promise<SpeechCapabilities> {
    const c: SpeechCapabilities = { en: VoiceState.DOWNLOADABLE, zh: VoiceState.INSTALLED };
    return Promise.resolve(c);
  }

  setListener(l: SpeechListener): void {
    this.listener = l;
  }

  speak(u: Utterance): void {
    this.spoken.push(u.text);
    this.spokenIds.push(u.id);
    this.inFlight = u;
    const l: SpeechListener | undefined = this.listener;
    if (l === undefined) {
      return;
    }
    l.onUtteranceStart(u.id);
    if (this.sync) {
      this.inFlight = undefined;
      l.onUtteranceDone(u.id);
      return;
    }
    const id: string = u.id;
    this.sched.after(this.sentenceMs, () => {
      if (this.inFlight !== undefined && this.inFlight.id === id) {
        this.inFlight = undefined;
        l.onUtteranceDone(id);
      }
    });
  }

  prefetch(u: Utterance): void {
    this.prefetched.push(u.id);
  }

  stopNow(): void {
    this.stops++;
    this.inFlight = undefined;
  }

  pause(): void {
  }

  resume(): void {
  }

  isSpeaking(): boolean {
    return this.inFlight !== undefined;
  }
}

class FakeVoice implements VoicePort {
  text: boolean;

  constructor(text: boolean) {
    this.text = text;
  }

  capabilities(): Promise<SpeechCapabilities> {
    const c: SpeechCapabilities = { en: VoiceState.DOWNLOADABLE, zh: VoiceState.INSTALLED };
    return Promise.resolve(c);
  }

  plan(textLang: Lang): VoicePlan {
    const v: VoicePlan = {
      textLang: textLang, speechMode: this.text ? 'text' : 'voice', engineLocale: this.text ? '' : 'zh-CN',
      person: this.text ? 0 : 13, languageContext: this.text ? '' : 'en-US',
      label: this.text ? VoiceLabel.TEXT_ONLY_USER : VoiceLabel.FALLBACK_ZH_READS_EN, reason: 'test'
    };
    return v;
  }

  downloadEnglish(onProgress: (pct: number) => void): Promise<boolean> {
    return Promise.resolve(false);
  }

  setStrategy(s: EnVoiceStrategy): void {
  }
}

class FakePack implements PackRepository {
  loads: number = 0;

  load(): Promise<PackLoadResult> {
    this.loads++;
    const m: PackManifest = {
      schemaVersion: 1, packId: 'mini', version: '0', builtAt: '2026-10-03T00:00:00Z',
      origin: { lat: 50.0617, lng: 19.9373 }, bbox: KRAKOW_BBOX, files: [],
      counts: { pois: 4, narrations_en: 2, narrations_pl: 0, narrations_zh: 0, legs: 0 }, licenses: []
    };
    const r: PackLoadResult = { ok: true, manifest: m, issues: [] };
    return Promise.resolve(r);
  }

  pois(): Poi[] {
    return miniPois();
  }

  poi(id: string): Poi | undefined {
    return miniPois().find((p: Poi) => p.id === id);
  }

  tours(): Tour[] {
    return [miniTour()];
  }

  personas(): Persona[] {
    return [miniPersona()];
  }

  routes(): RouteData {
    return miniRoutes();
  }

  map(level: string): MapData {
    const d: MapData = { level: level, origin: { lat: 50.0617, lng: 19.9373 }, bounds: [], layers: [] };
    return d;
  }

  narration(poiId: string, personaId: string, lang: Lang, len: NarrationLength): Narration | undefined {
    return miniNarrations().find((n: Narration) => n.poiId === poiId && n.length === len && n.lang === lang);
  }

  source(id: string): SourceRef | undefined {
    return undefined;
  }
}

class FakeSource implements LocationSource {
  readonly kind: FixSource;
  running: boolean = false;
  starts: number = 0;
  stops: number = 0;
  emitOnStart: Fix | undefined = undefined;
  private onFix: FixListener | undefined = undefined;

  constructor(kind: FixSource) {
    this.kind = kind;
  }

  start(onFix: FixListener, onError: LocationErrorListener): Promise<void> {
    this.running = true;
    this.starts++;
    this.onFix = onFix;
    if (this.emitOnStart !== undefined) {
      onFix(this.emitOnStart);
    }
    return Promise.resolve();
  }

  stop(): void {
    this.running = false;
    this.stops++;
  }

  isRunning(): boolean {
    return this.running;
  }

  emit(f: Fix): void {
    if (this.running && this.onFix !== undefined) {
      this.onFix(f);
    }
  }
}

class FakeDemo implements DemoControls {
  speed: number = 0;
  jumps: number = 0;
  hold: () => boolean = () => false;

  setSpeed(mult: number): void {
    this.speed = mult;
  }

  jumpToNextStop(): void {
    this.jumps++;
  }

  setHoldPredicate(p: () => boolean): void {
    this.hold = p;
  }
}

class FakeBackground implements BackgroundPort {
  running: boolean = false;
  starts: number = 0;
  stops: number = 0;

  start(): Promise<boolean> {
    this.running = true;
    this.starts++;
    return Promise.resolve(true);
  }

  stop(): Promise<void> {
    this.running = false;
    this.stops++;
    return Promise.resolve();
  }

  isRunning(): boolean {
    return this.running;
  }

  setListener(l: BackgroundListener): void {
  }
}

class FakeMedia implements MediaSessionPort {
  active: boolean = false;
  destroyed: number = 0;
  metas: MediaMeta[] = [];
  states: MediaPlayState[] = [];
  onCommand: MediaCommandListener | undefined = undefined;

  init(onCommand: MediaCommandListener): Promise<boolean> {
    this.onCommand = onCommand;
    this.active = true;
    return Promise.resolve(true);
  }

  setMeta(meta: MediaMeta): void {
    this.metas.push(meta);
  }

  setState(state: MediaPlayState): void {
    this.states.push(state);
  }

  isActive(): boolean {
    return this.active;
  }

  destroy(): Promise<void> {
    this.active = false;
    this.destroyed++;
    return Promise.resolve();
  }
}

class FakePerms implements PermissionPort {
  state: PermissionState;

  constructor(state: PermissionState) {
    this.state = state;
  }

  locationState(): Promise<PermissionState> {
    return Promise.resolve(this.state);
  }

  requestLocation(): Promise<PermissionState> {
    return Promise.resolve(this.state);
  }

  openLocationSettings(): Promise<PermissionState> {
    return Promise.resolve(this.state);
  }

  isLocationSwitchOn(): boolean {
    return true;
  }

  requestLocationSwitch(): Promise<boolean> {
    return Promise.resolve(true);
  }
}

// ---------------------------------------------------------------- harness

class Harness {
  clock: FakeClock = new FakeClock();
  sched: FakeScheduler;
  log: FakeLog = new FakeLog();
  speech: FakeSpeech;
  pack: FakePack = new FakePack();
  demo: FakeSource = new FakeSource(FixSource.DEMO);
  real: FakeSource = new FakeSource(FixSource.REAL);
  demoCtl: FakeDemo = new FakeDemo();
  bg: FakeBackground = new FakeBackground();
  media: FakeMedia = new FakeMedia();
  perms: FakePerms = new FakePerms(PermissionState.UNKNOWN);
  withSources: boolean = true;
  withPlatform: boolean = true;
  ctrl: TourController;
  lat: number = 0;
  lng: number = 0;
  acc: number = 5;

  constructor(text: boolean, withSources: boolean, withPlatform: boolean) {
    this.sched = new FakeScheduler(this.clock);
    this.speech = new FakeSpeech(this.sched);
    this.withSources = withSources;
    this.withPlatform = withPlatform;
    const deps: TourControllerDeps = {
      pack: this.pack, speech: this.speech, voice: new FakeVoice(text), log: this.log, clock: this.clock,
      scheduler: this.sched,
      sourceFor: (kind: FixSource): LocationSource | undefined => !this.withSources ? undefined :
        (kind === FixSource.DEMO ? this.demo : this.real),
      demoControls: (): DemoControls | undefined => this.withSources ? this.demoCtl : undefined,
      background: (): BackgroundPort | undefined => this.withPlatform ? this.bg : undefined,
      media: (): MediaSessionPort | undefined => this.withPlatform ? this.media : undefined,
      notifier: (): NotifierPort | undefined => undefined,
      haptics: (): HapticsPort | undefined => undefined,
      permissions: (): PermissionPort | undefined => this.perms
    };
    this.ctrl = new TourController(deps);
  }

  fixAt(lat: number, lng: number, speed: number, course: number, src: FixSource): Fix {
    const f: Fix = {
      lat: lat, lng: lng, accuracyM: this.acc, speedMps: speed, courseDeg: course, courseAccuracyDeg: Number.NaN,
      timestampMs: this.clock.t, provider: 0, source: src
    };
    return f;
  }

  /** One second: timers fire (TICK, speech), then the demo source emits a fix at the walker's position. */
  second(speed: number, course: number): void {
    this.sched.advance(1000);
    this.demo.emit(this.fixAt(this.lat, this.lng, speed, course, FixSource.DEMO));
  }

  placeNear(poiId: string, metres: number, fromBearingDeg: number): void {
    const p: Poi = this.pack.poi(poiId) as Poi;
    const b: number = fromBearingDeg * Math.PI / 180;
    this.lat = p.lat + metres * Math.cos(b) / M_PER_DEG_LAT;
    this.lng = p.lng + metres * Math.sin(b) / (M_PER_DEG_LAT * Math.cos(p.lat * Math.PI / 180));
  }

  walkTo(poiId: string, speed: number): void {
    const p: Poi = this.pack.poi(poiId) as Poi;
    const k: number = M_PER_DEG_LAT * Math.cos(p.lat * Math.PI / 180);
    const dx: number = (p.lng - this.lng) * k;
    const dy: number = (p.lat - this.lat) * M_PER_DEG_LAT;
    const dist: number = Math.hypot(dx, dy);
    const course: number = ((Math.atan2(dx, dy) * 180 / Math.PI) + 360) % 360;
    const steps: number = Math.floor(dist / speed);
    const lat0: number = this.lat;
    const lng0: number = this.lng;
    for (let i = 1; i <= steps; i++) {
      const f: number = i * speed / dist;
      this.lat = lat0 + dy * f / M_PER_DEG_LAT;
      this.lng = lng0 + dx * f / k;
      this.second(speed, course);
    }
    this.lat = p.lat;
    this.lng = p.lng;
  }

  /** Stands still until the controller left the stop and nothing is queued (max `max` s). */
  dwellUntilQuiet(max: number): void {
    for (let i = 0; i < max; i++) {
      const s: EngineSnapshot = this.ctrl.current();
      if (s.phase !== TourPhase.AT_STOP && s.nowPlaying === undefined && i > 2) {
        return;
      }
      this.second(0, Number.NaN);
    }
  }

  hasIssue(code: IssueCode): boolean {
    return this.ctrl.current().issues.some((i: AppIssue) => i.code === code);
  }
}

/** Asserts the log events appear in this order (each `[prefix, part]` after the previous match). */
function inOrder(log: FakeLog, steps: string[][]): number {
  let at: number = -1;
  for (const s of steps) {
    const i: number = log.find(s[0], s[1], at + 1);
    if (i < 0) {
      return -1;
    }
    at = i;
  }
  return at;
}

export default function tourControllerTest() {
  describe('TourController', () => {
    it('kmOutsideBbox is 0 inside, ~6900 km for Beijing, NaN for a bad bbox', 0, () => {
      expect(kmOutsideBbox(50.0617, 19.9373, KRAKOW_BBOX)).assertEqual(0);
      const km: number = kmOutsideBbox(BEIJING_LAT, BEIJING_LNG, KRAKOW_BBOX);
      expect(km > 6500 && km < 7500).assertTrue();
      const near: number = kmOutsideBbox(50.0675 + 0.009, 19.94, KRAKOW_BBOX);   // ~1 km north of the bbox
      expect(near > 0.9 && near < 1.1).assertTrue();
      expect(Number.isNaN(kmOutsideBbox(50, 19, [1, 2]))).assertTrue();
    });

    it('normalizeDemoSpeed snaps to 1/2/4/8 and predictNextUtteranceId follows the queue id scheme', 0, () => {
      expect(normalizeDemoSpeed(8)).assertEqual(8);
      expect(normalizeDemoSpeed(5)).assertEqual(4);
      expect(normalizeDemoSpeed(100)).assertEqual(8);
      expect(normalizeDemoSpeed(Number.NaN)).assertEqual(4);
      expect(predictNextUtteranceId('it3.0#7', 'it3.1')).assertEqual('it3.1#8');
      expect(predictNextUtteranceId('noseq', 'it3.1')).assertEqual('');
    });

    it('demo walk with voice: plan, start, 3 stops, finish and teardown, logs in order', 0, async (done: Function) => {
      const h: Harness = new Harness(false, true, true);
      await h.ctrl.setSource(FixSource.DEMO);
      const p: TourPlan = await h.ctrl.plan(MINI_TOUR_ID, 0);
      expect(p.algo).assertEqual('heldkarp');
      expect(p.order.length).assertEqual(3);
      expect(p.order[0]).assertEqual(MINI_BARBICAN);
      expect(h.ctrl.current().phase).assertEqual(TourPhase.READY);
      h.placeNear(MINI_BARBICAN, 120, 0);
      await h.ctrl.start();
      expect(h.ctrl.isRunning()).assertTrue();
      expect(h.bg.starts).assertEqual(1);
      expect(h.media.active).assertTrue();
      expect(h.demo.starts).assertEqual(1);
      expect(h.demoCtl.speed).assertEqual(4);
      expect(h.speech.spoken.length > 0).assertTrue();          // the welcome line starts at once
      for (const id of p.order) {
        h.walkTo(id, 1.3);
        h.dwellUntilQuiet(120);
      }
      for (let i = 0; i < 30 && h.ctrl.isRunning(); i++) {
        h.second(0, Number.NaN);
      }
      const s: EngineSnapshot = h.ctrl.current();
      expect(s.phase).assertEqual(TourPhase.FINISHED);
      expect(h.ctrl.isRunning()).assertFalse();
      expect(inOrder(h.log, [
        ['PACK_LOAD', 'pois=4'], ['ROUTE_PLAN', 'algo=heldkarp'], ['LOC_SOURCE', 'kind=demo'],
        ['STATE', 'to=walking'], ['POI_ENTER', `id=${MINI_BARBICAN}`], ['STORY_START', `poi=${MINI_BARBICAN}`],
        ['POI_ENTER', `id=${MINI_ST_MARYS}`], ['STORY_START', `poi=${MINI_ST_MARYS}`],
        ['POI_ENTER', `id=${MINI_CLOTH_HALL}`],
        ['STATE', 'to=finished'], ['STATE', 'ev=TEARDOWN why=finished']
      ]) >= 0).assertTrue();
      const enterSm: number = h.log.find('POI_ENTER', `id=${MINI_ST_MARYS}`, 0);
      const narrSm: number = h.log.find('NARR_SOURCE', `poi=${MINI_ST_MARYS} len=teaser`, 0);
      expect(narrSm > enterSm && enterSm >= 0).assertTrue();          // logged after the arrival, not inside reduce
      expect(h.log.lines[narrSm].indexOf('tier=reviewed') >= 0 || h.log.lines[narrSm].indexOf('sources=1') >= 0)
        .assertTrue();
      expect(h.speech.spoken.indexOf('Fixture teaser sentence one.') >= 0).assertTrue();
      expect(h.speech.spoken.indexOf('Fixture full sentence three.') >= 0).assertTrue();
      // Prefetch guesses: at least one prefetched id was spoken next, and none of them was wrong in this walk.
      const hits: number = h.speech.prefetched.filter((id: string) => h.speech.spokenIds.indexOf(id) >= 0).length;
      expect(hits > 0).assertTrue();
      expect(hits).assertEqual(h.speech.prefetched.length);
      // Platform: AVSession got titles and play..stop, then everything was released.
      expect(h.media.metas.length > 0).assertTrue();
      expect(h.media.states[0]).assertEqual(MediaPlayState.PLAY);
      expect(h.media.states[h.media.states.length - 1]).assertEqual(MediaPlayState.STOP);
      expect(h.media.destroyed).assertEqual(1);
      expect(h.bg.stops).assertEqual(1);
      expect(h.demo.running).assertFalse();
      expect(h.log.count('UNCAUGHT')).assertEqual(0);
      expect(h.log.count('NOTIF_PUBLISH')).assertEqual(1);            // A8 not wired: one no-op line per tour
      expect(h.log.count('HAPTIC kind=arrive')).assertEqual(1);
      expect(h.sched.count()).assertEqual(0);                          // no timer left behind
      done();
    });

    it('out of area: a Beijing fix at plan time logs LOC_OUT_OF_AREA and plans from the tour start', 0,
      async (done: Function) => {
        const h: Harness = new Harness(false, true, true);
        h.perms.state = PermissionState.GRANTED;
        h.real.emitOnStart = h.fixAt(BEIJING_LAT, BEIJING_LNG, 0, Number.NaN, FixSource.REAL);
        const p: TourPlan = await h.ctrl.plan(MINI_TOUR_ID, 0);
        expect(h.real.starts).assertEqual(1);
        expect(h.log.find('LOC_SOURCE', 'kind=real role=origin', 0) >= 0).assertTrue();
        const i: number = h.log.find('LOC_OUT_OF_AREA', 'km=', 0);
        expect(i >= 0).assertTrue();
        expect(h.log.lines[i].indexOf('src=real') >= 0).assertTrue();
        expect(h.hasIssue(IssueCode.LOC_OUT_OF_AREA)).assertTrue();
        expect(p.order[0]).assertEqual(MINI_BARBICAN);
        expect(h.ctrl.current().platform.realGpsAccuracyM).assertEqual(5);
        h.ctrl.shutdown();
        expect(h.real.running).assertFalse();
        done();
      });

    it('permission not granted: plan never starts the real source', 0, async (done: Function) => {
      const h: Harness = new Harness(false, true, true);
      await h.ctrl.plan(MINI_TOUR_ID, 0);
      expect(h.real.starts).assertEqual(0);
      expect(h.log.count('LOC_OUT_OF_AREA')).assertEqual(0);
      done();
    });

    it('missing services: one no-op line each, LOC_SOURCE available=false, FIX_TIMEOUT and LOC_NOFIX', 0,
      async (done: Function) => {
        const h: Harness = new Harness(false, false, false);
        await h.ctrl.setSource(FixSource.DEMO);
        await h.ctrl.plan(MINI_TOUR_ID, 0);
        await h.ctrl.start();
        expect(h.ctrl.isRunning()).assertTrue();
        expect(h.log.find('LOC_SOURCE', 'kind=demo available=false', 0) >= 0).assertTrue();
        expect(h.log.find('BG_START', 'noop=no_service', 0) >= 0).assertTrue();
        expect(h.hasIssue(IssueCode.LOC_UNAVAILABLE)).assertTrue();
        h.sched.advance(26000);
        expect(h.log.count('LOC_LOST')).assertEqual(1);
        h.sched.advance(5000);
        expect(h.log.count('LOC_NOFIX')).assertEqual(1);
        h.sched.advance(30000);
        expect(h.log.count('LOC_LOST')).assertEqual(1);
        expect(h.log.count('BG_START')).assertEqual(1);
        expect(h.log.count('AVS_META noop')).assertEqual(1);
        h.ctrl.setDemoSpeed(8);
        h.ctrl.setDemoSpeed(2);
        expect(h.log.count('LOC_SOURCE kind=demo action=speed')).assertEqual(1);
        expect(h.log.count('UNCAUGHT')).assertEqual(0);
        h.ctrl.end();
        expect(h.ctrl.isRunning()).assertFalse();
        expect(h.sched.count()).assertEqual(0);
        done();
      });

    it('text only: no SPEAK, captions advance on TICK, the tour still reaches the first stop', 0,
      async (done: Function) => {
        const h: Harness = new Harness(true, true, true);
        await h.ctrl.setSource(FixSource.DEMO);
        await h.ctrl.plan(MINI_TOUR_ID, 0);
        h.placeNear(MINI_BARBICAN, 60, 0);
        await h.ctrl.start();
        const first: string = h.ctrl.current().nowPlaying?.caption ?? '';
        expect(first.length > 0).assertTrue();
        h.walkTo(MINI_BARBICAN, 1.3);
        h.dwellUntilQuiet(120);
        expect(h.speech.spoken.length).assertEqual(0);
        expect(h.log.find('POI_ENTER', `id=${MINI_BARBICAN}`, 0) >= 0).assertTrue();
        expect(h.log.find('STORY_START', 'mode=text', 0) >= 0).assertTrue();
        expect(h.ctrl.current().platform.ttsEngine).assertEqual('none');
        h.ctrl.end();
        done();
      });

    it('lock-screen commands: pause stops speech and play re-speaks the sentence; demo hold while at a stop', 0,
      async (done: Function) => {
        const h: Harness = new Harness(false, true, true);
        await h.ctrl.setSource(FixSource.DEMO);
        await h.ctrl.plan(MINI_TOUR_ID, 0);
        h.placeNear(MINI_BARBICAN, 200, 0);
        await h.ctrl.start();
        const cmd: MediaCommandListener = h.media.onCommand as MediaCommandListener;
        const n: number = h.speech.spoken.length;
        cmd(MediaCommand.PAUSE);
        expect(h.speech.stops).assertEqual(1);
        expect(h.ctrl.current().paused).assertTrue();
        expect(h.media.states[h.media.states.length - 1]).assertEqual(MediaPlayState.PAUSE);
        cmd(MediaCommand.PLAY);
        expect(h.ctrl.current().paused).assertFalse();
        expect(h.speech.spoken.length).assertEqual(n + 1);
        expect(h.speech.spoken[n]).assertEqual(h.speech.spoken[n - 1]);
        expect(h.demoCtl.hold()).assertFalse();
        h.speech.sentenceMs = 1000000;                                 // keep the stop story from ending
        h.walkTo(MINI_BARBICAN, 1.3);
        h.second(0, Number.NaN);
        expect(h.ctrl.current().phase).assertEqual(TourPhase.AT_STOP);
        expect(h.demoCtl.hold()).assertTrue();
        expect(h.ctrl.current().platform.demoHold).assertTrue();
        h.ctrl.demoJumpToNext();
        expect(h.demoCtl.jumps).assertEqual(1);
        h.ctrl.end();
        done();
      });

    it('synchronous speech callbacks are queued, not re-entrant', 0, async (done: Function) => {
      const h: Harness = new Harness(false, true, true);
      h.speech.sync = true;
      await h.ctrl.setSource(FixSource.DEMO);
      await h.ctrl.plan(MINI_TOUR_ID, 0);
      h.placeNear(MINI_BARBICAN, 200, 0);
      await h.ctrl.start();
      expect(h.speech.spoken.length >= 2).assertTrue();                // whole welcome item in one dispatch
      expect(h.ctrl.current().nowPlaying === undefined).assertTrue();
      expect(h.log.count('UNCAUGHT')).assertEqual(0);
      h.ctrl.end();
      done();
    });

    it('snapshots are throttled to 4 Hz and end() mid-tour tears everything down', 0, async (done: Function) => {
      const h: Harness = new Harness(false, true, true);
      await h.ctrl.setSource(FixSource.DEMO);
      await h.ctrl.plan(MINI_TOUR_ID, 0);
      let published: number = 0;
      const unsub: () => void = h.ctrl.subscribe((s: EngineSnapshot) => {
        published++;
      });
      expect(published).assertEqual(1);                                // subscribe() delivers the current one
      h.placeNear(MINI_BARBICAN, 300, 0);
      await h.ctrl.start();
      const before: number = published;
      for (let i = 0; i < 10; i++) {
        h.demo.emit(h.fixAt(h.lat, h.lng, 1.3, 180, FixSource.DEMO));  // 10 fixes in the same millisecond
      }
      expect(published - before <= 1).assertTrue();
      h.sched.advance(300);
      expect(published - before <= 2).assertTrue();
      h.ctrl.end();
      expect(h.ctrl.current().phase).assertEqual(TourPhase.ABORTED);
      expect(h.ctrl.isRunning()).assertFalse();
      expect(h.demo.running).assertFalse();
      expect(h.bg.stops).assertEqual(1);
      expect(h.media.destroyed).assertEqual(1);
      const lines: number = h.log.lines.length;
      h.demo.running = true;                                           // a late fix from the stopped source
      h.demo.emit(h.fixAt(h.lat, h.lng, 1.3, 180, FixSource.DEMO));
      expect(h.log.lines.length).assertEqual(lines);
      unsub();
      done();
    });
  });
}

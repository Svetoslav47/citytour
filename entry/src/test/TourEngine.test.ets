// Suite: TourEngine.test - module under test: core/tour/TourEngine (reducer, task A3).
// Cases from docs/ARCHITECTURE.md §11.1: a scripted 3-stop track drives Idle -> Planning -> Ready -> Walking ->
// Approaching -> AtStop(Teaser -> Full -> Done) -> Walking -> ... -> Finished and asserts the exact effect
// sequence; pause during a story; USER_MORE; FIX_TIMEOUT => P0 once.
// Plus: walk-through => teaser only (STORY_SKIP_MOVING); acc 80 m => no arrival; a visited stop never fires
// again (jitter at the edge with acc 15 m); text-only arrival = HAPTIC + NOTIFY + META and TICK-paced captions;
// skip = STOP_SPEECH(afterCurrent) then the next line; 3 TTS errors => text only; USER_END => Aborted; snapshot.
// Fixtures: test/fixtures/MiniPack.ets (Barbican -> St Mary's -> Cloth Hall) plus a St Mary's full narration.
import { describe, it, expect } from '@ohos/hypium';
import {
  EngineLog, NarrationFn, StepResult, TourEngine, TourInput, TourState
} from '../main/ets/core/tour/TourEngine';
import { TourConfig } from '../main/ets/core/tour/TourConfig';
import {
  AppIssue, Effect, EffectType, EngineEvent, EngineEventType, EngineSnapshot, IssueCode, NextInfo, NowPlaying,
  SignalQuality, StopProgress, StopStatus, TourPhase, TourPlan
} from '../main/ets/contracts/EngineTypes';
import { Fix, FixSource, Utterance, VoicePlan } from '../main/ets/contracts/Ports';
import {
  ContentTier, Lang, Narration, NarrationLength, Poi, ProvenanceKind
} from '../main/ets/contracts/Model';
import { VoiceLabel } from '../main/ets/contracts/Settings';
import {
  MINI_BARBICAN, MINI_CLOTH_HALL, MINI_PERSONA_ID, MINI_ST_MARYS, MINI_TOUR_ID, miniNarrations, miniPois, miniTour
} from './fixtures/MiniPack';

const T0: number = 1000000;
const M_PER_DEG_LAT: number = 111195;
const SENTENCE_MS: number = 5000;     // simulated speaking time of one sentence
const GPS_LOST_EN: string = 'I\'ve lost the GPS signal. I\'ll continue when it\'s back.';

/** Deterministic pseudo-random numbers in (-1, 1) (Park-Miller, exact in doubles). */
class Lcg {
  private state: number;

  constructor(seed: number) {
    this.state = seed % 2147483647;
  }

  next(): number {
    this.state = (this.state * 16807) % 2147483647;
    return this.state / 2147483647 * 2 - 1;
  }
}

function caption(s: EngineSnapshot): string {
  const np: NowPlaying | undefined = s.nowPlaying;
  return np === undefined ? '' : np.caption;
}

function hasIssue(s: EngineSnapshot, code: IssueCode): boolean {
  return s.issues.some((i: AppIssue) => i.code === code);
}

/** The kv of the first LOG effect with this code, '' if none. */
function logKv(effects: Effect[], code: string): string {
  for (const e of effects) {
    if (e.type === EffectType.LOG && e.logCode === code) {
      return e.logKv === undefined ? '' : e.logKv;
    }
  }
  return '';
}

function speakCount(sigs: string[]): number {
  return sigs.filter((x: string) => x.indexOf('SPEAK') === 0).length;
}

function mPerDegLng(lat: number): number {
  return M_PER_DEG_LAT * Math.cos(lat * Math.PI / 180);
}

function poiById(id: string): Poi {
  for (const p of miniPois()) {
    if (p.id === id) {
      return p;
    }
  }
  return miniPois()[0];
}

function stMarysFull(): Narration {
  const n: Narration = {
    id: `${MINI_ST_MARYS}:${MINI_PERSONA_ID}:en:full`, poiId: MINI_ST_MARYS, personaId: MINI_PERSONA_ID,
    lang: Lang.EN, length: NarrationLength.FULL, sentences: ['Full story one.', 'Full story two.'],
    tier: ContentTier.REVIEWED_HISTORIAN, sources: ['src_test'], claims: [],
    generatedBy: { kind: ProvenanceKind.HUMAN, at: '2026-10-03T00:00:00Z' },
    reviewedBy: { reviewer: 'fixture', at: '2026-10-03T00:00:00Z', status: 'approved' },
    validation: { status: 'pass', checks: ['fixture'], validatorVersion: 1 }
  };
  return n;
}

function stMarysDeep(): Narration {
  const n: Narration = stMarysFull();
  n.id = `${MINI_ST_MARYS}:${MINI_PERSONA_ID}:en:deep`;
  n.length = NarrationLength.DEEP;
  n.sentences = ['Deep story one.'];
  return n;
}

function narrations(withDeep: boolean): NarrationFn {
  const all: Narration[] = miniNarrations();
  all.push(stMarysFull());
  if (withDeep) {
    all.push(stMarysDeep());
  }
  return (poiId: string, len: NarrationLength): Narration | undefined => {
    for (const n of all) {
      if (n.poiId === poiId && n.length === len) {
        return n;
      }
    }
    return undefined;
  };
}

function voicePlan(text: boolean): VoicePlan {
  const v: VoicePlan = {
    textLang: Lang.EN, speechMode: text ? 'text' : 'voice', engineLocale: text ? '' : 'zh-CN', person: text ? 0 : 13,
    languageContext: text ? '' : 'zh-CN', label: text ? VoiceLabel.TEXT_ONLY_USER : VoiceLabel.FALLBACK_ZH_READS_EN,
    reason: 'test'
  };
  return v;
}

function input(text: boolean, withDeep: boolean): TourInput {
  const i: TourInput = {
    tour: miniTour(), pois: miniPois(), lang: Lang.EN, personaId: MINI_PERSONA_ID, narration: narrations(withDeep),
    voice: voicePlan(text), adaptiveLength: true, spokenDirections: true, source: FixSource.DEMO
  };
  return i;
}

const ORDER_B_SM_CH: string[] = [MINI_BARBICAN, MINI_ST_MARYS, MINI_CLOTH_HALL];
const ORDER_SM_CH_B: string[] = [MINI_ST_MARYS, MINI_CLOTH_HALL, MINI_BARBICAN];

function plan(order: string[]): TourPlan {
  const p: TourPlan = {
    tourId: MINI_TOUR_ID, order: order, costS: 951, walkM: 768,
    savedM: 0, exact: true, algo: 'heldkarp', ms: 1, budgetS: 0, legs: []
  };
  return p;
}

/** Compact, deterministic text of one effect for sequence assertions. */
function sig(e: Effect): string {
  switch (e.type) {
    case EffectType.SPEAK:
      return `SPEAK ${e.utterance === undefined ? '' : e.utterance.text}`;
    case EffectType.STOP_SPEECH:
      return `STOP afterCurrent=${e.afterCurrent}`;
    case EffectType.SET_MEDIA_META:
      return e.meta === undefined ? 'META' : `META ${e.meta.title} | ${e.meta.voiceLabel} demo=${e.meta.demo}`;
    case EffectType.SET_MEDIA_STATE:
      return `MEDIA ${e.playState}`;
    case EffectType.NOTIFY_NEXT:
      return `NOTIFY ${e.notice === undefined ? '' : e.notice.poiId}`;
    case EffectType.HAPTIC:
      return `HAPTIC ${e.haptic}`;
    case EffectType.PERSIST_PROGRESS:
      return 'PERSIST';
    case EffectType.REQUEST_REPLAN:
      return 'REPLAN';
    default:
      return e.logCode === EngineLog.STATE ? `LOG STATE ${e.logKv}` : `LOG ${e.logCode}`;
  }
}

/** Drives the reducer: a 1 Hz fix track plus a speech simulator that finishes each sentence after 5 s. */
class Driver {
  st: TourState;
  t: number = T0;
  lat: number = 0;
  lng: number = 0;
  sigs: string[] = [];
  spoken: string[] = [];
  speaking: Utterance | undefined = undefined;
  speakStart: number = 0;
  autoSpeech: boolean = true;
  ticks: boolean = false;
  acc: number = 5;

  constructor(inp: TourInput) {
    this.st = TourEngine.init(inp, new TourConfig());
  }

  ev(type: EngineEventType): Effect[] {
    const e: EngineEvent = { type: type, nowMs: this.t };
    return this.send(e);
  }

  send(e: EngineEvent): Effect[] {
    const r: StepResult = TourEngine.reduce(this.st, e);
    this.st = r.state;
    for (const x of r.effects) {
      this.sigs.push(sig(x));
      if (x.type === EffectType.SPEAK && x.utterance !== undefined) {
        this.speaking = x.utterance;
        this.speakStart = this.t;
        this.spoken.push(x.utterance.text);
      } else if (x.type === EffectType.STOP_SPEECH && x.afterCurrent === false) {
        this.speaking = undefined;
      }
    }
    return r.effects;
  }

  fix(speed: number, course: number): Effect[] {
    const f: Fix = {
      lat: this.lat, lng: this.lng, accuracyM: this.acc, speedMps: speed, courseDeg: course,
      courseAccuracyDeg: Number.NaN, timestampMs: this.t, provider: 0, source: FixSource.DEMO
    };
    const e: EngineEvent = { type: EngineEventType.FIX, nowMs: this.t, fix: f };
    return this.send(e);
  }

  /** Finishes the in-flight sentence now. */
  done(): Effect[] {
    const u: Utterance | undefined = this.speaking;
    if (u === undefined) {
      return [];
    }
    this.speaking = undefined;
    const e: EngineEvent = { type: EngineEventType.UTTERANCE_DONE, nowMs: this.t, utteranceId: u.id };
    return this.send(e);
  }

  /** One second passes: a fix at the current position, then the speech simulator. */
  second(speed: number, course: number): void {
    this.t += 1000;
    this.fix(speed, course);
    if (this.ticks) {
      this.ev(EngineEventType.TICK);
    }
    if (this.autoSpeech && this.speaking !== undefined && this.t - this.speakStart >= SENTENCE_MS) {
      this.done();
    }
  }

  placeAt(lat: number, lng: number): void {
    this.lat = lat;
    this.lng = lng;
  }

  /** Puts the walker `metres` from a POI in the direction `fromBearingDeg` (0 = north of it). */
  placeNear(poiId: string, metres: number, fromBearingDeg: number): void {
    const p: Poi = poiById(poiId);
    const b: number = fromBearingDeg * Math.PI / 180;
    this.lat = p.lat + metres * Math.cos(b) / M_PER_DEG_LAT;
    this.lng = p.lng + metres * Math.sin(b) / mPerDegLng(p.lat);
  }

  /** Walks in a straight line at `speed` towards the POI until `shortM` metres before it. */
  walkTo(poiId: string, shortM: number, speed: number): void {
    const p: Poi = poiById(poiId);
    const k: number = mPerDegLng(p.lat);
    const dx: number = (p.lng - this.lng) * k;
    const dy: number = (p.lat - this.lat) * M_PER_DEG_LAT;
    const dist: number = Math.hypot(dx, dy);
    const course: number = ((Math.atan2(dx, dy) * 180 / Math.PI) + 360) % 360;
    const steps: number = Math.floor((dist - shortM) / speed);
    const lat0: number = this.lat;
    const lng0: number = this.lng;
    for (let i = 1; i <= steps; i++) {
      const f: number = i * speed / dist;
      this.lat = lat0 + dy * f / M_PER_DEG_LAT;
      this.lng = lng0 + dx * f / k;
      this.second(speed, course);
    }
  }

  /** Stands still until the engine is no longer at a stop and nothing is being said (max 120 s). */
  dwellUntilQuiet(): void {
    for (let i = 0; i < 120; i++) {
      if (this.st.phase !== TourPhase.AT_STOP && this.speaking === undefined && this.st.queue.size() === 0) {
        return;
      }
      this.second(0, Number.NaN);
    }
  }

  /** Stands still for n seconds. */
  dwell(n: number): void {
    for (let i = 0; i < n; i++) {
      this.second(0, Number.NaN);
    }
  }

  count(prefix: string): number {
    return this.sigs.filter((s: string) => s.indexOf(prefix) === 0).length;
  }

  snap(): EngineSnapshot {
    return TourEngine.snapshot(this.st);
  }

  /** Finishes sentences instantly until nothing is in flight. */
  flush(): void {
    for (let i = 0; i < 50 && this.speaking !== undefined; i++) {
      this.done();
    }
  }

  /** Effects since the given index of sigs. */
  since(from: number): string[] {
    return this.sigs.slice(from);
  }

  /** Planning + start with the walker already placed. */
  start(order: string[]): void {
    this.ev(EngineEventType.START_PLANNING);
    const e: EngineEvent = { type: EngineEventType.PLAN_READY, nowMs: this.t, plan: plan(order) };
    this.send(e);
    this.fix(0, Number.NaN);
    this.ev(EngineEventType.START_TOUR);
  }
}

/**
 * The exact effect sequence of the scripted 3-stop tour (reviewed by hand against ARCHITECTURE §4.1-4.4):
 * welcome + next stop, approach cue, arrival (haptic, media meta, story), teaser -> full when lingering,
 * next-stop line + notification, full-only stop, finish line + finish haptic, media stop.
 */
const EXPECTED_3_STOP: string[] = [
  'LOG STATE from=idle to=planning ev=START_PLANNING',
  'LOG ROUTE_PLAN',
  'LOG STATE from=planning to=ready ev=PLAN_READY',
  'LOG STATE from=ready to=walking ev=START_TOUR',
  'LOG TOUR_CONFIG',
  'MEDIA play',
  'META Barbican | fallback-zh demo=true',
  'NOTIFY poi_mini_barbican',
  'LOG STORY_QUEUE',
  'PERSIST',
  'LOG STORY_START',
  'SPEAK Welcome! Today\'s walk: Mini tour.',
  'SPEAK Put your phone away. I\'ll tell you where to go and where to look.',
  'SPEAK This is a simulated walk, so I\'ll move you along the route myself.',
  'SPEAK Next stop: Barbican, about 150 metres from here.',
  'LOG STORY_END',
  'LOG STATE from=walking to=approaching ev=FIX stop=poi_mini_barbican',
  'LOG POI_APPROACH',
  'LOG STORY_QUEUE',
  'LOG STORY_START',
  'SPEAK In about 100 metres, straight ahead: Barbican.',
  'LOG STORY_END',
  'LOG STATE from=approaching to=atStop ev=FIX stop=poi_mini_barbican',
  'LOG POI_ENTER',
  'HAPTIC arrive',
  'META Barbican | fallback-zh demo=true',
  'LOG NARR_FALLBACK',
  'LOG STORY_QUEUE',
  'LOG STORY_START',
  'SPEAK Barbican is straight ahead.',
  'LOG STORY_END',
  'PERSIST',
  'LOG STATE from=atStop to=walking ev=ITEM_DONE stop=poi_mini_barbican',
  'NOTIFY poi_mini_st_marys',
  'META St Mary\'s Basilica | fallback-zh demo=true',
  'LOG STORY_QUEUE',
  'LOG STORY_START',
  'SPEAK Next stop: St Mary\'s Basilica, about 500 metres from here.',
  'LOG STORY_END',
  'LOG STATE from=walking to=approaching ev=FIX stop=poi_mini_st_marys',
  'LOG POI_APPROACH',
  'LOG STORY_QUEUE',
  'LOG STORY_START',
  'SPEAK In about 100 metres, straight ahead: St Mary\'s Basilica.',
  'LOG STORY_END',
  'LOG STATE from=approaching to=atStop ev=FIX stop=poi_mini_st_marys',
  'LOG POI_ENTER',
  'HAPTIC arrive',
  'META St Mary\'s Basilica | fallback-zh demo=true',
  'LOG STORY_QUEUE',
  'LOG STORY_START',
  'SPEAK St Mary\'s Basilica is straight ahead.',
  'SPEAK Fixture teaser sentence one.',
  'SPEAK Fixture teaser sentence two.',
  'LOG STORY_END',
  'LOG STORY_QUEUE',
  'LOG STORY_START',
  'SPEAK Full story one.',
  'SPEAK Full story two.',
  'LOG STORY_END',
  'PERSIST',
  'LOG STATE from=atStop to=walking ev=ITEM_DONE stop=poi_mini_st_marys',
  'NOTIFY poi_mini_cloth_hall',
  'META Cloth Hall | fallback-zh demo=true',
  'LOG STORY_QUEUE',
  'LOG STORY_START',
  'SPEAK Next stop: Cloth Hall, about 150 metres from here.',
  'LOG STORY_END',
  'LOG STATE from=walking to=approaching ev=FIX stop=poi_mini_cloth_hall',
  'LOG POI_APPROACH',
  'LOG STORY_QUEUE',
  'LOG STORY_START',
  'SPEAK In about 100 metres, straight ahead: Cloth Hall.',
  'LOG STORY_END',
  'LOG STATE from=approaching to=atStop ev=FIX stop=poi_mini_cloth_hall',
  'LOG POI_ENTER',
  'HAPTIC arrive',
  'META Cloth Hall | fallback-zh demo=true',
  'LOG STORY_QUEUE',
  'LOG STORY_START',
  'SPEAK Cloth Hall is straight ahead.',
  'SPEAK Fixture full sentence one.',
  'SPEAK Fixture full sentence two.',
  'SPEAK Fixture full sentence three.',
  'LOG STORY_END',
  'PERSIST',
  'LOG STATE from=atStop to=finished ev=ITEM_DONE stop=poi_mini_cloth_hall',
  'HAPTIC finish',
  'META Mini tour | fallback-zh demo=true',
  'LOG STORY_QUEUE',
  'LOG STORY_START',
  'SPEAK That\'s the end of our walk.',
  'SPEAK Thank you for walking with me.',
  'LOG STORY_END',
  'MEDIA stop'
];

/** Asserts two sequences are equal, reporting the first difference with its index. */
function expectSeq(actual: string[], expected: string[]): void {
  const n: number = Math.max(actual.length, expected.length);
  for (let i = 0; i < n; i++) {
    const a: string = i < actual.length ? actual[i] : '<end>';
    const b: string = i < expected.length ? expected[i] : '<end>';
    if (a !== b) {
      expect(`#${i} ${a}`).assertEqual(`#${i} ${b}`);
      return;
    }
  }
  expect(actual.length).assertEqual(expected.length);
}

export default function tourEngineTest() {
  describe('TourEngine', () => {
    it('scripted_3_stop_tour_exact_effect_sequence', 0, () => {
      const d: Driver = new Driver(input(false, false));
      d.placeNear(MINI_BARBICAN, 150, 0);                // 150 m north of the Barbican
      d.start(ORDER_B_SM_CH);
      d.walkTo(MINI_BARBICAN, 25, 1.4);                  // passes the 110 m approach ring, enters at ~37 m
      d.dwellUntilQuiet();                               // arrival line only (no Barbican narration)
      d.walkTo(MINI_ST_MARYS, 25, 1.4);                  // stops 25 m short: lingering => teaser then full
      d.dwellUntilQuiet();
      d.walkTo(MINI_CLOTH_HALL, 20, 1.4);                // full story only (no teaser), then the finish
      d.dwellUntilQuiet();
      expectSeq(d.sigs, EXPECTED_3_STOP);
      expect(d.st.phase).assertEqual(TourPhase.FINISHED);
      const s: EngineSnapshot = d.snap();
      expect(s.stops[0].status).assertEqual(StopStatus.VISITED);
      expect(s.stops[1].status).assertEqual(StopStatus.VISITED);
      expect(s.stops[2].status).assertEqual(StopStatus.VISITED);
      expect(s.walkedM).assertLarger(600);
      expect(s.next === undefined).assertTrue();
    });

    it('pause_during_story_restarts_the_sentence_on_resume', 0, () => {
      const d: Driver = new Driver(input(false, false));
      d.autoSpeech = false;
      d.placeNear(MINI_ST_MARYS, 30, 0);
      d.start(ORDER_SM_CH_B);
      d.flush();                                         // welcome + next stop
      d.dwell(3);                                        // 3 still fixes 30 m away: debounced ENTER
      expect(d.st.phase).assertEqual(TourPhase.AT_STOP);
      expect(d.spoken[d.spoken.length - 1]).assertEqual('You\'re at St Mary\'s Basilica.'); // course unknown
      d.done();                                          // arrival line done, teaser sentence 1 in flight
      const cut: Utterance | undefined = d.speaking;
      expect(cut !== undefined && cut.text === 'Fixture teaser sentence one.').assertTrue();
      const mark: number = d.sigs.length;
      d.ev(EngineEventType.USER_PAUSE);
      expectSeq(d.since(mark), ['STOP afterCurrent=false', 'MEDIA pause']);
      expect(d.snap().paused).assertTrue();
      expect(caption(d.snap())).assertEqual('Fixture teaser sentence one.');
      d.dwell(5);                                        // fixes still arrive while paused
      const late: EngineEvent = {
        type: EngineEventType.UTTERANCE_DONE, nowMs: d.t, utteranceId: cut === undefined ? '' : cut.id
      };
      d.send(late);                                      // the cut sentence's DONE is ignored
      expect(speakCount(d.since(mark))).assertEqual(0);
      const m2: number = d.sigs.length;
      d.ev(EngineEventType.USER_RESUME);
      expectSeq(d.since(m2), ['MEDIA play', 'SPEAK Fixture teaser sentence one.']);
      const again: Utterance | undefined = d.speaking;
      expect(again !== undefined && cut !== undefined && again.id !== cut.id).assertTrue();
    });

    it('walk_through_is_teaser_only_then_user_more_plays_full', 0, () => {
      const d: Driver = new Driver(input(false, false));
      d.placeNear(MINI_ST_MARYS, 120, 0);
      d.start(ORDER_SM_CH_B);
      d.walkTo(MINI_ST_MARYS, -60, 1.4);                 // straight through at 1.4 m/s
      expect(d.count('LOG STORY_SKIP_MOVING')).assertEqual(1);
      expect(d.spoken.indexOf('Fixture teaser sentence two.') >= 0).assertTrue();
      expect(d.spoken.indexOf('Full story one.') < 0).assertTrue();
      expect(d.snap().stops[0].status).assertEqual(StopStatus.TEASER_ONLY);
      expect(d.st.phase).assertEqual(TourPhase.WALKING);
      d.ev(EngineEventType.USER_MORE);                  // "Tell me more" while walking on
      d.dwell(20);
      expect(d.spoken.indexOf('Full story one.') >= 0 && d.spoken.indexOf('Full story two.') >= 0).assertTrue();
      expect(d.snap().stops[0].status).assertEqual(StopStatus.VISITED);
    });

    it('user_more_during_teaser_forces_full_while_walking', 0, () => {
      const d: Driver = new Driver(input(false, false));
      d.placeNear(MINI_ST_MARYS, 120, 0);
      d.start(ORDER_SM_CH_B);
      d.walkTo(MINI_ST_MARYS, 30, 1.4);                  // enters at ~36 m, still walking
      expect(d.st.phase).assertEqual(TourPhase.AT_STOP);
      d.ev(EngineEventType.USER_MORE);
      d.walkTo(MINI_ST_MARYS, -60, 1.4);
      d.dwell(10);
      expect(d.count('LOG STORY_SKIP_MOVING')).assertEqual(0);
      expect(d.spoken.indexOf('Full story two.') >= 0).assertTrue();
      expect(d.snap().stops[0].status).assertEqual(StopStatus.VISITED);
    });

    it('user_more_during_full_queues_deep_before_the_next_stop_line', 0, () => {
      const d: Driver = new Driver(input(false, true));
      d.autoSpeech = false;
      d.placeNear(MINI_ST_MARYS, 30, 0);
      d.start(ORDER_SM_CH_B);
      d.flush();
      d.dwell(3);                                        // arrival
      d.done();                                          // arrival line
      d.done();                                          // teaser 1
      d.done();                                          // teaser 2 => lingering => full
      const u: Utterance | undefined = d.speaking;
      expect(u !== undefined && u.text === 'Full story one.').assertTrue();
      d.ev(EngineEventType.USER_MORE);
      d.flush();
      const full2: number = d.spoken.indexOf('Full story two.');
      const deep: number = d.spoken.indexOf('Deep story one.');
      const next: number = d.spoken.indexOf('Next stop: Cloth Hall, about 150 metres from here.');
      expect(full2 > 0 && deep > full2 && next > deep).assertTrue();
    });

    it('fix_timeout_speaks_p0_once_per_episode_and_the_story_resumes', 0, () => {
      const d: Driver = new Driver(input(false, false));
      d.autoSpeech = false;
      d.placeNear(MINI_ST_MARYS, 30, 0);
      d.start(ORDER_SM_CH_B);
      d.flush();
      d.dwell(3);
      d.done();                                          // teaser sentence 1 in flight
      const mark: number = d.sigs.length;
      d.t += 26000;
      d.ev(EngineEventType.FIX_TIMEOUT);
      const out: string[] = d.since(mark);
      expect(out.indexOf('LOG LOC_LOST') >= 0 && out.indexOf('LOG STORY_QUEUE') >= 0).assertTrue();
      expect(speakCount(out)).assertEqual(0);            // the teaser sentence is not cut
      d.ev(EngineEventType.FIX_TIMEOUT);
      d.ev(EngineEventType.FIX_TIMEOUT);
      expect(d.count('LOG LOC_LOST')).assertEqual(1);
      expect(d.snap().signal).assertEqual(SignalQuality.LOST);
      expect(hasIssue(d.snap(), IssueCode.LOC_LOST)).assertTrue();
      d.done();                                          // sentence boundary: P0 plays
      expect(d.speaking !== undefined && d.speaking.text === GPS_LOST_EN).assertTrue();
      d.done();                                          // then the teaser resumes at its cursor
      expect(d.speaking !== undefined && d.speaking.text === 'Fixture teaser sentence two.').assertTrue();
      d.second(0, Number.NaN);                           // signal back
      expect(d.count('LOG LOC_BACK')).assertEqual(1);
      expect(d.snap().signal).assertEqual(SignalQuality.GOOD);
      expect(hasIssue(d.snap(), IssueCode.LOC_LOST)).assertFalse();
      d.t += 26000;
      d.ev(EngineEventType.FIX_TIMEOUT);                 // a new episode speaks once more
      d.ev(EngineEventType.FIX_TIMEOUT);
      d.flush();
      expect(d.spoken.filter((x: string) => x === GPS_LOST_EN).length).assertEqual(2);
    });

    it('poor_accuracy_never_arrives', 0, () => {
      const d: Driver = new Driver(input(false, false));
      d.acc = 80;
      d.placeNear(MINI_ST_MARYS, 0, 0);                  // standing on the stop, but acc 80 m
      d.start(ORDER_SM_CH_B);
      d.dwell(20);
      expect(d.count('LOG POI_ENTER')).assertEqual(0);
      expect(d.st.phase).assertEqual(TourPhase.WALKING);
      expect(d.snap().signal).assertEqual(SignalQuality.POOR);
      expect(hasIssue(d.snap(), IssueCode.LOC_POOR)).assertTrue();
      expect(d.count('LOG LOC_POOR')).assertEqual(1);    // rate-limited to 1 per 30 s
      d.acc = 5;
      d.dwell(1);                                        // one good fix within R/2 enters at once
      expect(d.count('LOG POI_ENTER')).assertEqual(1);
      expect(hasIssue(d.snap(), IssueCode.LOC_POOR)).assertFalse();
    });

    it('a_visited_stop_never_fires_again_with_15m_jitter', 0, () => {
      const d: Driver = new Driver(input(false, false));
      d.acc = 15;
      d.placeNear(MINI_ST_MARYS, 35, 0);
      d.start(ORDER_SM_CH_B);
      const rnd: Lcg = new Lcg(4242);
      for (let i = 0; i < 300; i++) {
        d.placeNear(MINI_ST_MARYS, 35 + 15 * rnd.next(), 0);
        d.second(0.2, Number.NaN);
      }
      expect(d.count('LOG POI_ENTER')).assertEqual(1);
      expect(d.count('HAPTIC arrive')).assertEqual(1);
      const arrivals: string[] = d.spoken.filter((x: string) =>
        x.indexOf('St Mary\'s Basilica is') === 0 || x.indexOf('You\'re at St Mary') === 0);
      expect(arrivals.length).assertEqual(1);
    });

    it('text_only_arrival_haptic_notify_meta_and_tick_paced_captions', 0, () => {
      const d: Driver = new Driver(input(true, false));
      d.ticks = true;
      d.placeNear(MINI_ST_MARYS, 30, 0);
      d.start(ORDER_SM_CH_B);
      expect(d.snap().speechText).assertTrue();
      expect(caption(d.snap())).assertEqual('Welcome! Today\'s walk: Mini tour.');
      d.t += 2000;
      d.ev(EngineEventType.TICK);                        // 2.0 s < 2.5 s reading time
      expect(caption(d.snap())).assertEqual('Welcome! Today\'s walk: Mini tour.');
      d.t += 1000;
      d.ev(EngineEventType.TICK);
      expect(caption(d.snap())).assertEqual('Put your phone away. I\'ll tell you where to go and where to look.');
      const mark: number = d.sigs.length;
      d.dwell(3);
      expect(d.st.phase).assertEqual(TourPhase.AT_STOP);
      const out: string[] = d.since(mark);
      expect(out.indexOf('HAPTIC arrive') >= 0).assertTrue();
      expect(out.indexOf('NOTIFY poi_mini_st_marys') >= 0).assertTrue();
      expect(out.indexOf('META St Mary\'s Basilica | text-only-user demo=true') >= 0).assertTrue();
      d.dwell(120);                                      // captions advance on TICK through teaser and full
      expect(d.count('SPEAK')).assertEqual(0);
      expect(d.snap().stops[0].status).assertEqual(StopStatus.VISITED);
      expect(d.st.phase).assertEqual(TourPhase.WALKING);
    });

    it('skip_stops_after_the_current_sentence_then_the_next_stop_line', 0, () => {
      const d: Driver = new Driver(input(false, false));
      d.autoSpeech = false;
      d.placeNear(MINI_ST_MARYS, 30, 0);
      d.start(ORDER_SM_CH_B);
      d.flush();
      d.dwell(3);
      d.done();                                          // teaser sentence 1 in flight
      const mark: number = d.sigs.length;
      d.ev(EngineEventType.USER_SKIP);
      const out: string[] = d.since(mark);
      expect(out[0]).assertEqual('STOP afterCurrent=true');
      expect(out.indexOf('LOG STATE from=atStop to=walking ev=ITEM_DONE stop=poi_mini_st_marys') > 0).assertTrue();
      expect(speakCount(out)).assertEqual(0);            // the current sentence finishes first
      d.done();
      expect(d.speaking !== undefined && d.speaking.text.indexOf('Next stop: Cloth Hall') === 0).assertTrue();
      expect(d.spoken.indexOf('Fixture teaser sentence two.') < 0).assertTrue();
      expect(d.snap().stops[0].status).assertEqual(StopStatus.VISITED);
    });

    it('three_tts_errors_switch_to_text_only', 0, () => {
      const d: Driver = new Driver(input(false, false));
      d.autoSpeech = false;
      d.placeNear(MINI_BARBICAN, 150, 0);
      d.start(ORDER_B_SM_CH);
      for (let i = 0; i < 3; i++) {
        const u: Utterance | undefined = d.speaking;
        d.speaking = undefined;
        const e: EngineEvent = {
          type: EngineEventType.UTTERANCE_FAILED, nowMs: d.t, utteranceId: u === undefined ? '' : u.id, code: 1002300003
        };
        d.send(e);
      }
      expect(d.count('LOG TTS_ERR')).assertEqual(3);
      expect(d.count('SPEAK')).assertEqual(3);
      const s: EngineSnapshot = d.snap();
      expect(s.speechText).assertTrue();
      expect(s.voiceLabel).assertEqual(VoiceLabel.TEXT_ONLY_PLATFORM);
      expect(hasIssue(s, IssueCode.TTS_ERR)).assertTrue();
      expect(caption(s)).assertEqual('Next stop: Barbican, about 150 metres from here.');
      expect(d.count('META Barbican | text-only-platform')).assertEqual(1);
    });

    it('user_end_aborts_and_ignores_later_fixes', 0, () => {
      const d: Driver = new Driver(input(false, false));
      d.placeNear(MINI_BARBICAN, 150, 0);
      d.start(ORDER_B_SM_CH);
      const mark: number = d.sigs.length;
      d.ev(EngineEventType.USER_END);
      expectSeq(d.since(mark),
        ['STOP afterCurrent=false', 'MEDIA stop', 'LOG STATE from=walking to=aborted ev=USER_END', 'PERSIST']);
      d.walkTo(MINI_BARBICAN, 0, 1.4);
      expect(d.count('LOG POI_ENTER')).assertEqual(0);
      expect(d.st.phase).assertEqual(TourPhase.ABORTED);
    });

    it('replan_mid_tour_reorders_open_stops', 0, () => {
      const d: Driver = new Driver(input(false, false));
      d.placeNear(MINI_BARBICAN, 150, 0);
      d.start(ORDER_B_SM_CH);
      const same: EngineEvent = {
        type: EngineEventType.PLAN_READY, nowMs: d.t, plan: plan([MINI_BARBICAN, MINI_CLOTH_HALL, MINI_ST_MARYS])
      };
      d.send(same);
      expect(d.count('LOG REPLAN')).assertEqual(0);      // the next stop did not change
      expect(d.snap().plannedOrder.join(',')).assertEqual([MINI_BARBICAN, MINI_CLOTH_HALL, MINI_ST_MARYS].join(','));
      const mark: number = d.sigs.length;
      const other: EngineEvent = { type: EngineEventType.PLAN_READY, nowMs: d.t, plan: plan(ORDER_SM_CH_B) };
      d.send(other);
      expect(d.since(mark).indexOf('LOG REPLAN') >= 0).assertTrue();
      expect(d.since(mark).indexOf('NOTIFY poi_mini_st_marys') >= 0).assertTrue();
      expect(d.snap().next !== undefined && d.snap().next?.poiId === MINI_ST_MARYS).assertTrue();
    });

    it('audio_interrupt_pauses_and_its_resume_replays_but_never_undoes_a_user_or_route_pause', 0, () => {
      // §9 rows 12/13 (A10).
      const d: Driver = new Driver(input(false, false));
      d.autoSpeech = false;
      d.placeNear(MINI_BARBICAN, 150, 0);
      d.start(ORDER_B_SM_CH);
      const cut: Utterance | undefined = d.speaking;
      expect(cut !== undefined).assertTrue();
      const pause: EngineEvent = { type: EngineEventType.AUDIO_INTERRUPT, nowMs: d.t, hint: 'PAUSE' };
      const resume: EngineEvent = { type: EngineEventType.AUDIO_INTERRUPT, nowMs: d.t, hint: 'RESUME' };
      let mark: number = d.sigs.length;
      expect(logKv(d.send(pause), EngineLog.AUDIO_INTERRUPT)).assertEqual('hint=PAUSE action=pause');
      expectSeq(d.since(mark), ['LOG AUDIO_INTERRUPT', 'STOP afterCurrent=false', 'MEDIA pause']);
      expect(d.snap().paused).assertTrue();
      expect(hasIssue(d.snap(), IssueCode.AUDIO_INTERRUPT)).assertTrue();
      mark = d.sigs.length;
      expect(logKv(d.send(resume), EngineLog.AUDIO_INTERRUPT)).assertEqual('hint=RESUME action=resume');
      // the interrupted sentence replays from its start
      const after: string[] = d.since(mark).filter((x: string) => x.indexOf('LOG STORY') !== 0);
      expectSeq(after, ['LOG AUDIO_INTERRUPT', 'MEDIA play', `SPEAK ${cut === undefined ? '' : cut.text}`]);
      expect(d.snap().paused).assertFalse();
      expect(hasIssue(d.snap(), IssueCode.AUDIO_INTERRUPT)).assertFalse();
      // A user pause is not undone by an interrupt RESUME.
      d.ev(EngineEventType.USER_PAUSE);
      expect(logKv(d.send(pause), EngineLog.AUDIO_INTERRUPT)).assertEqual('hint=PAUSE action=already_paused');
      expect(logKv(d.send(resume), EngineLog.AUDIO_INTERRUPT)).assertEqual('hint=RESUME action=stay_paused');
      expect(d.snap().paused).assertTrue();
      d.ev(EngineEventType.USER_RESUME);
      expect(d.snap().paused).assertFalse();
      // Interrupt pause, then the user pauses too: the user owns it.
      d.send(pause);
      d.ev(EngineEventType.USER_PAUSE);
      d.send(resume);
      expect(d.snap().paused).assertTrue();
      d.ev(EngineEventType.USER_RESUME);
      // Headphones unplugged: pause + WARN issue; an interrupt RESUME does not resume on the loudspeaker.
      mark = d.sigs.length;
      expect(logKv(d.ev(EngineEventType.AUDIO_ROUTE_LOST), EngineLog.AUDIO_ROUTE)).assertEqual(
        'device=SPEAKER action=pause');
      expectSeq(d.since(mark), ['LOG AUDIO_ROUTE', 'STOP afterCurrent=false', 'MEDIA pause']);
      expect(hasIssue(d.snap(), IssueCode.AUDIO_ROUTE_LOST)).assertTrue();
      d.send(resume);
      expect(d.snap().paused).assertTrue();
      d.ev(EngineEventType.USER_RESUME);                 // the user's tap clears the banner
      expect(d.snap().paused).assertFalse();
      expect(hasIssue(d.snap(), IssueCode.AUDIO_ROUTE_LOST)).assertFalse();
      // DUCK and unknown hints change nothing.
      const duck: EngineEvent = { type: EngineEventType.AUDIO_INTERRUPT, nowMs: d.t, hint: 'DUCK' };
      expect(logKv(d.send(duck), EngineLog.AUDIO_INTERRUPT)).assertEqual('hint=DUCK action=none');
      expect(d.snap().paused).assertFalse();
    });

    it('audio_events_outside_a_running_tour_are_only_logged', 0, () => {
      const d: Driver = new Driver(input(false, false));
      const e: EngineEvent = { type: EngineEventType.AUDIO_INTERRUPT, nowMs: d.t, hint: 'PAUSE' };
      expect(logKv(d.send(e), EngineLog.AUDIO_INTERRUPT)).assertEqual('hint=PAUSE action=ignored phase=idle');
      expect(logKv(d.ev(EngineEventType.AUDIO_ROUTE_LOST), EngineLog.AUDIO_ROUTE)).assertEqual(
        'device=SPEAKER action=ignored phase=idle');
      expect(d.snap().paused).assertFalse();
      expect(d.snap().issues.length).assertEqual(0);
    });

    it('snapshot_for_the_ui', 0, () => {
      const d: Driver = new Driver(input(false, false));
      d.placeNear(MINI_BARBICAN, 150, 0);
      d.start(ORDER_B_SM_CH);
      const s: EngineSnapshot = d.snap();
      expect(s.phase).assertEqual(TourPhase.WALKING);
      expect(s.tourId).assertEqual(MINI_TOUR_ID);
      expect(s.stops.length).assertEqual(3);
      expect(s.stops.every((p: StopProgress) => p.status === StopStatus.PENDING)).assertTrue();
      expect(s.currentStopIdx).assertEqual(0);
      expect(s.plannedOrder.join(',')).assertEqual(ORDER_B_SM_CH.join(','));
      const n: NextInfo | undefined = s.next;
      expect(n !== undefined && n.poiId === MINI_BARBICAN && Math.abs(n.distanceM - 150) < 1).assertTrue();
      expect(n !== undefined && Math.abs(n.etaS - 150 / 1.3) < 1).assertTrue();
      const np: NowPlaying | undefined = s.nowPlaying;
      expect(np !== undefined && np.sentenceIndex === 0 && np.sentenceCount === 4 && np.kind === 'system').assertTrue();
      expect(s.user !== undefined && s.user.source === FixSource.DEMO && s.user.lat === d.lat).assertTrue();
      expect(s.voiceLabel).assertEqual(VoiceLabel.FALLBACK_ZH_READS_EN);
      expect(s.source).assertEqual(FixSource.DEMO);
      expect(s.signal).assertEqual(SignalQuality.GOOD);
      expect(s.paused || s.speechText || s.offRoute).assertFalse();
      expect(s.remainingM).assertLarger(150 + 450);
    });
  });
}

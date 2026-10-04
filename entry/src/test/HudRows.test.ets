// Suite: HudRows.test - module under test: core/hud/HudRows (task B12, "How it works" HUD).
// Every row shows only snapshot values or "n/a"; the Demo walk is SIMULATED; Fallback/Studio voice labels; A9 route
// state; the trigger radii match what TourEngine actually builds (cross-check against the reducer).
import { describe, it, expect } from '@ohos/hypium';
import {
  HudInput, HudRow, HudTone, hudDegrees, hudDistance, hudRows, hudSignedDegrees, hudSpeed, NA, serverRow, TriggerRadii,
  triggerRadii
} from 'common';
import { TourConfig } from 'common';
import { TourEngine, TourInput, TourState } from 'common';
import {
  EngineEvent, EngineEventType, EngineSnapshot, PlatformStatus, RelDir, SignalQuality, TourPhase, TourPlan
} from 'common';
import { ContentTier, Lang, Narration, NarrationLength, Poi, Tour } from 'common';
import { FixSource, VoicePlan } from 'common';
import { VoiceLabel } from 'common';
import {
  MINI_BARBICAN, MINI_CLOTH_HALL, MINI_PERSONA_ID, MINI_ST_MARYS, MINI_TOUR_ID, miniPois, miniTour
} from './fixtures/MiniPack';

function platform(): PlatformStatus {
  const p: PlatformStatus = {
    bgRunning: true, avsActive: true, ttsEngine: 'zh-CN/13', sourceKind: FixSource.REAL, realGpsAccuracyM: Number.NaN,
    demoHold: false
  };
  return p;
}

function snap(): EngineSnapshot {
  const s: EngineSnapshot = {
    phase: TourPhase.WALKING, tourId: MINI_TOUR_ID, stops: [], currentStopIdx: 0,
    next: {
      poiId: MINI_ST_MARYS, distanceM: 180.4, etaS: 139, relDir: RelDir.AHEAD_RIGHT, bearingDeg: 230,
      maneuverText: 'In 40 metres, turn left', maneuverDistM: 41
    },
    user: {
      x: 0, y: 0, lat: 50.0617, lng: 19.9373, accuracyM: 6.2, courseDeg: 212, speedMps: 1.34, source: FixSource.REAL
    },
    signal: SignalQuality.GOOD, offRoute: false, paused: false, speechText: false, plannedOrder: [], walkedM: 0,
    remainingM: 0, issues: [], voiceLabel: VoiceLabel.FALLBACK_ZH_READS_EN, source: FixSource.REAL, platform: platform()
  };
  return s;
}

function find(rows: HudRow[], key: string): HudRow {
  for (const r of rows) {
    if (r.key === key) {
      return r;
    }
  }
  const none: HudRow = { key: key, label: '', value: '<missing>', tone: HudTone.NA };
  return none;
}

function rows(s: EngineSnapshot | undefined, t?: TriggerRadii): HudRow[] {
  return hudRows({ snap: s, nextName: 'St Mary\'s Basilica', demoSpeed: 4, trigger: t });
}

function contains(hay: string, needle: string): boolean {
  return hay.indexOf(needle) >= 0;
}

/** Builds the engine's stops for one tour through the real reducer (START_PLANNING -> PLAN_READY). */
function engineStops(tour: Tour, pois: Poi[], cfg: TourConfig): TourState {
  const v: VoicePlan = {
    textLang: Lang.EN, speechMode: 'text', engineLocale: '', person: 0, languageContext: '',
    label: VoiceLabel.TEXT_ONLY_USER, reason: 'test'
  };
  const inp: TourInput = {
    tour: tour, pois: pois, lang: Lang.EN, personaId: MINI_PERSONA_ID,
    narration: (poiId: string, len: NarrationLength): Narration | undefined => undefined,
    voice: v, adaptiveLength: true, spokenDirections: true, source: FixSource.DEMO
  };
  let st: TourState = TourEngine.init(inp, cfg);
  const e1: EngineEvent = { type: EngineEventType.START_PLANNING, nowMs: 1000 };
  st = TourEngine.reduce(st, e1).state;
  const plan: TourPlan = {
    tourId: tour.id, order: tour.stops.map(s => s.poiId), costS: 1, walkM: 1, savedM: 0, exact: true,
    algo: 'heldkarp', ms: 1, budgetS: 0, legs: []
  };
  const e2: EngineEvent = { type: EngineEventType.PLAN_READY, nowMs: 1000, plan: plan };
  return TourEngine.reduce(st, e2).state;
}

export default function hudRowsTest() {
  describe('HudRows', () => {
    it('formats_units_and_na', 0, () => {
      expect(hudDistance(180.4)).assertEqual('180 m');
      expect(hudDistance(1234)).assertEqual('1.2 km');
      expect(hudDistance(Number.NaN)).assertEqual(NA);
      expect(hudDistance(-1)).assertEqual(NA);
      expect(hudDegrees(212.4)).assertEqual('212°');
      expect(hudDegrees(359.7)).assertEqual('0°');
      expect(hudDegrees(-10)).assertEqual('350°');
      expect(hudDegrees(Number.NaN)).assertEqual(NA);
      expect(hudSignedDegrees(18.2)).assertEqual('+18°');
      expect(hudSignedDegrees(-34)).assertEqual('-34°');
      expect(hudSignedDegrees(Number.NaN)).assertEqual(NA);
      expect(hudSpeed(1.34)).assertEqual('1.3 m/s');
      expect(hudSpeed(Number.NaN)).assertEqual(NA);
    });
    it('server_row_optional', 0, () => {
      const base: HudInput = { snap: snap(), nextName: 'x', demoSpeed: 4, trigger: undefined };
      expect(hudRows(base).length).assertEqual(8);
      const on: HudInput = { snap: snap(), nextName: 'x', demoSpeed: 4, trigger: undefined,
        server: 'server online · online voice on · 3 lines cached' };
      const r = hudRows(on);
      expect(r.length).assertEqual(9);
      expect(find(r, 'server').tone).assertEqual(HudTone.OK);
      expect(serverRow('server offline · online voice on · 0 lines cached').tone).assertEqual(HudTone.WARN);
      expect(serverRow('server budget reached · online voice on · 0 lines cached').tone).assertEqual(HudTone.WARN);
      expect(serverRow('server disabled').tone).assertEqual(HudTone.OFF);
      expect(serverRow('').value).assertEqual(NA);
    });
    it('no_snapshot_is_all_na', 0, () => {
      const r = rows(undefined);
      expect(r.length).assertEqual(8);
      for (const x of r) {
        expect(x.value).assertEqual(NA);
        expect(x.tone).assertEqual(HudTone.NA);
      }
    });
    it('real_source_rows', 0, () => {
      const r = rows(snap(), { arriveM: 35, approachM: 110 });
      expect(r.length).assertEqual(8);
      expect(find(r, 'location').value).assertEqual('Location Kit · ±6 m');
      expect(find(r, 'location').tone).assertEqual(HudTone.OK);
      expect(find(r, 'course').value).assertEqual('212° · 1.3 m/s');
      // bearing 230 vs course 212 => +18 relative
      expect(find(r, 'next').value).assertEqual('St Mary\'s Basilica · 180 m · brg 230° (+18°)');
      expect(find(r, 'trigger').value).assertEqual('approach 110 m · arrive 35 m');
      expect(find(r, 'route').value).assertEqual('on route · cue in 41 m: In 40 metres, turn left');
      const near = snap();
      near.phase = TourPhase.APPROACHING;
      expect(find(rows(near, { arriveM: 35, approachM: 110 }), 'trigger').value)
        .assertEqual('approach 110 m · arrive 35 m · approaching');
      expect(find(r, 'voice').value).assertEqual('Fallback voice (zh-CN reads EN) · Core Speech zh-CN/13 · idle');
      expect(find(r, 'voice').tone).assertEqual(HudTone.WARN);
      expect(find(r, 'session').value).assertEqual('AVSession active · playing');
      expect(find(r, 'background').value).assertEqual('LOCATION + AUDIO_PLAYBACK running');
    });
    it('demo_source_is_simulated_with_shadow_gps', 0, () => {
      const s = snap();
      s.source = FixSource.DEMO;
      s.platform.demoHold = true;
      let loc = find(rows(s), 'location');
      expect(contains(loc.value, 'SIMULATED')).assertTrue();
      expect(contains(loc.value, '4×')).assertTrue();
      expect(contains(loc.value, 'holding')).assertTrue();
      expect(contains(loc.value, `real GPS ${NA}`)).assertTrue();
      expect(loc.tone).assertEqual(HudTone.SIM);
      s.platform.realGpsAccuracyM = 12.4;
      loc = find(rows(s), 'location');
      expect(contains(loc.value, 'real GPS ±12 m')).assertTrue();
    });
    it('unknown_values_show_na', 0, () => {
      const s = snap();
      s.user = undefined;
      s.next = undefined;
      s.platform.ttsEngine = 'none';
      s.platform.avsActive = false;
      s.platform.bgRunning = false;
      const r = rows(s);
      expect(find(r, 'location').value).assertEqual(`Location Kit · accuracy ${NA}`);
      expect(find(r, 'course').value).assertEqual(`${NA} · ${NA}`);
      expect(find(r, 'next').value).assertEqual(NA);
      expect(find(r, 'trigger').value).assertEqual(`approach ${NA} · arrive ${NA}`);
      expect(find(r, 'route').value).assertEqual(`on route · cue ${NA}`);
      expect(contains(find(r, 'voice').value, `Core Speech ${NA}`)).assertTrue();
      expect(find(r, 'session').tone).assertEqual(HudTone.OFF);
      expect(find(r, 'background').value).assertEqual('continuous task not running');
    });
    it('next_without_course_has_no_relative_bearing', 0, () => {
      const s = snap();
      if (s.user !== undefined) {
        s.user.courseDeg = Number.NaN;
      }
      expect(find(rows(s), 'next').value).assertEqual('St Mary\'s Basilica · 180 m · brg 230°');
      expect(find(rows(s), 'course').tone).assertEqual(HudTone.NA);
    });
    it('off_route_lost_signal_and_voice_states', 0, () => {
      const s = snap();
      s.offRoute = true;
      s.signal = SignalQuality.LOST;
      s.voiceLabel = VoiceLabel.PRERENDERED;
      s.paused = true;
      s.nowPlaying = {
        itemId: 'a', poiId: MINI_ST_MARYS, kind: 'stopStory', sentenceIndex: 0, sentenceCount: 3, caption: 'x',
        tier: ContentTier.REVIEWED_HISTORIAN, lang: Lang.EN
      };
      const r = rows(s);
      expect(contains(find(r, 'route').value, 'OFF ROUTE')).assertTrue();
      expect(find(r, 'route').tone).assertEqual(HudTone.WARN);
      expect(find(r, 'location').tone).assertEqual(HudTone.OFF);
      expect(find(r, 'voice').value).assertEqual('Studio voice (pre-recorded) · Core Speech zh-CN/13 for other lines · paused');
      expect(find(r, 'session').value).assertEqual('AVSession active · paused');
      s.platform.ttsEngine = 'clips';
      expect(find(rows(s), 'voice').value).assertEqual('Studio voice (pre-recorded) · clips only, no TTS · paused');
      s.platform.ttsEngine = 'zh-CN/13';
      s.voiceLabel = VoiceLabel.TEXT_ONLY_USER;
      s.paused = false;
      s.speechText = true;
      expect(find(rows(s), 'voice').value).assertEqual('text only (your choice) · Core Speech zh-CN/13 · showing text');
      expect(find(rows(s), 'voice').tone).assertEqual(HudTone.OFF);
    });
    it('trigger_radii_match_the_engine', 0, () => {
      const tour = miniTour();
      tour.stops[1].triggerRadiusM = 50;      // tour stop override
      tour.stops[2].approachRadiusM = 60;     // below arrive + 30 => clamped
      const pois = miniPois();
      for (const scale of [1, 0.57, 1.43]) {
        const cfg = new TourConfig();
        cfg.triggerRadiusScale = scale;
        const st = engineStops(tour, pois, cfg);
        expect(st.stops.length).assertEqual(3);
        for (const rt of st.stops) {
          const ts = tour.stops.find(s => s.poiId === rt.poiId);
          const poi = pois.find(p => p.id === rt.poiId);
          const t = triggerRadii(ts, poi, cfg);
          expect(t === undefined).assertFalse();
          expect(t?.arriveM).assertEqual(rt.trigger.triggerRadiusM);
          expect(t?.approachM).assertEqual(rt.approachRadiusM);
        }
      }
      expect(triggerRadii(undefined, undefined, new TourConfig()) === undefined).assertTrue();
      const p = pois.find(x => x.id === MINI_BARBICAN);
      expect(triggerRadii(undefined, p, new TourConfig())?.arriveM).assertEqual(35);
      expect(triggerRadii(tour.stops[2], pois.find(x => x.id === MINI_CLOTH_HALL), new TourConfig())?.approachM)
        .assertEqual(65);
    });
  });
}

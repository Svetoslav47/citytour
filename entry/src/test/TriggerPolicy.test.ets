// Suite: TriggerPolicy.test - module under test: core/tour/TriggerPolicy (task A3).
// Cases from docs/ARCHITECTURE.md §11.1: jitter +-15 m at the radius edge => exactly one ENTER; acc = 80 m
// fixes => no ENTER; walk-through at 1.4 m/s => teaser only; stop 40 s => full; exit hysteresis.
// Plus: accuracy-aware distances, enter debounce (2 fixes >= 1.5 s, or 1 fix within R/2), streak reset,
// adaptive length off / user asked for more => full, unknown speed => full.
import { describe, it, expect } from '@ohos/hypium';
import {
  StopTrigger, TriggerSample, TriggerVerdict, StoryLength, evaluateTrigger, decideStoryLength,
  entryDistanceM, exitDistanceM
} from '../main/ets/core/tour/TriggerPolicy';
import { TourConfig, defaultTourConfig, MAX_TRIGGER_ACCURACY_M } from '../main/ets/core/tour/TourConfig';
import { median } from '../main/ets/core/geo/FixFilter';

const T0: number = 1000000;

function sample(tS: number, d: number, acc: number, speed: number): TriggerSample {
  const s: TriggerSample = {
    tMs: T0 + tS * 1000, distanceM: d, accuracyM: acc, speedMps: speed,
    triggerGrade: acc <= MAX_TRIGGER_ACCURACY_M
  };
  return s;
}

/** Deterministic pseudo-random numbers in (-1, 1) (Park-Miller, exact in doubles), so the jitter is reproducible. */
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

class Counts {
  enter: number = 0;
  exit: number = 0;
  firstEnterS: number = -1;
}

function feed(t: StopTrigger, s: TriggerSample, cfg: TourConfig, c: Counts, tS: number): TriggerVerdict {
  const v: TriggerVerdict = evaluateTrigger(t, s, cfg);
  if (v === TriggerVerdict.ENTER) {
    c.enter++;
    if (c.firstEnterS < 0) {
      c.firstEnterS = tS;
    }
  } else if (v === TriggerVerdict.EXIT) {
    c.exit++;
  }
  return v;
}

export default function triggerPolicyTest() {
  describe('TriggerPolicy', () => {
    it('accuracy_aware_distances', 0, () => {
      const cfg: TourConfig = defaultTourConfig();
      expect(entryDistanceM(50, 10, cfg)).assertEqual(40);
      expect(entryDistanceM(50, 40, cfg)).assertEqual(35);   // allowance capped at 15
      expect(entryDistanceM(5, 10, cfg)).assertEqual(0);
      expect(exitDistanceM(50, 40, cfg)).assertEqual(65);
      expect(exitDistanceM(50, Number.NaN, cfg)).assertEqual(50);
      expect(new StopTrigger('p', 35).exitRadiusM(cfg)).assertEqual(56);
    });

    it('enter_needs_two_fixes_over_1_5s_or_one_deep_fix', 0, () => {
      const cfg: TourConfig = defaultTourConfig();
      const t: StopTrigger = new StopTrigger('p', 35);
      // dEnter = 30 - 5 = 25: inside R but not within R/2
      expect(evaluateTrigger(t, sample(0, 30, 5, 1.4), cfg)).assertEqual(TriggerVerdict.NONE);
      expect(evaluateTrigger(t, sample(1, 30, 5, 1.4), cfg)).assertEqual(TriggerVerdict.NONE); // span 1 s < 1.5 s
      expect(evaluateTrigger(t, sample(2, 30, 5, 1.4), cfg)).assertEqual(TriggerVerdict.ENTER);
      expect(t.inside).assertTrue();
      expect(t.enteredAtMs).assertEqual(T0 + 2000);
      // a single deep fix (dEnter <= 17.5) enters at once
      const u: StopTrigger = new StopTrigger('q', 35);
      expect(evaluateTrigger(u, sample(0, 20, 5, 1.4), cfg)).assertEqual(TriggerVerdict.ENTER);
    });

    it('enter_streak_resets_when_a_fix_falls_outside', 0, () => {
      const cfg: TourConfig = defaultTourConfig();
      const t: StopTrigger = new StopTrigger('p', 35);
      evaluateTrigger(t, sample(0, 30, 5, 1.4), cfg);
      evaluateTrigger(t, sample(1, 60, 5, 1.4), cfg);                                          // outside: reset
      expect(evaluateTrigger(t, sample(2, 30, 5, 1.4), cfg)).assertEqual(TriggerVerdict.NONE);
      expect(evaluateTrigger(t, sample(3, 30, 5, 1.4), cfg)).assertEqual(TriggerVerdict.NONE); // span 1 s
      expect(evaluateTrigger(t, sample(4, 30, 5, 1.4), cfg)).assertEqual(TriggerVerdict.ENTER);
    });

    it('acc_80_fixes_never_enter', 0, () => {
      const cfg: TourConfig = defaultTourConfig();
      const t: StopTrigger = new StopTrigger('p', 35);
      for (let s = 0; s < 60; s++) {
        expect(evaluateTrigger(t, sample(s, 0, 80, 0), cfg)).assertEqual(TriggerVerdict.NONE);
      }
      // even if a caller wrongly marks it trigger-grade, accuracy > 40 is refused
      const bad: TriggerSample = { tMs: T0 + 61000, distanceM: 0, accuracyM: 80, speedMps: 0, triggerGrade: true };
      expect(evaluateTrigger(t, bad, cfg)).assertEqual(TriggerVerdict.NONE);
      expect(t.inside).assertFalse();
      expect(t.enterCount).assertEqual(0);
    });

    it('poor_fixes_neither_count_nor_reset', 0, () => {
      const cfg: TourConfig = defaultTourConfig();
      const t: StopTrigger = new StopTrigger('p', 35);
      evaluateTrigger(t, sample(0, 30, 5, 1.4), cfg);
      evaluateTrigger(t, sample(1, 300, 80, 1.4), cfg);   // ignored, does not reset the streak
      expect(evaluateTrigger(t, sample(2, 30, 5, 1.4), cfg)).assertEqual(TriggerVerdict.ENTER);
      // and inside, a far poor fix cannot cause an exit
      for (let s = 3; s < 10; s++) {
        expect(evaluateTrigger(t, sample(s, 500, 90, 1.4), cfg)).assertEqual(TriggerVerdict.NONE);
      }
      expect(t.inside).assertTrue();
    });

    it('jitter_15m_at_radius_edge_enters_exactly_once', 0, () => {
      // Standing at the 35 m edge, the reported distance jitters uniformly in 35 +- 15 m (acc 5 m) for 10 min.
      // Entry: dEnter = d - 5 reaches R; exit would need d + 5 > 56, i.e. d > 51, which the jitter never reaches.
      const cfg: TourConfig = defaultTourConfig();
      const t: StopTrigger = new StopTrigger('p', 35);
      const rnd: Lcg = new Lcg(20261003);
      const c: Counts = new Counts();
      for (let s = 0; s < 600; s++) {
        feed(t, sample(s, 35 + 15 * rnd.next(), 5, 0.3), cfg, c, s);
      }
      expect(c.enter).assertEqual(1);
      expect(c.exit).assertEqual(0);
      expect(c.firstEnterS).assertLess(10);
    });

    it('exit_hysteresis_needs_1_6R_for_3_fixes', 0, () => {
      const cfg: TourConfig = defaultTourConfig();
      const t: StopTrigger = new StopTrigger('p', 35);
      expect(evaluateTrigger(t, sample(0, 10, 5, 0), cfg)).assertEqual(TriggerVerdict.ENTER);
      // 50 m + 5 = 55 <= 56: still inside however long it lasts
      for (let s = 1; s <= 10; s++) {
        expect(evaluateTrigger(t, sample(s, 50, 5, 1.0), cfg)).assertEqual(TriggerVerdict.NONE);
      }
      // two fixes beyond, then one back inside: the streak resets
      expect(evaluateTrigger(t, sample(11, 60, 5, 1.0), cfg)).assertEqual(TriggerVerdict.NONE);
      expect(evaluateTrigger(t, sample(12, 60, 5, 1.0), cfg)).assertEqual(TriggerVerdict.NONE);
      expect(evaluateTrigger(t, sample(13, 40, 5, 1.0), cfg)).assertEqual(TriggerVerdict.NONE);
      expect(evaluateTrigger(t, sample(14, 60, 5, 1.0), cfg)).assertEqual(TriggerVerdict.NONE);
      expect(evaluateTrigger(t, sample(15, 60, 5, 1.0), cfg)).assertEqual(TriggerVerdict.NONE);
      expect(evaluateTrigger(t, sample(16, 60, 5, 1.0), cfg)).assertEqual(TriggerVerdict.EXIT);
      expect(t.inside).assertFalse();
      expect(t.exitCount).assertEqual(1);
    });

    it('walk_through_at_1_4mps_is_teaser_only', 0, () => {
      // Straight line through the stop at 1.4 m/s, 1 Hz; the teaser (arrival line + teaser) takes 20 s.
      const cfg: TourConfig = defaultTourConfig();
      const t: StopTrigger = new StopTrigger('p', 35);
      const c: Counts = new Counts();
      const speeds: number[] = [];
      let decision: string = '';
      for (let s = 0; s <= 180; s++) {
        const x: number = -126 + 1.4 * s;
        feed(t, sample(s, Math.abs(x), 8, 1.4), cfg, c, s);
        speeds.push(1.4);
        if (c.firstEnterS >= 0 && s === c.firstEnterS + 20) {
          decision = decideStoryLength(t, median(speeds.slice(-5)), true, false, cfg);
          expect(t.inside).assertTrue();   // still inside 1.6 R: "inside" alone must not mean "full"
        }
      }
      expect(decision).assertEqual(StoryLength.TEASER_ONLY);
      expect(c.enter).assertEqual(1);
      expect(c.exit).assertEqual(1);
      expect(t.slowDwellMs).assertEqual(0);
      // after the exit the decision stays teaser only
      expect(decideStoryLength(t, 0, true, false, cfg)).assertEqual(StoryLength.TEASER_ONLY);
    });

    it('stopping_40s_at_the_stop_is_full', 0, () => {
      const cfg: TourConfig = defaultTourConfig();
      const t: StopTrigger = new StopTrigger('p', 35);
      const c: Counts = new Counts();
      const speeds: number[] = [];
      let s: number = 0;
      for (let x = -100; x < -10; x += 1.4) {          // walk in
        feed(t, sample(s, Math.abs(x), 8, 1.4), cfg, c, s);
        speeds.push(1.4);
        s++;
      }
      for (let k = 0; k < 40; k++) {                   // stand still 40 s, 10 m from the stop
        feed(t, sample(s, 10, 8, 0.1), cfg, c, s);
        speeds.push(0.1);
        s++;
      }
      expect(c.enter).assertEqual(1);
      expect(t.slowDwellMs).assertLargerOrEqual(8000);
      expect(decideStoryLength(t, median(speeds.slice(-5)), true, false, cfg)).assertEqual(StoryLength.FULL);
      // dwell alone also proves the stop when the median is still high (e.g. a short pause between strides)
      expect(decideStoryLength(t, 1.2, true, false, cfg)).assertEqual(StoryLength.FULL);
    });

    it('length_overrides', 0, () => {
      const cfg: TourConfig = defaultTourConfig();
      const t: StopTrigger = new StopTrigger('p', 35);
      evaluateTrigger(t, sample(0, 5, 5, 1.4), cfg);
      expect(decideStoryLength(t, 1.4, true, false, cfg)).assertEqual(StoryLength.TEASER_ONLY);
      expect(decideStoryLength(t, 1.4, false, false, cfg)).assertEqual(StoryLength.FULL);  // adaptive off
      expect(decideStoryLength(t, 1.4, true, true, cfg)).assertEqual(StoryLength.FULL);    // USER_MORE
      expect(decideStoryLength(t, Number.NaN, true, false, cfg)).assertEqual(StoryLength.FULL); // speed unknown
    });
  });
}

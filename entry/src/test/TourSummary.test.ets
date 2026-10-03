// Suite: TourSummary.test - module under test: core/tour/TourSummary (task B11, Tour summary).
// Timer start/end/at-stop accounting across snapshots, real vs Demo walk (walking-pace) total time, heard vs still to
// see with the distance from the last position, complete vs ended early.
import { describe, it, expect } from '@ohos/hypium';
import {
  buildSummary, isHeard, routeWalkedM, summaryDurationS, SUMMARY_WALK_MPS, TourSummaryData, TourTimer
} from '../main/ets/core/tour/TourSummary';
import {
  EngineSnapshot, PlatformStatus, SignalQuality, StopProgress, StopStatus, TourPhase
} from '../main/ets/contracts/EngineTypes';
import { FixSource } from '../main/ets/contracts/Ports';
import { VoiceLabel } from '../main/ets/contracts/Settings';

function platform(): PlatformStatus {
  const p: PlatformStatus = {
    bgRunning: true, avsActive: true, ttsEngine: 'zh-CN/13', sourceKind: FixSource.REAL, realGpsAccuracyM: Number.NaN,
    demoHold: false
  };
  return p;
}

function stop(id: string, order: number, status: StopStatus): StopProgress {
  const p: StopProgress = { poiId: id, order: order, status: status };
  return p;
}

function snap(phase: TourPhase, stops: StopProgress[], source: FixSource): EngineSnapshot {
  const s: EngineSnapshot = {
    phase: phase, tourId: 'royal-route', stops: stops, currentStopIdx: 0,
    user: { x: 100, y: 0, lat: 50.06, lng: 19.93, accuracyM: 5, courseDeg: 0, speedMps: 1.3, source: source },
    signal: SignalQuality.GOOD, offRoute: false, paused: false, speechText: false,
    plannedOrder: stops.map((p: StopProgress) => p.poiId), walkedM: 2600, remainingM: 0, issues: [],
    voiceLabel: VoiceLabel.NATIVE, source: source, platform: platform()
  };
  return s;
}

function positions(id: string): number[] | undefined {
  if (id === 'a') {
    return [0, 0];
  }
  if (id === 'c') {
    return [100, 300];
  }
  return undefined;
}

/** Pack leg a->b is 500 m, b->c unknown (falls back to the straight line); everything else unknown. */
function legs(from: string, to: string): number {
  return from === 'a' && to === 'b' ? 500 : 0;
}

function near(a: number, b: number): boolean {
  return Math.abs(a - b) < 1e-6;
}

export default function tourSummaryTest() {
  describe('TourSummary', () => {
    it('timer_records_start_end_and_time_at_stops', 0, () => {
      const t = new TourTimer();
      expect(t.feed(snap(TourPhase.READY, [], FixSource.REAL), 0)).assertFalse();
      expect(t.feed(snap(TourPhase.WALKING, [], FixSource.REAL), 1000)).assertFalse();
      expect(t.isRunning()).assertTrue();
      t.feed(snap(TourPhase.AT_STOP, [], FixSource.REAL), 61000);   // walked 60 s
      t.feed(snap(TourPhase.AT_STOP, [], FixSource.REAL), 91000);   // +30 s at the stop
      t.feed(snap(TourPhase.WALKING, [], FixSource.REAL), 121000);  // +30 s at the stop
      expect(t.feed(snap(TourPhase.FINISHED, [], FixSource.REAL), 181000)).assertTrue();
      expect(t.startMs).assertEqual(1000);
      expect(t.endMs).assertEqual(181000);
      expect(t.atStopMs).assertEqual(60000);
      expect(t.isRunning()).assertFalse();
      // Further FINISHED snapshots don't end it again.
      expect(t.feed(snap(TourPhase.FINISHED, [], FixSource.REAL), 190000)).assertFalse();
      expect(t.endMs).assertEqual(181000);
    });
    it('timer_counts_at_stop_time_until_the_end_snapshot', 0, () => {
      const t = new TourTimer();
      t.feed(snap(TourPhase.WALKING, [], FixSource.REAL), 0);
      t.feed(snap(TourPhase.AT_STOP, [], FixSource.REAL), 10000);
      expect(t.feed(snap(TourPhase.ABORTED, [], FixSource.REAL), 25000)).assertTrue();
      expect(t.atStopMs).assertEqual(15000);
    });
    it('timer_restarts_for_a_new_tour', 0, () => {
      const t = new TourTimer();
      t.feed(snap(TourPhase.AT_STOP, [], FixSource.REAL), 0);
      t.feed(snap(TourPhase.FINISHED, [], FixSource.REAL), 5000);
      t.feed(snap(TourPhase.READY, [], FixSource.REAL), 6000);
      t.feed(snap(TourPhase.WALKING, [], FixSource.REAL), 9000);
      expect(t.startMs).assertEqual(9000);
      expect(Number.isNaN(t.endMs)).assertTrue();
      expect(t.atStopMs).assertEqual(0);
    });
    it('timer_ignores_a_tour_dropped_without_an_end_phase', 0, () => {
      const t = new TourTimer();
      t.feed(snap(TourPhase.WALKING, [], FixSource.REAL), 0);
      expect(t.feed(snap(TourPhase.IDLE, [], FixSource.REAL), 5000)).assertFalse();
      expect(Number.isNaN(t.startMs)).assertTrue();
      expect(Number.isNaN(summaryDurationS(t, 100, false))).assertTrue();
    });
    it('real_walk_total_is_elapsed_time', 0, () => {
      const t = new TourTimer();
      t.feed(snap(TourPhase.WALKING, [], FixSource.REAL), 1000);
      t.feed(snap(TourPhase.FINISHED, [], FixSource.REAL), 1000 + 84 * 60000);
      expect(summaryDurationS(t, 2600, false)).assertEqual(84 * 60);
    });
    it('demo_walk_total_is_walking_pace_plus_time_at_stops', 0, () => {
      const t = new TourTimer();
      t.feed(snap(TourPhase.WALKING, [], FixSource.DEMO), 0);
      t.feed(snap(TourPhase.AT_STOP, [], FixSource.DEMO), 20000);     // x8: 20 s real
      t.feed(snap(TourPhase.WALKING, [], FixSource.DEMO), 140000);    // listened 120 s
      t.feed(snap(TourPhase.FINISHED, [], FixSource.DEMO), 160000);
      expect(near(summaryDurationS(t, 2600, true), 2600 / SUMMARY_WALK_MPS + 120)).assertTrue();
      expect(near(summaryDurationS(t, Number.NaN, true), 120)).assertTrue();
    });
    it('heard_includes_visited_and_teasers', 0, () => {
      expect(isHeard(StopStatus.VISITED)).assertTrue();
      expect(isHeard(StopStatus.TEASER_ONLY)).assertTrue();
      expect(isHeard(StopStatus.SKIPPED)).assertFalse();
      expect(isHeard(StopStatus.PENDING)).assertFalse();
    });
    it('complete_tour_lists_every_stop_heard', 0, () => {
      const t = new TourTimer();
      const stops = [stop('a', 0, StopStatus.VISITED), stop('b', 1, StopStatus.TEASER_ONLY),
        stop('c', 2, StopStatus.VISITED)];
      t.feed(snap(TourPhase.WALKING, stops, FixSource.REAL), 0);
      t.feed(snap(TourPhase.FINISHED, stops, FixSource.REAL), 60000);
      const d: TourSummaryData = buildSummary(snap(TourPhase.FINISHED, stops, FixSource.REAL), t, positions, legs);
      expect(d.complete).assertTrue();
      expect(d.demo).assertFalse();
      expect(d.heardCount()).assertEqual(3);
      expect(d.totalStops).assertEqual(3);
      expect(d.stillToSee.length).assertEqual(0);
      expect(d.heard[1].order).assertEqual(2);
      expect(d.walkedM).assertEqual(500);           // route legs, not the engine's jittery 2600
      expect(d.durationS).assertEqual(60);
      expect(d.shown).assertFalse();
    });
    it('ended_early_lists_still_to_see_with_distance_from_here', 0, () => {
      const t = new TourTimer();
      const stops = [stop('a', 0, StopStatus.VISITED), stop('b', 1, StopStatus.SKIPPED),
        stop('c', 2, StopStatus.PENDING)];
      t.feed(snap(TourPhase.WALKING, stops, FixSource.DEMO), 0);
      t.feed(snap(TourPhase.ABORTED, stops, FixSource.DEMO), 1000);
      const d = buildSummary(snap(TourPhase.ABORTED, stops, FixSource.DEMO), t, positions, legs);
      expect(d.complete).assertFalse();
      expect(d.demo).assertTrue();
      expect(d.heardCount()).assertEqual(1);
      expect(d.stillToSee.length).assertEqual(2);
      expect(d.stillToSee[0].poiId).assertEqual('b');
      expect(Number.isNaN(d.stillToSee[0].distanceM)).assertTrue();   // no position for 'b'
      expect(d.stillToSee[1].order).assertEqual(3);
      expect(near(d.stillToSee[1].distanceM, 300)).assertTrue();      // user (100, 0) -> c (100, 300)
    });
    it('walked_is_route_length_to_the_last_stop_heard', 0, () => {
      // a -> b pack leg 500 m; b has no position, so b -> c counts 0; c -> d unheard is not walked.
      const heardAC = [stop('a', 0, StopStatus.VISITED), stop('b', 1, StopStatus.SKIPPED),
        stop('c', 2, StopStatus.VISITED), stop('d', 3, StopStatus.PENDING)];
      expect(routeWalkedM(heardAC, legs, positions)).assertEqual(500);
      // Straight-line fallback when the pack has no leg: a (0,0) -> c (100,300).
      const ac = [stop('a', 0, StopStatus.VISITED), stop('c', 1, StopStatus.TEASER_ONLY)];
      expect(near(routeWalkedM(ac, legs, positions), Math.hypot(100, 300))).assertTrue();
      // Only the first stop heard: nothing walked between stops yet.
      expect(routeWalkedM([stop('a', 0, StopStatus.VISITED), stop('b', 1, StopStatus.PENDING)], legs, positions))
        .assertEqual(0);
    });
    it('no_position_means_no_distance_and_bad_walked_is_zero', 0, () => {
      const t = new TourTimer();
      const stops = [stop('c', 0, StopStatus.PENDING)];
      const s = snap(TourPhase.ABORTED, stops, FixSource.REAL);
      s.user = undefined;
      s.walkedM = Number.NaN;
      const d = buildSummary(s, t, positions, legs);
      expect(Number.isNaN(d.stillToSee[0].distanceM)).assertTrue();
      expect(d.walkedM).assertEqual(0);             // nothing heard, nothing walked
      expect(d.heardCount()).assertEqual(0);
      expect(Number.isNaN(d.durationS)).assertTrue();   // never saw the start
    });
  });
}

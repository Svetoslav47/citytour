// Suite: Glance.test - module under test: core/watch/Glance (watch task W5, docs/research/WATCH.md).
// Arrow = bearing to the stop minus the walking course; relDir fallback without a course; "here" at the stop;
// the ring's progress count; the status line priority; which snapshots reach the glance (Done after a finished tour).
import { describe, it, expect } from '@ohos/hypium';
import {
  GlanceArrow, GlanceStatus, SnapshotUse, glanceArrow, glanceSnapshotUse, glanceStatus, glanceStopId, stopsDone
} from 'common';
import {
  AppIssue, EngineSnapshot, IssueCode, IssueSeverity, NextInfo, PlatformStatus, RelDir, SignalQuality, StopProgress,
  StopStatus, TourPhase, UserPos
} from 'common';
import { FixSource, VoiceLabel } from 'common';

function next(bearing: number, dir: RelDir, dist: number): NextInfo {
  const n: NextInfo = {
    poiId: 'p', distanceM: dist, etaS: 0, relDir: dir, bearingDeg: bearing, maneuverText: '', maneuverDistM: 0
  };
  return n;
}

function user(course: number): UserPos {
  const u: UserPos = {
    x: 0, y: 0, lat: 50.06, lng: 19.94, accuracyM: 5, courseDeg: course, speedMps: 1.3, source: FixSource.DEMO
  };
  return u;
}

function snap(phase: TourPhase, issues: AppIssue[], u: UserPos | undefined, offRoute: boolean): EngineSnapshot {
  const p: PlatformStatus = {
    bgRunning: false, avsActive: false, ttsEngine: 'none', sourceKind: FixSource.DEMO, realGpsAccuracyM: Number.NaN,
    demoHold: false
  };
  const s: EngineSnapshot = {
    phase: phase, tourId: 't', stops: [], currentStopIdx: 0, user: u, signal: SignalQuality.GOOD,
    offRoute: offRoute, paused: false, speechText: true, plannedOrder: [], walkedM: 0, remainingM: 0, issues: issues,
    voiceLabel: VoiceLabel.TEXT_ONLY_PLATFORM, source: FixSource.DEMO, platform: p
  };
  return s;
}

function issue(code: IssueCode): AppIssue {
  const i: AppIssue = { code: code, severity: IssueSeverity.WARN, detail: '' };
  return i;
}

export default function glanceTest() {
  describe('Glance', () => {
    it('arrow is the bearing to the stop relative to the walking course', 0, () => {
      const a: GlanceArrow = glanceArrow(next(90, RelDir.RIGHT, 200), user(0));
      expect(a.known).assertTrue();
      expect(a.deg).assertEqual(90);
      expect(glanceArrow(next(10, RelDir.AHEAD, 200), user(350)).deg).assertEqual(20);
      expect(glanceArrow(next(350, RelDir.AHEAD, 200), user(10)).deg).assertEqual(-20);
      expect(glanceArrow(next(180, RelDir.BEHIND, 200), user(0)).deg).assertEqual(180);
    });

    it('without a course the arrow falls back to the 8-way relDir; with nothing it is unknown', 0, () => {
      const a: GlanceArrow = glanceArrow(next(Number.NaN, RelDir.AHEAD_LEFT, 120), user(Number.NaN));
      expect(a.known).assertTrue();
      expect(a.deg).assertEqual(-45);
      expect(glanceArrow(next(Number.NaN, RelDir.AHEAD, Number.NaN), undefined).known).assertFalse();
      expect(glanceArrow(undefined, user(0)).known).assertFalse();
    });

    it('at the stop the glance says here instead of an arrow', 0, () => {
      const a: GlanceArrow = glanceArrow(next(90, RelDir.HERE, 3), user(0));
      expect(a.here).assertTrue();
      expect(a.known).assertFalse();
      // The engine also reports HERE without a usable fix (e.g. a fix 7000 km away was filtered): no "here", no arrow.
      const far: GlanceArrow = glanceArrow(next(Number.NaN, RelDir.HERE, Number.NaN), undefined);
      expect(far.here).assertFalse();
      expect(far.known).assertFalse();
    });

    it('progress counts visited, teaser-only and skipped stops', 0, () => {
      const stops: StopProgress[] = [
        { poiId: 'a', order: 0, status: StopStatus.VISITED },
        { poiId: 'b', order: 1, status: StopStatus.TEASER_ONLY },
        { poiId: 'c', order: 2, status: StopStatus.SKIPPED },
        { poiId: 'd', order: 3, status: StopStatus.APPROACHING },
        { poiId: 'e', order: 4, status: StopStatus.PENDING }
      ];
      expect(stopsDone(stops)).assertEqual(3);
      expect(stopsDone([])).assertEqual(0);
    });

    it('names the stop being visited while at a stop, the next stop otherwise', 0, () => {
      const s: EngineSnapshot = snap(TourPhase.AT_STOP, [], user(0), false);
      s.stops = [
        { poiId: 'barbican', order: 0, status: StopStatus.PENDING },
        { poiId: 'florian', order: 1, status: StopStatus.VISITED }
      ];
      s.currentStopIdx = 1;
      s.next = next(10, RelDir.AHEAD, 80);
      s.next.poiId = 'barbican';
      expect(glanceStopId(s)).assertEqual('florian');
      s.phase = TourPhase.WALKING;
      expect(glanceStopId(s)).assertEqual('barbican');
      s.next = undefined;
      expect(glanceStopId(s)).assertEqual('');
    });

    it('status line: finished, pack, permission, location off, no fix, off route, in that order', 0, () => {
      expect(glanceStatus(snap(TourPhase.FINISHED, [issue(IssueCode.PERM_DENIED)], user(0), true)))
        .assertEqual(GlanceStatus.FINISHED);
      expect(glanceStatus(snap(TourPhase.WALKING, [issue(IssueCode.PERM_DENIED), issue(IssueCode.PACK_ERR)],
        user(0), false))).assertEqual(GlanceStatus.PACK_ERROR);
      expect(glanceStatus(snap(TourPhase.WALKING, [issue(IssueCode.PERM_DENIED)], undefined, false)))
        .assertEqual(GlanceStatus.PERMISSION);
      expect(glanceStatus(snap(TourPhase.WALKING, [issue(IssueCode.LOC_SWITCH_OFF)], undefined, false)))
        .assertEqual(GlanceStatus.LOCATION_OFF);
      expect(glanceStatus(snap(TourPhase.WALKING, [], undefined, false))).assertEqual(GlanceStatus.NO_FIX);
      expect(glanceStatus(snap(TourPhase.WALKING, [issue(IssueCode.LOC_OUT_OF_AREA)], user(0), true)))
        .assertEqual(GlanceStatus.OUT_OF_AREA);
      expect(glanceStatus(snap(TourPhase.WALKING, [], user(0), true))).assertEqual(GlanceStatus.OFF_ROUTE);
      expect(glanceStatus(snap(TourPhase.WALKING, [], user(0), false))).assertEqual(GlanceStatus.NONE);
    });

    it('after Done (start screen) no snapshot reopens the glance, not even the FINISHED that ending publishes', 0, () => {
      expect(glanceSnapshotUse(false, true, TourPhase.FINISHED)).assertEqual(SnapshotUse.IGNORE);
      expect(glanceSnapshotUse(false, true, TourPhase.WALKING)).assertEqual(SnapshotUse.IGNORE);
      expect(glanceSnapshotUse(false, false, TourPhase.ABORTED)).assertEqual(SnapshotUse.IGNORE);
    });

    it('a new tour ignores the previous tour\'s end until it runs, then shows its own phases', 0, () => {
      expect(glanceSnapshotUse(true, false, TourPhase.FINISHED)).assertEqual(SnapshotUse.IGNORE);
      expect(glanceSnapshotUse(true, false, TourPhase.ABORTED)).assertEqual(SnapshotUse.IGNORE);
      expect(glanceSnapshotUse(true, false, TourPhase.PLANNING)).assertEqual(SnapshotUse.IGNORE);
      expect(glanceSnapshotUse(true, false, TourPhase.READY)).assertEqual(SnapshotUse.IGNORE);
      expect(glanceSnapshotUse(true, false, TourPhase.WALKING)).assertEqual(SnapshotUse.SHOW);
      expect(glanceSnapshotUse(true, true, TourPhase.AT_STOP)).assertEqual(SnapshotUse.SHOW);
      expect(glanceSnapshotUse(true, true, TourPhase.FINISHED)).assertEqual(SnapshotUse.SHOW);
      expect(glanceSnapshotUse(true, true, TourPhase.ABORTED)).assertEqual(SnapshotUse.ABORTED);
    });
  });
}

// Suite: CueMap.test - module under test: core/haptics/CueMap (watch task W6, docs/research/WATCH.md §5).
// The four approved cues, their patterns (left = 2 pulses, right = 3), the arrival + look sequence, the silent
// APPROACH, and the CueGate rate limit.
import { describe, it, expect } from '@ohos/hypium';
import {
  ANY_CUE_GAP_MS, ARRIVAL_MS, Cue, CueGate, SAME_CUE_GAP_MS, SEQUENCE_GAP_MS, TimedCue, cuesFor, lookCueFor,
  patternFor, patternMs, schedule
} from 'common';
import { HapticKind, RelDir } from 'common';

function pulses(c: Cue): number {
  return Math.ceil(patternFor(c).length / 2);
}

export default function cueMapTest() {
  describe('CueMap', () => {
    it('patterns: arrival one long, left 2 short, right 3 short, off-route 2 long', 0, () => {
      expect(JSON.stringify(patternFor(Cue.ARRIVAL))).assertEqual(JSON.stringify([ARRIVAL_MS]));
      expect(pulses(Cue.LOOK_LEFT)).assertEqual(2);
      expect(pulses(Cue.LOOK_RIGHT)).assertEqual(3);
      expect(pulses(Cue.OFF_ROUTE)).assertEqual(2);
      expect(patternFor(Cue.OFF_ROUTE)[0]).assertLarger(patternFor(Cue.LOOK_LEFT)[0]);
      expect(patternMs([80, 120, 80])).assertEqual(280);
    });

    it('look cue follows the stop side; ahead, behind, here and unknown give none', 0, () => {
      expect(lookCueFor(RelDir.LEFT)).assertEqual(Cue.LOOK_LEFT);
      expect(lookCueFor(RelDir.AHEAD_LEFT)).assertEqual(Cue.LOOK_LEFT);
      expect(lookCueFor(RelDir.BEHIND_LEFT)).assertEqual(Cue.LOOK_LEFT);
      expect(lookCueFor(RelDir.RIGHT)).assertEqual(Cue.LOOK_RIGHT);
      expect(lookCueFor(RelDir.AHEAD_RIGHT)).assertEqual(Cue.LOOK_RIGHT);
      expect(lookCueFor(RelDir.BEHIND_RIGHT)).assertEqual(Cue.LOOK_RIGHT);
      expect(lookCueFor(RelDir.AHEAD) === undefined).assertTrue();
      expect(lookCueFor(RelDir.BEHIND) === undefined).assertTrue();
      expect(lookCueFor(RelDir.HERE) === undefined).assertTrue();
      expect(lookCueFor(undefined) === undefined).assertTrue();
    });

    it('engine haptics map to cue sequences; approach stays silent', 0, () => {
      expect(JSON.stringify(cuesFor(HapticKind.ARRIVE, RelDir.LEFT))).assertEqual(
        JSON.stringify([Cue.ARRIVAL, Cue.LOOK_LEFT]));
      expect(JSON.stringify(cuesFor(HapticKind.ARRIVE, RelDir.AHEAD))).assertEqual(JSON.stringify([Cue.ARRIVAL]));
      expect(JSON.stringify(cuesFor(HapticKind.FINISH, RelDir.RIGHT))).assertEqual(JSON.stringify([Cue.ARRIVAL]));
      expect(JSON.stringify(cuesFor(HapticKind.OFF_ROUTE, undefined))).assertEqual(JSON.stringify([Cue.OFF_ROUTE]));
      expect(cuesFor(HapticKind.APPROACH, RelDir.LEFT).length).assertEqual(0);
    });

    it('schedule: the look cue starts after the arrival buzz plus the sequence gap', 0, () => {
      const s: TimedCue[] = schedule([Cue.ARRIVAL, Cue.LOOK_RIGHT]);
      expect(s.length).assertEqual(2);
      expect(s[0].atMs).assertEqual(0);
      expect(s[1].atMs).assertEqual(ARRIVAL_MS + SEQUENCE_GAP_MS);
      expect(s[1].pattern.length).assertEqual(5);
    });

    it('gate: no stacking, same cue at most once per window', 0, () => {
      const g: CueGate = new CueGate();
      expect(g.allow(Cue.ARRIVAL, 0)).assertTrue();
      expect(g.allow(Cue.OFF_ROUTE, ANY_CUE_GAP_MS - 1)).assertFalse();
      expect(g.allow(Cue.OFF_ROUTE, ANY_CUE_GAP_MS)).assertTrue();
      expect(g.allow(Cue.ARRIVAL, SAME_CUE_GAP_MS - 1)).assertFalse();
      expect(g.allow(Cue.ARRIVAL, SAME_CUE_GAP_MS)).assertTrue();
    });
  });
}

// Suite: WalkDisplay.test - module under test: core/map/WalkDisplay (task B5, Person B).
// Distance rounding and throttle rules of DESIGN §3.6 and the Look cue dial geometry of §3.6.1.
import { describe, it, expect } from '@ohos/hypium';
import {
  dialAngle, dialDot, dialShouldMove, relDirAngle, normalizeSigned, relativeBearing, RoundedDistance, roundWalkDistance,
  shouldUpdateDistance
} from '../main/ets/core/map/WalkDisplay';

function near(a: number, b: number): boolean {
  return Math.abs(a - b) < 1e-6;
}

export default function walkDisplayTest() {
  describe('WalkDisplay', () => {
    it('rounds_under_100m_to_10m', 0, () => {
      expect(roundWalkDistance(44).value).assertEqual(40);
      expect(roundWalkDistance(45).value).assertEqual(50);
      expect(roundWalkDistance(0).value).assertEqual(0);
      expect(roundWalkDistance(44).km).assertFalse();
    });
    it('rounds_100_to_1000m_to_20m', 0, () => {
      expect(roundWalkDistance(181).value).assertEqual(180);
      expect(roundWalkDistance(191).value).assertEqual(200);
      expect(roundWalkDistance(995).km).assertTrue();
      expect(roundWalkDistance(995).value).assertEqual(1);
    });
    it('shows_km_with_one_decimal_from_1km', 0, () => {
      const r = roundWalkDistance(1234);
      expect(r.km).assertTrue();
      expect(near(r.value, 1.2)).assertTrue();
      expect(near(roundWalkDistance(2497).value, 2.5)).assertTrue();
    });
    it('bad_input_is_zero_not_nan', 0, () => {
      expect(roundWalkDistance(Number.NaN).value).assertEqual(0);
      expect(roundWalkDistance(-5).value).assertEqual(0);
    });
    it('throttles_distance_updates', 0, () => {
      const shown: RoundedDistance = roundWalkDistance(180);
      expect(shouldUpdateDistance(undefined, shown, 0, 0)).assertTrue();
      expect(shouldUpdateDistance(shown, roundWalkDistance(178), 0, 10000)).assertFalse(); // same rounded value
      expect(shouldUpdateDistance(shown, roundWalkDistance(160), 1000, 2500)).assertFalse(); // < 2 s
      expect(shouldUpdateDistance(shown, roundWalkDistance(160), 1000, 3000)).assertTrue();
    });
    it('normalizes_and_relative_bearing', 0, () => {
      expect(normalizeSigned(190)).assertEqual(-170);
      expect(normalizeSigned(-190)).assertEqual(170);
      expect(normalizeSigned(180)).assertEqual(-180);
      expect(relativeBearing(30, 350)).assertEqual(40);
      expect(Number.isNaN(relativeBearing(30, Number.NaN))).assertTrue();
    });
    it('dial_dot_positions', 0, () => {
      const ahead = dialDot(0, 36, 36, 30, 20);
      expect(ahead.valid).assertTrue();
      expect(near(ahead.x, 36)).assertTrue();
      expect(near(ahead.y, 6)).assertTrue();
      const right = dialDot(90, 36, 36, 30, 20);
      expect(near(right.x, 66)).assertTrue();
      expect(near(right.y, 36)).assertTrue();
      const left = dialDot(-90, 36, 36, 30, 20);
      expect(near(left.x, 6)).assertTrue();
      const behind = dialDot(150, 36, 36, 30, 20);
      expect(behind.behind).assertTrue();
      expect(near(behind.y, 56)).assertTrue();
      expect(dialDot(Number.NaN, 36, 36, 30, 20).valid).assertFalse();
    });
    it('dial_angle_matches_spoken_bucket_when_slow', 0, () => {
      expect(relDirAngle('left')).assertEqual(-90);
      expect(relDirAngle('aheadRight')).assertEqual(45);
      expect(Number.isNaN(relDirAngle('here'))).assertTrue();
      expect(dialAngle(100, 80, 1.3, 'ahead')).assertEqual(20);         // walking: exact angle
      expect(dialAngle(100, 80, 0.2, 'right')).assertEqual(90);         // standing: the bucket
      expect(dialAngle(100, Number.NaN, 1.3, 'left')).assertEqual(-90); // no course: the bucket
    });
    it('dial_moves_only_on_10_degrees', 0, () => {
      expect(dialShouldMove(10, 15)).assertFalse();
      expect(dialShouldMove(10, 20)).assertTrue();
      expect(dialShouldMove(175, -175)).assertTrue();
      expect(dialShouldMove(Number.NaN, 10)).assertTrue();
    });
  });
}

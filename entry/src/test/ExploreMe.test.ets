// Suite: ExploreMe.test - module under test: core/map/ExploreMe ("you are here" on the Explore map).
import { describe, it, expect } from '@ohos/hypium';
import { centreOnFirstFix, chooseMeSource, insideBounds, LOCATE_MIN_SCALE, locateScale, MeSource } from 'common';

export default function exploreMeTest() {
  describe('ExploreMe', () => {
    it('a_running_tour_owns_the_fix', 0, () => {
      const c = chooseMeSource(true, false, false);
      expect(c.src).assertEqual(MeSource.TOUR);
      expect(c.reason).assertEqual('tour_running');
    });
    it('location_only_with_permission_and_switch', 0, () => {
      expect(chooseMeSource(false, true, true).src).assertEqual(MeSource.LOCATION);
      const noPerm = chooseMeSource(false, false, true);
      expect(noPerm.src).assertEqual(MeSource.NONE);
      expect(noPerm.reason).assertEqual('no_permission');
      const off = chooseMeSource(false, true, false);
      expect(off.src).assertEqual(MeSource.NONE);
      expect(off.reason).assertEqual('switch_off');
    });
    it('inside_bounds_checks_box_and_point', 0, () => {
      const b = [-100, -50, 100, 50];
      expect(insideBounds(b, 0, 0)).assertTrue();
      expect(insideBounds(b, 100, 50)).assertTrue();
      expect(insideBounds(b, 101, 0)).assertFalse();
      expect(insideBounds(b, 0, -51)).assertFalse();
      expect(insideBounds([], 0, 0)).assertFalse();
      expect(insideBounds(b, Number.NaN, 0)).assertFalse();
    });
    it('first_fix_centres_once_and_only_inside', 0, () => {
      const b = [0, 0, 1000, 1000];
      expect(centreOnFirstFix(false, b, 500, 500)).assertTrue();
      expect(centreOnFirstFix(true, b, 500, 500)).assertFalse();
      // Far from the city (e.g. the emulator's fixed point): keep the city view.
      expect(centreOnFirstFix(false, b, 900000, -40000)).assertFalse();
    });
    it('locate_zooms_in_but_never_out', 0, () => {
      expect(locateScale(0.2)).assertEqual(LOCATE_MIN_SCALE);
      expect(locateScale(3)).assertEqual(3);
      expect(locateScale(Number.NaN)).assertEqual(LOCATE_MIN_SCALE);
    });
  });
}

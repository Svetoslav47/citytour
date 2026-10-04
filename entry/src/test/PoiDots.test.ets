// Suite: PoiDots.test - module under test: core/map/PoiDots (task B13, Person B).
// Explore layer of the full map: level of detail by story/importance, screen-space thinning, tap hit test.
import { describe, it, expect } from '@ohos/hypium';
import { Camera } from 'common';
import { DotCandidate, dotMinScale, hitDot, NAME_ONLY_MIN_S0, NAME_ONLY_MIN_S1, PlacedDot, placeDots } from 'common';

export default function poiDotsTest() {
  describe('PoiDots', () => {
    it('stories_show_at_every_zoom_name_only_by_importance', 0, () => {
      expect(dotMinScale(0, true)).assertEqual(0);
      expect(dotMinScale(0, false)).assertEqual(NAME_ONLY_MIN_S0);
      expect(dotMinScale(1, false)).assertEqual(NAME_ONLY_MIN_S1);
      expect(dotMinScale(0.8, false) < dotMinScale(0.2, false)).assertTrue();   // important places appear first
      expect(dotMinScale(Number.NaN, false)).assertEqual(NAME_ONLY_MIN_S0);       // malformed importance
      expect(dotMinScale(5, false)).assertEqual(NAME_ONLY_MIN_S1);                // clamped
    });
    it('overview_hides_minor_name_only_places', 0, () => {
      const c = [new DotCandidate('story', 0, 0, 0.1, true), new DotCandidate('minor', 100, 0, 0.1, false)];
      const far = placeDots(c, new Camera(0, 0, 0.5), 400, 400);
      expect(far.length).assertEqual(1);
      expect(far[0].id).assertEqual('story');
      const near = placeDots(c, new Camera(0, 0, 2), 400, 400);
      expect(near.length).assertEqual(2);
    });
    it('off_screen_places_are_culled', 0, () => {
      const c = [new DotCandidate('in', 0, 0, 1, true), new DotCandidate('out', 1000, 0, 1, true)];
      const dots = placeDots(c, new Camera(0, 0, 1), 400, 400);
      expect(dots.length).assertEqual(1);
      expect(dots[0].id).assertEqual('in');
      expect(dots[0].sx).assertEqual(200);
      expect(dots[0].sy).assertEqual(200);
    });
    it('crowded_dots_are_thinned_keeping_the_story', 0, () => {
      // three places 2 m apart at 1 px/m: only one dot survives, the one with a story wins over importance
      const c = [new DotCandidate('a', 0, 0, 0.9, false), new DotCandidate('b', 2, 0, 0.1, true),
        new DotCandidate('c', 4, 0, 0.5, false)];
      const dots = placeDots(c, new Camera(0, 0, 3), 400, 400);
      expect(dots.length).assertEqual(1);
      expect(dots[0].id).assertEqual('b');
    });
    it('selected_place_is_kept_and_first', 0, () => {
      // a name-only place below its LOD scale still shows while selected, and wins a clash with a story
      const c = [new DotCandidate('a', 0, 0, 0.9, true), new DotCandidate('sel', 1, 0, 0.0, false),
        new DotCandidate('far', 200, 0, 0.9, true)];
      const dots = placeDots(c, new Camera(0, 0, 0.5), 400, 400, 'sel');
      expect(dots.length).assertEqual(2);
      expect(dots[0].id).assertEqual('sel');
      expect(dots[1].id).assertEqual('far');
    });
    it('max_dots_caps_the_frame', 0, () => {
      const c: DotCandidate[] = [];
      for (let i = 0; i < 50; i++) {
        c.push(new DotCandidate(`p${i}`, i * 20, 0, 0.5, true));
      }
      expect(placeDots(c, new Camera(500, 0, 1), 1200, 400, '', 10, 7).length).assertEqual(7);
    });
    it('hit_test_picks_the_nearest_within_radius', 0, () => {
      const dots = [new PlacedDot('a', 100, 100, true), new PlacedDot('b', 120, 100, true)];
      expect(hitDot(dots, 112, 100)).assertEqual('b');
      expect(hitDot(dots, 100, 90)).assertEqual('a');
      expect(hitDot(dots, 300, 300)).assertEqual('');
      expect(hitDot([], 0, 0)).assertEqual('');
    });
  });
}

// Suite: MapCamera.test - module under test: core/map/Camera (task B6, Person B).
// North-up camera of ARCHITECTURE §3.2: world <-> screen, fit, pan, zoom about a point, culling, hit test.
import { describe, it, expect } from '@ohos/hypium';
import {
  boundsOf, Camera, clampScale, fitBounds, hitTest, intersects, pan, S_MAX, S_MIN, screenToWorld, viewport,
  worldToScreen, zoomAt
} from '../main/ets/core/map/Camera';

function near(a: number, b: number, eps: number = 1e-6): boolean {
  return Math.abs(a - b) < eps;
}

export default function mapCameraTest() {
  describe('MapCamera', () => {
    it('world_to_screen_is_north_up', 0, () => {
      const cam = new Camera(100, 200, 2);
      const c = worldToScreen(cam, 100, 200, 400, 300);
      expect(near(c.x, 200) && near(c.y, 150)).assertTrue();       // centre maps to the middle
      const north = worldToScreen(cam, 100, 210, 400, 300);
      expect(near(north.y, 130)).assertTrue();                       // +10 m north = 20 px up
      const east = worldToScreen(cam, 110, 200, 400, 300);
      expect(near(east.x, 220)).assertTrue();
    });
    it('screen_to_world_inverts', 0, () => {
      const cam = new Camera(-35.5, 812.25, 3.3);
      const s = worldToScreen(cam, 12.5, -40, 390, 320);
      const w = screenToWorld(cam, s.x, s.y, 390, 320);
      expect(near(w.x, 12.5) && near(w.y, -40)).assertTrue();
    });
    it('scale_is_clamped', 0, () => {
      expect(clampScale(100)).assertEqual(S_MAX);
      expect(clampScale(0.001)).assertEqual(S_MIN);
      expect(clampScale(Number.NaN)).assertEqual(1);
    });
    it('fit_bounds_contains_the_box', 0, () => {
      const cam = fitBounds([-100, -200, 300, 600], 400, 400, 20);
      const a = worldToScreen(cam, -100, 600, 400, 400);
      const b = worldToScreen(cam, 300, -200, 400, 400);
      expect(a.x >= 19.99 && a.y >= 19.99 && b.x <= 380.01 && b.y <= 380.01).assertTrue();
      expect(near(cam.s, 0.45)).assertTrue();                        // 360 / 800 m
    });
    it('fit_bounds_respects_insets', 0, () => {
      const cam = fitBounds([0, 0, 100, 100], 300, 400, 10, 60, 40);
      const top = worldToScreen(cam, 50, 100, 300, 400);
      const bottom = worldToScreen(cam, 50, 0, 300, 400);
      expect(top.y >= 69.99).assertTrue();                           // below pad + topInset
      expect(bottom.y <= 350.01).assertTrue();                       // above pad + bottomInset
    });
    it('pan_follows_the_finger', 0, () => {
      const cam = new Camera(0, 0, 2);
      const before = worldToScreen(cam, 50, 50, 300, 300);
      const moved = pan(cam, 30, -10);
      const after = worldToScreen(moved, 50, 50, 300, 300);
      expect(near(after.x - before.x, 30) && near(after.y - before.y, -10)).assertTrue();
    });
    it('zoom_keeps_the_focus_point_fixed', 0, () => {
      const cam = new Camera(10, 20, 1);
      const z = zoomAt(cam, 2, 80, 60, 300, 200);
      const w1 = screenToWorld(cam, 80, 60, 300, 200);
      const w2 = screenToWorld(z, 80, 60, 300, 200);
      expect(near(z.s, 2) && near(w1.x, w2.x) && near(w1.y, w2.y)).assertTrue();
    });
    it('viewport_and_culling', 0, () => {
      const vp = viewport(new Camera(0, 0, 1), 200, 100);
      expect(vp.join(',')).assertEqual('-100,-50,100,50');
      expect(intersects(vp, [90, 40, 120, 60])).assertTrue();
      expect(intersects(vp, [101, 0, 120, 10])).assertFalse();
    });
    it('bounds_of_flat_arrays', 0, () => {
      expect((boundsOf([[1, 2, 5, -3], [0, 9]]) as number[]).join(',')).assertEqual('0,-3,5,9');
      expect(boundsOf([[]]) === undefined).assertTrue();
    });
    it('hit_test_finds_nearest_within_radius', 0, () => {
      const cam = new Camera(0, 0, 1);
      const pts = [0, 0, 30, 0, 100, 100];
      expect(hitTest(cam, 160, 100, 300, 200, pts, 24)).assertEqual(0);    // (150,100) is world (0,0)
      expect(hitTest(cam, 178, 100, 300, 200, pts, 24)).assertEqual(1);
      expect(hitTest(cam, 10, 10, 300, 200, pts, 24)).assertEqual(-1);
    });
  });
}

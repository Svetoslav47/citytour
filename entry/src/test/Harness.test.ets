// Suite: Harness.test - sanity checks for the test harness itself (task T1).
// Proves that Hypium runs and that assertions are evaluated; scripts/test.sh requires Tests run > 0.
import { describe, it, expect } from '@ohos/hypium';

export default function harnessTest() {
  describe('Harness', () => {
    it('runs_and_asserts', 0, () => {
      expect(1 + 1).assertEqual(2);
    });
    it('compares_numbers', 0, () => {
      expect(3).assertLarger(2);
      expect('CityTour').assertContain('Tour');
    });
  });
}

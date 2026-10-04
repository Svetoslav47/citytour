// Suite: SvgPath.test - module under test: core/map/SvgPath (one SVG path string per map layer, built once and
// handed to Path2D in a single call). Cases: a line, a polygon with two rings, empty and malformed features.
import { describe, it, expect } from '@ohos/hypium';
import { MapLayer } from 'common';
import { svgPathOf } from 'common';

function layer(geom: string, featuresJson: string): MapLayer {
  return JSON.parse(`{"id":"l","geom":"${geom}","minScale":0,"features":${featuresJson}}`) as MapLayer;
}

export default function svgPathTest() {
  describe('SvgPath', () => {
    it('line_in_metres', 0, () => {
      expect(svgPathOf(layer('line', '[{"c":[10,20,30,45],"bb":[]}]'))).assertEqual('M1 2L3 4.5');
    });
    it('polygon_rings_closed', 0, () => {
      const p = svgPathOf(layer('polygon', '[{"c":[0,0,10,0,10,10,20,20,30,20,30,30],"rings":[0,6],"bb":[]}]'));
      expect(p).assertEqual('M0 0L1 0L1 1ZM2 2L3 2L3 3Z');
    });
    it('empty_and_malformed', 0, () => {
      expect(svgPathOf(layer('line', '[]'))).assertEqual('');
      expect(svgPathOf(layer('line', '[{"c":[5],"bb":[]}]'))).assertEqual('');
    });
  });
}

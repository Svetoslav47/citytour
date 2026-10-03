/*
 * One SVG path string per map layer ("M x y L x y … Z"), handed to `new Path2D(svg)` in a single native call.
 * Building Path2Ds with one moveTo/lineTo bridge call per point took > 6 s for the city map on the emulator and the
 * system killed the app (THREAD_BLOCK_6S in MapRenderer.buildPath). Pure: no @kit imports.
 */
import { MapLayer } from '../../contracts/Model';

/** Pack geometry is in decimetres; paths are in metres, one decimal is enough for a city map. */
const DM: number = 10;

/** `rings` are start offsets into `c` (flat index, even); one ring when absent. */
export function svgPathOf(l: MapLayer): string {
  const polygon = l.geom === 'polygon';
  const parts: string[] = [];
  for (const f of l.features) {
    const c = f.c;
    const starts: number[] = f.rings !== undefined && f.rings !== null && f.rings.length > 0 ? f.rings : [0];
    for (let r = 0; r < starts.length; r++) {
      const from = starts[r];
      const to = r + 1 < starts.length ? starts[r + 1] : c.length;
      if (from < 0 || from + 1 >= c.length) {
        continue;
      }
      parts.push(`M${c[from] / DM} ${c[from + 1] / DM}`);
      for (let i = from + 2; i + 1 < to; i += 2) {
        parts.push(`L${c[i] / DM} ${c[i + 1] / DM}`);
      }
      if (polygon) {
        parts.push('Z');
      }
    }
  }
  return parts.join('');
}

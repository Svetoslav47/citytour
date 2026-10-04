/*
 * One SVG path string per map layer ("M x y L x y … Z"), handed to `new Path2D(svg)` in a single native call.
 * Building Path2Ds with one moveTo/lineTo bridge call per point took > 6 s for the city map on the emulator and the
 * system killed the app (THREAD_BLOCK_6S in MapRenderer.buildPath). Pure: no @kit imports.
 */
import { MapLayer } from '../../contracts/Model';

/** Pack geometry is in decimetres; paths are in metres, one decimal is enough for a city map. */
const DM: number = 10;

/** Points per path string: Path2D(svg) silently drops the tail of very long strings (a 290k-char buildings layer
 * drew only partly on the emulator), so a layer is split into chunks of whole features. */
export const MAX_POINTS_PER_PATH: number = 1000;

/** The whole layer as one string (tests, small layers). */
export function svgPathOf(l: MapLayer): string {
  return svgPathsOf(l, Number.MAX_SAFE_INTEGER).join('');
}

/** The layer as several path strings of at most ~maxPoints points each (features are never split). */
export function svgPathsOf(l: MapLayer, maxPoints: number = MAX_POINTS_PER_PATH): string[] {
  const polygon = l.geom === 'polygon';
  const out: string[] = [];
  let parts: string[] = [];
  let points = 0;
  for (const f of l.features) {
    if (points >= maxPoints && parts.length > 0) {
      out.push(parts.join(''));
      parts = [];
      points = 0;
    }
    const c = f.c;
    const starts: number[] = f.rings !== undefined && f.rings !== null && f.rings.length > 0 ? f.rings : [0];
    for (let r = 0; r < starts.length; r++) {
      const from = starts[r];
      const to = r + 1 < starts.length ? starts[r + 1] : c.length;
      if (from < 0 || from + 1 >= c.length) {
        continue;
      }
      parts.push(`M${c[from] / DM} ${c[from + 1] / DM}`);
      points++;
      for (let i = from + 2; i + 1 < to; i += 2) {
        parts.push(`L${c[i] / DM} ${c[i + 1] / DM}`);
        points++;
      }
      if (polygon) {
        parts.push('Z');
      }
    }
  }
  if (parts.length > 0) {
    out.push(parts.join(''));
  }
  return out;
}

/*
 * Schematic route preview for Home, Tour detail and Route ready until the native Canvas map (task B6) lands:
 * the stops (projected metres from the pack) joined in walking order on the map land colour, north up,
 * fitted to the box. No base map is drawn, so no map attribution is needed here.
 */
import { Plaque, PlaqueState } from './Plaque';

export class PreviewPoint {
  x: number;   // projected metres east of the pack origin
  y: number;   // projected metres north of the pack origin
  n: number;   // plaque number

  constructor(x: number, y: number, n: number) {
    this.x = x;
    this.y = y;
    this.n = n;
  }
}

class ScreenPoint {
  x: number = 0;
  y: number = 0;
  n: number = 0;
}

const PAD: number = 28;

@ComponentV2
export struct RoutePreview {
  @Param points: PreviewPoint[] = [];
  /** Fixed height in vp; the width follows the parent. */
  @Param boxHeight: number = 260;
  /** Space reserved at the top for floating header controls, so no plaque hides under them. */
  @Param topInset: number = 0;
  /** Space reserved at the bottom (e.g. a panel overlapping the map). */
  @Param bottomInset: number = 0;
  /** Plaques bigger than this many are drawn as small dots to keep the preview readable. */
  @Param maxPlaques: number = 11;
  /** Optional plaque state per point (same order); default: first = next, others upcoming. */
  @Param states: PlaqueState[] = [];
  /** Optional user position (projected metres); drawn as the blue dot, hollow when simulated. */
  @Param user: PreviewPoint | undefined = undefined;
  @Param userSimulated: boolean = false;
  @Local boxWidth: number = 0;

  private project(): ScreenPoint[] {
    return this.projectWith(this.points);
  }

  /** The user dot in the same transform as the stops (undefined when off-screen or unknown). */
  private projectUser(): ScreenPoint | undefined {
    if (this.user === undefined || this.points.length === 0) {
      return undefined;
    }
    return this.projectWith2(this.points, this.user);
  }

  private projectWith2(stops: PreviewPoint[], extra: PreviewPoint): ScreenPoint | undefined {
    const pts = this.projectWith(stops.concat([extra]), stops.length);
    if (pts.length !== stops.length + 1) {
      return undefined;
    }
    const u = pts[pts.length - 1];
    if (u.x < 0 || u.y < 0 || u.x > this.boxWidth || u.y > this.boxHeight) {
      return undefined;
    }
    return u;
  }

  /** Fits the first `fitCount` points (default: all) into the box and projects every point with that transform. */
  private projectWith(source: PreviewPoint[], fitCount: number = -1): ScreenPoint[] {
    const out: ScreenPoint[] = [];
    const n = fitCount < 0 ? source.length : fitCount;
    if (n === 0 || this.boxWidth <= 0) {
      return out;
    }
    let minX = Number.POSITIVE_INFINITY;
    let maxX = Number.NEGATIVE_INFINITY;
    let minY = Number.POSITIVE_INFINITY;
    let maxY = Number.NEGATIVE_INFINITY;
    for (let i = 0; i < n; i++) {
      const p = source[i];
      minX = Math.min(minX, p.x);
      maxX = Math.max(maxX, p.x);
      minY = Math.min(minY, p.y);
      maxY = Math.max(maxY, p.y);
    }
    const spanX = Math.max(1, maxX - minX);
    const spanY = Math.max(1, maxY - minY);
    const usableH = Math.max(1, this.boxHeight - this.topInset - this.bottomInset);
    const scale = Math.min((this.boxWidth - 2 * PAD) / spanX, (usableH - 2 * PAD) / spanY);
    const offX = (this.boxWidth - spanX * scale) / 2;
    const offY = this.topInset + (usableH - spanY * scale) / 2;
    for (const p of source) {
      const s = new ScreenPoint();
      s.x = offX + (p.x - minX) * scale;
      s.y = offY + (maxY - p.y) * scale;   // north up
      s.n = p.n;
      out.push(s);
    }
    return out;
  }

  private stateAt(idx: number): PlaqueState {
    if (idx < this.states.length) {
      return this.states[idx];
    }
    return idx === 0 ? PlaqueState.NEXT : PlaqueState.UPCOMING;
  }

  private halfSize(idx: number): number {
    const st = this.stateAt(idx);
    if (st === PlaqueState.NEXT || st === PlaqueState.CURRENT) {
      return 17;
    }
    return st === PlaqueState.VISITED || st === PlaqueState.SKIPPED ? 12 : 14;
  }

  private polyline(pts: ScreenPoint[]): number[][] {
    return pts.map((p: ScreenPoint) => [p.x, p.y]);
  }

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      if (this.boxWidth > 0 && this.points.length > 1) {
        Polyline()
          .points(this.polyline(this.project()))
          .width(this.boxWidth)
          .height(this.boxHeight)
          .fillOpacity(0)
          .stroke($r('app.color.accent'))
          .strokeWidth(4)
          .strokeLineJoin(LineJoinStyle.Round)
          .strokeLineCap(LineCapStyle.Round)
      }
      ForEach(this.project(), (p: ScreenPoint, idx: number) => {
        if (this.points.length <= this.maxPlaques) {
          Plaque({ n: p.n, state: this.stateAt(idx) })
            .position({ x: p.x - this.halfSize(idx), y: p.y - this.halfSize(idx) })
        } else {
          Column()
            .width(8)
            .height(8)
            .borderRadius(4)
            .backgroundColor($r('app.color.accent'))
            .position({ x: p.x - 4, y: p.y - 4 })
        }
      }, (p: ScreenPoint) => `${p.n}:${Math.round(p.x)}:${Math.round(p.y)}`)
      if (this.projectUser() !== undefined) {
        Column()
          .width(14)
          .height(14)
          .borderRadius(7)
          .backgroundColor(this.userSimulated ? Color.Transparent : $r('app.color.map_user'))
          .border({ width: 3, color: this.userSimulated ? $r('app.color.map_user') : Color.White })
          .shadow(ShadowStyle.OUTER_DEFAULT_XS)
          .position({ x: (this.projectUser() as ScreenPoint).x - 7, y: (this.projectUser() as ScreenPoint).y - 7 })
          .accessibilityText(this.userSimulated ? $r('app.string.label_simulated_a11y') : $r('app.string.map_you'))
      }
    }
    .width('100%')
    .height(this.boxHeight)
    .clip(true)
    .backgroundColor($r('app.color.map_land'))
    .onAreaChange((oldArea: Area, newArea: Area) => {
      this.boxWidth = newArea.width as number;
    })
  }
}

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
  /** Plaques bigger than this many are drawn as small dots to keep the preview readable. */
  @Param maxPlaques: number = 11;
  @Local boxWidth: number = 0;

  private project(): ScreenPoint[] {
    const out: ScreenPoint[] = [];
    if (this.points.length === 0 || this.boxWidth <= 0) {
      return out;
    }
    let minX = Number.POSITIVE_INFINITY;
    let maxX = Number.NEGATIVE_INFINITY;
    let minY = Number.POSITIVE_INFINITY;
    let maxY = Number.NEGATIVE_INFINITY;
    for (const p of this.points) {
      minX = Math.min(minX, p.x);
      maxX = Math.max(maxX, p.x);
      minY = Math.min(minY, p.y);
      maxY = Math.max(maxY, p.y);
    }
    const spanX = Math.max(1, maxX - minX);
    const spanY = Math.max(1, maxY - minY);
    const scale = Math.min((this.boxWidth - 2 * PAD) / spanX, (this.boxHeight - 2 * PAD) / spanY);
    const offX = (this.boxWidth - spanX * scale) / 2;
    const offY = (this.boxHeight - spanY * scale) / 2;
    for (const p of this.points) {
      const s = new ScreenPoint();
      s.x = offX + (p.x - minX) * scale;
      s.y = offY + (maxY - p.y) * scale;   // north up
      s.n = p.n;
      out.push(s);
    }
    return out;
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
          Plaque({ n: p.n, state: idx === 0 ? PlaqueState.NEXT : PlaqueState.UPCOMING })
            .position({ x: p.x - (idx === 0 ? 17 : 14), y: p.y - (idx === 0 ? 17 : 14) })
        } else {
          Column()
            .width(8)
            .height(8)
            .borderRadius(4)
            .backgroundColor($r('app.color.accent'))
            .position({ x: p.x - 4, y: p.y - 4 })
        }
      }, (p: ScreenPoint) => `${p.n}:${Math.round(p.x)}:${Math.round(p.y)}`)
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

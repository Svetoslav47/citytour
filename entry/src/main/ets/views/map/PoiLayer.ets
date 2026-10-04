/*
 * Explore layer of the full map (B13, DESIGN §3.7): every place in the pack as a neutral dot, culled to the
 * viewport with GridIndex (A1) and thinned by PoiDots (stories from the overview zoom, name-only places as you
 * zoom in). Drawn by MapRenderer between the route and the stop plaques; MapCanvas asks it for tap hits.
 * Built once per POI list (4k places) and shared, like the base map paths.
 */
import { ContentTier, Poi } from 'common';
import { GridIndex } from 'common';
import { Camera, viewport } from 'common';
import { DOT_SEP_PX, DotCandidate, hitDot, PlacedDot, placeDots } from 'common';
import { MapPalette } from './MapStyle';

export class PoiLayer {
  /** Selected place id ('' = none): drawn as an accent ring, kept through thinning. */
  selectedId: string = '';
  private grid: GridIndex<DotCandidate> = new GridIndex<DotCandidate>();
  private placed: PlacedDot[] = [];
  private static shared: PoiLayer | undefined = undefined;
  private static sharedSource: Poi[] | undefined = undefined;

  /** The layer for this POI list; rebuilt only when the pack's list object changes (course switch). */
  static of(pois: Poi[]): PoiLayer {
    if (PoiLayer.shared === undefined || PoiLayer.sharedSource !== pois) {
      const l = new PoiLayer();
      for (const p of pois) {
        l.grid.add(new DotCandidate(p.id, p.x, p.y, p.importance, p.tier !== ContentTier.NAME_ONLY), p.x, p.y);
      }
      PoiLayer.shared = l;
      PoiLayer.sharedSource = pois;
    }
    const layer = PoiLayer.shared as PoiLayer;
    layer.selectedId = '';
    return layer;
  }

  size(): number {
    return this.grid.size();
  }

  /** Dots drawn by the last frame. */
  shown(): number {
    return this.placed.length;
  }

  draw(ctx: CanvasRenderingContext2D, w: number, h: number, cam: Camera, pal: MapPalette): void {
    const vp = viewport(cam, w, h);
    const padM = DOT_SEP_PX / cam.s;
    const cands = this.grid.inRect(vp[0] - padM, vp[1] - padM, vp[2] + padM, vp[3] + padM);
    this.placed = placeDots(cands, cam, w, h, this.selectedId);
    // Back to front: the first placed dot ranks highest (selected, stories), so draw it last.
    for (let i = this.placed.length - 1; i >= 0; i--) {
      const d = this.placed[i];
      if (d.id === this.selectedId) {
        ctx.beginPath();
        ctx.arc(d.sx, d.sy, 9, 0, Math.PI * 2);
        ctx.fillStyle = pal.accent;
        ctx.fill();
        ctx.lineWidth = 3;
        ctx.strokeStyle = pal.surface;
        ctx.stroke();
        continue;
      }
      ctx.beginPath();
      ctx.arc(d.sx, d.sy, d.story ? 4.5 : 3, 0, Math.PI * 2);
      ctx.globalAlpha = d.story ? 1 : 0.7;
      ctx.fillStyle = pal.tertiary;
      ctx.fill();
      ctx.lineWidth = d.story ? 1.5 : 1;
      ctx.strokeStyle = pal.surface;
      ctx.stroke();
      ctx.globalAlpha = 1;
    }
  }

  /** Place id under a tap at (sx, sy) on the last frame, or ''. */
  hit(sx: number, sy: number): string {
    return hitDot(this.placed, sx, sy);
  }
}

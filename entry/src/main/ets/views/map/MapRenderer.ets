/*
 * Draws the offline map on an ArkUI Canvas (ARCHITECTURE §3.2): one Path2D per pack layer, built once in world
 * metres (pack geometry is decimetre ints in the Projection frame), then per frame one setTransform for the
 * camera, layers bottom to top, the route, and screen-space overlays (explore dots, plaques, user). During a gesture
 * (`fast`) only water, green, major streets and the overlays are drawn. Returns the frame time in ms
 * (logged as MAP_FRAME by MapCanvas). Canvas: doc ts-components-canvas-canvas (CanvasRenderingContext2D, Path2D).
 */
import { MapData, MapFeature, MapLayer } from '../../contracts/Model';
import { Camera } from '../../core/map/Camera';
import { Log } from '../../app/Log';
import { PlaqueState } from '../common/Plaque';
import { defaultMinScale, LineWidth, MapPalette } from './MapStyle';
import { PoiLayer } from './PoiLayer';

export class StopMark {
  x: number;
  y: number;
  n: number;
  state: PlaqueState;
  name: string;

  constructor(x: number, y: number, n: number, state: PlaqueState, name: string) {
    this.x = x;
    this.y = y;
    this.n = n;
    this.state = state;
    this.name = name;
  }
}

export class UserMark {
  x: number = 0;
  y: number = 0;
  accuracyM: number = Number.NaN;
  courseDeg: number = Number.NaN;   // NaN = unknown: no cone
  simulated: boolean = false;
}

export class MapOverlay {
  /** Route legs in walking order, flat world metres [x0, y0, x1, y1, ...]. */
  legs: number[][] = [];
  /** Legs before this index are walked (grey), this one is next (accent + casing), later ones 45 % accent. */
  nextLegIdx: number = 0;
  /** Previews: draw every leg in the "next" style. */
  allActive: boolean = false;
  stops: StopMark[] = [];
  user: UserMark | undefined = undefined;
  labels: boolean = false;
}

class LayerPath {
  id: string;
  polygon: boolean;
  minScale: number;
  path: Path2D;

  constructor(id: string, polygon: boolean, minScale: number, path: Path2D) {
    this.id = id;
    this.polygon = polygon;
    this.minScale = minScale;
    this.path = path;
  }
}


function clampPx(metres: number, s: number, minPx: number, maxPx: number): number {
  return Math.max(minPx, Math.min(maxPx, metres * s));
}

const MAP_FRAME: string = 'MAP_FRAME';

/** Pack geometry: decimetres. */
const DM: number = 10;
/** UI-thread budget per slice while building paths; the rest continues on the next macrotask. */
const SLICE_MS: number = 8;

/**
 * The Path2Ds of one map, built incrementally: a slice of features at a time (moveTo/lineTo, one bridge call per
 * point), yielding to the UI thread between slices. A one-shot build took > 6 s on the emulator and the system killed
 * the app (THREAD_BLOCK_6S); the SVG-string constructor (Path2D(d)) was fast but drew the base map only partly.
 * Layers become visible one by one as they finish; every MapCanvas showing this map is notified.
 */
class PathBuild {
  layers: LayerPath[] = [];
  done: boolean = false;
  private listeners: Set<() => void> = new Set<() => void>();

  listen(f: () => void): void {
    this.listeners.add(f);
  }

  unlisten(f: () => void): void {
    this.listeners.delete(f);
  }

  start(data: MapData): void {
    const t0 = Date.now();
    let li = 0;
    let fi = 0;
    let path: Path2D = new Path2D();
    const step = (): void => {
      const sliceStart = Date.now();
      try {
        while (li < data.layers.length) {
          const l: MapLayer = data.layers[li];
          const polygon = l.geom === 'polygon';
          while (fi < l.features.length) {
            addFeature(path, l.features[fi], polygon);
            fi++;
            if ((fi & 63) === 0 && Date.now() - sliceStart > SLICE_MS) {
              setTimeout(step, 0);
              return;
            }
          }
          this.layers.push(new LayerPath(l.id, polygon, l.minScale > 0 ? l.minScale : defaultMinScale(l.id), path));
          this.notify();
          li++;
          fi = 0;
          path = new Path2D();
        }
      } catch (e) {
        Log.e(MAP_FRAME, `event=paths_fail layer=${li} ${Log.errKv(e as Object)}`);
      }
      this.done = true;
      Log.i(MAP_FRAME, `event=paths_built layers=${this.layers.length} ms=${Date.now() - t0}`);
      this.notify();
    };
    step();
  }

  private notify(): void {
    this.listeners.forEach((f: () => void) => {
      try {
        f();
      } catch (e) {
        // a disappeared canvas: ignore
      }
    });
  }
}

/** `rings` are start offsets into `c` (flat index, even); one ring when absent. */
function addFeature(p: Path2D, f: MapFeature, polygon: boolean): void {
  const c = f.c;
  const starts: number[] = f.rings !== undefined && f.rings !== null && f.rings.length > 0 ? f.rings : [0];
  for (let r = 0; r < starts.length; r++) {
    const from = starts[r];
    const to = r + 1 < starts.length ? starts[r + 1] : c.length;
    if (from < 0 || from + 1 >= c.length) {
      continue;
    }
    p.moveTo(c[from] / DM, c[from + 1] / DM);
    for (let i = from + 2; i + 1 < to; i += 2) {
      p.lineTo(c[i] / DM, c[i + 1] / DM);
    }
    if (polygon) {
      p.closePath();
    }
  }
}

export class MapRenderer {
  private build: PathBuild | undefined = undefined;
  private source: MapData | undefined = undefined;
  private onUpdate: (() => void) | undefined = undefined;
  /** Path builds per MapData object (a few maps per session: the city map, a course's own map). */
  private static builds: Map<MapData, PathBuild> = new Map<MapData, PathBuild>();

  private get layers(): LayerPath[] {
    return this.build !== undefined ? this.build.layers : [];
  }

  /** Starts (or joins) the incremental path build for this map; `onUpdate` fires as layers become ready. */
  setMap(data: MapData | undefined, onUpdate?: () => void): void {
    if (data === this.source) {
      return;
    }
    if (this.build !== undefined && this.onUpdate !== undefined) {
      this.build.unlisten(this.onUpdate);
    }
    this.source = data;
    this.build = undefined;
    this.onUpdate = onUpdate;
    if (data === undefined) {
      return;
    }
    let b = MapRenderer.builds.get(data);
    if (b === undefined) {
      if (MapRenderer.builds.size >= 4) {
        MapRenderer.builds.clear();
      }
      b = new PathBuild();
      MapRenderer.builds.set(data, b);
      if (onUpdate !== undefined) {
        b.listen(onUpdate);
      }
      this.build = b;
      b.start(data);
      return;
    }
    if (onUpdate !== undefined && !b.done) {
      b.listen(onUpdate);
    }
    this.build = b;
  }

  /** Stop notifying this renderer's canvas (the canvas is going away). */
  release(): void {
    if (this.build !== undefined && this.onUpdate !== undefined) {
      this.build.unlisten(this.onUpdate);
    }
    this.onUpdate = undefined;
  }

  hasBase(): boolean {
    return this.layers.length > 0;
  }

  layerCount(): number {
    return this.layers.length;
  }

  /** `transparentLand`: clear instead of painting the land, so a base image under the canvas shows through. */
  draw(ctx: CanvasRenderingContext2D, w: number, h: number, cam: Camera, ov: MapOverlay, pal: MapPalette,
    fast: boolean, transparentLand: boolean = false, places: PoiLayer | undefined = undefined,
    lodScale: number = 1): number {
    const t0 = Date.now();
    const s = cam.s;
    ctx.resetTransform();
    ctx.setLineDash([]);
    ctx.globalAlpha = 1;
    if (transparentLand) {
      ctx.clearRect(0, 0, w, h);
    } else {
      ctx.fillStyle = pal.land;
      ctx.fillRect(0, 0, w, h);
    }

    // World transform: x east, y north (flipped), metres -> vp.
    ctx.setTransform(s, 0, 0, -s, w / 2 - cam.cx * s, h / 2 + cam.cy * s);
    ctx.lineJoin = 'round';
    ctx.lineCap = 'round';
    for (const l of this.layers) {
      // lodScale < 1 (static previews, e.g. Tour detail's Route card) shows the street layers further out.
      if (s < l.minScale * lodScale) {
        continue;
      }
      if (fast && !(l.id === 'water' || l.id === 'river' || l.id === 'green' || l.id === 'major')) {
        continue;
      }
      this.drawLayer(ctx, l, s, pal);
    }
    this.drawRoute(ctx, ov, s, pal);

    ctx.resetTransform();
    ctx.setLineDash([]);
    if (places !== undefined) {
      places.draw(ctx, w, h, cam, pal);   // B13 explore layer: under the stop plaques and the user
    }
    this.drawStops(ctx, w, h, cam, ov, pal);
    if (ov.user !== undefined) {
      this.drawUser(ctx, w, h, cam, ov.user, pal);
    }
    return Date.now() - t0;
  }

  private drawLayer(ctx: CanvasRenderingContext2D, l: LayerPath, s: number, pal: MapPalette): void {
    switch (l.id) {
      case 'water':
        ctx.fillStyle = pal.water;
        ctx.fill(l.path);
        return;
      case 'river':
        ctx.strokeStyle = pal.water;
        ctx.lineWidth = Math.max(4, LineWidth.RIVER_M * s) / s;
        ctx.stroke(l.path);
        return;
      case 'green':
        ctx.fillStyle = pal.green;
        ctx.fill(l.path);
        return;
      case 'buildings':
        ctx.fillStyle = pal.buildings;
        ctx.fill(l.path);
        if (s > 1.5) {
          ctx.strokeStyle = pal.buildingStroke;
          ctx.lineWidth = 1 / s;
          ctx.stroke(l.path);
        }
        return;
      case 'unesco':
        ctx.strokeStyle = pal.unesco;
        ctx.lineWidth = 1 / s;
        ctx.setLineDash([6 / s, 4 / s]);
        ctx.stroke(l.path);
        ctx.setLineDash([]);
        return;
      case 'paths':
        ctx.strokeStyle = pal.path;
        ctx.lineWidth = clampPx(LineWidth.PATH_M, s, LineWidth.PATH_MIN_PX, LineWidth.PATH_MAX_PX) / s;
        ctx.stroke(l.path);
        return;
      case 'minor':
        ctx.strokeStyle = pal.minorStreet;
        ctx.lineWidth = clampPx(LineWidth.MINOR_M, s, LineWidth.MINOR_MIN_PX, LineWidth.MINOR_MAX_PX) / s;
        ctx.stroke(l.path);
        return;
      case 'major':
        ctx.strokeStyle = pal.majorStreet;
        ctx.lineWidth = clampPx(LineWidth.MAJOR_M, s, LineWidth.MAJOR_MIN_PX, LineWidth.MAJOR_MAX_PX) / s;
        ctx.stroke(l.path);
        return;
      default:
        return;
    }
  }

  private legPath(flat: number[]): Path2D {
    const p = new Path2D();
    if (flat.length >= 4) {
      p.moveTo(flat[0], flat[1]);
      for (let i = 2; i + 1 < flat.length; i += 2) {
        p.lineTo(flat[i], flat[i + 1]);
      }
    }
    return p;
  }

  private drawRoute(ctx: CanvasRenderingContext2D, ov: MapOverlay, s: number, pal: MapPalette): void {
    for (let i = ov.legs.length - 1; i >= 0; i--) {
      const path = this.legPath(ov.legs[i]);
      const isNext = ov.allActive || i === ov.nextLegIdx;
      const walked = !ov.allActive && i < ov.nextLegIdx;
      if (isNext) {
        ctx.strokeStyle = pal.casing;
        ctx.lineWidth = 9 / s;
        ctx.stroke(path);
        ctx.strokeStyle = pal.routeNext;
        ctx.lineWidth = 5 / s;
        ctx.stroke(path);
      } else {
        ctx.strokeStyle = walked ? pal.routeWalked : pal.routeLater;
        ctx.lineWidth = 4 / s;
        ctx.stroke(path);
      }
    }
  }

  private drawStops(ctx: CanvasRenderingContext2D, w: number, h: number, cam: Camera, ov: MapOverlay,
    pal: MapPalette): void {
    // Priority: next/current, then the first and last stop, then upcoming, then visited. A plaque that would
    // overlap one already placed becomes a small dot, so crowded squares (Rynek at overview zoom) stay legible.
    const last = ov.stops.length - 1;
    const order = ov.stops.map((st: StopMark, i: number) => i).sort((a: number, b: number) =>
      this.priority(ov.stops[b], b === 0 || b === last) - this.priority(ov.stops[a], a === 0 || a === last));
    const placed: number[] = [];
    const dots: number[] = [];
    for (const i of order) {
      const st = ov.stops[i];
      const x = (st.x - cam.cx) * cam.s + w / 2;
      const y = -(st.y - cam.cy) * cam.s + h / 2;
      if (x < -30 || y < -30 || x > w + 30 || y > h + 30) {
        continue;
      }
      let clash = false;
      for (let k = 0; k + 1 < placed.length; k += 2) {
        const dx = placed[k] - x;
        const dy = placed[k + 1] - y;
        if (dx * dx + dy * dy < 30 * 30) {
          clash = true;
          break;
        }
      }
      if (clash) {
        dots.push(i);
        continue;
      }
      placed.push(x, y);
      this.drawPlaque(ctx, x, y, st, pal);
      if (ov.labels && st.name !== '' && (st.state === PlaqueState.NEXT || st.state === PlaqueState.CURRENT)) {
        ctx.font = '500 12vp sans-serif';
        ctx.textAlign = 'left';
        ctx.textBaseline = 'middle';
        ctx.lineWidth = 3;
        ctx.strokeStyle = pal.labelHalo;
        ctx.strokeText(st.name, x + 22, y);
        ctx.fillStyle = pal.label;
        ctx.fillText(st.name, x + 22, y);
      }
    }
    // Crowded stops as small dots, under the plaques' halo colours.
    for (const i of dots) {
      const st = ov.stops[i];
      const x = (st.x - cam.cx) * cam.s + w / 2;
      const y = -(st.y - cam.cy) * cam.s + h / 2;
      ctx.beginPath();
      ctx.arc(x, y, 4, 0, Math.PI * 2);
      ctx.fillStyle = st.state === PlaqueState.VISITED ? pal.tertiary : pal.accent;
      ctx.fill();
      ctx.lineWidth = 1.5;
      ctx.strokeStyle = pal.surface;
      ctx.stroke();
    }
  }

  private priority(st: StopMark, endpoint: boolean): number {
    if (st.state === PlaqueState.NEXT || st.state === PlaqueState.CURRENT) {
      return 4;
    }
    if (endpoint) {
      return 3;
    }
    return st.state === PlaqueState.UPCOMING ? 2 : 1;
  }

  private rank(state: PlaqueState): number {
    if (state === PlaqueState.NEXT || state === PlaqueState.CURRENT) {
      return 3;
    }
    return state === PlaqueState.UPCOMING ? 2 : 1;
  }

  private drawPlaque(ctx: CanvasRenderingContext2D, x: number, y: number, st: StopMark, pal: MapPalette): void {
    const big = st.state === PlaqueState.NEXT || st.state === PlaqueState.CURRENT;
    const small = st.state === PlaqueState.VISITED || st.state === PlaqueState.SKIPPED;
    const r = big ? 17 : small ? 12 : 14;
    if (st.state === PlaqueState.CURRENT) {
      ctx.beginPath();
      ctx.arc(x, y, r + 8, 0, Math.PI * 2);
      ctx.fillStyle = pal.routeLater;
      ctx.fill();
    }
    ctx.beginPath();
    ctx.arc(x, y, r, 0, Math.PI * 2);
    ctx.fillStyle = big ? pal.accent : st.state === PlaqueState.VISITED ? pal.tertiary : pal.surface;
    ctx.fill();
    ctx.lineWidth = big ? 3 : st.state === PlaqueState.UPCOMING ? 2 : 1.5;
    ctx.strokeStyle = big ? pal.surface : st.state === PlaqueState.UPCOMING ? pal.accent : pal.tertiary;
    if (st.state === PlaqueState.SKIPPED) {
      ctx.setLineDash([3, 2]);
    }
    if (st.state !== PlaqueState.VISITED) {
      ctx.stroke();
    }
    ctx.setLineDash([]);
    if (st.state === PlaqueState.VISITED) {
      ctx.beginPath();
      ctx.moveTo(x - 4.5, y + 0.5);
      ctx.lineTo(x - 1.2, y + 3.8);
      ctx.lineTo(x + 5, y - 3.5);
      ctx.strokeStyle = pal.surface;
      ctx.lineWidth = 2;
      ctx.stroke();
      return;
    }
    if (st.n <= 0) {
      // Not a tour stop (Place detail of an explore place): a plain pin, no number.
      ctx.beginPath();
      ctx.arc(x, y, 5, 0, Math.PI * 2);
      ctx.fillStyle = big ? pal.onAccent : pal.accent;
      ctx.fill();
      return;
    }
    ctx.font = big ? 'bold 13vp sans-serif' : 'bold 12vp sans-serif';
    ctx.textAlign = 'center';
    ctx.textBaseline = 'middle';
    ctx.fillStyle = big ? pal.onAccent : st.state === PlaqueState.UPCOMING ? pal.accent : pal.tertiary;
    ctx.fillText(`${st.n}`, x, y + 0.5);
  }

  private drawUser(ctx: CanvasRenderingContext2D, w: number, h: number, cam: Camera, u: UserMark,
    pal: MapPalette): void {
    const x = (u.x - cam.cx) * cam.s + w / 2;
    const y = -(u.y - cam.cy) * cam.s + h / 2;
    if (x < -40 || y < -40 || x > w + 40 || y > h + 40) {
      return;
    }
    if (Number.isFinite(u.accuracyM) && u.accuracyM >= 10) {
      ctx.beginPath();
      ctx.arc(x, y, u.accuracyM * cam.s, 0, Math.PI * 2);
      ctx.fillStyle = pal.userHalo;
      ctx.fill();
    }
    if (Number.isFinite(u.courseDeg)) {
      // 60 degree wedge, 40 vp, pointing along the course (0 = north, clockwise).
      const a = (u.courseDeg - 90) * Math.PI / 180;
      ctx.beginPath();
      ctx.moveTo(x, y);
      ctx.arc(x, y, 40, a - Math.PI / 6, a + Math.PI / 6);
      ctx.closePath();
      ctx.fillStyle = pal.userCone;
      ctx.fill();
    }
    ctx.beginPath();
    ctx.arc(x, y, 7, 0, Math.PI * 2);
    if (u.simulated) {
      ctx.lineWidth = 3;
      ctx.strokeStyle = pal.user;   // hollow ring = simulated (DESIGN §4.8)
      ctx.stroke();
    } else {
      ctx.fillStyle = pal.user;
      ctx.fill();
      ctx.lineWidth = 3;
      ctx.strokeStyle = '#FFFFFF';
      ctx.stroke();
    }
  }
}

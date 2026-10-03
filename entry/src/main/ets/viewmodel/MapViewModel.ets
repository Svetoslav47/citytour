/*
 * Map data for the screens (B6): the pack's detail map (parsed once, lazily) and route overlays built from the
 * pack (stop positions, OSRM leg geometry; straight lines only when a leg is missing). Pack geometry is already
 * in the shared Projection frame (metres east/north of Rynek), so no projection happens here.
 */
import { EngineSnapshot, StopProgress, StopStatus, TourPhase } from '../contracts/EngineTypes';
import { Lang, MapData, RouteData, RouteLeg } from '../contracts/Model';
import { FixSource, PackRepository } from '../contracts/Ports';
import { AppContainer } from '../app/AppContainer';
import { Log } from '../app/Log';
import { LogEvents } from '../app/LogEvents';
import { boundsOf } from '../core/map/Camera';
import { PlaqueState } from '../views/common/Plaque';
import { MapOverlay, StopMark, UserMark } from '../views/map/MapRenderer';
import { poiName, safePoi, safeRoutes } from './PackView';

export class MapCache {
  private static detail: MapData | undefined = undefined;
  private static tried: boolean = false;

  /** The detail map, or undefined when the pack has none (then only the overlay is drawn). */
  static detailMap(): MapData | undefined {
    if (!MapCache.tried) {
      MapCache.tried = true;
      const t0 = Date.now();
      try {
        const m = AppContainer.packRepository().map('detail');
        MapCache.detail = m.layers.length > 0 ? m : undefined;
        let features = 0;
        m.layers.forEach((l) => {
          features += l.features.length;
        });
        Log.i(LogEvents.PACK_LOAD, `file=map-detail.json layers=${m.layers.length} features=${features} ` +
          `ms=${Date.now() - t0}`);
      } catch (e) {
        Log.e(LogEvents.PACK_ERR, `file=map-detail.json ${Log.errKv(e as Object)} blocking=false`);
        MapCache.detail = undefined;
      }
    }
    return MapCache.detail;
  }
}

function findLeg(routes: RouteData | undefined, from: string, to: string): RouteLeg | undefined {
  if (routes === undefined) {
    return undefined;
  }
  return routes.legs.find((l: RouteLeg) => l.fromPoiId === from && l.toPoiId === to);
}

/** Leg geometry between two stops: OSRM geometry from the pack, else a straight line between the POIs. */
export function legGeometry(pack: PackRepository, routes: RouteData | undefined, from: string, to: string): number[] {
  const leg = findLeg(routes, from, to);
  if (leg !== undefined && leg.geometry.length >= 4) {
    return leg.geometry;
  }
  const a = safePoi(pack, from);
  const b = safePoi(pack, to);
  return a !== undefined && b !== undefined ? [a.x, a.y, b.x, b.y] : [];
}

/** Whole route in one style (Home, Tour detail, Route ready previews). */
export function previewOverlay(order: string[], lang: Lang): MapOverlay {
  const pack = AppContainer.packRepository();
  const routes = safeRoutes(pack);
  const ov = new MapOverlay();
  ov.allActive = true;
  for (let i = 0; i + 1 < order.length; i++) {
    const g = legGeometry(pack, routes, order[i], order[i + 1]);
    if (g.length >= 4) {
      ov.legs.push(g);
    }
  }
  order.forEach((id: string, i: number) => {
    const p = safePoi(pack, id);
    if (p !== undefined) {
      ov.stops.push(new StopMark(p.x, p.y, i + 1, i === 0 ? PlaqueState.NEXT : PlaqueState.UPCOMING,
        poiName(pack, id, lang)));
    }
  });
  return ov;
}

function stateOf(s: EngineSnapshot, i: number): PlaqueState {
  const st: StopProgress = s.stops[i];
  if (st.status === StopStatus.SKIPPED) {
    return PlaqueState.SKIPPED;
  }
  if (i === s.currentStopIdx && s.phase === TourPhase.AT_STOP) {
    return PlaqueState.CURRENT;
  }
  if (st.status === StopStatus.VISITED || st.status === StopStatus.TEASER_ONLY) {
    return PlaqueState.VISITED;
  }
  return i === s.currentStopIdx ? PlaqueState.NEXT : PlaqueState.UPCOMING;
}

/** Live tour overlay for Now Walking: walked legs grey, the leg to the current stop highlighted, the user dot. */
export function walkOverlay(s: EngineSnapshot, lang: Lang): MapOverlay {
  const pack = AppContainer.packRepository();
  const routes = safeRoutes(pack);
  const ov = new MapOverlay();
  const order = s.stops.length > 0 ? s.stops.map((p: StopProgress) => p.poiId) : s.plannedOrder;
  for (let i = 0; i + 1 < order.length; i++) {
    const g = legGeometry(pack, routes, order[i], order[i + 1]);
    ov.legs.push(g.length >= 4 ? g : []);
  }
  // Leg i goes from stop i to stop i+1: the one leading to the current stop is next.
  ov.nextLegIdx = Math.max(0, s.currentStopIdx - 1);
  if (s.phase === TourPhase.FINISHED) {
    ov.nextLegIdx = ov.legs.length;
  }
  order.forEach((id: string, i: number) => {
    const p = safePoi(pack, id);
    if (p !== undefined) {
      ov.stops.push(new StopMark(p.x, p.y, i + 1, i < s.stops.length ? stateOf(s, i) : PlaqueState.UPCOMING,
        poiName(pack, id, lang)));
    }
  });
  ov.labels = true;
  if (s.user !== undefined && Number.isFinite(s.user.x) && Number.isFinite(s.user.y)) {
    const u = new UserMark();
    u.x = s.user.x;
    u.y = s.user.y;
    u.accuracyM = s.user.accuracyM;
    u.courseDeg = Number.isFinite(s.user.speedMps) && s.user.speedMps >= 0.6 ? s.user.courseDeg : Number.NaN;
    u.simulated = s.user.source === FixSource.DEMO;
    ov.user = u;
  }
  return ov;
}

/** World box of the overlay's stops and legs (for fit-to-route). */
export function overlayBounds(ov: MapOverlay): number[] | undefined {
  const flat: number[][] = ov.legs.slice();
  const pts: number[] = [];
  ov.stops.forEach((s: StopMark) => {
    pts.push(s.x, s.y);
  });
  flat.push(pts);
  return boundsOf(flat);
}

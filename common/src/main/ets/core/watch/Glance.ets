/*
 * What the watch's next-stop glance shows (docs/research/WATCH.md §1 "Progress ring", task W5), derived from an
 * EngineSnapshot: the arrow to the next stop relative to the walking direction, the progress n/N for the ring,
 * and the one status line that matters most right now. Pure (unit-tested in entry/src/test/Glance.test.ets).
 * Arrow: bearing to the stop minus the walker's course (both from GPS; the DevEco emulator has no compass).
 * Without a course it falls back to the engine's 8-way relDir; without either, or at the stop, there is no arrow.
 */
import {
  AppIssue, EngineSnapshot, IssueCode, NextInfo, RelDir, SignalQuality, StopProgress, StopStatus, TourPhase, UserPos
} from '../../contracts/EngineTypes';
import { relAngleDeg } from '../geo/GeoMath';
import { relDirAngle } from '../map/WalkDisplay';

/** "Here" needs a known distance at most this far (the engine also says HERE when it has no usable fix). */
export const HERE_MAX_M: number = 30;

export class GlanceArrow {
  known: boolean = false;
  /** Clockwise degrees from "straight ahead" (-180..180]. */
  deg: number = 0;
  /** The stop is here (within the engine's HERE distance): show "here" instead of an arrow. */
  here: boolean = false;
}

export function glanceArrow(next: NextInfo | undefined, user: UserPos | undefined): GlanceArrow {
  const a: GlanceArrow = new GlanceArrow();
  if (next === undefined) {
    return a;
  }
  if (next.relDir === RelDir.HERE) {
    a.here = Number.isFinite(next.distanceM) && next.distanceM <= HERE_MAX_M;
    return a;
  }
  const course: number = user !== undefined ? user.courseDeg : Number.NaN;
  if (Number.isFinite(next.bearingDeg) && Number.isFinite(course)) {
    a.known = true;
    a.deg = relAngleDeg(next.bearingDeg, course);
    return a;
  }
  if (Number.isFinite(next.distanceM)) {
    a.known = true;
    a.deg = relDirAngle(next.relDir);
  }
  return a;
}

/**
 * The stop the glance names: while AT_STOP the stop being visited (its story is playing; the engine's next/target
 * may already point past it, e.g. when the walk passes one stop on the way to another), otherwise the next stop.
 */
export function glanceStopId(s: EngineSnapshot): string {
  if (s.phase === TourPhase.AT_STOP && s.currentStopIdx >= 0 && s.currentStopIdx < s.stops.length) {
    return s.stops[s.currentStopIdx].poiId;
  }
  return s.next !== undefined ? s.next.poiId : '';
}

/** Stops already done (visited, heard as a teaser, or skipped). */
export function stopsDone(stops: StopProgress[]): number {
  let n: number = 0;
  for (const s of stops) {
    if (s.status === StopStatus.VISITED || s.status === StopStatus.TEASER_ONLY || s.status === StopStatus.SKIPPED) {
      n++;
    }
  }
  return n;
}

export enum GlanceStatus {
  NONE = 'none', PACK_ERROR = 'packError', PERMISSION = 'permission', LOCATION_OFF = 'locationOff',
  NO_FIX = 'noFix', OUT_OF_AREA = 'outOfArea', OFF_ROUTE = 'offRoute', FINISHED = 'finished'
}

function has(issues: AppIssue[], code: IssueCode): boolean {
  for (const i of issues) {
    if (i.code === code) {
      return true;
    }
  }
  return false;
}

/** The single status line of the glance, most important first (far from Kraków: out of area, not off route). */
export function glanceStatus(s: EngineSnapshot): GlanceStatus {
  if (s.phase === TourPhase.FINISHED) {
    return GlanceStatus.FINISHED;
  }
  if (has(s.issues, IssueCode.PACK_ERR)) {
    return GlanceStatus.PACK_ERROR;
  }
  if (has(s.issues, IssueCode.PERM_DENIED)) {
    return GlanceStatus.PERMISSION;
  }
  if (has(s.issues, IssueCode.LOC_SWITCH_OFF) || has(s.issues, IssueCode.LOC_UNAVAILABLE)) {
    return GlanceStatus.LOCATION_OFF;
  }
  if (s.user === undefined || s.signal === SignalQuality.LOST || has(s.issues, IssueCode.LOC_NOFIX)) {
    return GlanceStatus.NO_FIX;
  }
  if (has(s.issues, IssueCode.LOC_OUT_OF_AREA)) {
    return GlanceStatus.OUT_OF_AREA;
  }
  if (s.offRoute) {
    return GlanceStatus.OFF_ROUTE;
  }
  return GlanceStatus.NONE;
}

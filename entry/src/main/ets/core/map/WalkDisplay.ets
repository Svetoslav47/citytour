/*
 * Pure display maths for the Now Walking screen (DESIGN §3.6, §3.6.1). No @kit imports (unit-tested locally).
 * - Distance rounding: < 100 m in 10 m steps, 100-1000 m in 20 m steps, >= 1 km as "1.2 km".
 * - Update throttle: the hero distance changes at most every 2 s and only when the rounded value changes.
 * - Look cue dial: relative bearing -> dot position on a top half-arc; |rel| > 110 deg = "behind".
 */

export class RoundedDistance {
  value: number = 0;      // metres (rounded) or kilometres (1 decimal)
  km: boolean = false;
}

export function roundWalkDistance(metres: number): RoundedDistance {
  const r = new RoundedDistance();
  const m = Number.isFinite(metres) ? Math.max(0, metres) : 0;
  if (m < 100) {
    r.value = Math.round(m / 10) * 10;
  } else if (m < 1000) {
    r.value = Math.round(m / 20) * 20;
    if (r.value >= 1000) {
      r.km = true;
      r.value = 1.0;
    }
  } else {
    r.km = true;
    r.value = Math.round(m / 100) / 10;
  }
  return r;
}

/** Same rounded value? (compares unit and value) */
export function sameRounded(a: RoundedDistance, b: RoundedDistance): boolean {
  return a.km === b.km && Math.abs(a.value - b.value) < 1e-9;
}

export const DISTANCE_UPDATE_MIN_MS: number = 2000;

/** DESIGN §3.6: update the shown distance at most every 2 s and only when the rounded value changed. */
export function shouldUpdateDistance(shown: RoundedDistance | undefined, next: RoundedDistance, lastUpdateMs: number,
  nowMs: number): boolean {
  if (shown === undefined) {
    return true;
  }
  if (sameRounded(shown, next)) {
    return false;
  }
  return nowMs - lastUpdateMs >= DISTANCE_UPDATE_MIN_MS;
}

/** Normalises to [-180, 180). */
export function normalizeSigned(deg: number): number {
  let d = deg % 360;
  if (d < -180) {
    d += 360;
  }
  if (d >= 180) {
    d -= 360;
  }
  return d;
}

/** Target bearing relative to the walking course; NaN when either is unknown. */
export function relativeBearing(targetBearingDeg: number, courseDeg: number): number {
  if (!Number.isFinite(targetBearingDeg) || !Number.isFinite(courseDeg)) {
    return Number.NaN;
  }
  return normalizeSigned(targetBearingDeg - courseDeg);
}

export const BEHIND_DEG: number = 110;

export class DialDot {
  x: number = 0;          // centre of the dot, in the dial's local coordinates
  y: number = 0;
  behind: boolean = false;
  valid: boolean = false; // false = landmark mode (no course): hide the dot
}

/**
 * Dot centre for a dial whose arc centre is (cx, cy) with radius r (a top half-arc: -90 = left, 0 = ahead, +90 =
 * right). Targets behind (|rel| > 110 deg) go to (cx, cy + behindDy).
 */
export function dialDot(relDeg: number, cx: number, cy: number, r: number, behindDy: number): DialDot {
  const d = new DialDot();
  if (!Number.isFinite(relDeg)) {
    return d;
  }
  d.valid = true;
  const rel = normalizeSigned(relDeg);
  if (Math.abs(rel) > BEHIND_DEG) {
    d.behind = true;
    d.x = cx;
    d.y = cy + behindDy;
    return d;
  }
  const a = Math.max(-90, Math.min(90, rel)) * Math.PI / 180;
  d.x = cx + r * Math.sin(a);
  d.y = cy - r * Math.cos(a);
  return d;
}

/** DESIGN §3.6.1: move the dot only when the change is >= 10 degrees. */
export function dialShouldMove(prevRelDeg: number, nextRelDeg: number): boolean {
  if (!Number.isFinite(prevRelDeg) || !Number.isFinite(nextRelDeg)) {
    return Number.isFinite(prevRelDeg) !== Number.isFinite(nextRelDeg);
  }
  return Math.abs(normalizeSigned(nextRelDeg - prevRelDeg)) >= 10;
}

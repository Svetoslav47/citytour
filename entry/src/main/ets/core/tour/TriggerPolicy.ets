/*
 * Arrival / exit geofence logic per tour stop, and the teaser-vs-full decision (task A3).
 * Source: docs/ARCHITECTURE.md §4.3.
 *   - Accuracy-aware distance: dEnter = max(0, d - min(acc, 15)) for entry (benefit of the doubt),
 *     dExit = d + min(acc, 15) for exit (conservative); exit radius = triggerR * 1.6.
 *   - Enter: 2 consecutive inside fixes spanning >= 1.5 s, or 1 fix with dEnter <= 0.5 * triggerR.
 *   - Exit: 3 consecutive fixes with dExit beyond the exit radius.
 *   - Fixes that are not trigger-grade (accuracy > 40 m, coarse NETWORK; see FixFilter) are ignored here:
 *     they neither count towards nor reset a streak, so they can never cause an arrival or an exit.
 * Teaser vs full (decided when the teaser item completes, i.e. at a sentence boundary):
 *   FULL when adaptive length is off, the user asked for more, or the user has not left the stop
 *   (no EXIT yet) and is lingering: speed median < 0.6 m/s, or >= 8 s of slow fixes inside the trigger radius,
 *   or the speed is unknown (benefit of the doubt). Otherwise TEASER_ONLY (STORY_SKIP_MOVING).
 *   Interpretation (flagged for review): §4.3 lists `insideExit || slow || dwell >= 8 s`, but a walker is
 *   still inside 1.6 * R when a 20 s teaser ends and spends ~50 s inside R, so "inside" and plain dwell
 *   would make every walk-through FULL. Here leaving the stop forces TEASER_ONLY and dwell counts slow time only.
 * Pure: no platform imports.
 */
import { TourConfig } from './TourConfig';

export enum TriggerVerdict { NONE = 'none', ENTER = 'enter', EXIT = 'exit' }

export enum StoryLength { FULL = 'full', TEASER_ONLY = 'teaserOnly' }

/** One fix, reduced to what the geofence needs. */
export interface TriggerSample {
  tMs: number;
  distanceM: number;      // haversine user -> stop
  accuracyM: number;
  speedMps: number;       // NaN if unknown
  triggerGrade: boolean;  // FixFilter verdict
}

/** Geofence state of one stop. Mutated by evaluateTrigger. */
export class StopTrigger {
  readonly poiId: string;
  readonly triggerRadiusM: number;
  inside: boolean = false;
  enterStreak: number = 0;
  enterFirstMs: number = Number.NaN;
  exitStreak: number = 0;
  enteredAtMs: number = Number.NaN;
  exitedAtMs: number = Number.NaN;
  enterCount: number = 0;
  exitCount: number = 0;
  /** Slow (speed < slowSpeedMps) time inside the trigger radius since the last ENTER. */
  slowDwellMs: number = 0;
  lastInsideSampleMs: number = Number.NaN;
  lastDistanceM: number = Number.NaN;

  constructor(poiId: string, triggerRadiusM: number) {
    this.poiId = poiId;
    this.triggerRadiusM = triggerRadiusM;
  }

  exitRadiusM(cfg: TourConfig): number {
    return this.triggerRadiusM * cfg.exitFactor;
  }

  /** Time since ENTER (ms), NaN when not inside. */
  dwellMs(nowMs: number): number {
    return this.inside ? nowMs - this.enteredAtMs : Number.NaN;
  }
}

export function accuracyAllowanceM(accuracyM: number, cfg: TourConfig): number {
  return Number.isFinite(accuracyM) && accuracyM > 0 ? Math.min(accuracyM, cfg.accuracyAllowanceCapM) : 0;
}

/** Entry distance: max(0, d - min(acc, 15)). */
export function entryDistanceM(distanceM: number, accuracyM: number, cfg: TourConfig): number {
  return Math.max(0, distanceM - accuracyAllowanceM(accuracyM, cfg));
}

/** Exit distance: d + min(acc, 15). */
export function exitDistanceM(distanceM: number, accuracyM: number, cfg: TourConfig): number {
  return distanceM + accuracyAllowanceM(accuracyM, cfg);
}

/** True when the sample may move a geofence (trigger-grade and accuracy within the limit). */
export function isTriggerSample(s: TriggerSample, cfg: TourConfig): boolean {
  return s.triggerGrade && Number.isFinite(s.distanceM) && Number.isFinite(s.tMs) &&
    s.accuracyM <= cfg.maxTriggerAccuracyM;
}

/** Feeds one sample (in time order) to a stop's geofence; returns ENTER or EXIT on a transition. */
export function evaluateTrigger(t: StopTrigger, s: TriggerSample, cfg: TourConfig): TriggerVerdict {
  if (!isTriggerSample(s, cfg)) {
    return TriggerVerdict.NONE;
  }
  t.lastDistanceM = s.distanceM;
  if (!t.inside) {
    const dEnter: number = entryDistanceM(s.distanceM, s.accuracyM, cfg);
    if (dEnter > t.triggerRadiusM) {
      t.enterStreak = 0;
      t.enterFirstMs = Number.NaN;
      return TriggerVerdict.NONE;
    }
    t.enterStreak++;
    if (t.enterStreak === 1) {
      t.enterFirstMs = s.tMs;
    }
    const immediate: boolean = dEnter <= cfg.enterImmediateFraction * t.triggerRadiusM;
    const confirmed: boolean = t.enterStreak >= cfg.enterConfirmFixes &&
      s.tMs - t.enterFirstMs >= cfg.enterConfirmMinSpanMs;
    if (!immediate && !confirmed) {
      return TriggerVerdict.NONE;
    }
    t.inside = true;
    t.enterCount++;
    t.enteredAtMs = s.tMs;
    t.exitedAtMs = Number.NaN;
    t.enterStreak = 0;
    t.enterFirstMs = Number.NaN;
    t.exitStreak = 0;
    t.slowDwellMs = 0;
    t.lastInsideSampleMs = s.tMs;
    return TriggerVerdict.ENTER;
  }
  // Inside: dwell bookkeeping, then the exit hysteresis.
  if (s.distanceM <= t.triggerRadiusM && Number.isFinite(t.lastInsideSampleMs)) {
    const gap: number = s.tMs - t.lastInsideSampleMs;
    if (gap > 0 && gap <= cfg.maxDwellGapMs && Number.isFinite(s.speedMps) && s.speedMps < cfg.slowSpeedMps) {
      t.slowDwellMs += gap;
    }
  }
  t.lastInsideSampleMs = s.tMs;
  if (exitDistanceM(s.distanceM, s.accuracyM, cfg) <= t.exitRadiusM(cfg)) {
    t.exitStreak = 0;
    return TriggerVerdict.NONE;
  }
  t.exitStreak++;
  if (t.exitStreak < cfg.exitConfirmFixes) {
    return TriggerVerdict.NONE;
  }
  t.inside = false;
  t.exitCount++;
  t.exitedAtMs = s.tMs;
  t.exitStreak = 0;
  t.lastInsideSampleMs = Number.NaN;
  return TriggerVerdict.EXIT;
}

/**
 * Teaser vs full when the teaser item has finished (see the header for the rule and its interpretation).
 * speedMedianMps is FixFilter's median of the last 5 trigger-grade speeds (NaN if unknown).
 */
export function decideStoryLength(t: StopTrigger, speedMedianMps: number, adaptiveLength: boolean,
  userAskedMore: boolean, cfg: TourConfig): StoryLength {
  if (!adaptiveLength || userAskedMore) {
    return StoryLength.FULL;
  }
  if (!t.inside) {
    return StoryLength.TEASER_ONLY;          // moving away: EXIT already confirmed
  }
  if (!Number.isFinite(speedMedianMps) || speedMedianMps < cfg.slowSpeedMps) {
    return StoryLength.FULL;
  }
  if (t.slowDwellMs >= cfg.fullStoryDwellS * 1000) {
    return StoryLength.FULL;
  }
  return StoryLength.TEASER_ONLY;
}

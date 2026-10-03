/*
 * Demo walk replay (task A5, docs/ARCHITECTURE.md §5). SIMULATED location: plays a pre-generated track
 * (rawfile/demo/royal-route-walk.json, written by scripts/demo/make-demo-walk.mjs) as Fix objects with
 * source DEMO, so the emulator demo runs through the same FixFilter -> TourEngine pipeline as real GPS.
 *
 * Rules:
 *   - each tick advances the track by `ms` of track time (DemoWalkSource ticks every 1 s with ms = 1000 x speed);
 *   - hold segments (`hold: true`, the dwell at a stop): when the cursor reaches the end of a hold segment while
 *     `holdActive` is true, it loops back to the segment start instead of leaving, so the walker keeps standing
 *     (with the recorded jitter) while the story plays ("Demo assist");
 *   - emitted timestamps are startMs + simulated elapsed time (strictly increasing, also while holding); a consumer
 *     that times dwell/off-route on fix timestamps then sees walking pace at any speed. DemoWalkSource restamps
 *     with the wall clock by default (setSimulatedTimestamps(true) keeps these);
 *   - the walk ends at the last fix (which may itself be a hold that loops while holdActive).
 * Pure: no platform imports, no randomness, no logging.
 */
import { Fix, FixSource } from '../../contracts/Ports';

/** Allowed speed multipliers (ARCHITECTURE §5). */
export const DEMO_SPEEDS: number[] = [1, 2, 4, 8];
/** DemoWalkSource tick period. */
export const DEMO_TICK_MS: number = 1000;
/** Provider code for demo fixes (Fix.provider: 0 = unknown/demo). */
export const DEMO_PROVIDER: number = 0;

/** One track sample: Fix fields + tRelMs + hold (ARCHITECTURE §5). `stop` = stop number while holding, else 0. */
export interface DemoFix {
  tRelMs: number;
  lat: number;
  lng: number;
  accuracyM: number;
  speedMps: number;
  courseDeg: number;           // NaN if unknown (null in the JSON)
  courseAccuracyDeg: number;   // NaN if unknown
  hold: boolean;
  stop: number;
}

export interface DemoTrack {
  id: string;
  name: string;
  simulated: boolean;          // must be true
  generatedBy: string;
  fixes: DemoFix[];
}

/** Shape of the JSON file before validation (every field optional, values unchecked). */
interface RawDemoFix {
  tRelMs?: number;
  lat?: number;
  lng?: number;
  accuracyM?: number;
  speedMps?: number;
  courseDeg?: number | null;
  courseAccuracyDeg?: number | null;
  hold?: boolean;
  stop?: number;
}

interface RawDemoTrack {
  id?: string;
  name?: string;
  simulated?: boolean;
  generatedBy?: string;
  fixes?: RawDemoFix[];
}

export class DemoTrackParse {
  track?: DemoTrack;
  error: string = '';          // '' when ok
}

function isNum(v: number | null | undefined): boolean {
  return typeof v === 'number' && Number.isFinite(v);
}

function numOr(v: number | null | undefined, dflt: number): number {
  return (v !== undefined && v !== null && typeof v === 'number' && Number.isFinite(v)) ? v : dflt;
}

/** Parses and validates the track JSON. Never throws. */
export function parseDemoTrack(json: string): DemoTrackParse {
  const out = new DemoTrackParse();
  let raw: RawDemoTrack;
  try {
    raw = JSON.parse(json) as RawDemoTrack;
  } catch (e) {
    out.error = 'json';
    return out;
  }
  if (raw === null || raw === undefined || typeof raw !== 'object') {
    out.error = 'not_object';
    return out;
  }
  if (raw.simulated !== true) {
    out.error = 'not_simulated';   // the Demo walk must be labelled simulated
    return out;
  }
  const rawFixes = raw.fixes;
  if (rawFixes === undefined || rawFixes === null || !Array.isArray(rawFixes) || rawFixes.length === 0) {
    out.error = 'no_fixes';
    return out;
  }
  const fixes: DemoFix[] = [];
  let lastT = Number.NEGATIVE_INFINITY;
  for (let i = 0; i < rawFixes.length; i++) {
    const r = rawFixes[i];
    if (r === null || r === undefined || !isNum(r.tRelMs) || !isNum(r.lat) || !isNum(r.lng) ||
      Math.abs(r.lat as number) > 90 || Math.abs(r.lng as number) > 180) {
      out.error = `bad_fix i=${i}`;
      return out;
    }
    const t = r.tRelMs as number;
    if (t <= lastT) {
      out.error = `time_order i=${i}`;
      return out;
    }
    lastT = t;
    const hold = r.hold === true;
    const f: DemoFix = {
      tRelMs: t,
      lat: r.lat as number,
      lng: r.lng as number,
      accuracyM: numOr(r.accuracyM, Number.NaN),
      speedMps: numOr(r.speedMps, Number.NaN),
      courseDeg: numOr(r.courseDeg, Number.NaN),
      courseAccuracyDeg: numOr(r.courseAccuracyDeg, Number.NaN),
      hold: hold,
      stop: hold ? numOr(r.stop, 0) : 0
    };
    fixes.push(f);
  }
  const track: DemoTrack = {
    id: typeof raw.id === 'string' ? raw.id as string : 'demo',
    name: typeof raw.name === 'string' ? raw.name as string : 'Demo walk',
    simulated: true,
    generatedBy: typeof raw.generatedBy === 'string' ? raw.generatedBy as string : '',
    fixes: fixes
  };
  out.track = track;
  return out;
}

/** Nearest allowed multiplier (1 | 2 | 4 | 8). */
export function normalizeDemoSpeed(mult: number): number {
  if (!Number.isFinite(mult)) {
    return DEMO_SPEEDS[0];
  }
  let best = DEMO_SPEEDS[0];
  for (const s of DEMO_SPEEDS) {
    if (Math.abs(s - mult) < Math.abs(best - mult)) {
      best = s;
    }
  }
  return best;
}

/** Next multiplier in 1 -> 2 -> 4 -> 8 -> 1. */
export function nextDemoSpeed(mult: number): number {
  const i = DEMO_SPEEDS.indexOf(normalizeDemoSpeed(mult));
  return DEMO_SPEEDS[(i + 1) % DEMO_SPEEDS.length];
}

/** A Fix (source DEMO, provider 0) from a track sample. */
export function demoFixToFix(d: DemoFix, timestampMs: number): Fix {
  const f: Fix = {
    lat: d.lat,
    lng: d.lng,
    accuracyM: d.accuracyM,
    speedMps: d.speedMps,
    courseDeg: d.courseDeg,
    courseAccuracyDeg: d.courseAccuracyDeg,
    timestampMs: timestampMs,
    provider: DEMO_PROVIDER,
    source: FixSource.DEMO
  };
  return f;
}

export interface DemoTick {
  fix: Fix;
  index: number;       // index of the emitted sample in the track
  holding: boolean;    // this tick kept the walker at a stop because holdActive was true ("Demo assist")
  ended: boolean;      // the cursor is on the last sample and cannot advance
}

export class DemoWalkPlayer {
  private readonly track: DemoTrack;
  private idx: number = 0;
  private carryMs: number = 0;
  private simMs: number = 0;
  private startMs: number = 0;
  private started: boolean = false;

  constructor(track: DemoTrack) {
    this.track = track;
  }

  /** Rewinds to the first sample; timestamps restart at startMs. */
  reset(startMs: number): void {
    this.idx = 0;
    this.carryMs = 0;
    this.simMs = 0;
    this.startMs = startMs;
    this.started = true;
  }

  length(): number {
    return this.track.fixes.length;
  }

  index(): number {
    return this.idx;
  }

  trackId(): string {
    return this.track.id;
  }

  /** 0..1 along the track. */
  progress(): number {
    const n = this.track.fixes.length;
    return n <= 1 ? 1 : this.idx / (n - 1);
  }

  /** Stop number of the hold segment under the cursor, 0 while walking. */
  currentStop(): number {
    const f = this.track.fixes[this.idx];
    return f.hold ? f.stop : 0;
  }

  isAtEnd(): boolean {
    return this.idx >= this.track.fixes.length - 1;
  }

  /** The sample under the cursor as a Fix stamped with the current simulated time (no advance). */
  current(): Fix {
    if (!this.started) {
      this.reset(0);
    }
    return demoFixToFix(this.track.fixes[this.idx], this.startMs + this.simMs);
  }

  /**
   * Advances by `ms` of track time (> 0) and returns the sample to emit. While `holdActive` is true, the end of a
   * hold segment loops back to its start instead of leaving it.
   */
  tick(ms: number, holdActive: boolean): DemoTick {
    if (!this.started) {
      this.reset(0);
    }
    const step = Number.isFinite(ms) && ms > 0 ? ms : DEMO_TICK_MS;
    this.simMs += step;
    this.carryMs += step;
    const fixes = this.track.fixes;
    let holding = false;
    let guard = 0;
    while (guard < 100000) {
      guard++;
      if (this.isHoldEnd(this.idx) && holdActive) {
        const start = this.holdStart(this.idx);
        const cost = this.loopCost(start, this.idx);
        if (this.carryMs < cost) {
          holding = true;
          break;
        }
        this.carryMs -= cost;
        this.idx = start;
        holding = true;
        continue;
      }
      if (this.idx >= fixes.length - 1) {
        this.carryMs = 0;
        break;
      }
      const dt = Math.max(1, fixes[this.idx + 1].tRelMs - fixes[this.idx].tRelMs);
      if (this.carryMs < dt) {
        break;
      }
      this.carryMs -= dt;
      this.idx++;
    }
    const ended = this.isAtEnd() && !holding;
    const t: DemoTick = {
      fix: demoFixToFix(fixes[this.idx], this.startMs + this.simMs), index: this.idx, holding: holding, ended: ended
    };
    return t;
  }

  /**
   * "Demo assist: jump to next stop": moves the cursor to the first sample of the next hold segment that belongs to a
   * different stop (or to the last sample). Returns the stop number reached (0 if none).
   */
  jumpToNextStop(): number {
    const fixes = this.track.fixes;
    const cur = this.currentStop();
    let i = this.idx;
    // leave the current hold segment first
    while (i < fixes.length - 1 && fixes[i].hold && fixes[i].stop === cur && cur !== 0) {
      i++;
    }
    while (i < fixes.length - 1 && !(fixes[i].hold && fixes[i].stop !== cur)) {
      i++;
    }
    this.idx = i;
    this.carryMs = 0;
    return fixes[i].hold ? fixes[i].stop : 0;
  }

  private isHoldEnd(i: number): boolean {
    const fixes = this.track.fixes;
    const f = fixes[i];
    if (!f.hold) {
      return false;
    }
    return i >= fixes.length - 1 || !fixes[i + 1].hold || fixes[i + 1].stop !== f.stop;
  }

  private holdStart(i: number): number {
    const fixes = this.track.fixes;
    let s = i;
    while (s > 0 && fixes[s - 1].hold && fixes[s - 1].stop === fixes[i].stop) {
      s--;
    }
    return s;
  }

  /** Track time consumed by jumping from the segment end back to its start: one sample period. */
  private loopCost(start: number, end: number): number {
    const fixes = this.track.fixes;
    if (end > start) {
      return Math.max(1, (fixes[end].tRelMs - fixes[start].tRelMs) / (end - start));
    }
    return DEMO_TICK_MS;
  }
}

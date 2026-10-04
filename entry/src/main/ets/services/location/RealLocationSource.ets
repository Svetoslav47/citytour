/*
 * Real GPS through Location Kit (task A5, docs/ARCHITECTURE.md §2.3 and §5).
 *   - ContinuousLocationRequest { interval: 1, locationScenario: UserActivityScenario.NAVIGATION } (API 12);
 *   - on('locationChange') + on('locationError') (API 12) with callbacks held as fields, so off() receives the
 *     SAME references (the docs: a different callback silently fails to unsubscribe);
 *   - before subscribing: permission (PermissionPort.requestLocation) and the location switch
 *     (isLocationEnabled -> requestGlobalSwitch, RISKS b1/b3: a fresh emulator has the switch OFF);
 *   - Location -> Fix: direction is ignored when speed < 0.3 m/s; directionAccuracy/sourceType are optional (12+).
 * Doc: API参考/Location_Kit_位置服务/ArkTS_API/ohos_geoLocationManager_位置服务_/js-apis-geolocationmanager
 * (on/off locationChange, on/off locationError, LocationError -1..-5, exceptions 201/401/801/3301000/3301100).
 * On the emulator the fix is a static point in Beijing (lat 40, lng 116; RISKS b4/b5).
 * Never throws; start() always resolves and reports failures through onError (and isRunning() stays false).
 */
import { geoLocationManager } from '@kit.LocationKit';
import { Fix, FixListener, FixSource, LocationErrorListener, LocationSource, PermissionPort, PermissionState }
  from 'common';
import { Log } from '../../app/Log';
import { LogEvents } from 'common';

/** Course from the platform is unreliable below this speed (ARCHITECTURE §5). */
export const REAL_MIN_COURSE_SPEED_MPS: number = 0.3;
/** LOC_FIX log rate limit (ARCHITECTURE §10). */
export const LOC_FIX_LOG_EVERY_MS: number = 5000;
/** onError codes used for failures before subscribing (LocationError values, ARCHITECTURE §2.3). */
export const ERR_PERMISSION: number = -2;
export const ERR_SWITCH_OFF: number = -4;
/** Exception codes of on() (API reference). */
export const CODE_SWITCH_OFF: number = 3301100;
export const CODE_SERVICE_UNAVAILABLE: number = 3301000;
export const CODE_NOT_SUPPORTED: number = 801;

function errCode(e: Object): number {
  try {
    const c = (e as Record<string, Object>)['code'];
    return typeof c === 'number' ? c as number : -1;
  } catch (x) {
    return -1;
  }
}

function num(v: number | undefined): number {
  return v !== undefined && typeof v === 'number' && Number.isFinite(v) ? v : Number.NaN;
}

/** Location Kit -> contracts Fix (pure mapping, exported for reuse). */
export function locationToFix(l: geoLocationManager.Location): Fix {
  const speed = num(l.speed);
  const dir = num(l.direction);
  const courseValid = Number.isFinite(speed) && speed >= REAL_MIN_COURSE_SPEED_MPS && Number.isFinite(dir);
  const ts = num(l.timeStamp);
  const f: Fix = {
    lat: l.latitude,
    lng: l.longitude,
    accuracyM: num(l.accuracy),
    speedMps: speed,
    courseDeg: courseValid ? dir : Number.NaN,
    courseAccuracyDeg: courseValid ? num(l.directionAccuracy) : Number.NaN,
    timestampMs: Number.isFinite(ts) && ts > 0 ? ts : Date.now(),
    provider: l.sourceType !== undefined ? (l.sourceType as number) : 0,
    source: FixSource.REAL
  };
  return f;
}

function fmt(v: number, digits: number): string {
  return Number.isFinite(v) ? v.toFixed(digits) : 'nan';
}

export class RealLocationSource implements LocationSource {
  readonly kind: FixSource = FixSource.REAL;
  private readonly perms: PermissionPort;
  private running: boolean = false;
  private starting: boolean = false;
  private onFix: FixListener | undefined = undefined;
  private onError: LocationErrorListener | undefined = undefined;
  private count: number = 0;
  private lastLogMs: number = 0;
  private lastAcc: number = Number.NaN;
  private lastFixMs: number = 0;
  private lastErr: string = '';
  // Held as fields: off() must get the same references that on() got.
  private readonly fixCb: (l: geoLocationManager.Location) => void = (l: geoLocationManager.Location) => {
    this.handleLocation(l);
  };
  private readonly errCb: (e: geoLocationManager.LocationError) => void = (e: geoLocationManager.LocationError) => {
    this.handleLocationError(e);
  };

  constructor(perms: PermissionPort) {
    this.perms = perms;
  }

  isRunning(): boolean {
    return this.running;
  }

  /** Last real accuracy (m), NaN before the first fix: PlatformStatus.realGpsAccuracyM. */
  lastAccuracyM(): number {
    return this.lastAcc;
  }

  fixCount(): number {
    return this.count;
  }

  lastFixAtMs(): number {
    return this.lastFixMs;
  }

  /** Short reason of the last failure, '' if none (DevPanel / HUD). */
  lastError(): string {
    return this.lastErr;
  }

  async start(onFix: FixListener, onError: LocationErrorListener): Promise<void> {
    this.onFix = onFix;
    this.onError = onError;
    if (this.running || this.starting) {
      return;
    }
    this.starting = true;
    this.lastErr = '';
    try {
      // 1. Permission (system dialog the first time; a denial is reported, Settings is the caller's next step).
      let state = await this.perms.locationState();
      if (state !== PermissionState.GRANTED && state !== PermissionState.APPROX_ONLY) {
        state = await this.perms.requestLocation();
      }
      if (state !== PermissionState.GRANTED && state !== PermissionState.APPROX_ONLY) {
        this.fail(ERR_PERMISSION, `permission ${state}`);
        return;
      }
      if (state === PermissionState.APPROX_ONLY) {
        // §9 row 2: approximate fixes still move the dot; the engine disables triggers.
        Log.w(LogEvents.PERM_APPROX_ONLY, 'src=real action=continue_approximate');
      }
      // 2. Location switch (off on a fresh emulator: 3301100 otherwise).
      if (!this.perms.isLocationSwitchOn()) {
        Log.w(LogEvents.LOC_SWITCH_OFF, 'src=real action=request');
        const on = await this.perms.requestLocationSwitch();
        if (!on) {
          this.fail(ERR_SWITCH_OFF, 'location switch off');
          return;
        }
      }
      // 3. Subscribe.
      this.subscribe();
    } catch (e) {
      this.fail(errCode(e as Object), `start threw ${Log.errKv(e as Object)}`);
    } finally {
      this.starting = false;
    }
  }

  stop(): void {
    if (!this.running) {
      return;
    }
    this.running = false;
    try {
      geoLocationManager.off('locationChange', this.fixCb);
    } catch (e) {
      Log.w(LogEvents.LOC_ERR, `src=real where=off_locationChange ${Log.errKv(e as Object)}`);
    }
    try {
      geoLocationManager.off('locationError', this.errCb);
    } catch (e) {
      Log.w(LogEvents.LOC_ERR, `src=real where=off_locationError ${Log.errKv(e as Object)}`);
    }
    Log.i(LogEvents.LOC_SOURCE, `kind=real state=stop fixes=${this.count}`);
  }

  private subscribe(): void {
    const req: geoLocationManager.ContinuousLocationRequest = {
      interval: 1,
      locationScenario: geoLocationManager.UserActivityScenario.NAVIGATION
    };
    try {
      geoLocationManager.on('locationError', this.errCb);
    } catch (e) {
      // Not fatal: fixes can still arrive; log and continue.
      Log.w(LogEvents.LOC_ERR, `src=real where=on_locationError ${Log.errKv(e as Object)}`);
    }
    try {
      geoLocationManager.on('locationChange', req, this.fixCb);
      this.running = true;
      this.lastLogMs = 0;
      Log.i(LogEvents.LOC_SOURCE, 'kind=real state=start scenario=NAVIGATION interval=1');
    } catch (e) {
      try {
        geoLocationManager.off('locationError', this.errCb);
      } catch (x) {
        // ignore
      }
      const code = errCode(e as Object);
      if (code === CODE_SWITCH_OFF) {
        Log.w(LogEvents.LOC_SWITCH_OFF, `src=real code=${code}`);
      } else if (code === CODE_SERVICE_UNAVAILABLE || code === CODE_NOT_SUPPORTED) {
        Log.e(LogEvents.LOC_UNAVAILABLE, `src=real code=${code}`);
      }
      this.fail(code, `on(locationChange) ${Log.errKv(e as Object)}`);
    }
  }

  private handleLocation(l: geoLocationManager.Location): void {
    try {
      const f = locationToFix(l);
      this.count++;
      this.lastAcc = f.accuracyM;
      this.lastFixMs = Date.now();
      const now = Date.now();
      if (now - this.lastLogMs >= LOC_FIX_LOG_EVERY_MS) {
        this.lastLogMs = now;
        // Real coordinates rounded to 4 decimals (~10 m), ARCHITECTURE §10.
        Log.i(LogEvents.LOC_FIX, `src=real lat=${fmt(f.lat, 4)} lng=${fmt(f.lng, 4)} acc=${fmt(f.accuracyM, 1)}` +
          ` spd=${fmt(f.speedMps, 2)} crs=${fmt(f.courseDeg, 0)} prov=${f.provider} n=${this.count}`);
      }
      if (this.onFix !== undefined) {
        this.onFix(f);
      }
    } catch (e) {
      Log.e(LogEvents.UNCAUGHT, `where=RealLocationSource.onLocation ${Log.errKv(e as Object)}`);
    }
  }

  private handleLocationError(code: geoLocationManager.LocationError): void {
    try {
      const c = code as number;
      Log.w(LogEvents.LOC_ERR, `src=real code=${c}`);
      if (c === geoLocationManager.LocationError.LOCATING_FAILED_LOCATION_SWITCH_OFF) {
        Log.w(LogEvents.LOC_SWITCH_OFF, `src=real code=${c}`);
      } else if (c === geoLocationManager.LocationError.LOCATING_FAILED_LOCATION_PERMISSION_DENIED) {
        Log.e(LogEvents.PERM_DENIED, `perm=LOCATION src=real code=${c}`);
      }
      this.lastErr = `locationError ${c}`;
      if (this.onError !== undefined) {
        this.onError(c, `locationError ${c}`);
      }
    } catch (e) {
      Log.e(LogEvents.UNCAUGHT, `where=RealLocationSource.onLocationError ${Log.errKv(e as Object)}`);
    }
  }

  private fail(code: number, msg: string): void {
    this.running = false;
    this.lastErr = `${code} ${msg}`;
    Log.e(LogEvents.LOC_ERR, `src=real code=${code} msg=${msg}`);
    try {
      if (this.onError !== undefined) {
        this.onError(code, msg);
      }
    } catch (e) {
      Log.e(LogEvents.UNCAUGHT, `where=RealLocationSource.fail ${Log.errKv(e as Object)}`);
    }
  }
}

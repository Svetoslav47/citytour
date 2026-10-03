// Copied from entry/src/main/ets/services/location/PermissionService.ets (one watch change: requestLocationSwitch) for the watch HAP (watch config: app/WatchConfig).
/*
 * PermissionPort implementation (task A5, docs/ARCHITECTURE.md §2.3 and §9 rows 1-3).
 * Location permission (precise vs approximate), the re-request after a denial and the system location switch.
 * Verified emulator facts (docs/RISKS.md §1): a fresh emulator has the location switch OFF, on() then throws 3301100
 * (b1); requestPermissionsFromUser shows the dialog with the "Precise location" toggle (b2); requestGlobalSwitch
 * shows a system sheet and returns true once the user enables the switch (b3).
 *
 * Kit APIs (all 起始版本 <= 20, so no canIUse guard is needed with compatibleSdkVersion 20):
 *   - abilityAccessCtrl.getSelfPermissionStatus (20), requestPermissionsFromUser (9, Promise form),
 *     requestPermissionOnSetting (12), requestGlobalSwitch (12), SwitchType.LOCATION (12):
 *     doc API参考/Ability_Kit_程序框架服务/ArkTS_API/通用能力的接口_推荐/ohos_abilityAccessCtrl_程序访问控制管理_/
 *     js-apis-abilityaccessctrl
 *   - geoLocationManager.isLocationEnabled (9): doc API参考/Location_Kit_位置服务/ArkTS_API/
 *     ohos_geoLocationManager_位置服务_/js-apis-geolocationmanager
 *   - flow: FAQ/位置服务_Location_Kit/如何判断_访问我的位置_配置是否开启_若关闭如何跳转对应设置页面/faqs-location-22,
 *     FAQ/安全/程序访问控制/如何判断应用权限是否允许_以及拒绝后再次授权/faqs-access-control-15
 * Never throws: every platform call is wrapped; failures are logged and reported as a state.
 */
import { abilityAccessCtrl, common, Permissions } from '@kit.AbilityKit';
import { geoLocationManager } from '@kit.LocationKit';
import { PermissionPort, PermissionState } from 'common';
import { Log } from '../../app/Log';
import { LogEvents } from 'common';

export const PERM_APPROX: Permissions = 'ohos.permission.APPROXIMATELY_LOCATION';
export const PERM_PRECISE: Permissions = 'ohos.permission.LOCATION';
/** requestGlobalSwitch: "the specific global switch is already open". */
const ERR_SWITCH_ALREADY_OPEN: number = 12100013;
/** requestPermissionOnSetting: "all permissions in the list have been granted". */
const ERR_ALL_GRANTED: number = 12100011;

function errCode(e: Object): number {
  try {
    const c = (e as Record<string, Object>)['code'];
    return typeof c === 'number' ? c as number : -1;
  } catch (x) {
    return -1;
  }
}

export class PermissionService implements PermissionPort {
  private readonly ctx: common.UIAbilityContext;
  private atManager: abilityAccessCtrl.AtManager | undefined = undefined;
  private lastState: PermissionState = PermissionState.UNKNOWN;

  constructor(ctx: common.UIAbilityContext) {
    this.ctx = ctx;
  }

  /** Last state seen by any call (for the HUD / DevPanel). */
  last(): PermissionState {
    return this.lastState;
  }

  /** GRANTED (precise), APPROX_ONLY, DENIED (asked and refused), UNKNOWN (never asked or not readable). */
  locationState(): Promise<PermissionState> {
    return Promise.resolve(this.readState());
  }

  /** The system dialog (approximate + precise in one request). After a denial it no longer appears. */
  requestLocation(): Promise<PermissionState> {
    const before = this.readState();
    if (before === PermissionState.GRANTED) {
      return Promise.resolve(before);
    }
    const atm = this.at();
    if (atm === undefined) {
      return Promise.resolve(PermissionState.UNKNOWN);
    }
    return atm.requestPermissionsFromUser(this.ctx, [PERM_APPROX, PERM_PRECISE])
      .then((r): PermissionState => {
        const approx = r.authResults.length > 0 && r.authResults[0] === 0;
        const precise = r.authResults.length > 1 && r.authResults[1] === 0;
        const shown = r.dialogShownResults !== undefined ? JSON.stringify(r.dialogShownResults) : '?';
        const s = this.stateFrom(approx, precise);
        Log.i(LogEvents.SETTINGS, `perm_request results=${JSON.stringify(r.authResults)} dialogShown=${shown} state=${s}`);
        return this.report(s, 'request');
      })
      .catch((e: Object): PermissionState => {
        Log.e(LogEvents.PERM_DENIED, `perm=LOCATION where=requestPermissionsFromUser ${Log.errKv(e)}`);
        return this.report(this.readState(), 'request_error');
      });
  }

  /** Second chance after a denial: requestPermissionOnSetting for the permissions that are still denied. */
  openLocationSettings(): Promise<PermissionState> {
    const now = this.readState();
    if (now === PermissionState.GRANTED) {
      return Promise.resolve(now);
    }
    const atm = this.at();
    if (atm === undefined) {
      return Promise.resolve(now);
    }
    // Only permissions the user revoked may be passed (12100012 otherwise); both are in the location group.
    const list: Permissions[] = now === PermissionState.APPROX_ONLY ? [PERM_PRECISE] : [PERM_APPROX, PERM_PRECISE];
    return atm.requestPermissionOnSetting(this.ctx, list)
      .then((res: abilityAccessCtrl.GrantStatus[]): PermissionState => {
        Log.i(LogEvents.SETTINGS, `perm_on_setting list=${list.length} result=${JSON.stringify(res)}`);
        return this.report(this.readState(), 'on_setting');
      })
      .catch((e: Object): PermissionState => {
        if (errCode(e) === ERR_ALL_GRANTED) {
          return this.report(this.readState(), 'on_setting');
        }
        Log.w(LogEvents.PERM_DENIED, `perm=LOCATION where=requestPermissionOnSetting ${Log.errKv(e)}`);
        return this.report(this.readState(), 'on_setting_error');
      });
  }

  isLocationSwitchOn(): boolean {
    try {
      return geoLocationManager.isLocationEnabled();
    } catch (e) {
      Log.e(LogEvents.LOC_UNAVAILABLE, `where=isLocationEnabled ${Log.errKv(e as Object)}`);
      return false;
    }
  }

  /** Opens the system sheet for the location switch (no sheet and true when it is already on). */
  requestLocationSwitch(): Promise<boolean> {
    if (this.isLocationSwitchOn()) {
      return Promise.resolve(true);
    }
    Log.w(LogEvents.LOC_SWITCH_OFF, 'action=requestGlobalSwitch');
    const atm = this.at();
    if (atm === undefined) {
      return Promise.resolve(false);
    }
    return atm.requestGlobalSwitch(this.ctx, abilityAccessCtrl.SwitchType.LOCATION)
      .then((on: boolean): boolean => {
        const enabled = this.isLocationSwitchOn();
        Log.i(LogEvents.SETTINGS, `loc_switch requestGlobalSwitch=${on} enabled=${enabled}`);
        if (!enabled) {
          Log.w(LogEvents.LOC_SWITCH_OFF, 'result=still_off');
        }
        return enabled;
      })
      .catch((e: Object): boolean => {
        if (errCode(e) === ERR_SWITCH_ALREADY_OPEN) {
          return true;
        }
        // Watch: dismissing the switch dialog with a swipe rejects with 12100009 even when the user turned
        // location on, so the real switch state decides.
        const enabled = this.isLocationSwitchOn();
        Log.w(LogEvents.LOC_SWITCH_OFF, `where=requestGlobalSwitch enabled=${enabled} ${Log.errKv(e)}`);
        return enabled;
      });
  }

  private at(): abilityAccessCtrl.AtManager | undefined {
    if (this.atManager === undefined) {
      try {
        this.atManager = abilityAccessCtrl.createAtManager();
      } catch (e) {
        Log.e(LogEvents.UNCAUGHT, `where=createAtManager ${Log.errKv(e as Object)}`);
      }
    }
    return this.atManager;
  }

  private readState(): PermissionState {
    const atm = this.at();
    if (atm === undefined) {
      return PermissionState.UNKNOWN;
    }
    try {
      const approx = atm.getSelfPermissionStatus(PERM_APPROX);
      const precise = atm.getSelfPermissionStatus(PERM_PRECISE);
      const G = abilityAccessCtrl.PermissionStatus.GRANTED;
      if (approx === G && precise === G) {
        this.lastState = PermissionState.GRANTED;
      } else if (approx === G) {
        this.lastState = PermissionState.APPROX_ONLY;
      } else if (approx === abilityAccessCtrl.PermissionStatus.DENIED) {
        this.lastState = PermissionState.DENIED;
      } else {
        this.lastState = PermissionState.UNKNOWN;   // NOT_DETERMINED: never asked yet
      }
    } catch (e) {
      Log.w(LogEvents.UNCAUGHT, `where=getSelfPermissionStatus ${Log.errKv(e as Object)}`);
      this.lastState = PermissionState.UNKNOWN;
    }
    return this.lastState;
  }

  private stateFrom(approx: boolean, precise: boolean): PermissionState {
    if (approx && precise) {
      return PermissionState.GRANTED;
    }
    if (approx) {
      return PermissionState.APPROX_ONLY;
    }
    return PermissionState.DENIED;
  }

  private report(s: PermissionState, where: string): PermissionState {
    this.lastState = s;
    if (s === PermissionState.DENIED) {
      Log.e(LogEvents.PERM_DENIED, `perm=LOCATION where=${where}`);
    } else if (s === PermissionState.APPROX_ONLY) {
      Log.w(LogEvents.PERM_APPROX_ONLY, `where=${where}`);
    }
    return s;
  }
}

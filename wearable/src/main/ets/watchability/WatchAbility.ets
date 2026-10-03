/*
 * WatchAbility: the watch HAP's only UIAbility (docs/research/WATCH.md §4). Lifecycle wiring only:
 * log WATCH_APP_START, load pages/WatchHome.
 */
import { AbilityConstant, UIAbility, Want } from '@kit.AbilityKit';
import { window } from '@kit.ArkUI';
import { WatchLog } from '../app/WatchLog';

export default class WatchAbility extends UIAbility {
  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    WatchLog.i('WATCH_APP_START', `reason=${launchParam.launchReason}`);
  }

  onDestroy(): void {
    WatchLog.i('WATCH_APP_STOP', 'reason=onDestroy');
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    windowStage.loadContent('pages/WatchHome', (err) => {
      if (err && err.code) {
        WatchLog.e('WATCH_UNCAUGHT', `where=loadContent ${WatchLog.errKv(err)}`);
        return;
      }
      WatchLog.i('WATCH_PAGE', 'page=WatchHome');
    });
  }
}

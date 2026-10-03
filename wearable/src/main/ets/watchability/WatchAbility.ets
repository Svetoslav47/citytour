/*
 * WatchAbility: the watch HAP's only UIAbility (docs/research/WATCH.md §4). Lifecycle wiring only:
 * WatchContainer.init, log WATCH_APP_START, load pages/WatchHome. Launch parameter `demo` (`aa start ... --ps demo 1`)
 * starts the SIMULATED Demo walk tour right away, for verification from the command line.
 */
import { AbilityConstant, UIAbility, Want } from '@kit.AbilityKit';
import { window } from '@kit.ArkUI';
import { FixSource } from 'common';
import { Log } from '../app/Log';
import { WatchConfig } from '../app/WatchConfig';
import { WatchContainer } from '../app/WatchContainer';

function wantsDemo(want: Want | undefined): boolean {
  const params = want?.parameters;
  if (params === undefined) {
    return false;
  }
  const v = params[WatchConfig.LAUNCH_PARAM_DEMO];
  return v !== undefined && String(v) === '1';
}

export default class WatchAbility extends UIAbility {
  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    WatchContainer.init(this.context);
    Log.i('WATCH_APP_START', `reason=${launchParam.launchReason} demo=${wantsDemo(want) ? 1 : 0}`);
    if (wantsDemo(want)) {
      WatchContainer.startTour(FixSource.DEMO);
    }
  }

  onNewWant(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    if (wantsDemo(want)) {
      WatchContainer.startTour(FixSource.DEMO);
    }
  }

  onDestroy(): void {
    Log.i('WATCH_APP_STOP', 'reason=onDestroy');
    WatchContainer.shutdown();
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    windowStage.loadContent('pages/WatchHome', (err) => {
      if (err && err.code) {
        Log.e('WATCH_UNCAUGHT', `where=loadContent ${Log.errKv(err)}`);
        return;
      }
      Log.i('WATCH_PAGE', 'page=WatchHome');
    });
  }
}

/*
 * DevPanel section for the location sources (task A5). Kept in its own file so the DevPanel page only gains an import
 * and one line (A6 edits DevPanel in parallel). Developer page: literal strings on purpose.
 * Buttons (ids for `devecocli ui click --id ...`):
 *   btnDemoWalkX8   start the SIMULATED Demo walk at x8 (the PLAN A5 verify step)
 *   btnDemoStart / btnDemoStop / btnDemoSpeed (cycle 1-2-4-8) / btnDemoJump (next stop) / btnDemoRewind
 *   btnDemoHold     toggles the hold predicate ("a story is playing"), to see the Demo assist hold
 *   btnRealStart    Real GPS (Location Kit): permission dialog, location switch sheet, then 1 Hz fixes
 *   btnRealStop / btnPermSettings (requestPermissionOnSetting after a denial) / btnLocSwitch (requestGlobalSwitch)
 */
import { Fix, FixSource, PermissionState } from '../contracts/Ports';
import { nextDemoSpeed } from '../core/sim/DemoWalkPlayer';
import { AppContainer } from '../app/AppContainer';
import { Log } from '../app/Log';

const AMBER: string = '#FFB000';

function fmtFix(f: Fix | undefined): string {
  if (f === undefined) {
    return 'no fix';
  }
  const crs = Number.isFinite(f.courseDeg) ? `${f.courseDeg.toFixed(0)}°` : '-';
  const digits = f.source === FixSource.REAL ? 4 : 6;
  return `${f.lat.toFixed(digits)}, ${f.lng.toFixed(digits)} ±${f.accuracyM.toFixed(0)} m ` +
    `${Number.isFinite(f.speedMps) ? f.speedMps.toFixed(2) : '-'} m/s crs ${crs}`;
}

@ComponentV2
export struct LocationDevSection {
  @Local permLine: string = 'permission: ?';
  @Local realLine: string = 'Real GPS: stopped';
  @Local realFix: string = '';
  @Local demoLine: string = 'Demo walk: stopped';
  @Local demoFix: string = '';
  @Local demoRunning: boolean = false;
  @Local demoSpeed: number = 4;
  @Local storyHold: boolean = false;
  @Local note: string = '';
  private realLast: Fix | undefined = undefined;
  private uiTimer: number = -1;

  aboutToAppear(): void {
    const demo = AppContainer.demoWalk();
    if (demo !== undefined) {
      this.demoSpeed = demo.speed();
      demo.setHoldPredicate(() => this.storyHold);
    }
    this.refresh();
    this.uiTimer = setInterval(() => this.refresh(), 1000);
  }

  aboutToDisappear(): void {
    if (this.uiTimer >= 0) {
      clearInterval(this.uiTimer);
      this.uiTimer = -1;
    }
  }

  private refresh(): void {
    try {
      const perms = AppContainer.permissions();
      perms.locationState().then((s: PermissionState) => {
        this.permLine = `permission: ${s} | location switch: ${perms.isLocationSwitchOn() ? 'on' : 'OFF'}`;
      }).catch((e: Object) => {
        this.permLine = `permission: error ${Log.errKv(e)}`;
      });
      const real = AppContainer.realLocation();
      const acc = real.lastAccuracyM();
      this.realLine = `Real GPS: ${real.isRunning() ? 'running' : 'stopped'} | fixes ${real.fixCount()}` +
        ` | acc ${Number.isFinite(acc) ? acc.toFixed(1) + ' m' : '-'}` +
        (real.lastError() !== '' ? ` | ${real.lastError()}` : '');
      this.realFix = fmtFix(this.realLast);
      const demo = AppContainer.demoWalk();
      if (demo !== undefined) {
        this.demoRunning = demo.isRunning();
        this.demoSpeed = demo.speed();
        const stop = demo.currentStop();
        this.demoLine = `Demo walk: ${demo.isRunning() ? 'running' : (demo.isFinished() ? 'finished' : 'stopped')}` +
          ` | x${demo.speed()} | ${(demo.progress() * 100).toFixed(1)}%` +
          ` | ${stop > 0 ? 'at stop ' + stop : 'walking'}` +
          (demo.isHolding() ? ' | Demo assist: waiting at stop while the story plays' : '') +
          (demo.lastError() !== '' ? ` | ${demo.lastError()}` : '');
        this.demoFix = fmtFix(demo.lastEmitted());
      }
    } catch (e) {
      this.note = `refresh failed ${Log.errKv(e as Object)}`;
    }
  }

  private startDemo(speed: number): void {
    const demo = AppContainer.demoWalk();
    if (demo === undefined) {
      this.note = 'Demo walk unavailable (no context)';
      return;
    }
    if (speed > 0) {
      demo.setSpeed(speed);
    }
    demo.start((f: Fix) => {
      this.demoFix = fmtFix(f);
    }, (code: number, msg: string) => {
      this.note = `demo error ${code}: ${msg}`;
    }).then(() => this.refresh());
  }

  private startReal(): void {
    this.note = 'Real GPS: checking permission and location switch...';
    AppContainer.realLocation().start((f: Fix) => {
      this.realLast = f;
    }, (code: number, msg: string) => {
      this.note = `real GPS error ${code}: ${msg}`;
    }).then(() => {
      this.refresh();
      if (AppContainer.realLocation().isRunning()) {
        this.note = 'Real GPS subscribed (NAVIGATION, 1 s)';
      }
    });
  }

  build() {
    Column({ space: 8 }) {
      Text('Location (A5)').fontSize(18).fontWeight(FontWeight.Medium)
      if (this.demoRunning) {
        Text('SIMULATED LOCATION · Demo walk')
          .id('simulatedBadge')
          .fontSize(14)
          .fontWeight(FontWeight.Bold)
          .fontColor(Color.Black)
          .backgroundColor(AMBER)
          .padding({ left: 10, right: 10, top: 4, bottom: 4 })
          .borderRadius(12)
      }
      Text(this.permLine).id('locPerm').fontSize(12)
      Text(this.realLine).id('locReal').fontSize(12)
      Text(this.realFix).id('locRealFix').fontSize(12)
      Text(this.demoLine).id('locDemo').fontSize(12)
      Text(this.demoFix).id('locDemoFix').fontSize(12)
      Text(this.note).id('locNote').fontSize(12)
      Button('Demo walk x8 (SIMULATED)').id('btnDemoWalkX8').width('100%').backgroundColor(AMBER)
        .fontColor(Color.Black)
        .onClick(() => this.startDemo(8))
      Row({ space: 8 }) {
        Button('Demo start').id('btnDemoStart').layoutWeight(1).onClick(() => this.startDemo(0))
        Button('Demo stop').id('btnDemoStop').layoutWeight(1).onClick(() => {
          AppContainer.demoWalk()?.stop();
          this.refresh();
        })
      }.width('100%')
      Row({ space: 8 }) {
        Button(`Speed x${this.demoSpeed}`).id('btnDemoSpeed').layoutWeight(1).onClick(() => {
          const demo = AppContainer.demoWalk();
          if (demo !== undefined) {
            demo.setSpeed(nextDemoSpeed(demo.speed()));
            this.demoSpeed = demo.speed();
          }
        })
        Button('Next stop').id('btnDemoJump').layoutWeight(1).onClick(() => {
          AppContainer.demoWalk()?.jumpToNextStop();
          this.refresh();
        })
        Button('Rewind').id('btnDemoRewind').layoutWeight(1).onClick(() => {
          AppContainer.demoWalk()?.rewind();
          this.refresh();
        })
      }.width('100%')
      Button(this.storyHold ? 'Story playing: ON (demo holds at stops)' : 'Story playing: off')
        .id('btnDemoHold').width('100%')
        .onClick(() => {
          this.storyHold = !this.storyHold;
        })
      Row({ space: 8 }) {
        Button('Real GPS start').id('btnRealStart').layoutWeight(1).onClick(() => this.startReal())
        Button('Real GPS stop').id('btnRealStop').layoutWeight(1).onClick(() => {
          AppContainer.realLocation().stop();
          this.refresh();
        })
      }.width('100%')
      Row({ space: 8 }) {
        Button('Open settings').id('btnPermSettings').layoutWeight(1).onClick(() => {
          AppContainer.permissions().openLocationSettings().then((s: PermissionState) => {
            this.note = `after settings: ${s}`;
            this.refresh();
          });
        })
        Button('Location switch').id('btnLocSwitch').layoutWeight(1).onClick(() => {
          AppContainer.permissions().requestLocationSwitch().then((on: boolean) => {
            this.note = `location switch: ${on ? 'on' : 'still off'}`;
            this.refresh();
          });
        })
      }.width('100%')
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }
}

/*
 * The watch's screens (docs/research/WATCH.md, task W5; user decisions 2026-10-04):
 *   START     tour name, stops and time, "Start walk" (Location Kit) and "Demo walk" (SIMULATED replay).
 *   GLANCE    progress ring on the bezel (stops done / total), arrow to the next stop relative to the walking
 *             direction, distance, n / N, stop name, SIMULATED pill, one status line, and a 2.5 s flash of each
 *             haptic cue (the emulator has no motor). Long-press ends the tour.
 *   FINISHED  tour complete, stops done, Done.
 * Round screen 466 x 466 px = 233 x 233 vp; content stays inside the inscribed square, dark theme.
 * The watch UI exists in English only so far: on other system languages (the DevEco emulators are set to Arabic) the
 * layout is forced left-to-right and numbers are passed as plain strings (Latin digits). Unlike the phone, the watch
 * does not pin the app language: setAppPreferredLanguage closes the ability on the first launch after an install.
 */
import { Cue, FixSource, GlanceStatus } from 'common';
import { WatchScreen, WatchViewModel } from '../viewmodel/WatchViewModel';

const RING_STROKE: number = 10;

@Entry
@ComponentV2
struct WatchHome {
  @Local vm: WatchViewModel = new WatchViewModel();

  aboutToAppear(): void {
    this.vm.attach();
    this.vm.load();
  }

  aboutToDisappear(): void {
    this.vm.detach();
  }

  build() {
    Stack() {
      if (this.vm.screen === WatchScreen.START) {
        this.StartScreen()
      } else if (this.vm.screen === WatchScreen.GLANCE) {
        this.GlanceScreen()
      } else {
        this.FinishedScreen()
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.watch_bg'))
    .direction(Direction.Ltr)
  }

  @Builder
  StartScreen() {
    Column({ space: 8 }) {
      if (this.vm.packOk) {
        Text(this.vm.title)
          .fontSize(17)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.text_primary'))
          .textAlign(TextAlign.Center)
          .maxLines(2)
        Text($r('app.string.start_meta', String(this.vm.stopCount), String(this.vm.estMinutes)))
          .fontSize(12)
          .fontColor($r('app.color.text_secondary'))
        Button($r('app.string.start_walk'))
          .width(150)
          .height(40)
          .fontSize(15)
          .fontColor($r('app.color.on_accent'))
          .backgroundColor($r('app.color.accent'))
          .margin({ top: 6 })
          .onClick(() => this.vm.start(FixSource.REAL))
        Button($r('app.string.start_demo'))
          .width(150)
          .height(40)
          .fontSize(15)
          .fontColor($r('app.color.text_primary'))
          .backgroundColor($r('app.color.button_secondary'))
          .onClick(() => this.vm.start(FixSource.DEMO))
        Row({ space: 4 }) {
          this.SimulatedPill()
          Text($r('app.string.start_demo_note'))
            .fontSize(10)
            .fontColor($r('app.color.text_secondary'))
        }
      } else {
        Text($r('app.string.start_pack_error'))
          .fontSize(14)
          .fontColor($r('app.color.status_warn'))
          .textAlign(TextAlign.Center)
          .width(160)
      }
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
  }

  @Builder
  GlanceScreen() {
    Stack() {
      Progress({ value: this.vm.done, total: Math.max(1, this.vm.total), type: ProgressType.Ring })
        .width('100%')
        .height('100%')
        .color($r('app.color.accent'))
        .backgroundColor($r('app.color.ring_track'))
        .style({ strokeWidth: RING_STROKE })
      Column({ space: 2 }) {
        if (this.vm.simulated) {
          this.SimulatedPill()
        }
        if (this.vm.here) {
          Text($r('app.string.glance_here'))
            .fontSize(22)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.accent'))
            .height(46)
        } else if (this.vm.arrowKnown) {
          Path()
            .width(40)
            .height(46)
            .commands('M40 0 L80 92 L40 70 L0 92 Z')   // px, inside the 40 x 46 vp box (2 px per vp)
            .fill($r('app.color.text_primary'))
            .rotate({ angle: this.vm.arrowDeg })
            .animation({ duration: 300, curve: Curve.EaseOut })
            .accessibilityText($r('app.string.a11y_arrow'))
        } else {
          Blank().height(46)
        }
        if (this.vm.status !== GlanceStatus.NONE && this.vm.status !== GlanceStatus.OFF_ROUTE) {
          Text(this.statusText())
            .fontSize(13)
            .fontColor($r('app.color.status_warn'))
            .textAlign(TextAlign.Center)
            .width(150)
            .maxLines(2)
        } else {
          Row({ space: 3 }) {
            Text(this.vm.distValue)
              .fontSize(30)
              .fontWeight(FontWeight.Bold)
              .fontColor($r('app.color.text_primary'))
            Text(this.vm.distUnit)
              .fontSize(14)
              .fontColor($r('app.color.text_secondary'))
          }
          .alignItems(VerticalAlign.Bottom)
        }
        Text($r('app.string.glance_progress', String(this.vm.done), String(this.vm.total)))
          .fontSize(12)
          .fontColor($r('app.color.text_secondary'))
        Text(this.vm.nextName)
          .fontSize(14)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.text_primary'))
          .textAlign(TextAlign.Center)
          .width(150)
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        if (this.vm.status === GlanceStatus.OFF_ROUTE) {
          Text(this.statusText())
            .fontSize(11)
            .fontColor($r('app.color.status_warn'))
        }
      }
      .justifyContent(FlexAlign.Center)
      if (this.vm.cue !== undefined) {
        Text(this.cueText(this.vm.cue))
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.text_primary'))
          .backgroundColor($r('app.color.cue_bg'))
          .borderRadius(24)
          .padding({ left: 16, right: 16, top: 10, bottom: 10 })
      }
    }
    .width('100%')
    .height('100%')
    .gesture(LongPressGesture({ duration: 1000 }).onAction(() => this.vm.end()))
  }

  @Builder
  FinishedScreen() {
    Column({ space: 8 }) {
      Text($r('app.string.finished_title'))
        .fontSize(18)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.text_primary'))
      Text($r('app.string.finished_stops', String(this.vm.done), String(this.vm.total)))
        .fontSize(13)
        .fontColor($r('app.color.text_secondary'))
      if (this.vm.simulated) {
        this.SimulatedPill()
      }
      Button($r('app.string.finished_done'))
        .width(120)
        .height(40)
        .fontColor($r('app.color.on_accent'))
        .backgroundColor($r('app.color.accent'))
        .onClick(() => this.vm.end())
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
  }

  @Builder
  SimulatedPill() {
    Text($r('app.string.label_simulated'))
      .fontSize(10)
      .fontWeight(FontWeight.Bold)
      .fontColor($r('app.color.signal_simulated_fg'))
      .backgroundColor($r('app.color.signal_simulated_bg'))
      .borderRadius(8)
      .padding({ left: 6, right: 6, top: 2, bottom: 2 })
  }

  private statusText(): ResourceStr {
    switch (this.vm.status) {
      case GlanceStatus.PACK_ERROR:
        return $r('app.string.status_pack');
      case GlanceStatus.PERMISSION:
        return $r('app.string.status_permission');
      case GlanceStatus.LOCATION_OFF:
        return $r('app.string.status_location_off');
      case GlanceStatus.NO_FIX:
        return $r('app.string.status_no_fix');
      case GlanceStatus.OFF_ROUTE:
        return $r('app.string.status_off_route');
      default:
        return '';
    }
  }

  private cueText(c: Cue): ResourceStr {
    switch (c) {
      case Cue.ARRIVAL:
        return $r('app.string.cue_arrival');
      case Cue.LOOK_LEFT:
        return $r('app.string.cue_look_left');
      case Cue.LOOK_RIGHT:
        return $r('app.string.cue_look_right');
      default:
        return $r('app.string.cue_off_route');
    }
  }
}

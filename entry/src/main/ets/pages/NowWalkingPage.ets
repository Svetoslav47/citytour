/*
 * Now Walking (B5, DESIGN §3.6 + §3.6.2): the glanceable mirror of the audio. Map slot on top (the schematic
 * route preview until the Canvas map of B6), a fixed panel below: banner, where next / how far / which way
 * (Look cue), what am I hearing, pause / replay / skip. Honest labels: the amber SIMULATED pill whenever the
 * source is the Demo walk (tap -> Demo controls, "Demo assist"), and the "Fallback voice" chip whenever English
 * is read by the zh-CN voice. Back (chevron down) returns Home and the tour keeps running.
 * Ids: btnMinimise, btnWalkMenu, badgeSimulated, chipFallbackVoice, btnReplay, btnPlayPause, btnSkip,
 * btnStops, btnNextStopText, btnBackHome, btnJumpNext, segSpeedN.
 */
import { IssueCode } from '../contracts/EngineTypes';
import { Log } from '../app/Log';
import { LogEvents } from '../app/LogEvents';
import { AppViewModel } from '../viewmodel/AppViewModel';
import { NowWalkingViewModel, WalkState } from '../viewmodel/NowWalkingViewModel';
import { IssueBanner, topIssue } from '../views/common/IssueBanner';
import { MapCanvas } from '../views/map/MapCanvas';
import { SimulatedBadge } from '../views/common/SimulatedBadge';
import { StopList } from '../views/common/StopList';
import { Radius, Size, Space, Type } from '../views/common/Tokens';
import { FloatingIconButton } from '../views/common/FloatingIconButton';
import { DemoControlsSheet } from '../views/walk/DemoControlsSheet';
import { NextStopBlock } from '../views/walk/NextStopBlock';
import { NowPlayingCard } from '../views/walk/NowPlayingCard';
import { WalkControls } from '../views/walk/WalkControls';

const MAP_H: number = 300;
const MAP_H_READING: number = 200;

@ComponentV2
export struct NowWalkingPage {
  @Local app: AppViewModel = AppViewModel.get();
  @Local vm: NowWalkingViewModel = new NowWalkingViewModel();

  aboutToAppear(): void {
    this.vm.attach(this.app.textLang);
  }

  aboutToDisappear(): void {
    this.vm.detach();
  }

  // ---------- derived display ----------

  private overline(): Resource {
    const st = this.vm.state();
    const n = this.vm.stopNumber;
    if (st === WalkState.COMPLETE) {
      return $r('app.string.walk_tour_complete');
    }
    if (st === WalkState.ENDED) {
      return $r('app.string.walk_tour_ended');
    }
    if (this.vm.paused()) {
      return $r('app.string.walk_paused');
    }
    switch (st) {
      case WalkState.APPROACHING:
        return $r('app.string.walk_in_m', this.vm.shownDistance !== undefined && !this.vm.shownDistance.km ?
          this.vm.shownDistance.value : 50);
      case WalkState.AT_STOP:
      case WalkState.READING:
        return $r('app.string.walk_here_stop', n);
      case WalkState.TEASER:
        return $r('app.string.walk_passing', n);
      case WalkState.NO_GPS:
        return $r('app.string.walk_waiting_gps');
      case WalkState.OFF_ROUTE:
        return $r('app.string.walk_off_route');
      default:
        return $r('app.string.walk_next_stop', n);
    }
  }

  private title(): ResourceStr {
    if (this.finished()) {
      return this.vm.tourTitle;
    }
    if (this.vm.stopName !== '') {
      return this.vm.stopName;
    }
    return this.vm.totalStops > 0 ? $r('app.string.fmt_stop_of', this.vm.stopNumber, this.vm.totalStops) : '';
  }

  private atStop(): boolean {
    const st = this.vm.state();
    return st === WalkState.AT_STOP || st === WalkState.TEASER || st === WalkState.READING;
  }

  private finished(): boolean {
    const st = this.vm.state();
    return st === WalkState.COMPLETE || st === WalkState.ENDED;
  }

  private hero(): ResourceStr {
    const st = this.vm.state();
    if (st === WalkState.NO_GPS) {
      return '—';
    }
    if (this.atStop() || this.finished() || st === WalkState.IDLE) {
      return '';
    }
    const d = this.vm.shownDistance;
    if (d === undefined) {
      return '';
    }
    return d.km ? $r('app.string.fmt_km', d.value.toFixed(1)) : $r('app.string.fmt_m', d.value);
  }

  private sub(): ResourceStr {
    if (this.hero() === '' || this.vm.state() === WalkState.NO_GPS) {
      return '';
    }
    return $r('app.string.walk_about_min', this.vm.etaMinutes());
  }

  /** Highest-priority engine issue (permission > GPS > other), if any. */
  private issueCode(): IssueCode | undefined {
    if (this.vm.snap === undefined) {
      return undefined;
    }
    const i = topIssue(this.vm.snap.issues);
    return i === undefined ? undefined : i.code;
  }

  private confirmEnd(): void {
    try {
      this.getUIContext().showAlertDialog({
        title: $r('app.string.end_dialog_title'),
        message: $r('app.string.end_dialog_msg', this.vm.visitedCount(), this.vm.totalStops),
        primaryButton: {
          value: $r('app.string.cta_keep_walking'),
          action: () => {}
        },
        secondaryButton: {
          value: $r('app.string.cta_end_tour'),
          fontColor: $r('app.color.signal_error'),
          action: () => this.vm.end()
        }
      });
    } catch (e) {
      Log.e(LogEvents.UNCAUGHT, `where=NowWalkingPage.confirmEnd ${Log.errKv(e as Object)}`);
    }
  }

  // ---------- builders ----------

  @Builder
  banner() {
    if (this.issueCode() !== undefined) {
      IssueBanner({ code: this.issueCode() as IssueCode })
    } else if (this.vm.state() === WalkState.NO_GPS) {
      IssueBanner({
        message: $r('app.string.err_loc_lost'),
        code: IssueCode.LOC_LOST,
        actionLabel: this.vm.isDemo() ? '' : $r('app.string.err_try_demo'),
        actionId: 'btnNoGpsDemo',
        onAction: () => {
          this.vm.switchToDemo();
        }
      })
    } else if (this.vm.weakGps()) {
      IssueBanner({ message: $r('app.string.err_loc_poor'), code: IssueCode.LOC_POOR })
    } else if (this.vm.state() === WalkState.OFF_ROUTE) {
      IssueBanner({ message: $r('app.string.walk_replanned'), code: IssueCode.ROUTE_FALLBACK })
    }
  }

  @Builder
  header() {
    Row({ space: Space.S2 }) {
      Row() {
        FloatingIconButton({
          symbol: $r('sys.symbol.chevron_down'),
          label: $r('app.string.walk_minimise'),
          buttonId: 'btnMinimise',
          diameter: 36,
          onTap: () => this.app.back()
        })
        Text(this.vm.tourTitle)
          .fontSize(17)
          .fontWeight(FontWeight.Medium)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .fontColor($r('app.color.text_primary'))
          .constraintSize({ maxWidth: 170 })
        if (this.vm.totalStops > 0) {
          Text(`${this.finished() ? this.vm.visitedCount() : this.vm.stopNumber}/${this.vm.totalStops}`)
            .fontSize(Type.CALLOUT)
            .fontFeature('"tnum" 1')
            .fontColor($r('app.color.text_secondary'))
            .margin({ left: Space.S2 })
        }
      }
      .height(Size.TOUCH)
      .padding({ right: Space.S4 })
      .borderRadius(24)
      .backgroundColor($r('app.color.bg_scrim'))
      .backgroundBlurStyle(BlurStyle.COMPONENT_THICK)

      Blank()

      Button({ type: ButtonType.Circle, buttonStyle: ButtonStyleMode.NORMAL }) {
        SymbolGlyph($r('sys.symbol.dot_grid_1x2'))
          .fontSize(20)
          .fontColor([$r('app.color.text_primary')])
      }
      .id('btnWalkMenu')
      .width(Size.ICON_BUTTON)
      .height(Size.ICON_BUTTON)
      .margin(4)
      .backgroundColor($r('app.color.bg_scrim'))
      .backgroundBlurStyle(BlurStyle.COMPONENT_THICK)
      .shadow(ShadowStyle.OUTER_DEFAULT_XS)
      .accessibilityText($r('app.string.walk_menu'))
      .bindMenu([
        {
          value: $r('app.string.walk_menu_stops'),
          action: () => this.vm.openStops()
        },
        {
          value: $r('app.string.walk_menu_full_map'),
          action: () => this.app.openFullMap('walk')
        },
        {
          value: $r('app.string.cta_end_tour'),
          enabled: !this.finished(),
          action: () => this.confirmEnd()
        }
      ])
    }
    .width('100%')
    .padding({ left: Space.S2, right: Space.S2, top: Space.S2 })
  }

  @Builder
  chips() {
    Column({ space: Space.S2 }) {
      Row({ space: Space.S2 }) {
        SimulatedBadge({
          visible: this.vm.isDemo(),
          tappable: true,
          onTap: () => {
            this.vm.showDemoSheet = true;
          }
        })
        if (this.vm.isFallbackVoice()) {
          Row({ space: 4 }) {
            SymbolGlyph($r('sys.symbol.speaker_wave_2'))
              .fontSize(14)
              .fontColor([$r('app.color.text_secondary')])
            Text($r('app.string.voice_fallback_badge'))
              .fontSize(Type.CAPTION)
              .fontWeight(FontWeight.Medium)
              .fontColor($r('app.color.text_secondary'))
          }
          .id('chipFallbackVoice')
          .height(28)
          .padding({ left: 10, right: 10 })
          .borderRadius(14)
          .backgroundColor($r('app.color.bg_scrim'))
          .backgroundBlurStyle(BlurStyle.COMPONENT_THICK)
          .accessibilityText($r('app.string.walk_voice_info_a11y'))
          .onClick(() => {
            this.vm.showVoiceInfo = !this.vm.showVoiceInfo;
          })
        }
      }
      if (this.vm.showVoiceInfo && this.vm.isFallbackVoice()) {
        Text($r('app.string.voice_fallback_tooltip'))
          .fontSize(Type.FOOTNOTE)
          .lineHeight(Type.FOOTNOTE_LH)
          .fontColor($r('app.color.text_primary'))
          .padding(Space.S3)
          .borderRadius(Radius.MD)
          .backgroundColor($r('app.color.bg_surface'))
          .shadow(ShadowStyle.OUTER_DEFAULT_XS)
          .constraintSize({ maxWidth: 300 })
      }
    }
    .alignItems(HorizontalAlign.End)
    .width('100%')
    .padding({ right: Space.S3, top: 64 })
    .hitTestBehavior(HitTestMode.Transparent)   // the header buttons underneath stay tappable
  }

  @Builder
  playingOrDirections() {
    if (this.vm.nowPlaying() !== undefined) {
      NowPlayingCard({
        title: this.vm.nowPlayingTitle,
        caption: this.vm.nowPlaying()?.caption ?? '',
        sentenceIndex: this.vm.nowPlaying()?.sentenceIndex ?? 0,
        sentenceCount: this.vm.nowPlaying()?.sentenceCount ?? 0,
        playing: !this.vm.paused(),
        teaser: this.vm.state() === WalkState.TEASER,
        reading: this.vm.state() === WalkState.READING
      })
    } else if (this.vm.snap !== undefined && this.vm.snap.next !== undefined &&
      this.vm.snap.next.maneuverText !== '' && !this.atStop() && !this.finished()) {
      Row({ space: Space.S2 }) {
        SymbolGlyph($r('sys.symbol.figure_walk'))
          .fontSize(18)
          .fontColor([$r('app.color.accent')])
        Text(this.vm.snap.next.maneuverText)
          .fontSize(Type.BODY)
          .lineHeight(Type.BODY_LH)
          .fontColor($r('app.color.text_primary'))
          .layoutWeight(1)
      }
      .id('cardDirections')
      .width('100%')
      .padding(Space.S4)
      .borderRadius(Radius.LG)
      .backgroundColor($r('app.color.bg_surface_sunken'))
    }
  }

  @Builder
  controls() {
    if (this.finished()) {
      Button($r('app.string.walk_back_home'), { type: ButtonType.Capsule, buttonStyle: ButtonStyleMode.EMPHASIZED })
        .id('btnBackHome')
        .width('100%')
        .height(Size.BUTTON_H)
        .fontColor($r('app.color.on_accent'))
        .backgroundColor($r('app.color.accent'))
        .onClick(() => this.app.back())
    } else if (this.vm.state() === WalkState.READING) {
      Button($r('app.string.walk_next_stop_cta'), { type: ButtonType.Capsule, buttonStyle: ButtonStyleMode.EMPHASIZED })
        .id('btnNextStopText')
        .width('100%')
        .height(Size.BUTTON_H)
        .fontColor($r('app.color.on_accent'))
        .backgroundColor($r('app.color.accent'))
        .onClick(() => this.vm.skip())
    } else {
      WalkControls({
        paused: this.vm.paused(),
        active: this.vm.state() !== WalkState.IDLE,
        onReplay: () => this.vm.replay(),
        onToggle: () => this.vm.togglePlay(),
        onSkip: () => this.vm.skip()
      })
    }
  }

  @Builder
  panel() {
    Scroll() {
      Column({ space: Space.S4 }) {
        this.banner()
        NextStopBlock({
          overline: this.overline(),
          title: this.title(),
          hero: this.hero(),
          approx: this.vm.weakGps(),
          sub: this.sub(),
          dim: this.vm.paused(),
          showCue: !this.finished() && this.vm.state() !== WalkState.NO_GPS && this.vm.state() !== WalkState.IDLE,
          angleDeg: this.vm.dialDeg,
          relDir: this.vm.relDir(),
          lookUp: this.vm.lookUp && (this.atStop() || this.vm.state() === WalkState.APPROACHING),
          landmark: this.vm.stopName,
          emphasised: this.vm.state() === WalkState.APPROACHING
        })
        this.playingOrDirections()
        this.controls()
        if (!this.finished() && this.vm.totalStops > 0) {
          Row() {
            if (this.vm.stopName !== '' && this.vm.snap !== undefined && this.vm.snap.next !== undefined) {
              Button($r('app.string.walk_transcript'), { type: ButtonType.Capsule, buttonStyle: ButtonStyleMode.TEXTUAL })
                .id('btnTranscript')
                .height(Size.TOUCH)
                .fontSize(Type.CALLOUT)
                .fontColor($r('app.color.accent'))
                .onClick(() => this.app.openPlace(this.vm.snap?.next?.poiId ?? ''))
            }
            Blank()
            Button($r('app.string.walk_stops', this.vm.totalStops),
              { type: ButtonType.Capsule, buttonStyle: ButtonStyleMode.TEXTUAL })
              .id('btnStops')
              .height(Size.TOUCH)
              .fontSize(Type.CALLOUT)
              .fontColor($r('app.color.accent'))
              .onClick(() => this.vm.openStops())
              .bindSheet(this.vm.showStopsSheet, this.stopsSheet(), {
                detents: [SheetSize.MEDIUM, SheetSize.LARGE],
                dragBar: true,
                showClose: true,
                preferType: SheetType.BOTTOM,
                title: { title: $r('app.string.stops_sheet_title') },
                onDisappear: () => {
                  this.vm.showStopsSheet = false;
                }
              })
          }
          .width('100%')
        }
      }
      .width('100%')
      .padding({ left: Space.S4, right: Space.S4, top: Space.S5, bottom: Space.S5 })
    }
    .scrollBar(BarState.Off)
    .align(Alignment.Top)
    .layoutWeight(1)
    .width('100%')
    .borderRadius({ topLeft: Radius.XL, topRight: Radius.XL })
    .backgroundColor($r('app.color.bg_surface'))
    .shadow(ShadowStyle.OUTER_FLOATING_SM)
    .margin({ top: -Space.S5 })
  }

  @Builder
  stopsSheet() {
    Scroll() {
      Column({ space: Space.S3 }) {
        StopList({ rows: this.vm.stopRows })
        Text($r('app.string.stops_footer', this.vm.visitedCount(), this.vm.totalStops,
          `${Math.round((this.vm.snap?.remainingM ?? 0) / 100) / 10} km`))
          .fontSize(Type.FOOTNOTE)
          .fontColor($r('app.color.text_secondary'))
      }
      .padding({ left: Space.S4, right: Space.S4, bottom: Space.S6 })
    }
  }

  @Builder
  demoSheet() {
    DemoControlsSheet({
      speed: this.vm.demoSpeed,
      onSpeed: (x: number) => this.vm.setDemoSpeed(x),
      onJump: () => this.vm.demoJumpToNext()
    })
  }

  build() {
    NavDestination() {
      Stack({ alignContent: Alignment.TopStart }) {
        Column() {
          MapCanvas({
            map: this.vm.map,
            scene: this.vm.scene,
            bounds: this.vm.sceneBounds,
            follow: this.vm.scene.user !== undefined,
            followScale: 1.4,
            boxHeight: this.vm.state() === WalkState.READING ? MAP_H_READING : MAP_H,
            topInset: 96,
            bottomInset: 24,
            mapId: 'mapWalk'
          })
            .accessibilityText($r('app.string.walk_map_a11y', this.vm.stopName))
          this.panel()
        }
        .width('100%')
        .height('100%')

        this.header()
        this.chips()
      }
      .width('100%')
      .height('100%')
      .bindSheet(this.vm.showDemoSheet, this.demoSheet(), {
        detents: [SheetSize.FIT_CONTENT],
        dragBar: true,
        showClose: true,
        preferType: SheetType.BOTTOM,
        title: { title: $r('app.string.demo_controls_title') },
        onDisappear: () => {
          this.vm.showDemoSheet = false;
        }
      })
    }
    .id('pageNowWalking')
    .hideTitleBar(true)
    .backgroundColor($r('app.color.bg_canvas'))
    .onShown(() => {
      Log.i(LogEvents.APP_PAGE, 'page=NowWalking shown');
    })
  }
}

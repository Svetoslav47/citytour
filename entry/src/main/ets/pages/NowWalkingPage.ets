/*
 * Now Walking (B5, DESIGN §3.6 + §3.6.2): the glanceable mirror of the audio. Map slot on top (the schematic
 * route preview until the Canvas map of B6), a fixed panel below: banner, where next / how far / which way
 * (Look cue), what am I hearing, pause / replay / skip. Honest labels: the amber SIMULATED pill whenever the
 * source is the Demo walk (tap -> Demo controls, "Demo assist"). The voice type is not labelled on screen (it is
 * named in Settings -> About). Back (chevron down) returns Home and the tour keeps running.
 * Ids: btnMinimise, btnWalkMenu, badgeSimulated, btnReplay, btnPlayPause, btnSkip,
 * btnStops, btnNextStopText, btnBackHome, btnJumpNext, segSpeedN.
 * B11: when the tour ends (FINISHED or ABORTED) the page hands over to the Tour summary (SummaryPage).
 * B12: the ⋯ menu toggles the "How it works" HUD (views/walk/HowItWorksHud, id hudHowItWorks) over the map.
 * §3.6.3: the panel is a two-detent bottom sheet (core/map/SheetDetents). EXPANDED = the full panel below the DESIGN
 * map box; COLLAPSED ("peek") = next stop, distance + ETA, the turn text and play/pause + skip, so the map gets the
 * rest of the screen. Drag or fling the handle / peek (spring), tap the handle to toggle; the detent is kept for the
 * app session. Only translateY and opacity animate; the map's follow inset follows the settled detent.
 * Ids: sheetWalk, btnSheetHandle, sheetPeek, btnPeekPlayPause, btnPeekSkip.
 */
import { curves } from '@kit.ArkUI';
import { IssueCode } from 'common';
import { Log } from '../app/Log';
import { LogEvents } from 'common';
import { AppViewModel } from '../viewmodel/AppViewModel';
import { NowWalkingViewModel, WalkState } from '../viewmodel/NowWalkingViewModel';
import { IssueBanner, topIssue } from '../views/common/IssueBanner';
import { MapCanvas } from '../views/map/MapCanvas';
import { SimulatedBadge } from '../views/common/SimulatedBadge';
import { StopList } from '../views/common/StopList';
import { Radius, Size, Space, Type } from '../views/common/Tokens';
import { FloatingIconButton } from '../views/common/FloatingIconButton';
import { DemoControlsSheet } from '../views/walk/DemoControlsSheet';
import { HowItWorksHud, HudPrefs, hudRowsFor } from '../views/walk/HowItWorksHud';
import { NextStopBlock } from '../views/walk/NextStopBlock';
import { NowPlayingCard } from '../views/walk/NowPlayingCard';
import { WalkControls } from '../views/walk/WalkControls';
import { SafeArea } from '../viewmodel/SafeArea';
import { liveLangName } from 'common';
import {
  collapseProgress, detentOffset, dragOffset, expandedHeight, mapBottomInset, mapBoxHeight, peekHeight, resolveDetent,
  SheetDetent, sheetTravel, toggleDetent, visibleSheetHeight
} from 'common';

const MAP_H: number = 300;
const MAP_H_READING: number = 200;
/** B12: with the HUD on, the map box reaches this far below the HUD, so the HUD never covers the panel and a strip of
 * map (user dot, route) stays visible under it (24 vp of it sit under the panel's rounded top). */
const HUD_MAP_STRIP: number = 120;
/** Drag handle strip at the top of the sheet (the bar is 36 x 4 vp, the strip is the touch area). */
const HANDLE_H: number = 24;

/** Sheet detent kept for the app session (the page is rebuilt each time Now Walking opens). */
let sessionDetent: SheetDetent = SheetDetent.EXPANDED;

@ComponentV2
export struct NowWalkingPage {
  @Local app: AppViewModel = AppViewModel.get();
  @Local vm: NowWalkingViewModel = new NowWalkingViewModel();
  /** Window avoid areas (edge-to-edge window, issue #63): the map runs under the status bar (DESIGN §3.6), the
   * header capsule and chips sit below it, the panel runs under the navigation indicator and its controls clear it. */
  @Local sa: SafeArea = SafeArea.get();
  /** B12: "How it works" HUD on/off, kept for the app session. */
  @Local hud: HudPrefs = HudPrefs.get();
  /** Height of the chips + HUD overlay column (onAreaChange), for the map box and its follow inset. */
  @Local overlayH: number = 0;
  /** Page height (onAreaChange), for the sheet and the map box. 0 until the first layout. */
  @Local pageH: number = 0;
  /** Settled sheet detent (§3.6.3). */
  @Local detent: SheetDetent = sessionDetent;
  /** While a finger drags the sheet, its offset follows `dragOff` instead of the detent. */
  @Local dragging: boolean = false;
  @Local dragOff: number = 0;
  private dragStartOff: number = 0;

  aboutToAppear(): void {
    this.vm.onTourEnded = () => this.app.openSummary();   // B11: Tour summary when the tour ends
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

  /** Map box height: the DESIGN height, grown with the HUD on so the HUD sits over the map, never over the panel. */
  private mapBoxH(): number {
    const base: number = (this.vm.state() === WalkState.READING ? MAP_H_READING : MAP_H) + this.sa.top;
    return this.hud.visible && this.overlayH > 0 ? Math.max(base, this.overlayH + HUD_MAP_STRIP) : base;
  }

  /** Map follow inset: below the header (DESIGN), or below the HUD while it is on, so the user dot stays visible. */
  private mapTopInset(): number {
    const base: number = 96 + this.sa.top;
    return this.hud.visible && this.overlayH > 0 ? Math.max(base, this.overlayH) : base;
  }

  // ---------- sheet (§3.6.3) ----------

  private peekH(): number {
    return peekHeight(this.sa.bottom);
  }

  /** Expanded sheet: the page below the DESIGN map box (grown with the HUD), as the fixed panel was. */
  private sheetH(): number {
    return expandedHeight(this.pageH, this.mapBoxH(), this.peekH());
  }

  private travel(): number {
    return sheetTravel(this.sheetH(), this.peekH());
  }

  private sheetOffset(): number {
    return this.dragging ? this.dragOff : detentOffset(this.detent, this.travel());
  }

  /** 0 expanded .. 1 collapsed: the peek block fades in over the top of the full panel. */
  private progress(): number {
    return collapseProgress(this.sheetOffset(), this.travel());
  }

  private collapsed(): boolean {
    return this.detent === SheetDetent.COLLAPSED;
  }

  /** The map runs behind the sheet down to the peek; before the first layout, the DESIGN box. */
  private canvasH(): number {
    return this.pageH > 0 ? mapBoxHeight(this.pageH, this.peekH()) : this.mapBoxH();
  }

  /** Follow inset from the settled detent (not every drag frame), so the camera moves once per detent change. */
  private mapBottom(): number {
    if (this.pageH <= 0) {
      return 24;
    }
    const visible = visibleSheetHeight(this.sheetH(), detentOffset(this.detent, this.travel()));
    return mapBottomInset(visible, this.pageH, this.canvasH());
  }

  private settle(d: SheetDetent, why: string): void {
    sessionDetent = d;
    try {
      this.getUIContext().animateTo({ curve: curves.springMotion(0.4, 0.86) }, () => {
        this.detent = d;
        this.dragging = false;
      });
    } catch (e) {
      this.detent = d;
      this.dragging = false;
    }
    Log.i(LogEvents.APP_PAGE, `page=NowWalking sheet=${d === SheetDetent.COLLAPSED ? 'collapsed' : 'expanded'} by=${why}`);
  }

  private sheetDragStart(): void {
    this.dragStartOff = this.sheetOffset();
    this.dragOff = this.dragStartOff;
    this.dragging = true;
  }

  private sheetDragMove(e: GestureEvent): void {
    this.dragOff = dragOffset(this.dragStartOff, e.offsetY, this.travel());
  }

  private sheetDragEnd(e: GestureEvent): void {
    if (!this.dragging) {
      return;
    }
    this.settle(resolveDetent(this.dragOff, e.velocityY, this.travel()), 'drag');
  }

  private sheetDragCancel(): void {
    if (this.dragging) {
      this.settle(this.detent, 'cancel');
    }
  }

  private toggleHud(): void {
    this.hud.visible = !this.hud.visible;
    Log.i(LogEvents.APP_PAGE, `page=NowWalking hud=${this.hud.visible ? 'on' : 'off'}`);
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
        actionLabel: this.vm.isDemo() || !this.vm.demoOffered() ? '' : $r('app.string.err_try_demo'),
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
          value: this.hud.visible ? $r('app.string.walk_menu_how_hide') : $r('app.string.walk_menu_how'),
          action: () => this.toggleHud()
        },
        {
          value: $r('app.string.walk_menu_lang', liveLangName(this.vm.menuLangs()[0])),
          enabled: !this.finished(),
          action: () => this.vm.switchStoryLang(this.vm.menuLangs()[0])
        },
        {
          value: $r('app.string.walk_menu_lang', liveLangName(this.vm.menuLangs()[1])),
          enabled: !this.finished(),
          action: () => this.vm.switchStoryLang(this.vm.menuLangs()[1])
        },
        {
          value: $r('app.string.cta_end_tour'),
          enabled: !this.finished(),
          action: () => this.confirmEnd()
        }
      ])
    }
    .width('100%')
    .padding({ left: Space.S2 + this.sa.left, right: Space.S2 + this.sa.right, top: Space.S2 + this.sa.top })
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
      }
      if (this.hud.visible) {
        HowItWorksHud({ rows: hudRowsFor(this.vm.snap, this.vm.stopName, this.vm.demoSpeed) })
      }
    }
    .alignItems(HorizontalAlign.End)
    .width('100%')
    .padding({ left: Space.S3 + this.sa.left, right: Space.S3 + this.sa.right, top: 64 + this.sa.top })
    .onAreaChange((_old: Area, now: Area) => {
      this.overlayH = Number(now.height);
    })
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
  handle() {
    Button({ type: ButtonType.Normal, buttonStyle: ButtonStyleMode.TEXTUAL, stateEffect: false }) {
      Row()
        .width(36)
        .height(4)
        .borderRadius(2)
        .backgroundColor($r('app.color.text_secondary'))
        .opacity(0.5)
    }
    .id('btnSheetHandle')
    .width('100%')
    .height(HANDLE_H)
    .responseRegion({ x: 0, y: -12, width: '100%', height: HANDLE_H + 24 })   // 48 vp touch target
    .backgroundColor(Color.Transparent)
    .accessibilityText(this.collapsed() ? $r('app.string.walk_sheet_expand') : $r('app.string.walk_sheet_collapse'))
    .onClick(() => this.settle(toggleDetent(this.detent), 'tap'))
    .gesture(
      PanGesture({ direction: PanDirection.Vertical, distance: 4 })
        .onActionStart(() => this.sheetDragStart())
        .onActionUpdate((e: GestureEvent) => this.sheetDragMove(e))
        .onActionEnd((e: GestureEvent) => this.sheetDragEnd(e))
        .onActionCancel(() => this.sheetDragCancel()))
  }

  /** Peek line under the stop name: the distance + ETA, or the story being told at a stop. */
  private peekSub(): ResourceStr {
    if (this.hero() !== '') {
      return this.hero();
    }
    return this.vm.nowPlaying() !== undefined ? this.vm.nowPlayingTitle : '';
  }

  private maneuver(): string {
    if (this.vm.snap === undefined || this.vm.snap.next === undefined || this.atStop() || this.finished()) {
      return '';
    }
    return this.vm.snap.next.maneuverText;
  }

  @Builder
  peekControls() {
    if (!this.finished()) {
      Row({ space: Space.S3 }) {
        if (this.vm.state() !== WalkState.READING) {
          Button({ type: ButtonType.Circle, buttonStyle: ButtonStyleMode.EMPHASIZED }) {
            SymbolGlyph(this.vm.paused() ? $r('sys.symbol.play_fill') : $r('sys.symbol.pause_fill'))
              .fontSize(24)
              .fontColor([$r('app.color.on_accent')])
          }
          .id('btnPeekPlayPause')
          .width(56)
          .height(56)
          .backgroundColor($r('app.color.accent'))
          .enabled(this.vm.state() !== WalkState.IDLE)
          .accessibilityText(this.vm.paused() ? $r('app.string.walk_play') : $r('app.string.walk_pause'))
          .onClick(() => this.vm.togglePlay())
        }
        Button({ type: ButtonType.Circle, buttonStyle: ButtonStyleMode.NORMAL }) {
          SymbolGlyph($r('sys.symbol.forward_end_fill'))
            .fontSize(20)
            .fontColor([$r('app.color.text_primary')])
        }
        .id('btnPeekSkip')
        .width(Size.TOUCH)
        .height(Size.TOUCH)
        .backgroundColor($r('app.color.bg_surface_sunken'))
        .enabled(this.vm.state() !== WalkState.IDLE)
        .accessibilityText(this.vm.state() === WalkState.READING ? $r('app.string.walk_next_stop_cta') :
          $r('app.string.walk_skip'))
        .onClick(() => this.vm.skip())
      }
    }
  }

  /** COLLAPSED content (§3.6.3): where next, how far, which way, play/pause. Opaque, over the full panel's top. */
  @Builder
  peek() {
    Column({ space: Space.S1 }) {
      Row({ space: Space.S3 }) {
        Column({ space: 2 }) {
          Text(this.overline())
            .fontSize(Type.CAPTION)
            .lineHeight(Type.CAPTION_LH)
            .fontWeight(FontWeight.Medium)
            .letterSpacing(Type.OVERLINE_SPACING)
            .textCase(TextCase.UpperCase)
            .maxLines(1)
            .maxFontScale(1.3)
            .fontColor($r('app.color.text_secondary'))
          Text(this.title())
            .id('peekTitle')
            .fontSize(Type.TITLE3)
            .lineHeight(Type.TITLE3_LH)
            .fontWeight(FontWeight.Bold)
            .maxLines(1)
            .maxFontScale(1.3)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .fontColor($r('app.color.text_primary'))
          if (this.peekSub() !== '') {
            Row({ space: Space.S2 }) {
              Text() {
                if (this.hero() !== '' && this.vm.weakGps()) {
                  Span('~')
                }
                Span(this.peekSub())
              }
              .id('peekHero')
              .fontSize(this.hero() !== '' ? Type.TITLE2 : Type.CALLOUT)
              .fontWeight(this.hero() !== '' ? FontWeight.Bold : FontWeight.Regular)
              .fontFeature('"tnum" 1')
              .maxLines(1)
              .maxFontScale(1.3)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .flexShrink(1)
              .fontColor(this.vm.paused() || this.hero() === '' ? $r('app.color.text_secondary') :
                $r('app.color.text_primary'))
              if (this.sub() !== '') {
                Text(this.sub())
                  .fontSize(Type.CALLOUT)
                  .maxLines(1)
                  .maxFontScale(1.3)
                  .fontColor($r('app.color.text_secondary'))
              }
            }
            .alignItems(VerticalAlign.Bottom)
          }
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)
        .accessibilityGroup(true)

        this.peekControls()
      }
      .width('100%')

      if (this.maneuver() !== '') {
        Row({ space: Space.S2 }) {
          SymbolGlyph($r('sys.symbol.figure_walk'))
            .fontSize(16)
            .fontColor([$r('app.color.accent')])
          Text(this.maneuver())
            .fontSize(Type.CALLOUT)
            .lineHeight(Type.CALLOUT_LH)
            .maxLines(1)
            .maxFontScale(1.3)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .fontColor($r('app.color.text_primary'))
            .layoutWeight(1)
        }
        .id('peekDirections')
        .width('100%')
      }
    }
    .id('sheetPeek')
    .width('100%')
    .height(this.peekH() - HANDLE_H)
    .padding({ left: Space.S4 + this.sa.left, right: Space.S4 + this.sa.right, top: Space.S1, bottom: this.sa.bottom })
    .justifyContent(FlexAlign.Start)
    .clip(true)
    .backgroundColor($r('app.color.bg_surface'))
    .opacity(this.progress())
    // Fully expanded: transparent to touches and screen readers (kept in the tree so expanding crossfades).
    .hitTestBehavior(this.progress() > 0 ? HitTestMode.Default : HitTestMode.None)
    .accessibilityLevel(this.collapsed() ? 'auto' : 'no-hide-descendants')
    .onClick(() => this.settle(SheetDetent.EXPANDED, 'peek'))
    .gesture(
      PanGesture({ direction: PanDirection.Vertical, distance: 4 })
        .onActionStart(() => this.sheetDragStart())
        .onActionUpdate((e: GestureEvent) => this.sheetDragMove(e))
        .onActionEnd((e: GestureEvent) => this.sheetDragEnd(e))
        .onActionCancel(() => this.sheetDragCancel()))
  }

  @Builder
  panel() {
    // The surface runs under the navigation indicator; the scroll viewport (and so every control) stays above it.
    // §3.6.3: fixed expanded height, slid down by translateY to the peek; the peek block covers the panel's top.
    Column() {
      this.handle()
      Stack({ alignContent: Alignment.Top }) {
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
                  Button($r('app.string.walk_transcript'),
                    { type: ButtonType.Capsule, buttonStyle: ButtonStyleMode.TEXTUAL })
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
          .padding({
            left: Space.S4 + this.sa.left,
            right: Space.S4 + this.sa.right,
            top: Space.S5 - HANDLE_H / 2,
            bottom: Space.S5 + this.sa.bottom
          })
        }
        .scrollBar(BarState.Off)
        .align(Alignment.Top)
        .height('100%')
        .width('100%')
        .accessibilityLevel(this.collapsed() ? 'no-hide-descendants' : 'auto')

        this.peek()
      }
      .layoutWeight(1)
      .width('100%')
    }
    .id('sheetWalk')
    .width('100%')
    .height(this.pageH > 0 ? this.sheetH() : '45%')
    .translate({ y: this.sheetOffset() })
    .borderRadius({ topLeft: Radius.XL, topRight: Radius.XL })
    .backgroundColor($r('app.color.bg_surface'))
    .shadow(ShadowStyle.OUTER_FLOATING_SM)
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
        Stack({ alignContent: Alignment.Bottom }) {
          Column() {
            MapCanvas({
              map: this.vm.map,
              scene: this.vm.scene,
              bounds: this.vm.sceneBounds,
              follow: this.vm.scene.user !== undefined,
              followScale: 1.4,
              boxHeight: this.canvasH(),
              topInset: this.mapTopInset(),
              bottomInset: this.mapBottom(),
              mapId: 'mapWalk'
            })
              .accessibilityText($r('app.string.walk_map_a11y', this.vm.stopName))
          }
          .width('100%')
          .height('100%')

          this.panel()
        }
        .width('100%')
        .height('100%')
        .onAreaChange((_old: Area, now: Area) => {
          this.pageH = Number(now.height);
        })

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

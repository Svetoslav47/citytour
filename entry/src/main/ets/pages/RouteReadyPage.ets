/*
 * Route ready (DESIGN §3.4) + the Before-you-go sheet (§3.5). The plan comes from TourControl.plan (Held-Karp in
 * A2/A7; the scripted fake until then). A saving is claimed only when a real planner computed it and it is at
 * least 50 m. "Begin" (id btnBegin) opens the sheet; "Start walking" (id btnStartWalking) starts the tour.
 * Sheet: bindSheet + SheetOptions (doc: arkts-sheet-page).
 */
import { IssueCode } from '../contracts/EngineTypes';
import { Log } from '../app/Log';
import { LogEvents } from '../app/LogEvents';
import { AppViewModel } from '../viewmodel/AppViewModel';
import { distanceRes, durationRes } from '../viewmodel/Format';
import { OrderRow, TourPlanViewModel } from '../viewmodel/TourPlanViewModel';
import { FloatingIconButton } from '../views/common/FloatingIconButton';
import { IssueBanner } from '../views/common/IssueBanner';
import { Plaque, PlaqueState } from '../views/common/Plaque';
import { MapCanvas } from '../views/map/MapCanvas';
import { SimulatedBadge } from '../views/common/SimulatedBadge';
import { Radius, Size, Space, TABULAR, Type } from '../views/common/Tokens';

@ComponentV2
export struct RouteReadyPage {
  @Local app: AppViewModel = AppViewModel.get();
  @Local vm: TourPlanViewModel = AppViewModel.get().tourPlan;

  aboutToAppear(): void {
    this.vm.planRoute();
  }

  private async onSheetGone(): Promise<void> {
    const ok = await this.vm.onSheetGone();
    if (ok) {
      this.app.openNowWalking();
    }
  }

  @Builder
  overline(label: Resource) {
    Text(label)
      .fontSize(Type.CAPTION)
      .lineHeight(Type.CAPTION_LH)
      .fontWeight(FontWeight.Medium)
      .letterSpacing(Type.OVERLINE_SPACING)
      .textCase(TextCase.UpperCase)
      .fontColor($r('app.color.text_secondary'))
  }

  @Builder
  orderList() {
    Column() {
      ForEach(this.vm.orderRows, (row: OrderRow) => {
        Column() {
          Row({ space: Space.S3 }) {
            Plaque({ n: row.order, state: row.order === 1 ? PlaqueState.NEXT : PlaqueState.UPCOMING })
            Text(row.name !== '' ? row.name : `${row.order}`)
              .fontSize(Type.BODY)
              .fontColor($r('app.color.text_primary'))
              .layoutWeight(1)
          }
          .height(Size.TOUCH)
          .width('100%')

          if (row.legToNextM > 0) {
            Row({ space: Space.S2 }) {
              SymbolGlyph($r('sys.symbol.chevron_down'))
                .fontSize(12)
                .fontColor([$r('app.color.text_tertiary')])
              Text(distanceRes(row.legToNextM))
                .fontSize(Type.FOOTNOTE)
                .fontFeature(TABULAR)
                .fontColor($r('app.color.text_secondary'))
            }
            .padding({ left: 10 })
            .width('100%')
          }
        }
      }, (row: OrderRow) => `${row.order}:${row.poiId}`)
    }
    .width('100%')
    .margin({ top: Space.S2 })
  }

  @Builder
  planSummary() {
    if (this.vm.plan !== undefined) {
      Text() {
        Span(distanceRes(this.vm.plan.walkM))
        if (this.vm.walkMinutes() > 0) {
          Span(' · ')
          Span(durationRes(this.vm.walkMinutes()))
          Span(' ')
          Span($r('app.string.route_walking'))
        }
      }
      .fontSize(Type.BODY)
      .lineHeight(Type.BODY_LH)
      .fontFeature(TABULAR)
      .fontColor($r('app.color.text_primary'))
      .margin({ top: Space.S2 })

      Text() {
        Span('~')
        Span(durationRes(this.vm.withStoriesMinutes()))
        Span(' ')
        Span($r('app.string.tour_stat_with_stories'))
      }
      .fontSize(Type.BODY)
      .lineHeight(Type.BODY_LH)
      .fontFeature(TABULAR)
      .fontColor($r('app.color.text_secondary'))

      if (this.vm.showSaving()) {
        Row({ space: Space.S2 }) {
          SymbolGlyph($r('sys.symbol.checkmark'))
            .fontSize(16)
            .fontColor([$r('app.color.accent')])
          Text() {
            Span($r('app.string.route_optimised_prefix'))
            Span(' ')
            Span(distanceRes(this.vm.plan.savedM))
            Span(' ')
            Span($r('app.string.route_optimised_suffix'))
          }
          .fontSize(Type.CALLOUT)
          .lineHeight(Type.CALLOUT_LH)
          .fontColor($r('app.color.text_primary'))
          .layoutWeight(1)
        }
        .alignItems(VerticalAlign.Top)
        .margin({ top: 10 })
      } else if (this.vm.showListedOptimal()) {
        Text($r('app.string.route_listed_optimal'))
          .fontSize(Type.CALLOUT)
          .fontColor($r('app.color.text_secondary'))
          .margin({ top: 10 })
      }
      if (this.vm.isRealPlanner()) {
        Text($r('app.string.route_computed', this.vm.plan.ms, this.vm.plan.algo))
          .fontSize(Type.FOOTNOTE)
          .fontColor($r('app.color.text_secondary'))
          .margin({ top: Space.S1 })
      }
    }
  }

  @Builder
  sheetRow(n: number, symbol: Resource, title: Resource, body: Resource, last: boolean) {
    Row({ space: 14 }) {
      Plaque({ n: n, state: PlaqueState.NEUTRAL })
      Column({ space: 2 }) {
        Row({ space: Space.S2 }) {
          SymbolGlyph(symbol)
            .fontSize(18)
            .fontColor([$r('app.color.accent')])
          Text(title)
            .fontSize(Type.BODY)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.text_primary'))
        }
        Text(body)
          .fontSize(Type.CALLOUT)
          .lineHeight(Type.CALLOUT_LH)
          .fontColor($r('app.color.text_secondary'))
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
    }
    .alignItems(VerticalAlign.Top)
    .width('100%')
    .padding({ bottom: last ? Space.S2 : 20 })
  }

  @Builder
  beforeYouGo() {
    Column() {
      this.sheetRow(1, $r('sys.symbol.headphones'), $r('app.string.byg_headphones_title'),
        $r('app.string.byg_headphones_body'), false)
      this.sheetRow(2, $r('sys.symbol.speaker_wave_2'), $r('app.string.byg_volume_title'),
        $r('app.string.byg_volume_body'), false)
      this.sheetRow(3, $r('sys.symbol.lock_fill'), $r('app.string.byg_lock_title'),
        $r('app.string.byg_lock_body'), true)
      Text($r('app.string.byg_footnote'))
        .fontSize(Type.FOOTNOTE)
        .lineHeight(Type.FOOTNOTE_LH)
        .fontColor($r('app.color.text_secondary'))
        .margin({ top: Space.S2, bottom: Space.S4 })
      Button($r('app.string.cta_start_walking'), { type: ButtonType.Capsule, buttonStyle: ButtonStyleMode.EMPHASIZED })
        .id('btnStartWalking')
        .width('100%')
        .height(Size.BUTTON_H)
        .fontSize(Type.BODY)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.on_accent'))
        .backgroundColor($r('app.color.accent'))
        .onClick(() => this.vm.startWalking())
    }
    .width('100%')
    .padding({ left: Space.S4, right: Space.S4, top: Space.S2, bottom: Space.S5 })
  }

  @Builder
  panel() {
    Column() {
      Row() {
        Column({ space: Space.S1 }) {
          this.overline($r('app.string.route_first_stop'))
          Text(this.vm.firstStopName() !== '' ? this.vm.firstStopName() : '—')
            .fontSize(Type.TITLE2)
            .lineHeight(Type.TITLE2_LH)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.text_primary'))
            .maxLines(2)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)

        if (this.vm.orderRows.length > 0) {
          Button({ type: ButtonType.Normal, buttonStyle: ButtonStyleMode.TEXTUAL }) {
            Row({ space: 2 }) {
              Text(this.vm.showOrder ? $r('app.string.route_hide_order') : $r('app.string.route_show_order'))
                .fontSize(Type.CALLOUT)
                .fontWeight(FontWeight.Medium)
                .fontColor($r('app.color.accent'))
              SymbolGlyph(this.vm.showOrder ? $r('sys.symbol.chevron_up') : $r('sys.symbol.chevron_down'))
                .fontSize(14)
                .fontColor([$r('app.color.accent')])
            }
          }
          .id('btnShowOrder')
          .height(Size.TOUCH)
          .onClick(() => {
            this.vm.showOrder = !this.vm.showOrder;
          })
        }
      }
      .alignItems(VerticalAlign.Top)
      .width('100%')

      if (this.vm.planning) {
        Row({ space: Space.S2 }) {
          LoadingProgress()
            .width(24)
            .height(24)
            .color($r('app.color.accent'))
          Text($r('app.string.route_planning'))
            .fontSize(Type.CALLOUT)
            .fontColor($r('app.color.text_secondary'))
        }
        .margin({ top: Space.S3 })
      } else if (this.vm.planFailed) {
        IssueBanner({
          message: $r('app.string.err_plan_failed'),
          code: IssueCode.ROUTE_FALLBACK,
          actionLabel: $r('app.string.err_try_again'),
          actionId: 'btnReplan',
          onAction: () => {
            this.vm.planRoute();
          }
        })
          .margin({ top: Space.S3 })
      } else {
        this.planSummary()
      }

      if (this.vm.showOrder) {
        this.orderList()
      }

      if (this.vm.demo) {
        Text($r('app.string.route_demo_note'))
          .fontSize(Type.FOOTNOTE)
          .lineHeight(Type.FOOTNOTE_LH)
          .fontColor($r('app.color.signal_simulated_fg'))
          .margin({ top: Space.S3 })
      }

      if (this.vm.startFailed) {
        IssueBanner({ message: $r('app.string.route_start_failed'), code: IssueCode.UNCAUGHT })
          .margin({ top: Space.S3 })
      }

      Button({ type: ButtonType.Capsule, buttonStyle: ButtonStyleMode.EMPHASIZED }) {
        if (this.vm.starting) {
          LoadingProgress()
            .width(24)
            .height(24)
            .color($r('app.color.on_accent'))
        } else {
          Text($r('app.string.cta_begin'))
            .fontSize(Type.BODY)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.on_accent'))
        }
      }
      .id('btnBegin')
      .width('100%')
      .height(Size.BUTTON_H)
      .margin({ top: Space.S5 })
      .backgroundColor($r('app.color.accent'))
      .enabled(this.vm.plan !== undefined && !this.vm.planning && !this.vm.starting)
      .onClick(() => this.vm.begin())
      .bindSheet(this.vm.showSheet, this.beforeYouGo(), {
        detents: [SheetSize.FIT_CONTENT],
        dragBar: true,
        showClose: true,
        preferType: SheetType.BOTTOM,
        title: { title: $r('app.string.byg_title') },
        onDisappear: () => {
          this.onSheetGone();
        }
      })
    }
    .alignItems(HorizontalAlign.Start)
    .width('100%')
    .padding({ left: Space.S4, right: Space.S4, top: Space.S5, bottom: Space.S5 })
    .borderRadius({ topLeft: Radius.XL, topRight: Radius.XL })
    .backgroundColor($r('app.color.bg_surface'))
    .shadow(ShadowStyle.OUTER_FLOATING_SM)
  }

  build() {
    NavDestination() {
      Stack({ alignContent: Alignment.TopStart }) {
        Scroll() {
          Column() {
            MapCanvas({
              map: this.vm.map,
              scene: this.vm.orderScene.stops.length > 0 ? this.vm.orderScene : this.vm.scene,
              bounds: this.vm.orderScene.stops.length > 0 ? this.vm.orderBounds : this.vm.sceneBounds,
              boxHeight: 300,
              topInset: 56,
              mapId: 'mapRouteReady'
            })
            this.panel()
          }
          .width('100%')
        }
        .scrollBar(BarState.Off)
        .align(Alignment.Top)
        .width('100%')
        .height('100%')

        Row() {
          Row() {
            FloatingIconButton({
              symbol: $r('sys.symbol.chevron_backward'),
              label: $r('app.string.a11y_back'),
              buttonId: 'btnBackRoute',
              diameter: 36,
              onTap: () => this.app.back()
            })
            Text($r('app.string.route_title'))
              .fontSize(17)
              .fontWeight(FontWeight.Medium)
              .fontColor($r('app.color.text_primary'))
              .margin({ right: 20 })
          }
          .height(Size.TOUCH)
          .borderRadius(24)
          .backgroundColor($r('app.color.bg_scrim'))
          .backgroundBlurStyle(BlurStyle.COMPONENT_THICK)

          Blank()
          SimulatedBadge({ visible: this.vm.demo })
        }
        .width('100%')
        .padding({ left: Space.S2, right: Space.S3, top: Space.S2 })
      }
      .width('100%')
      .height('100%')
    }
    .hideTitleBar(true)
    .backgroundColor($r('app.color.bg_canvas'))
    .onShown(() => {
      Log.i(LogEvents.APP_PAGE, `page=RouteReady shown tour=${this.vm.tourId} demo=${this.vm.demo}`);
    })
  }
}

/*
 * Tour detail (DESIGN §3.3): route preview, title, stats, guide row (with the honest voice label), the stop
 * list from the pack, "About these stories" and the sticky "Start tour" (id btnStartTour). Location is checked
 * here, in context (Flow D): a denied/approximate/switched-off state shows a banner that always offers the
 * Demo walk, so the flow never dead-ends.
 */
import { AppViewModel } from '../viewmodel/AppViewModel';
import { distanceRes, durationRes, langNameRes, voiceLabelRes } from '../viewmodel/Format';
import { LocBanner, TourPlanViewModel } from '../viewmodel/TourPlanViewModel';
import { FloatingIconButton } from '../views/common/FloatingIconButton';
import { IssueBanner } from '../views/common/IssueBanner';
import { MapCanvas } from '../views/map/MapCanvas';
import { StopList } from '../views/common/StopList';
import { Radius, Size, Space, TABULAR, Type } from '../views/common/Tokens';
import { IssueCode } from '../contracts/EngineTypes';
import { Log } from '../app/Log';
import { LogEvents } from '../app/LogEvents';
import { SafeArea } from '../viewmodel/SafeArea';

@ComponentV2
export struct TourDetailPage {
  @Param tourId: string = '';
  @Local app: AppViewModel = AppViewModel.get();
  @Local vm: TourPlanViewModel = AppViewModel.get().tourPlan;
  /** Window avoid areas (edge-to-edge window, issue #63): the map runs under the status bar, the CTA bar under the
   * navigation indicator; the back button and the button stay clear of both. */
  @Local sa: SafeArea = SafeArea.get();

  aboutToAppear(): void {
    this.vm.load(this.tourId, this.app.textLang);
  }

  private async onStartTour(): Promise<void> {
    const ok = await this.vm.startTour();
    if (ok) {
      this.app.openRouteReady();
    }
  }

  private async onAllow(): Promise<void> {
    const ok = this.vm.locBanner === LocBanner.SWITCH_OFF ? await this.vm.turnOnLocationSwitch() :
      await this.vm.allowLocation();
    if (ok) {
      this.app.openRouteReady();
    }
  }

  private async onDemo(): Promise<void> {
    const ok = await this.vm.useDemo();
    if (ok) {
      this.app.openRouteReady();
    }
  }

  private bannerMessage(): Resource {
    if (this.vm.locBanner === LocBanner.APPROX) {
      return $r('app.string.err_perm_approx');
    }
    if (this.vm.locBanner === LocBanner.SWITCH_OFF) {
      return $r('app.string.err_loc_switch_off');
    }
    return $r('app.string.err_perm_denied');
  }

  private bannerAction(): Resource {
    return this.vm.locBanner === LocBanner.DENIED ? $r('app.string.err_perm_allow') :
      $r('app.string.err_perm_turn_on');
  }

  @Builder
  stat(value: ResourceStr, label: Resource) {
    Column({ space: 2 }) {
      Text(value)
        .fontSize(Type.TITLE3)
        .lineHeight(Type.TITLE3_LH)
        .fontWeight(FontWeight.Medium)
        .fontFeature(TABULAR)
        .fontColor($r('app.color.text_primary'))
      Text(label)
        .fontSize(Type.CAPTION)
        .lineHeight(Type.CAPTION_LH)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.text_secondary'))
    }
    .alignItems(HorizontalAlign.Start)
    .layoutWeight(1)
  }

  @Builder
  sectionHeader(label: Resource) {
    Text(label)
      .fontSize(Type.CAPTION)
      .lineHeight(Type.CAPTION_LH)
      .fontWeight(FontWeight.Medium)
      .letterSpacing(Type.OVERLINE_SPACING)
      .textCase(TextCase.UpperCase)
      .fontColor($r('app.color.text_secondary'))
      .margin({ top: 22, bottom: Space.S2, left: Space.S1 })
  }

  @Builder
  guideRow() {
    Row({ space: Space.S3 }) {
      Stack() {
        SymbolGlyph($r('sys.symbol.person'))
          .fontSize(18)
          .fontColor([$r('app.color.accent')])
      }
      .width(36)
      .height(36)
      .borderRadius(18)
      .backgroundColor($r('app.color.accent_subtle'))

      Column() {
        Text(this.vm.guideName)
          .fontSize(Type.BODY)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.text_primary'))
        Text() {
          Span($r('app.string.tour_your_guide'))
          Span(' · ')
          Span(langNameRes(this.vm.textLang))
          Span(' · ')
          Span(voiceLabelRes(this.vm.voiceLabel))
        }
        .fontSize(Type.FOOTNOTE)
        .lineHeight(Type.FOOTNOTE_LH)
        .fontColor($r('app.color.text_secondary'))
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
    }
    .id('rowGuide')
    .width('100%')
    .height(60)
    .padding({ left: Space.S4, right: Space.S4 })
    .borderRadius(Radius.LG)
    .backgroundColor($r('app.color.bg_surface'))
    .margin({ top: Space.S5 })
    .accessibilityGroup(true)
  }

  @Builder
  content() {
    Column() {
      Text(this.vm.title)
        .fontSize(Type.TITLE1)
        .lineHeight(Type.TITLE1_LH)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.text_primary'))
      if (this.vm.summary !== '') {
        Text(this.vm.summary)
          .fontSize(Type.BODY)
          .lineHeight(Type.BODY_LH)
          .fontColor($r('app.color.text_secondary'))
          .margin({ top: Space.S1 })
      }
      Row() {
        this.stat(this.vm.listedM > 0 ? distanceRes(this.vm.listedM) : '—', $r('app.string.tour_stat_walk'))
        if (this.vm.estMinutes > 0) {
          this.stat(durationRes(this.vm.estMinutes), $r('app.string.tour_stat_with_stories'))
        }
        this.stat(`${this.vm.stops.length}`, $r('app.string.tour_stat_stops'))
      }
      .width('100%')
      .padding({ left: Space.S1, right: Space.S1 })
      .margin({ top: Space.S5 })

      if (this.vm.guideName !== '') {
        this.guideRow()
      }

      this.sectionHeader($r('app.string.tour_stops_header'))
      StopList({ rows: this.vm.stops, tappable: true, onTapStop: (poiId: string) => this.app.openPlace(poiId) })

      this.sectionHeader($r('app.string.tour_about_stories'))
      Text(this.vm.sourcesCount === 0 ? $r('app.string.tour_about_none') :
        this.vm.allReviewed ? $r('app.string.tour_about_reviewed', this.vm.sourcesCount) :
          this.vm.aiDrafted ? $r('app.string.tour_about_ai', this.vm.sourcesCount) :
            $r('app.string.tour_about_extract', this.vm.sourcesCount))
        .fontSize(Type.CALLOUT)
        .lineHeight(Type.CALLOUT_LH)
        .fontColor($r('app.color.text_secondary'))
        .padding({ left: Space.S1, right: Space.S1 })
      Text($r('app.string.place_see_sources'))
        .id('btnSeeSources')
        .fontSize(Type.CALLOUT)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.accent'))
        .padding({ left: Space.S1, top: Space.S2, bottom: Space.S2 })
        .onClick(() => this.app.openAbout())

      Column().height((this.vm.locBanner === LocBanner.NONE ? 104 : 240) + this.sa.bottom)
    }
    .alignItems(HorizontalAlign.Start)
    .width('100%')
    .padding({ left: Space.S4 + this.sa.left, right: Space.S4 + this.sa.right, top: 18 })
  }

  @Builder
  bottomBar() {
    Column({ space: Space.S3 }) {
      if (this.vm.locBanner !== LocBanner.NONE) {
        IssueBanner({
          message: this.bannerMessage(),
          code: IssueCode.PERM_DENIED,
          actionLabel: this.bannerAction(),
          actionId: 'btnAllowLocation',
          secondaryLabel: $r('app.string.err_try_demo'),
          secondaryId: 'btnTryDemo',
          onAction: () => {
            this.onAllow();
          },
          onSecondary: () => {
            this.onDemo();
          }
        })
      }
      Button({ type: ButtonType.Capsule, buttonStyle: ButtonStyleMode.EMPHASIZED }) {
        if (this.vm.checking) {
          LoadingProgress()
            .width(24)
            .height(24)
            .color($r('app.color.on_accent'))
        } else {
          Text($r('app.string.cta_start_tour'))
            .fontSize(Type.BODY)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.on_accent'))
        }
      }
      .id('btnStartTour')
      .width('100%')
      .height(Size.BUTTON_H)
      .backgroundColor($r('app.color.accent'))
      .enabled(this.vm.found && !this.vm.checking)
      .onClick(() => {
        this.onStartTour();
      })
    }
    .width('100%')
    .padding({
      left: Space.S4 + this.sa.left,
      right: Space.S4 + this.sa.right,
      top: Space.S3,
      bottom: Space.S5 + this.sa.bottom
    })
    .backgroundColor($r('app.color.bg_surface'))
    .border({ width: { top: 1 }, color: $r('app.color.divider') })
  }

  build() {
    NavDestination() {
      Stack({ alignContent: Alignment.Bottom }) {
        Scroll() {
          Column() {
            Stack({ alignContent: Alignment.TopStart }) {
              MapCanvas({ map: this.vm.map, scene: this.vm.scene, bounds: this.vm.sceneBounds,
                boxHeight: 260 + this.sa.top, topInset: 40 + this.sa.top, mapId: 'mapTourDetail' })
                .onClick(() => this.app.openFullMap('tour'))
                .accessibilityText($r('app.string.tour_map_a11y', this.vm.title, this.vm.stops.length))
              FloatingIconButton({
                symbol: $r('sys.symbol.chevron_backward'),
                label: $r('app.string.a11y_back'),
                buttonId: 'btnBack',
                onTap: () => this.app.back()
              })
                .margin({ left: Space.S1 + this.sa.left, top: Space.S1 + this.sa.top })
            }
            .width('100%')

            if (this.vm.found) {
              this.content()
            } else {
              Text($r('app.string.tour_not_found'))
                .fontSize(Type.BODY)
                .fontColor($r('app.color.text_secondary'))
                .padding(Space.S4)
            }
          }
          .width('100%')
        }
        .scrollBar(BarState.Off)
        .align(Alignment.Top)
        .width('100%')
        .height('100%')

        this.bottomBar()
      }
      .width('100%')
      .height('100%')
    }
    .hideTitleBar(true)
    .backgroundColor($r('app.color.bg_canvas'))
    .onShown(() => {
      Log.i(LogEvents.APP_PAGE, `page=TourDetail shown tour=${this.vm.tourId} stops=${this.vm.stops.length}`);
    })
  }
}

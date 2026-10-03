/*
 * Home (DESIGN §3.2): the "Now walking" continue card when a tour runs, the Royal Route card, a one-tap
 * "Try a demo walk" (id btnDemoWalk, SIMULATED) and the offline place count. Root content of the Navigation.
 */
import { StopStatus } from '../contracts/EngineTypes';
import { AppViewModel, PackState, Routes } from '../viewmodel/AppViewModel';
import { distanceRes, durationRes } from '../viewmodel/Format';
import { HomeViewModel } from '../viewmodel/HomeViewModel';
import { IssueBanner } from '../views/common/IssueBanner';
import { MapCanvas } from '../views/map/MapCanvas';
import { SimulatedBadge } from '../views/common/SimulatedBadge';
import { Radius, Size, Space, TABULAR, Type } from '../views/common/Tokens';
import { IssueCode, StopProgress } from '../contracts/EngineTypes';

@ComponentV2
export struct HomePage {
  @Local app: AppViewModel = AppViewModel.get();
  @Local vm: HomeViewModel = new HomeViewModel();

  aboutToAppear(): void {
    this.vm.attach();
    if (this.app.packState === PackState.READY) {
      this.vm.refresh(this.app.textLang);
    }
  }

  aboutToDisappear(): void {
    this.vm.detach();
  }

  @Monitor('app.packState', 'app.textLang')
  onPackChanged(): void {
    if (this.app.packState === PackState.READY) {
      this.vm.refresh(this.app.textLang);
    }
  }

  private async onDemoWalk(): Promise<void> {
    const ok = await this.vm.tryDemoWalk();
    if (ok) {
      this.app.openNowWalking();
    }
  }

  private confirmEnd(): void {
    const s = this.vm.snap;
    const visited = s === undefined ? 0 : s.stops.filter((p: StopProgress) => p.status === StopStatus.VISITED).length;
    try {
      this.getUIContext().showAlertDialog({
        title: $r('app.string.end_dialog_title'),
        message: $r('app.string.end_dialog_msg', visited, this.vm.totalStops()),
        primaryButton: {
          value: $r('app.string.cta_keep_walking'),
          action: () => {}
        },
        secondaryButton: {
          value: $r('app.string.cta_end_tour'),
          fontColor: $r('app.color.signal_error'),
          action: () => this.vm.endTour()
        }
      });
    } catch (e) {
      this.vm.endTour();
    }
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
      .margin({ top: 28, bottom: Space.S2, left: Space.S1 })
  }

  @Builder
  header() {
    Column({ space: 2 }) {
      Row() {
        Text($r('app.string.home_title'))
          .fontSize(Type.TITLE1)
          .lineHeight(Type.TITLE1_LH)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.text_primary'))
          .layoutWeight(1)
        // DESIGN §3.2: gearshape -> Settings (B9). 48 vp hit area.
        Stack() {
          SymbolGlyph($r('sys.symbol.gearshape'))
            .fontSize(24)
            .fontColor([$r('app.color.text_primary')])
        }
        .id('btnSettings')
        .width(Size.TOUCH)
        .height(Size.TOUCH)
        .margin({ right: -Space.S3 })
        .accessibilityText($r('app.string.a11y_settings'))
        .onClick(() => this.app.openSettingsPage(Routes.SETTINGS, ''))
      }
      .height(56)
      .width('100%')

      Row({ space: Space.S1 }) {
        Text($r('app.string.offline_ready'))
          .fontSize(Type.CALLOUT)
          .lineHeight(Type.CALLOUT_LH)
          .fontColor($r('app.color.text_secondary'))
        SymbolGlyph($r('sys.symbol.checkmark'))
          .fontSize(14)
          .fontColor([$r('app.color.accent')])
      }
    }
    .alignItems(HorizontalAlign.Start)
    .width('100%')
  }

  @Builder
  continueCard() {
    Column({ space: Space.S2 }) {
      Row() {
        Text($r('app.string.home_now_walking'))
          .fontSize(Type.CAPTION)
          .fontWeight(FontWeight.Medium)
          .letterSpacing(Type.OVERLINE_SPACING)
          .textCase(TextCase.UpperCase)
          .fontColor($r('app.color.text_secondary'))
        Blank()
        SimulatedBadge({ visible: this.vm.isDemo() })
        Row({ space: 6 }) {
          Column()
            .width(8)
            .height(8)
            .borderRadius(4)
            .backgroundColor(this.vm.snap?.paused ? $r('app.color.text_tertiary') : $r('app.color.accent'))
          Text(this.vm.snap?.paused ? $r('app.string.home_paused') : $r('app.string.home_live'))
            .fontSize(Type.CAPTION)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.text_secondary'))
        }
        .margin({ left: Space.S2 })
      }
      .width('100%')

      Text(this.vm.title)
        .fontSize(Type.TITLE3)
        .lineHeight(Type.TITLE3_LH)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.text_primary'))
      Text($r('app.string.home_continue_line', this.vm.currentStopNumber(), this.vm.totalStops(),
        this.vm.currentStopName))
        .fontSize(Type.CALLOUT)
        .lineHeight(Type.CALLOUT_LH)
        .fontColor($r('app.color.text_secondary'))
      Progress({ value: this.vm.progressPct(), total: 100, type: ProgressType.Linear })
        .color($r('app.color.accent'))
        .backgroundColor($r('app.color.divider'))
        .style({ strokeWidth: 4 })
        .width('100%')
        .accessibilityText($r('app.string.home_progress_a11y', this.vm.currentStopNumber(), this.vm.totalStops()))
      Row() {
        Button($r('app.string.home_open'), { type: ButtonType.Capsule, buttonStyle: ButtonStyleMode.NORMAL })
          .id('btnOpenWalking')
          .height(36)
          .fontSize(Type.CALLOUT)
          .fontColor($r('app.color.accent'))
          .backgroundColor($r('app.color.accent_subtle'))
          .accessibilityText($r('app.string.home_open_a11y'))
          .onClick(() => this.app.openNowWalking())
        Blank()
        Button($r('app.string.cta_end_tour'), { type: ButtonType.Capsule, buttonStyle: ButtonStyleMode.TEXTUAL })
          .id('btnEndTourHome')
          .height(Size.TOUCH)
          .fontSize(Type.CALLOUT)
          .fontColor($r('app.color.signal_error'))
          .onClick(() => this.confirmEnd())
      }
      .width('100%')
    }
    .alignItems(HorizontalAlign.Start)
    .width('100%')
    .padding({ left: Space.S4, right: Space.S4, top: Space.S4, bottom: Space.S2 })
    .borderRadius(Radius.LG)
    .backgroundColor($r('app.color.bg_surface'))
    .margin({ top: Space.S5 })
  }

  @Builder
  tourCard() {
    Column() {
      MapCanvas({ map: this.vm.map, scene: this.vm.mapScene, bounds: this.vm.mapBounds, boxHeight: 180,
        mapId: 'mapHome' })
      Column({ space: 2 }) {
        Text(this.vm.title)
          .fontSize(Type.TITLE3)
          .lineHeight(Type.TITLE3_LH)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.text_primary'))
        if (this.vm.firstStop !== '' && this.vm.lastStop !== '') {
          Text($r('app.string.home_tour_from_to', this.vm.firstStop, this.vm.lastStop))
            .fontSize(Type.CALLOUT)
            .lineHeight(Type.CALLOUT_LH)
            .fontColor($r('app.color.text_secondary'))
        }
        Text() {
          Span($r('app.string.home_stops_n', this.vm.stopCount))
          if (this.vm.listedM > 0) {
            Span(' · ')
            Span(distanceRes(this.vm.listedM))
          }
          if (this.vm.estMinutes > 0) {
            Span(' · ~')
            Span(durationRes(this.vm.estMinutes))
          }
        }
        .fontSize(Type.FOOTNOTE)
        .lineHeight(Type.FOOTNOTE_LH)
        .fontFeature(TABULAR)
        .fontColor($r('app.color.text_secondary'))

        Row({ space: Space.S2 }) {
          if (this.vm.guideName !== '') {
            Row({ space: 6 }) {
              SymbolGlyph($r('sys.symbol.person'))
                .fontSize(14)
                .fontColor([$r('app.color.text_secondary')])
              Text(this.vm.guideName)
                .fontSize(Type.CAPTION)
                .fontWeight(FontWeight.Medium)
                .fontColor($r('app.color.text_secondary'))
            }
            .height(28)
            .padding({ left: 10, right: 10 })
            .borderRadius(Radius.SM)
            .border({ width: 1, color: $r('app.color.divider') })
          }
          Text('EN · 中文 · PL')
            .fontSize(Type.CAPTION)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.text_secondary'))
            .height(28)
            .padding({ left: 10, right: 10 })
            .borderRadius(Radius.SM)
            .border({ width: 1, color: $r('app.color.divider') })
        }
        .margin({ top: Space.S2 })
      }
      .alignItems(HorizontalAlign.Start)
      .width('100%')
      .padding({ left: Space.S4, right: Space.S4, top: 14, bottom: Space.S4 })
    }
    .id('cardTour')
    .width('100%')
    .borderRadius(Radius.LG)
    .clip(true)
    .backgroundColor($r('app.color.bg_surface'))
    .accessibilityGroup(true)
    .onClick(() => this.app.openTour(this.vm.tourId))
  }

  @Builder
  demoButton() {
    Column({ space: Space.S2 }) {
      Button({ type: ButtonType.Capsule, buttonStyle: ButtonStyleMode.NORMAL }) {
        Row({ space: Space.S2 }) {
          if (this.vm.startingDemo) {
            LoadingProgress()
              .width(20)
              .height(20)
              .color($r('app.color.accent'))
          } else {
            SymbolGlyph($r('sys.symbol.figure_walk'))
              .fontSize(18)
              .fontColor([$r('app.color.accent')])
          }
          Text($r('app.string.home_demo_walk'))
            .fontSize(Type.BODY)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.accent'))
        }
      }
      .id('btnDemoWalk')
      .width('100%')
      .height(Size.BUTTON_H)
      .backgroundColor($r('app.color.accent_subtle'))
      .enabled(!this.vm.startingDemo && this.vm.hasTour)
      .onClick(() => {
        this.onDemoWalk();
      })

      Text($r('app.string.home_demo_walk_hint'))
        .fontSize(Type.FOOTNOTE)
        .lineHeight(Type.FOOTNOTE_LH)
        .fontColor($r('app.color.text_secondary'))
        .padding({ left: Space.S1, right: Space.S1 })

      if (this.vm.demoFailed) {
        IssueBanner({ message: $r('app.string.route_start_failed'), code: IssueCode.UNCAUGHT })
      }
    }
    .margin({ top: Space.S3 })
  }

  @Builder
  exploreRow() {
    Row({ space: Space.S3 }) {
      Stack() {
        SymbolGlyph($r('sys.symbol.map'))
          .fontSize(20)
          .fontColor([$r('app.color.text_primary')])
      }
      .width(36)
      .height(36)
      .borderRadius(10)
      .backgroundColor($r('app.color.bg_surface_sunken'))

      Column() {
        Text($r('app.string.home_all_places'))
          .fontSize(Type.BODY)
          .lineHeight(Type.BODY_LH)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.text_primary'))
        Text($r('app.string.home_places_count', this.vm.placesCount))
          .fontSize(Type.CALLOUT)
          .lineHeight(Type.CALLOUT_LH)
          .fontFeature(TABULAR)
          .fontColor($r('app.color.text_secondary'))
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
    }
    .width('100%')
    .padding({ left: Space.S4, right: Space.S3, top: 10, bottom: 10 })
    .borderRadius(Radius.LG)
    .backgroundColor($r('app.color.bg_surface'))
    .accessibilityGroup(true)
  }

  @Builder
  packError() {
    Column({ space: Space.S2 }) {
      SymbolGlyph($r('sys.symbol.exclamationmark_triangle_fill'))
        .fontSize(32)
        .fontColor([$r('app.color.text_secondary')])
      Text($r('app.string.home_pack_error_title'))
        .fontSize(Type.TITLE3)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.text_primary'))
        .textAlign(TextAlign.Center)
      Text($r('app.string.home_pack_error_body'))
        .fontSize(Type.CALLOUT)
        .fontColor($r('app.color.text_secondary'))
        .textAlign(TextAlign.Center)
    }
    .width('100%')
    .padding(Space.S6)
    .margin({ top: Space.S6 })
  }

  build() {
    Scroll() {
      Column() {
        this.header()
        if (this.app.packState === PackState.LOADING) {
          Row({ space: Space.S2 }) {
            LoadingProgress()
              .width(24)
              .height(24)
              .color($r('app.color.accent'))
            Text($r('app.string.home_loading'))
              .fontSize(Type.CALLOUT)
              .fontColor($r('app.color.text_secondary'))
          }
          .margin({ top: Space.S6 })
        } else if (this.app.packState === PackState.ERROR) {
          this.packError()
        } else {
          if (this.vm.sessionActive()) {
            this.continueCard()
          }
          this.sectionHeader($r('app.string.home_guided_tours'))
          if (this.vm.hasTour) {
            this.tourCard()
          }
          this.demoButton()
          this.sectionHeader($r('app.string.home_explore'))
          this.exploreRow()
        }
      }
      .alignItems(HorizontalAlign.Start)
      .width('100%')
      .constraintSize({ maxWidth: Size.PAGE_MAX_W })
      .padding({ left: Space.S4, right: Space.S4, bottom: Space.S5 })
    }
    .id('pageHome')
    .scrollBar(BarState.Off)
    .align(Alignment.Top)
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.bg_canvas'))
  }
}

/*
 * Home (DESIGN §3.2): the "Now walking" continue card when a tour runs, the tour card (cover photo, or the route map
 * when the course has no cover), a one-tap
 * "Try a demo walk" (id btnDemoWalk, SIMULATED; only for the Kraków course) and the offline place count. Root
 * content of the Navigation. The app ships no built-in course: with none installed Home shows the empty state
 * "Download your first walk" (id cardNoCourse, button btnBrowseWalks -> Courses); a course that fails to load shows
 * the error state with a way to Courses (btnHomeCourses).
 */
import { StopStatus } from '../contracts/EngineTypes';
import { AppViewModel, PackState, Routes } from '../viewmodel/AppViewModel';
import { distanceRes, durationRes } from '../viewmodel/Format';
import { HomeViewModel } from '../viewmodel/HomeViewModel';
import { IssueBanner } from '../views/common/IssueBanner';
import { MapCanvas } from '../views/map/MapCanvas';
import { CoverPhoto } from '../views/common/CoverPhoto';
import { CoverView } from '../core/remote/CoverRules';
import { SimulatedBadge } from '../views/common/SimulatedBadge';
import { Radius, Size, Space, TABULAR, Type } from '../views/common/Tokens';
import { IssueCode, StopProgress } from '../contracts/EngineTypes';
import { SafeArea } from '../viewmodel/SafeArea';

@ComponentV2
export struct HomePage {
  @Local app: AppViewModel = AppViewModel.get();
  @Local vm: HomeViewModel = new HomeViewModel();
  /** Window avoid areas (edge-to-edge window, issue #63). */
  @Local sa: SafeArea = SafeArea.get();

  aboutToAppear(): void {
    this.vm.attach();
    if (this.app.packState === PackState.READY) {
      this.vm.refresh(this.app.textLang);
    }
  }

  aboutToDisappear(): void {
    this.vm.detach();
  }

  @Monitor('app.packState', 'app.textLang', 'app.courseRev')
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

      if (this.app.packState === PackState.READY) {
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
      // Cover photo (16:10, full bleed; the card clips the top corners); the map preview when the course has none.
      if (this.vm.cover.view() === CoverView.FALLBACK) {
        MapCanvas({ map: this.vm.map, scene: this.vm.mapScene, bounds: this.vm.mapBounds, boxHeight: 180,
          mapId: 'mapHome' })
      } else {
        CoverPhoto({
          path: this.vm.cover.path,
          credit: this.vm.cover.credit,
          alt: $r('app.string.cover_alt_title', this.vm.title),
          ratio: 16 / 10,
          photoId: 'coverHome'
        })
      }
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
    .id('rowAllPlaces')
    .onClick(() => this.app.openFullMap('explore'))   // B13: full map, explore mode (all places)
  }

  /** SERVER.md §6: Home -> Courses. Hidden when the build has no course server (RemoteConfig.BASE_URL ''). */
  @Builder
  coursesRow() {
    Row({ space: Space.S3 }) {
      Stack() {
        SymbolGlyph($r('sys.symbol.arrow_down_circle'))
          .fontSize(20)
          .fontColor([$r('app.color.text_primary')])
      }
      .width(36)
      .height(36)
      .borderRadius(10)
      .backgroundColor($r('app.color.bg_surface_sunken'))

      Column() {
        Text($r('app.string.home_more_courses'))
          .fontSize(Type.BODY)
          .lineHeight(Type.BODY_LH)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.text_primary'))
        Text($r('app.string.home_more_courses_sub'))
          .fontSize(Type.CALLOUT)
          .lineHeight(Type.CALLOUT_LH)
          .fontColor($r('app.color.text_secondary'))
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)

      SymbolGlyph($r('sys.symbol.chevron_right'))
        .fontSize(16)
        .fontColor([$r('app.color.text_tertiary')])
    }
    .id('rowMoreCourses')
    .width('100%')
    .constraintSize({ minHeight: Size.TOUCH })
    .padding({ left: Space.S4, right: Space.S3, top: 10, bottom: 10 })
    .borderRadius(Radius.LG)
    .backgroundColor($r('app.color.bg_surface'))
    .margin({ top: Space.S2 })
    .accessibilityGroup(true)
    .accessibilityText($r('app.string.courses_a11y_open'))
    .onClick(() => this.app.openCourses())
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
      if (this.vm.coursesEnabled()) {
        Button($r('app.string.home_open_courses'), { type: ButtonType.Capsule, buttonStyle: ButtonStyleMode.NORMAL })
          .id('btnHomeCourses')
          .height(Size.BUTTON_H)
          .fontSize(Type.BODY)
          .fontColor($r('app.color.accent'))
          .backgroundColor($r('app.color.accent_subtle'))
          .margin({ top: Space.S2 })
          .onClick(() => this.app.openCourses())
      }
    }
    .width('100%')
    .padding(Space.S6)
    .margin({ top: Space.S6 })
  }

  /** First run (or the last course deleted): nothing to walk yet, one clear way to the Courses screen. */
  @Builder
  noCourse() {
    Column({ space: Space.S3 }) {
      Stack() {
        SymbolGlyph($r('sys.symbol.arrow_down_circle'))
          .fontSize(32)
          .fontColor([$r('app.color.accent')])
      }
      .width(64)
      .height(64)
      .borderRadius(32)
      .backgroundColor($r('app.color.accent_subtle'))

      Text($r('app.string.home_empty_title'))
        .fontSize(Type.TITLE3)
        .lineHeight(Type.TITLE3_LH)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.text_primary'))
        .textAlign(TextAlign.Center)
      Text(this.vm.coursesEnabled() ? $r('app.string.home_empty_body') : $r('app.string.courses_no_server_note'))
        .fontSize(Type.CALLOUT)
        .lineHeight(Type.CALLOUT_LH)
        .fontColor($r('app.color.text_secondary'))
        .textAlign(TextAlign.Center)
      if (this.vm.coursesEnabled()) {
        Button($r('app.string.home_empty_cta'), { type: ButtonType.Capsule, buttonStyle: ButtonStyleMode.EMPHASIZED })
          .id('btnBrowseWalks')
          .width('100%')
          .height(Size.BUTTON_H)
          .fontSize(Type.BODY)
          .backgroundColor($r('app.color.accent'))
          .margin({ top: Space.S2 })
          .onClick(() => this.app.openCourses())
      }
    }
    .id('cardNoCourse')
    .width('100%')
    .padding(Space.S5)
    .borderRadius(Radius.LG)
    .backgroundColor($r('app.color.bg_surface'))
    .margin({ top: Space.S6 })
  }

  build() {
    // Edge-to-edge window (issue #63): the canvas colour runs under the status bar and the navigation indicator.
    // The list scrolls below the status bar (top inset on the frame); its end clears the navigation indicator.
    Column() {
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
          } else if (this.app.packState === PackState.NO_COURSE) {
            this.noCourse()
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
            if (this.vm.demoOffered) {
              this.demoButton()
            }
            this.sectionHeader($r('app.string.home_explore'))
            this.exploreRow()
            if (this.vm.coursesEnabled()) {
              this.coursesRow()
            }
          }
        }
        .alignItems(HorizontalAlign.Start)
        .width('100%')
        .constraintSize({ maxWidth: Size.PAGE_MAX_W })
        .padding({ left: Space.S4, right: Space.S4, bottom: Space.S5 + this.sa.bottom })
      }
      .id('pageHome')
      .scrollBar(BarState.Off)
      .align(Alignment.Top)
      .width('100%')
      .layoutWeight(1)
    }
    .width('100%')
    .height('100%')
    .padding({ top: this.sa.top, left: this.sa.left, right: this.sa.right })
    .backgroundColor($r('app.color.bg_canvas'))
  }
}

/*
 * Home (DESIGN §3.2; SERVER.md §6 "Home"): the walks of the current city straight from the catalog, one tap to walk.
 * Header "You're in {city}" (a real fix inside the city's bbox) or "Walks in {city}" (core/remote/HomeRules). The
 * "Now walking" continue card when a tour runs; then one card per walk (cover 16:10, title, stops · km · ~min,
 * languages) with its actions ON the card: Start (id btnStartWalk: stream it if needed, check location, plan every
 * stop, start, Now Walking; no Route ready), Demo walk (id btnDemoWalk, SIMULATED), a small offline button
 * (download / progress ring / downloaded) and ⋯ / long-press "Remove download". The running walk's card says
 * Continue; another card's Start first asks to end the running tour. Tapping the cover or title opens Tour detail.
 * "All places in {city}" below (download-gated). Ids of the second and later cards end in _<course id>.
 * There is no separate Courses page in the flow.
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
import { CardDownload, CardPrimary, HomeHeader } from '../core/remote/HomeRules';
import { CatalogNote, CourseItem } from '../viewmodel/CoursesViewModel';
import { LocBanner } from '../viewmodel/TourPlanViewModel';
import { Log } from '../app/Log';
import { LogEvents } from '../app/LogEvents';

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
    this.vm.loadWalks(this.app.textLang);
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

  /** Card Start / Demo walk: Continue for the running walk; another walk first ends the running tour (confirm). */
  private onStart(it: CourseItem, demo: boolean): void {
    const a = this.vm.card(it);
    if (a.primary === CardPrimary.CONTINUE && !demo) {
      this.app.openNowWalking();
      return;
    }
    if (a.confirmEnd) {
      this.confirmEnd(() => {
        this.run(it.id, demo);
      });
      return;
    }
    this.run(it.id, demo);
  }

  private async run(id: string, demo: boolean): Promise<void> {
    if (await this.vm.startWalk(id, demo)) {
      this.app.openNowWalking();
    }
  }

  private async onAllow(): Promise<void> {
    if (await this.vm.allowAndStart()) {
      this.app.openNowWalking();
    }
  }

  private async onDemoInstead(): Promise<void> {
    if (await this.vm.demoInstead()) {
      this.app.openNowWalking();
    }
  }

  /** Cover / title: Tour detail of that walk (made the active course first when needed). */
  private async onOpen(it: CourseItem): Promise<void> {
    if (this.vm.startingId !== '') {
      return;
    }
    const id = await this.vm.openWalk(it.id);
    if (id !== '') {
      this.app.openTour(id);
    }
  }

  private confirmRemove(it: CourseItem): void {
    if (!this.vm.card(it).canRemove) {
      return;
    }
    try {
      this.getUIContext().showAlertDialog({
        title: $r('app.string.home_remove_title'),
        message: it.active ? $r('app.string.courses_delete_active_msg') : $r('app.string.courses_delete_msg'),
        primaryButton: {
          value: $r('app.string.courses_cancel'),
          action: () => {}
        },
        secondaryButton: {
          value: $r('app.string.home_remove_download'),
          fontColor: $r('app.color.signal_error'),
          action: () => {
            this.vm.courses.remove(it.id);
          }
        }
      });
    } catch (e) {
      Log.e(LogEvents.UNCAUGHT, `where=HomePage.confirmRemove ${Log.errKv(e as Object)}`);
    }
  }

  private bannerMessage(): Resource {
    if (this.vm.gate.locBanner === LocBanner.APPROX) {
      return $r('app.string.err_perm_approx');
    }
    if (this.vm.gate.locBanner === LocBanner.SWITCH_OFF) {
      return $r('app.string.err_loc_switch_off');
    }
    return $r('app.string.err_perm_denied');
  }

  private bannerAction(): Resource {
    return this.vm.gate.locBanner === LocBanner.DENIED ? $r('app.string.err_perm_allow') :
      $r('app.string.err_perm_turn_on');
  }

  private confirmEnd(then?: () => void): void {
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
          action: () => {
            this.vm.endTour();
            if (then !== undefined) {
              then();
            }
          }
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
        Text(this.vm.cityLabel === '' ? $r('app.string.home_walks_any') :
          (this.vm.header === HomeHeader.IN_CITY ? $r('app.string.home_in_city', this.vm.cityLabel) :
            $r('app.string.home_walks_in', this.vm.cityLabel)))
          .id('txtHomeCity')
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
          .onClick(() => this.confirmEnd(undefined))
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

  /** Card ids: the first walk keeps the short ids (btnStartWalk, btnDemoWalk); the others add _<course id>. */
  private cardId(base: string, it: CourseItem): string {
    const list = this.vm.walks();
    return list.length > 0 && list[0].id === it.id ? base : `${base}_${it.id}`;
  }

  @Builder
  chip(text: ResourceStr) {
    Text(text)
      .fontSize(Type.CAPTION)
      .fontWeight(FontWeight.Medium)
      .fontColor($r('app.color.text_secondary'))
      .height(28)
      .padding({ left: 10, right: 10 })
      .borderRadius(Radius.SM)
      .border({ width: 1, color: $r('app.color.divider') })
  }

  /** Small offline button: download / progress ring / downloaded check. */
  @Builder
  downloadButton(it: CourseItem) {
    if (this.vm.card(it).download === CardDownload.PROGRESS) {
      Stack() {
        Progress({ value: it.pct, total: 100, type: ProgressType.Ring })
          .width(28)
          .height(28)
          .color($r('app.color.accent'))
          .style({ strokeWidth: 3 })
      }
      .id(this.cardId('btnWalkDownload', it))
      .width(Size.TOUCH)
      .height(Size.TOUCH)
      .accessibilityText($r('app.string.courses_downloading', `${it.pct}%`))
      .onClick(() => this.vm.courses.cancel(it.id))
    } else if (this.vm.card(it).download === CardDownload.DONE) {
      Stack() {
        SymbolGlyph($r('sys.symbol.checkmark_circle_fill'))
          .fontSize(22)
          .fontColor([$r('app.color.accent')])
      }
      .id(this.cardId('btnWalkDownload', it))
      .width(Size.TOUCH)
      .height(Size.TOUCH)
      .accessibilityText($r('app.string.home_downloaded_a11y'))
      .onClick(() => this.confirmRemove(it))
    } else if (this.vm.card(it).download === CardDownload.DOWNLOAD) {
      Stack() {
        SymbolGlyph($r('sys.symbol.arrow_down_circle'))
          .fontSize(22)
          .fontColor([$r('app.color.text_secondary')])
      }
      .id(this.cardId('btnWalkDownload', it))
      .width(Size.TOUCH)
      .height(Size.TOUCH)
      .accessibilityText(it.size !== '' ? $r('app.string.courses_download', it.size) :
        $r('app.string.home_download_a11y'))
      .onClick(() => {
        this.vm.courses.download(it.id);
      })
    }
  }

  @Builder
  primaryButton(it: CourseItem) {
    Button({ type: ButtonType.Capsule, buttonStyle: ButtonStyleMode.EMPHASIZED }) {
      Row({ space: Space.S2 }) {
        if (this.vm.card(it).primary === CardPrimary.PREPARING) {
          LoadingProgress()
            .width(20)
            .height(20)
            .color($r('app.color.on_accent'))
          Text($r('app.string.courses_preparing'))
            .fontSize(Type.BODY)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.on_accent'))
        } else {
          SymbolGlyph(this.vm.card(it).primary === CardPrimary.CONTINUE ? $r('sys.symbol.figure_walk') :
            $r('sys.symbol.play_fill'))
            .fontSize(18)
            .fontColor([$r('app.color.on_accent')])
          Text(this.vm.card(it).primary === CardPrimary.CONTINUE ? $r('app.string.home_continue') :
            $r('app.string.home_start'))
            .fontSize(Type.BODY)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.on_accent'))
        }
      }
    }
    .id(this.cardId('btnStartWalk', it))
    .layoutWeight(1)
    .height(Size.BUTTON_H)
    .backgroundColor($r('app.color.accent'))
    .enabled(this.vm.card(it).enabled && this.vm.startingId === '')
    .onClick(() => this.onStart(it, false))
  }

  @Builder
  demoButton(it: CourseItem) {
    Button({ type: ButtonType.Capsule, buttonStyle: ButtonStyleMode.NORMAL }) {
      Text($r('app.string.home_demo_short'))
        .fontSize(Type.BODY)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.accent'))
    }
    .id(this.cardId('btnDemoWalk', it))
    .height(Size.BUTTON_H)
    .padding({ left: Space.S4, right: Space.S4 })
    .backgroundColor($r('app.color.accent_subtle'))
    .accessibilityText($r('app.string.home_demo_a11y'))
    .enabled(this.vm.card(it).enabled && this.vm.startingId === '')
    .onClick(() => this.onStart(it, true))
  }

  /** One walk: cover, title, stats, languages; Start / Demo walk and the offline button on the card itself. */
  @Builder
  walkCard(it: CourseItem) {
    Column() {
      if (it.hasCover) {
        CoverPhoto({
          path: it.coverPath,
          alt: $r('app.string.cover_alt_title', it.title),
          ratio: 16 / 10,
          photoId: this.cardId('coverWalk', it)
        })
          .onClick(() => this.onOpen(it))
      }
      Column({ space: 2 }) {
        Row() {
          Text(it.title)
            .fontSize(Type.TITLE3)
            .lineHeight(Type.TITLE3_LH)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.text_primary'))
            .layoutWeight(1)
            .onClick(() => this.onOpen(it))
          this.downloadButton(it)
          if (this.vm.card(it).canRemove) {
            Text('⋯')
              .id(this.cardId('btnWalkMore', it))
              .fontSize(Type.TITLE3)
              .fontColor($r('app.color.text_secondary'))
              .textAlign(TextAlign.Center)
              .width(36)
              .height(Size.TOUCH)
              .margin({ right: -Space.S2 })
              .accessibilityText($r('app.string.home_more_a11y'))
              .bindMenu([{
                value: $r('app.string.home_remove_download'),
                action: () => this.confirmRemove(it)
              }])
          }
        }
        .width('100%')
        .alignItems(VerticalAlign.Top)

        Text(it.km !== '' ? $r('app.string.home_card_meta', it.stops, it.km, it.minutes) :
          $r('app.string.home_card_meta_no_km', it.stops, it.minutes))
          .fontSize(Type.FOOTNOTE)
          .lineHeight(Type.FOOTNOTE_LH)
          .fontFeature(TABULAR)
          .fontColor($r('app.color.text_secondary'))
        if (it.langs !== '') {
          Row() {
            this.chip(it.langs)
          }
          .margin({ top: Space.S2 })
        }
        if (this.vm.card(it).showFailed) {
          Text(it.failed ? $r('app.string.courses_failed') : $r('app.string.home_start_failed'))
            .fontSize(Type.FOOTNOTE)
            .lineHeight(Type.FOOTNOTE_LH)
            .fontColor($r('app.color.signal_error'))
            .margin({ top: Space.S2 })
        }
        if (this.vm.noDemoId === it.id) {
          Text($r('app.string.home_no_demo'))
            .fontSize(Type.FOOTNOTE)
            .lineHeight(Type.FOOTNOTE_LH)
            .fontColor($r('app.color.text_secondary'))
            .margin({ top: Space.S2 })
        }
        if (this.vm.gateId === it.id && this.vm.gate.locBanner !== LocBanner.NONE) {
          IssueBanner({
            message: this.bannerMessage(),
            code: IssueCode.PERM_DENIED,
            actionLabel: this.bannerAction(),
            actionId: 'btnAllowLocation',
            secondaryLabel: this.vm.demoOffered ? $r('app.string.err_try_demo') : '',
            secondaryId: 'btnTryDemo',
            onAction: () => {
              this.onAllow();
            },
            onSecondary: () => {
              this.onDemoInstead();
            }
          })
            .margin({ top: Space.S2 })
        }
        Row({ space: Space.S2 }) {
          this.primaryButton(it)
          if (this.vm.card(it).demo) {
            this.demoButton(it)
          }
        }
        .width('100%')
        .margin({ top: Space.S3 })
      }
      .alignItems(HorizontalAlign.Start)
      .width('100%')
      .padding({ left: Space.S4, right: Space.S4, top: 14, bottom: Space.S4 })
    }
    .id(this.cardId('cardWalk', it))
    .width('100%')
    .borderRadius(Radius.LG)
    .clip(true)
    .backgroundColor($r('app.color.bg_surface'))
    .margin({ bottom: Space.S3 })
    .gesture(LongPressGesture().onAction(() => {
      if (this.vm.card(it).canRemove) {
        this.confirmRemove(it);
      }
    }))
  }

  /** Catalog notes: checking, offline (cached or nothing), no server, nothing published. */
  @Builder
  walksNote() {
    if (this.vm.courses.note === CatalogNote.LOADING && this.vm.walks().length === 0) {
      Row({ space: Space.S2 }) {
        LoadingProgress()
          .width(20)
          .height(20)
          .color($r('app.color.accent'))
        Text($r('app.string.courses_loading'))
          .fontSize(Type.CALLOUT)
          .fontColor($r('app.color.text_secondary'))
      }
      .margin({ bottom: Space.S3 })
    } else if (this.vm.courses.note === CatalogNote.DISABLED && this.vm.walks().length === 0) {
      this.noteBox($r('app.string.courses_no_server_note'), false)
    } else if (this.vm.courses.note === CatalogNote.OFFLINE_CACHED) {
      this.noteBox($r('app.string.courses_offline'), true)
    } else if (this.vm.courses.note === CatalogNote.OFFLINE_EMPTY) {
      this.noteBox($r('app.string.courses_offline_empty'), true)
    } else if (this.vm.courses.note === CatalogNote.UNVERIFIED) {
      this.noteBox($r('app.string.courses_unverified'), true)
    } else if (this.vm.courses.note === CatalogNote.NONE && this.vm.walks().length === 0) {
      this.noteBox($r('app.string.courses_empty'), true)
    }
  }

  @Builder
  noteBox(text: Resource, retry: boolean) {
    Column({ space: Space.S2 }) {
      Text(text)
        .fontSize(Type.FOOTNOTE)
        .lineHeight(Type.FOOTNOTE_LH)
        .fontColor($r('app.color.text_secondary'))
      if (retry) {
        Button($r('app.string.courses_retry'), { type: ButtonType.Capsule, buttonStyle: ButtonStyleMode.TEXTUAL })
          .id('btnCoursesRetry')
          .height(Size.TOUCH)
          .fontSize(Type.CALLOUT)
          .fontColor($r('app.color.accent'))
          .onClick(() => {
            this.vm.loadWalks(this.app.textLang);
          })
      }
    }
    .id('noteCourses')
    .alignItems(HorizontalAlign.Start)
    .width('100%')
    .padding({ left: 14, right: 14, top: 10, bottom: 10 })
    .borderRadius(Radius.MD)
    .backgroundColor($r('app.color.bg_surface_sunken'))
    .margin({ bottom: Space.S3 })
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
        Text(this.app.cityName !== '' ? $r('app.string.home_all_places', this.app.cityName) :
          $r('app.string.home_all_places_any'))
          .fontSize(Type.BODY)
          .lineHeight(Type.BODY_LH)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.text_primary'))
        Text(this.vm.allPlaces ? $r('app.string.home_places_count', this.vm.placesCount) :
          $r('app.string.home_all_places_download'))
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
    // B13: full map, explore mode (all places). A streamed walk has only its stops: a tap downloads it.
    .onClick(() => this.vm.allPlaces ? this.app.openFullMap('explore') : this.vm.downloadActive())
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
    // Edge-to-edge window (issue #63): the canvas colour runs under the status bar and the navigation indicator.
    // The list scrolls below the status bar (top inset on the frame); its end clears the navigation indicator.
    Column() {
      Scroll() {
        Column() {
          this.header()
          if (this.app.packState === PackState.ERROR) {
            this.packError()
          }
          if (this.vm.sessionActive()) {
            this.continueCard()
          }
          Column() {
            this.walksNote()
            // rebuild() makes new CourseItem objects: key on the row state too (as on the Courses rows).
            ForEach(this.vm.walks(), (it: CourseItem) => {
              this.walkCard(it)
            }, (it: CourseItem) => `${it.id}|${it.state}|${it.downloading}|${it.active}|${it.failed}|` +
              `${it.streaming}|${it.preparing}|${it.playFailed}|${it.hasCover}`)
          }
          .width('100%')
          .margin({ top: Space.S4 })
          if (this.app.packState === PackState.READY && this.vm.hasTour) {
            this.sectionHeader($r('app.string.home_explore'))
            this.exploreRow()
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

/*
 * Courses screen (docs/SERVER.md §6), opened from Home ("Browse walks" on first run, "More courses" later). The app
 * ships no built-in course: the catalog loads on open. One card per course: title in the UI language, city, stops ·
 * km · minutes, languages, and the action for its state: Download · size / progress % + Cancel / Downloaded ✓ /
 * Update / Try again / Delete, plus "Use" for a downloaded course that is not active ("In use" on the active one).
 * Notes: server disabled -> "No course server"; offline -> the cached list (or nothing) with an "Offline" note and
 * Try again; an empty catalog -> "No walks are published yet". DESIGN.md tokens (Tokens.ets, app colours),
 * SafeArea insets.
 * Ids: pageCourses, courseRow_<id>, btnCourseDownload_<id>, btnCourseCancel_<id>, btnCourseUse_<id>,
 * btnCourseDelete_<id>, noteCourses.
 */
import { Log } from '../app/Log';
import { LogEvents } from '../app/LogEvents';
import { CourseState } from '../core/remote/CourseRules';
import { AppViewModel } from '../viewmodel/AppViewModel';
import { CatalogNote, CourseItem, CoursesViewModel } from '../viewmodel/CoursesViewModel';
import { SafeArea } from '../viewmodel/SafeArea';
import { Radius, Size, Space, TABULAR, Type } from '../views/common/Tokens';
import { SettingsHeader } from '../views/settings/SettingsRows';

@ComponentV2
export struct CoursesPage {
  @Local app: AppViewModel = AppViewModel.get();
  @Local vm: CoursesViewModel = CoursesViewModel.get();
  @Local sa: SafeArea = SafeArea.get();
  @Local refreshing: boolean = false;

  aboutToAppear(): void {
    Log.i(LogEvents.APP_PAGE, 'page=Courses');
    this.vm.open(this.app.textLang);
  }

  private confirmDelete(it: CourseItem): void {
    try {
      this.getUIContext().showAlertDialog({
        title: $r('app.string.courses_delete_title'),
        message: it.active ? $r('app.string.courses_delete_active_msg') : $r('app.string.courses_delete_msg'),
        primaryButton: {
          value: $r('app.string.courses_cancel'),
          action: () => {}
        },
        secondaryButton: {
          value: $r('app.string.courses_delete'),
          fontColor: $r('app.color.signal_error'),
          action: () => {
            this.vm.remove(it.id);
          }
        }
      });
    } catch (e) {
      Log.e(LogEvents.UNCAUGHT, `where=CoursesPage.confirmDelete ${Log.errKv(e as Object)}`);
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
          .onClick(() => this.vm.retry())
      }
    }
    .id('noteCourses')
    .alignItems(HorizontalAlign.Start)
    .width('100%')
    .padding({ left: 14, right: 14, top: 10, bottom: 10 })
    .borderRadius(Radius.MD)
    .backgroundColor($r('app.color.bg_surface_sunken'))
  }

  @Builder
  notes() {
    if (this.vm.note === CatalogNote.LOADING) {
      Row({ space: Space.S2 }) {
        LoadingProgress()
          .width(20)
          .height(20)
          .color($r('app.color.accent'))
        Text($r('app.string.courses_loading'))
          .fontSize(Type.CALLOUT)
          .fontColor($r('app.color.text_secondary'))
      }
    } else if (this.vm.note === CatalogNote.DISABLED) {
      Column({ space: Space.S1 }) {
        Text($r('app.string.courses_no_server'))
          .fontSize(Type.BODY)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.text_primary'))
        Text($r('app.string.courses_no_server_note'))
          .fontSize(Type.FOOTNOTE)
          .lineHeight(Type.FOOTNOTE_LH)
          .fontColor($r('app.color.text_secondary'))
      }
      .id('noteCourses')
      .alignItems(HorizontalAlign.Start)
      .width('100%')
    } else if (this.vm.note === CatalogNote.OFFLINE_CACHED) {
      this.noteBox($r('app.string.courses_offline'), true)
    } else if (this.vm.note === CatalogNote.OFFLINE_EMPTY) {
      this.noteBox($r('app.string.courses_offline_empty'), true)
    } else if (this.vm.note === CatalogNote.UNVERIFIED) {
      this.noteBox($r('app.string.courses_unverified'), true)
    } else if (this.vm.note === CatalogNote.NONE && this.vm.items.length === 0) {
      this.noteBox($r('app.string.courses_empty'), true)
    }
    if (this.vm.tourRunning) {
      this.noteBox($r('app.string.courses_tour_running'), false)
    }
    if (this.vm.switchFailed) {
      this.noteBox($r('app.string.courses_switch_failed'), false)
    }
  }

  @Builder
  chip(text: ResourceStr) {
    Text(text)
      .fontSize(Type.CAPTION)
      .fontWeight(FontWeight.Medium)
      .fontColor($r('app.color.text_secondary'))
      .height(24)
      .padding({ left: Space.S2, right: Space.S2 })
      .borderRadius(Radius.SM)
      .border({ width: 1, color: $r('app.color.divider') })
  }

  @Builder
  primaryAction(it: CourseItem) {
    if (it.downloading) {
      Column({ space: Space.S1 }) {
        Text(it.cancelling ? $r('app.string.courses_cancelling') : $r('app.string.courses_downloading', `${it.pct}%`))
          .fontSize(Type.CALLOUT)
          .fontFeature(TABULAR)
          .fontColor($r('app.color.text_secondary'))
        Progress({ value: it.pct, total: 100, type: ProgressType.Linear })
          .color($r('app.color.accent'))
          .backgroundColor($r('app.color.divider'))
          .style({ strokeWidth: 4 })
          .width('100%')
          .accessibilityText($r('app.string.courses_downloading', `${it.pct}%`))
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
      Button($r('app.string.courses_cancel'), { type: ButtonType.Capsule, buttonStyle: ButtonStyleMode.TEXTUAL })
        .id(`btnCourseCancel_${it.id}`)
        .height(Size.TOUCH)
        .fontSize(Type.CALLOUT)
        .fontColor($r('app.color.text_secondary'))
        .enabled(!it.cancelling)
        .onClick(() => this.vm.cancel(it.id))
    } else if (it.state === CourseState.AVAILABLE || it.state === CourseState.UPDATE) {
      Button(it.failed ? $r('app.string.courses_retry') :
        (it.state === CourseState.UPDATE ? $r('app.string.courses_update') :
          (it.size !== '' ? $r('app.string.courses_download', it.size) : $r('app.string.courses_download_plain'))),
        { type: ButtonType.Capsule, buttonStyle: ButtonStyleMode.NORMAL })
        .id(`btnCourseDownload_${it.id}`)
        .height(36)
        .fontSize(Type.CALLOUT)
        .fontColor($r('app.color.accent'))
        .backgroundColor($r('app.color.accent_subtle'))
        .enabled(this.vm.enabled)
        .onClick(() => {
          this.vm.download(it.id);
        })
    } else {
      Text($r('app.string.courses_downloaded'))
        .fontSize(Type.CALLOUT)
        .fontColor($r('app.color.accent'))
    }
  }

  @Builder
  card(it: CourseItem) {
    Column({ space: Space.S2 }) {
      Row({ space: Space.S2 }) {
        Text(it.title)
          .fontSize(Type.TITLE3)
          .lineHeight(Type.TITLE3_LH)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.text_primary'))
          .layoutWeight(1)
        if (it.active) {
          Text($r('app.string.courses_active'))
            .fontSize(Type.CAPTION)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.accent'))
            .height(24)
            .padding({ left: Space.S2, right: Space.S2 })
            .borderRadius(Radius.SM)
            .backgroundColor($r('app.color.accent_subtle'))
        }
      }
      .width('100%')

      if (it.city !== '') {
        Text(it.city)
          .fontSize(Type.CALLOUT)
          .lineHeight(Type.CALLOUT_LH)
          .fontColor($r('app.color.text_secondary'))
      }
      Text(it.km !== '' ? $r('app.string.courses_meta', it.stops, it.km, it.minutes) :
        $r('app.string.courses_meta_no_km', it.stops, it.minutes))
        .fontSize(Type.FOOTNOTE)
        .lineHeight(Type.FOOTNOTE_LH)
        .fontFeature(TABULAR)
        .fontColor($r('app.color.text_secondary'))
      Row({ space: Space.S2 }) {
        if (it.langs !== '') {
          this.chip(it.langs)
        }
      }

      if (it.failed) {
        Text($r('app.string.courses_failed'))
          .fontSize(Type.FOOTNOTE)
          .lineHeight(Type.FOOTNOTE_LH)
          .fontColor($r('app.color.signal_error'))
      }

      Row({ space: Space.S2 }) {
        this.primaryAction(it)
        Blank()
        if (it.canSelect && !it.active && !it.downloading) {
          Button($r('app.string.courses_use'), { type: ButtonType.Capsule, buttonStyle: ButtonStyleMode.NORMAL })
            .id(`btnCourseUse_${it.id}`)
            .height(36)
            .fontSize(Type.CALLOUT)
            .fontColor($r('app.color.accent'))
            .backgroundColor($r('app.color.accent_subtle'))
            .enabled(!this.vm.tourRunning && !this.vm.busySwitch)
            .onClick(() => {
              this.vm.select(it.id);
            })
        }
        if (it.canDelete && !it.downloading) {
          Button($r('app.string.courses_delete'), { type: ButtonType.Capsule, buttonStyle: ButtonStyleMode.TEXTUAL })
            .id(`btnCourseDelete_${it.id}`)
            .height(Size.TOUCH)
            .fontSize(Type.CALLOUT)
            .fontColor($r('app.color.signal_error'))
            .enabled(!(it.active && this.vm.tourRunning))
            .onClick(() => this.confirmDelete(it))
        }
      }
      .width('100%')
      .margin({ top: Space.S1 })
    }
    .id(`courseRow_${it.id}`)
    .alignItems(HorizontalAlign.Start)
    .width('100%')
    .padding(Space.S4)
    .borderRadius(Radius.LG)
    .backgroundColor($r('app.color.bg_surface'))
  }

  build() {
    NavDestination() {
      // Pull down to fetch the catalog again (it is also fetched every time the page opens).
      Refresh({ refreshing: $$this.refreshing }) {
        Scroll() {
          Column() {
            SettingsHeader({ title: $r('app.string.courses_title'), backId: 'btnCoursesBack',
              onBack: () => this.app.back() })
            Column({ space: Space.S3 }) {
              this.notes()
              ForEach(this.vm.items, (it: CourseItem) => {
                this.card(it)
              }, (it: CourseItem) =>
                // rebuild() makes new CourseItem objects: key on the row state too, or ForEach keeps the old row
                // bound to the old object and never shows "downloading" / the progress bar.
                `${it.id}|${it.state}|${it.downloading}|${it.active}|${it.failed}|${it.cancelling}`)
            }
            .width('100%')
            .padding({ left: Space.S4, right: Space.S4, bottom: Space.S6 + this.sa.bottom })
          }
          .width('100%')
          .constraintSize({ maxWidth: Size.PAGE_MAX_W })
        }
        .id('pageCourses')
        .scrollBar(BarState.Off)
        .align(Alignment.Top)
        .width('100%')
        .height('100%')
      }
      .onRefreshing(() => {
        this.vm.open(this.app.textLang).finally(() => {
          this.refreshing = false;
        });
      })
    }
    .hideTitleBar(true)
    .backgroundColor($r('app.color.bg_canvas'))
    .padding({ top: this.sa.top, left: this.sa.left, right: this.sa.right })
  }
}

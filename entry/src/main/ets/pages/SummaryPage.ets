/*
 * Tour summary (B11, DESIGN §3.10): closes the loop after a tour. Header "Tour complete" / "Tour ended" with Done
 * (-> Home), the walked route on the offline map, tour title and date, the amber SIMULATED pill and note for the Demo
 * walk, the stat trio (stops heard, walked, total), "You heard" (tap -> Place detail), "Still to see" with the
 * distance from where the walk ended, and Start again (-> Tour detail).
 * No confetti, no rating prompt, no share push. Opened by Now Walking when the tour ends (SummaryViewModel.pending).
 * Ids: pageSummary, btnSummaryDone, mapSummary, badgeSimulated, txtSummarySimulated, statStops, statWalked, statTotal,
 * listHeard, listStillToSee, btnStartAgain.
 */
import { Log } from '../app/Log';
import { LogEvents } from 'common';
import { AppViewModel } from '../viewmodel/AppViewModel';
import { distanceRes, durationRes } from '../viewmodel/Format';
import { SafeArea } from '../viewmodel/SafeArea';
import { StillRow, SummaryViewModel } from '../viewmodel/SummaryViewModel';
import { Plaque, PlaqueState } from '../views/common/Plaque';
import { SimulatedBadge } from '../views/common/SimulatedBadge';
import { StopList } from '../views/common/StopList';
import { Radius, Size, Space, Type } from '../views/common/Tokens';
import { MapCanvas } from '../views/map/MapCanvas';

const MAP_H: number = 220;

@ComponentV2
export struct SummaryPage {
  @Local app: AppViewModel = AppViewModel.get();
  @Local vm: SummaryViewModel = new SummaryViewModel();
  @Local sa: SafeArea = SafeArea.get();

  aboutToAppear(): void {
    this.vm.load(this.app.textLang);
  }

  private complete(): boolean {
    return this.vm.data !== undefined && this.vm.data.complete;
  }

  private demo(): boolean {
    return this.vm.data !== undefined && this.vm.data.demo;
  }

  private stopsValue(): string {
    const d = this.vm.data;
    return d === undefined ? '—' : `${d.heardCount()}/${d.totalStops}`;
  }

  private walkedValue(): ResourceStr {
    const d = this.vm.data;
    return d === undefined || d.walkedM <= 0 ? '—' : distanceRes(d.walkedM);
  }

  private totalValue(): ResourceStr {
    const s = this.vm.totalTime();
    return Number.isFinite(s) && s > 0 ? durationRes(s / 60) : '—';
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
  stat(value: ResourceStr, caption: Resource, id: string) {
    Column({ space: 2 }) {
      Text(value)
        .fontSize(Type.TITLE2)
        .lineHeight(Type.TITLE2_LH)
        .fontWeight(FontWeight.Medium)
        .fontFeature('"tnum" 1')
        .fontColor($r('app.color.text_primary'))
        .maxLines(1)
      Text(caption)
        .fontSize(Type.CAPTION)
        .lineHeight(Type.CAPTION_LH)
        .fontColor($r('app.color.text_secondary'))
    }
    .id(id)
    .layoutWeight(1)
    .alignItems(HorizontalAlign.Start)
    .accessibilityGroup(true)
  }

  @Builder
  stillList() {
    Column() {
      ForEach(this.vm.stillRows, (row: StillRow, idx: number) => {
        Row({ space: 14 }) {
          Plaque({ n: row.order, state: row.skipped ? PlaqueState.SKIPPED : PlaqueState.UPCOMING })
          Text(row.name)
            .fontSize(Type.BODY)
            .lineHeight(Type.BODY_LH)
            .fontColor($r('app.color.text_primary'))
            .maxLines(2)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .layoutWeight(1)
          if (Number.isFinite(row.distanceM)) {
            Text(distanceRes(row.distanceM))
              .fontSize(Type.FOOTNOTE)
              .lineHeight(Type.FOOTNOTE_LH)
              .fontFeature('"tnum" 1')
              .fontColor($r('app.color.text_secondary'))
          }
          SymbolGlyph($r('sys.symbol.chevron_right'))
            .fontSize(16)
            .fontColor([$r('app.color.text_tertiary')])
        }
        .width('100%')
        .height(Size.TOUCH)
        .padding({ left: 10, right: 12 })
        .border({ width: { top: idx === 0 ? 0 : 1 }, color: $r('app.color.divider') })
        .accessibilityGroup(true)
        .onClick(() => this.app.openPlace(row.poiId))
      }, (row: StillRow) => `${row.order}:${row.poiId}`)
    }
    .id('listStillToSee')
    .width('100%')
    .padding({ top: Space.S1, bottom: Space.S1 })
    .borderRadius(Radius.LG)
    .backgroundColor($r('app.color.bg_surface'))
  }

  @Builder
  body() {
    Column() {
      Stack() {
        MapCanvas({
          map: this.vm.map,
          scene: this.vm.scene,
          bounds: this.vm.sceneBounds,
          boxHeight: MAP_H,
          mapId: 'mapSummary'
        })
          .accessibilityText($r('app.string.summary_map_a11y'))
      }
      .width('100%')
      .height(MAP_H)
      .borderRadius(Radius.LG)
      .clip(true)

      Text(this.vm.tourTitle)
        .fontSize(Type.TITLE1)
        .lineHeight(Type.TITLE1_LH)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.text_primary'))
        .margin({ top: Space.S5 })
      if (this.vm.dateText !== '') {
        Text(this.vm.dateText)
          .fontSize(Type.CALLOUT)
          .lineHeight(Type.CALLOUT_LH)
          .fontColor($r('app.color.text_secondary'))
          .margin({ top: Space.S1 })
      }
      if (this.demo()) {
        Column({ space: Space.S2 }) {
          SimulatedBadge({ visible: true })
          Text($r('app.string.summary_simulated'))
            .id('txtSummarySimulated')
            .fontSize(Type.FOOTNOTE)
            .lineHeight(Type.FOOTNOTE_LH)
            .fontColor($r('app.color.text_secondary'))
        }
        .alignItems(HorizontalAlign.Start)
        .margin({ top: Space.S3 })
      }

      Row({ space: Space.S3 }) {
        this.stat(this.stopsValue(), $r('app.string.summary_stops'), 'statStops')
        this.stat(this.walkedValue(), $r('app.string.summary_walked'), 'statWalked')
        this.stat(this.totalValue(), $r('app.string.summary_total'), 'statTotal')
      }
      .width('100%')
      .padding(Space.S4)
      .margin({ top: Space.S5 })
      .borderRadius(Radius.LG)
      .backgroundColor($r('app.color.bg_surface'))

      if (this.vm.heardRows.length > 0) {
        this.sectionHeader($r('app.string.summary_heard'))
        StopList({ rows: this.vm.heardRows, tappable: true, onTapStop: (poiId: string) => this.app.openPlace(poiId) })
          .id('listHeard')
      } else if (!this.complete()) {
        Text($r('app.string.summary_empty'))
          .id('txtSummaryEmpty')
          .fontSize(Type.BODY)
          .lineHeight(Type.BODY_LH)
          .fontColor($r('app.color.text_secondary'))
          .margin({ top: Space.S5 })
      }
      if (this.vm.stillRows.length > 0) {
        this.sectionHeader($r('app.string.summary_still_to_see'))
        this.stillList()
      }

      if (this.vm.data !== undefined && this.vm.data.tourId !== '') {
        Button($r('app.string.summary_start_again'), { type: ButtonType.Capsule, buttonStyle: ButtonStyleMode.NORMAL })
          .id('btnStartAgain')
          .width('100%')
          .height(Size.BUTTON_H)
          .margin({ top: Space.S5 })
          .onClick(() => this.app.startTourAgain(this.vm.data !== undefined ? this.vm.data.tourId : ''))
      }
      Column().height(Space.S6)
    }
    .alignItems(HorizontalAlign.Start)
    .width('100%')
    .constraintSize({ maxWidth: Size.PAGE_MAX_W })
    .padding({ left: Space.S4, right: Space.S4 })
  }

  build() {
    NavDestination() {
      Column() {
        Row() {
          Text(this.complete() ? $r('app.string.summary_complete') : $r('app.string.summary_ended'))
            .fontSize(Type.TITLE3)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.text_primary'))
            .layoutWeight(1)
          Button($r('app.string.summary_done'), { type: ButtonType.Normal, buttonStyle: ButtonStyleMode.TEXTUAL })
            .id('btnSummaryDone')
            .height(Size.TOUCH)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.accent'))
            .onClick(() => this.app.home())
        }
        .width('100%')
        .padding({ left: Space.S4, right: Space.S2, top: Space.S2, bottom: Space.S2 })

        Scroll() {
          if (this.vm.data !== undefined) {
            this.body()
          } else {
            Text($r('app.string.summary_empty'))
              .id('txtSummaryEmpty')
              .fontSize(Type.BODY)
              .lineHeight(Type.BODY_LH)
              .fontColor($r('app.color.text_secondary'))
              .padding(Space.S4)
          }
        }
        .scrollBar(BarState.Off)
        .align(Alignment.Top)
        .layoutWeight(1)
        .width('100%')
      }
      .width('100%')
      .height('100%')
      .padding({ top: this.sa.top, bottom: this.sa.bottom, left: this.sa.left, right: this.sa.right })
    }
    .id('pageSummary')
    .hideTitleBar(true)
    .backgroundColor($r('app.color.bg_canvas'))
    .onShown(() => {
      Log.i(LogEvents.APP_PAGE, 'page=Summary shown');
    })
  }
}

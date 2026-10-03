/*
 * The tour's stop list (DESIGN §3.3 "STOPS"): plaque, a 2 vp connector between plaques, name and story length.
 * Rows are plain data built by the view model.
 */
import { Plaque, PlaqueState } from './Plaque';
import { Radius, Size, Space, Type } from './Tokens';

export class StopRow {
  order: number;        // 1-based position in the shown order
  poiId: string;
  name: string;         // already localised; '' = unknown (shown as "Stop N")
  storyMin: number;     // estimated story length, 0 = unknown
  state: PlaqueState;

  constructor(order: number, poiId: string, name: string, storyMin: number, state: PlaqueState) {
    this.order = order;
    this.poiId = poiId;
    this.name = name;
    this.storyMin = storyMin;
    this.state = state;
  }
}

@ComponentV2
export struct StopList {
  @Param rows: StopRow[] = [];
  @Param tappable: boolean = false;
  @Event onTapStop: (poiId: string) => void = (poiId: string) => {};

  @Builder
  connector(visible: boolean) {
    Column()
      .width(2)
      .layoutWeight(1)
      .backgroundColor(visible ? $r('app.color.divider') : Color.Transparent)
  }

  build() {
    Column() {
      ForEach(this.rows, (row: StopRow, idx: number) => {
        Row({ space: 14 }) {
          Stack() {
            Column() {
              this.connector(idx > 0)
              this.connector(idx < this.rows.length - 1)
            }
            .height('100%')

            Plaque({ n: row.order, state: row.state })
          }
          .width(34)
          .height(Size.TOUCH)

          if (row.name !== '') {
            Text(row.name)
              .fontSize(Type.BODY)
              .lineHeight(Type.BODY_LH)
              .fontColor($r('app.color.text_primary'))
              .maxLines(2)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .layoutWeight(1)
          } else {
            Text($r('app.string.fmt_stop_of', row.order, this.rows.length))
              .fontSize(Type.BODY)
              .lineHeight(Type.BODY_LH)
              .fontColor($r('app.color.text_secondary'))
              .layoutWeight(1)
          }

          if (row.storyMin > 0) {
            Text($r('app.string.tour_story_min', row.storyMin))
              .fontSize(Type.FOOTNOTE)
              .lineHeight(Type.FOOTNOTE_LH)
              .fontFeature('"tnum" 1')
              .fontColor($r('app.color.text_secondary'))
          }
          if (this.tappable) {
            SymbolGlyph($r('sys.symbol.chevron_right'))
              .fontSize(16)
              .fontColor([$r('app.color.text_tertiary')])
          }
        }
        .width('100%')
        .height(Size.TOUCH)
        .padding({ left: 10, right: 12 })
        .accessibilityGroup(true)
        .accessibilityText(row.name !== '' ? $r('app.string.tour_stop_a11y', row.order, row.name) :
          $r('app.string.fmt_stop_of', row.order, this.rows.length))
        .onClick(() => {
          if (this.tappable) {
            this.onTapStop(row.poiId);
          }
        })
      }, (row: StopRow) => `${row.order}:${row.poiId}:${row.state}`)
    }
    .width('100%')
    .padding({ top: Space.S1, bottom: Space.S1 })
    .borderRadius(Radius.LG)
    .backgroundColor($r('app.color.bg_surface'))
  }
}

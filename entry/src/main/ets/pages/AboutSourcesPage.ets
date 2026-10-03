/*
 * About & licences (B8, DESIGN §3.15, ARCHITECTURE §7.1 licences, RISKS T14): how the stories are made (AI
 * disclosure), every data source with its licence and attribution, the machine-translation note, and the offline
 * pack's version from its manifest. Static and offline.
 */
import { Log } from '../app/Log';
import { LogEvents } from '../app/LogEvents';
import { AppViewModel } from '../viewmodel/AppViewModel';
import { FloatingIconButton } from '../views/common/FloatingIconButton';
import { Radius, Size, Space, Type } from '../views/common/Tokens';

class LicenceRow {
  title: Resource;
  note: Resource | undefined;

  constructor(title: Resource, note: Resource | undefined) {
    this.title = title;
    this.note = note;
  }
}

@ComponentV2
export struct AboutSourcesPage {
  @Local app: AppViewModel = AppViewModel.get();
  private licences: LicenceRow[] = [
    new LicenceRow($r('app.string.about_osm'), undefined),
    new LicenceRow($r('app.string.about_wikipedia'), undefined),
    new LicenceRow($r('app.string.about_wikidata'), undefined),
    new LicenceRow($r('app.string.about_arcgis'), $r('app.string.about_arcgis_terms')),
    new LicenceRow($r('app.string.about_osrm'), undefined)
  ];

  @Builder
  header(label: Resource) {
    Text(label)
      .fontSize(Type.CAPTION)
      .lineHeight(Type.CAPTION_LH)
      .fontWeight(FontWeight.Medium)
      .letterSpacing(Type.OVERLINE_SPACING)
      .textCase(TextCase.UpperCase)
      .fontColor($r('app.color.text_secondary'))
      .margin({ left: Space.S1, top: Space.S5, bottom: Space.S2 })
  }

  @Builder
  card(body: Resource, id: string) {
    Text(body)
      .id(id)
      .fontSize(Type.BODY)
      .lineHeight(Type.BODY_LH)
      .fontColor($r('app.color.text_primary'))
      .width('100%')
      .padding(Space.S4)
      .borderRadius(Radius.LG)
      .backgroundColor($r('app.color.bg_surface'))
  }

  build() {
    NavDestination() {
      Column() {
        Row({ space: Space.S1 }) {
          FloatingIconButton({
            symbol: $r('sys.symbol.chevron_backward'),
            label: $r('app.string.a11y_back'),
            buttonId: 'btnBackAbout',
            onTap: () => this.app.back()
          })
          Text($r('app.string.about_title'))
            .fontSize(Type.TITLE3)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.text_primary'))
        }
        .width('100%')
        .padding({ left: Space.S2, top: Space.S2 })

        Scroll() {
          Column() {
            this.header($r('app.string.about_ai_title'))
            this.card($r('app.string.about_ai_body'), 'aboutAi')
            this.header($r('app.string.about_ai_disclosure_title'))
            this.card($r('app.string.about_ai_model'), 'aboutModel')

            this.header($r('app.string.about_data_title'))
            Column() {
              ForEach(this.licences, (l: LicenceRow, idx: number) => {
                Column({ space: 2 }) {
                  Text(l.title)
                    .fontSize(Type.BODY)
                    .lineHeight(Type.BODY_LH)
                    .fontColor($r('app.color.text_primary'))
                  if (l.note !== undefined) {
                    Text(l.note)
                      .fontSize(Type.FOOTNOTE)
                      .lineHeight(Type.FOOTNOTE_LH)
                      .fontColor($r('app.color.text_secondary'))
                  }
                }
                .alignItems(HorizontalAlign.Start)
                .width('100%')
                .padding({ top: Space.S3, bottom: Space.S3 })
                .border({ width: { top: idx === 0 ? 0 : 1 }, color: $r('app.color.divider') })
              }, (l: LicenceRow, idx: number) => `${idx}`)
            }
            .id('aboutLicences')
            .width('100%')
            .padding({ left: Space.S4, right: Space.S4 })
            .borderRadius(Radius.LG)
            .backgroundColor($r('app.color.bg_surface'))

            Column() {
              this.card($r('app.string.about_mt'), 'aboutMt')
            }
            .width('100%')
            .margin({ top: Space.S3 })

            if (this.app.packVersion !== '') {
              this.header($r('app.string.about_pack_title'))
              Text($r('app.string.about_pack_line', this.app.packVersion, this.app.packBuiltAt, this.app.packPois))
                .id('aboutPack')
                .fontSize(Type.CALLOUT)
                .fontColor($r('app.color.text_secondary'))
                .padding({ left: Space.S1 })
            }
            Column().height(Space.S6)
          }
          .alignItems(HorizontalAlign.Start)
          .width('100%')
          .constraintSize({ maxWidth: Size.PAGE_MAX_W })
          .padding({ left: Space.S4, right: Space.S4 })
        }
        .scrollBar(BarState.Off)
        .align(Alignment.Top)
        .layoutWeight(1)
        .width('100%')
      }
      .width('100%')
      .height('100%')
    }
    .id('pageAbout')
    .hideTitleBar(true)
    .backgroundColor($r('app.color.bg_canvas'))
    .onShown(() => {
      Log.i(LogEvents.APP_PAGE, 'page=AboutSources shown');
    })
  }
}

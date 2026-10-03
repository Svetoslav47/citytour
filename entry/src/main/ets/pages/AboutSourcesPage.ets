/*
 * About & licences (B8, DESIGN §3.15, ARCHITECTURE §7.1 licences, RISKS T14): the ONLY screen with attribution and
 * disclosure (the everyday screens stay clean; AI and sources are also presented in the pitch). In order: the full
 * credit of each downloaded course's cover photo (author, licence + link, Commons page, our changes;
 * data/ATTRIBUTION.md), map and data licences, the narration voice credit (ElevenLabs), one short paragraph on how
 * the stories are made (AI, machine translation), and the offline pack's version. Offline.
 */
import { Log } from '../app/Log';
import { LogEvents } from '../app/LogEvents';
import { AppViewModel } from '../viewmodel/AppViewModel';
import { SafeArea } from '../viewmodel/SafeArea';
import { FloatingIconButton } from '../views/common/FloatingIconButton';
import { Radius, Size, Space, Type } from '../views/common/Tokens';
import { AppContainer } from '../app/AppContainer';
import { courseTitle } from '../core/remote/CourseRules';
import { coverSubject } from '../core/remote/CoverRules';
import { CourseCoverCredit } from '../services/remote/CourseRepository';
import { coverLang } from '../viewmodel/CoverModel';
import { withTimeout } from '../viewmodel/Async';

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
  /** Window avoid areas (edge-to-edge window, issue #63). */
  @Local sa: SafeArea = SafeArea.get();
  @Local covers: CourseCoverCredit[] = [];
  private licences: LicenceRow[] = [
    new LicenceRow($r('app.string.about_osm'), undefined),
    new LicenceRow($r('app.string.about_wikipedia'), undefined),
    new LicenceRow($r('app.string.about_wikidata'), undefined),
    new LicenceRow($r('app.string.about_arcgis'), $r('app.string.about_arcgis_terms')),
    new LicenceRow($r('app.string.about_osrm'), undefined)
  ];

  aboutToAppear(): void {
    try {
      withTimeout(AppContainer.courses().coverCredits(), 10000, [] as CourseCoverCredit[], 'about.coverCredits')
        .then((list: CourseCoverCredit[]) => {
          this.covers = list;
        });
    } catch (e) {
      Log.e(LogEvents.UNCAUGHT, `where=AboutSourcesPage.covers ${Log.errKv(e as Object)}`);
    }
  }

  @Builder
  coverRow(c: CourseCoverCredit, idx: number) {
    Column({ space: 2 }) {
      Text(courseTitle(c.summary, coverLang(this.app.textLang)))
        .fontSize(Type.BODY)
        .lineHeight(Type.BODY_LH)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.text_primary'))
      if (coverSubject(c.credit, coverLang(this.app.textLang)) !== '') {
        Text(coverSubject(c.credit, coverLang(this.app.textLang)))
          .fontSize(Type.CALLOUT)
          .lineHeight(Type.CALLOUT_LH)
          .fontColor($r('app.color.text_primary'))
      }
      Text($r('app.string.cover_photo_credit', `${c.credit.author}, ${c.credit.license}`))
        .fontSize(Type.FOOTNOTE)
        .lineHeight(Type.FOOTNOTE_LH)
        .fontColor($r('app.color.text_secondary'))
      if (c.credit.licenseUrl !== '') {
        Text($r('app.string.about_cover_licence', c.credit.licenseUrl))
          .fontSize(Type.FOOTNOTE)
          .lineHeight(Type.FOOTNOTE_LH)
          .fontColor($r('app.color.text_secondary'))
          .copyOption(CopyOptions.LocalDevice)
      }
      if (c.credit.sourceUrl !== '') {
        Text($r('app.string.about_cover_source', c.credit.publisher !== '' ? c.credit.publisher : 'Wikimedia Commons',
          c.credit.sourceUrl))
          .fontSize(Type.FOOTNOTE)
          .lineHeight(Type.FOOTNOTE_LH)
          .fontColor($r('app.color.text_secondary'))
          .copyOption(CopyOptions.LocalDevice)
      }
      Text($r('app.string.about_cover_changes'))
        .fontSize(Type.FOOTNOTE)
        .lineHeight(Type.FOOTNOTE_LH)
        .fontColor($r('app.color.text_secondary'))
    }
    .alignItems(HorizontalAlign.Start)
    .width('100%')
    .padding({ top: Space.S3, bottom: Space.S3 })
    .border({ width: { top: idx === 0 ? 0 : 1 }, color: $r('app.color.divider') })
  }

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
            if (this.covers.length > 0) {
              this.header($r('app.string.about_cover_title'))
              Column() {
                ForEach(this.covers, (c: CourseCoverCredit, idx: number) => {
                  this.coverRow(c, idx)
                }, (c: CourseCoverCredit) => c.id)
              }
              .id('aboutCovers')
              .width('100%')
              .padding({ left: Space.S4, right: Space.S4 })
              .borderRadius(Radius.LG)
              .backgroundColor($r('app.color.bg_surface'))
            }

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

            this.header($r('app.string.about_voice_title'))
            this.card($r('app.string.about_voice_body'), 'aboutVoice')

            this.header($r('app.string.about_ai_title'))
            this.card($r('app.string.about_ai_body'), 'aboutAi')

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
      // The canvas runs under the system bars; the back button and the text stay clear of them.
      .padding({ top: this.sa.top, bottom: this.sa.bottom, left: this.sa.left, right: this.sa.right })
    }
    .id('pageAbout')
    .hideTitleBar(true)
    .backgroundColor($r('app.color.bg_canvas'))
    .onShown(() => {
      Log.i(LogEvents.APP_PAGE, 'page=AboutSources shown');
    })
  }
}

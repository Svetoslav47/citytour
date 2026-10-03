/*
 * Settings > About rows (task B9): "How these stories are made" (topic 'ai') and "Sources and licences"
 * (topic 'sources'). A placeholder with the real copy B4 already wrote (about_* strings); task B8 replaces it with
 * the full About & licences page. Ids: pageSettingsInfo.
 */
import { AppViewModel } from '../../viewmodel/AppViewModel';
import { Size, Space, Type } from '../common/Tokens';
import { Footnote, SettingsCard, SettingsHeader } from './SettingsRows';

const SOURCE_LINES: Resource[] = [
  $r('app.string.about_osm'),
  $r('app.string.about_wikipedia'),
  $r('app.string.about_wikidata'),
  $r('app.string.about_arcgis'),
  $r('app.string.about_osrm'),
  $r('app.string.about_mt')
];

@ComponentV2
export struct SettingsInfoPage {
  @Param topic: string = 'ai';
  @Local app: AppViewModel = AppViewModel.get();

  @Builder
  body() {
    if (this.topic === 'sources') {
      SettingsCard() {
        Column({ space: Space.S3 }) {
          ForEach(SOURCE_LINES, (r: Resource) => {
            Text(r)
              .fontSize(Type.BODY)
              .lineHeight(Type.BODY_LH)
              .fontColor($r('app.color.text_primary'))
              .width('100%')
          }, (r: Resource, i: number) => `${i}`)
        }
        .padding(Space.S4)
        .width('100%')
      }
      Footnote({ text: $r('app.string.settings_sources_body') })
    } else {
      SettingsCard() {
        Text($r('app.string.about_ai_body'))
          .fontSize(Type.BODY)
          .lineHeight(Type.BODY_LH)
          .fontColor($r('app.color.text_primary'))
          .padding(Space.S4)
          .width('100%')
      }
    }
  }

  build() {
    NavDestination() {
      Scroll() {
        Column() {
          SettingsHeader({
            title: this.topic === 'sources' ? $r('app.string.settings_sources') : $r('app.string.settings_how_made'),
            onBack: () => this.app.back()
          })
          Column() {
            this.body()
          }
          .width('100%')
          .padding({ left: Space.S4, right: Space.S4, bottom: Space.S6 })
        }
        .width('100%')
        .constraintSize({ maxWidth: Size.PAGE_MAX_W })
      }
      .id('pageSettingsInfo')
      .scrollBar(BarState.Off)
      .align(Alignment.Top)
      .width('100%')
      .height('100%')
    }
    .hideTitleBar(true)
    .backgroundColor($r('app.color.bg_canvas'))
  }
}

/*
 * Settings > Story language (task B9, DESIGN §3.11 + Flow F): a radio list of the four narration choices and the
 * one-time footnote about Polish being text only. Ids: radioStory<en|zh|pl|pl-listen-en>.
 */
import { StoryLang, STORY_LANGS } from '../../core/settings/SettingsRules';
import { AppViewModel } from '../../viewmodel/AppViewModel';
import { SettingsViewModel } from '../../viewmodel/SettingsViewModel';
import { storyLangRes } from './SettingsText';
import { Size, Space } from '../common/Tokens';
import { Footnote, RadioRow, RowDivider, SettingsCard, SettingsHeader } from './SettingsRows';

@ComponentV2
export struct StoryLanguagePage {
  @Local app: AppViewModel = AppViewModel.get();
  @Local vm: SettingsViewModel = SettingsViewModel.get();

  build() {
    NavDestination() {
      Scroll() {
        Column() {
          SettingsHeader({ title: $r('app.string.settings_story_language'), onBack: () => this.app.back() })
          Column() {
            SettingsCard() {
              ForEach(STORY_LANGS, (l: StoryLang, i: number) => {
                if (i > 0) {
                  RowDivider()
                }
                RadioRow({
                  title: storyLangRes(l), selected: this.vm.storyLang() === l, rowId: `radioStory${l}`,
                  group: 'storyLang', onSelect: () => this.vm.setStoryLang(l)
                })
              }, (l: StoryLang) => l)
            }
            Footnote({ text: $r('app.string.lang_pl_footnote') })
          }
          .width('100%')
          .padding({ left: Space.S4, right: Space.S4, bottom: Space.S6 })
        }
        .width('100%')
        .constraintSize({ maxWidth: Size.PAGE_MAX_W })
      }
      .id('pageStoryLanguage')
      .scrollBar(BarState.Off)
      .align(Alignment.Top)
      .width('100%')
      .height('100%')
    }
    .hideTitleBar(true)
    .backgroundColor($r('app.color.bg_canvas'))
  }
}

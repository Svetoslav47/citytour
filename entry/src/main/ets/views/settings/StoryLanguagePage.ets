/*
 * Settings > Story language (task B9, DESIGN §3.11 + Flow F): a radio list of the four narration choices and the
 * one-time footnote about Polish (studio voice with the A13 clips, else text only). Ids: radioStory<en|zh|pl|pl-listen-en>.
 */
import { StoryLang, STORY_LANGS } from '../../core/settings/SettingsRules';
import { AppViewModel } from '../../viewmodel/AppViewModel';
import { SettingsViewModel } from '../../viewmodel/SettingsViewModel';
import { storyLangRes } from './SettingsText';
import { Size, Space } from '../common/Tokens';
import { Footnote, RadioRow, RowDivider, SettingsCard, SettingsHeader } from './SettingsRows';
import { SafeArea } from '../../viewmodel/SafeArea';

@ComponentV2
export struct StoryLanguagePage {
  @Local app: AppViewModel = AppViewModel.get();
  @Local vm: SettingsViewModel = SettingsViewModel.get();
  /** Window avoid areas (edge-to-edge window, issue #63). */
  @Local sa: SafeArea = SafeArea.get();

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
                  title: storyLangRes(l, this.vm.plSpoken()), selected: this.vm.storyLang() === l, rowId: `radioStory${l}`,
                  group: 'storyLang', onSelect: () => this.vm.setStoryLang(l)
                })
              }, (l: StoryLang) => l)
            }
            Footnote({
              text: this.vm.plSpoken() ? $r('app.string.lang_pl_footnote_studio') : $r('app.string.lang_pl_footnote')
            })
          }
          .width('100%')
          .padding({ left: Space.S4, right: Space.S4, bottom: Space.S6 + this.sa.bottom })
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
    // The canvas runs under the status bar; the scroll viewport starts below it.
    .padding({ top: this.sa.top, left: this.sa.left, right: this.sa.right })
  }
}

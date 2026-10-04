/*
 * Settings > App language (task B9, DESIGN §3.11): System / English / Polski / 中文 through
 * i18n.System.setAppPreferredLanguage (SettingsViewModel.applyUiLang). B10 owns the translations.
 * Ids: radioUi<system|en|pl|zh>.
 */
import { UiLang } from 'common';
import { UI_LANGS } from 'common';
import { AppViewModel } from '../../viewmodel/AppViewModel';
import { SettingsViewModel } from '../../viewmodel/SettingsViewModel';
import { uiLangRes } from './SettingsText';
import { Size, Space } from '../common/Tokens';
import { Footnote, RadioRow, RowDivider, SettingsCard, SettingsHeader } from './SettingsRows';
import { SafeArea } from '../../viewmodel/SafeArea';

@ComponentV2
export struct AppLanguagePage {
  @Local app: AppViewModel = AppViewModel.get();
  @Local vm: SettingsViewModel = SettingsViewModel.get();
  /** Window avoid areas (edge-to-edge window, issue #63). */
  @Local sa: SafeArea = SafeArea.get();

  build() {
    NavDestination() {
      Scroll() {
        Column() {
          SettingsHeader({ title: $r('app.string.settings_app_language'), onBack: () => this.app.back() })
          Column() {
            SettingsCard() {
              ForEach(UI_LANGS, (u: UiLang, i: number) => {
                if (i > 0) {
                  RowDivider()
                }
                RadioRow({
                  title: uiLangRes(u), selected: this.vm.uiLang() === u, rowId: `radioUi${u}`, group: 'uiLang',
                  onSelect: () => this.vm.setUiLang(u)
                })
              }, (u: UiLang) => u)
            }
            Footnote({ text: $r('app.string.settings_app_language_note') })
          }
          .width('100%')
          .padding({ left: Space.S4, right: Space.S4, bottom: Space.S6 + this.sa.bottom })
        }
        .width('100%')
        .constraintSize({ maxWidth: Size.PAGE_MAX_W })
      }
      .id('pageAppLanguage')
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

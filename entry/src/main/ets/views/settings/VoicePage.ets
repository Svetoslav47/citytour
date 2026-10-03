/*
 * Settings > Voice (task B9, DESIGN §3.11 + Flow E, PLAN §0.4): what you hear for the story language (the same
 * VoicePlan label the tour uses), the English voice Laura with Download / progress / honest failure (30 s give-up
 * when the system dialog is cancelled, issue #24), and the strategy picker Auto / Chinese voice / Text only.
 * Ids: rowVoiceNow, rowLaura, btnDownloadVoice, radioStrategy<auto|zh|text>.
 */
import { VoiceState } from '../../contracts/Ports';
import { STRATEGY_CHOICES, StrategyChoice } from '../../core/settings/SettingsRules';
import { AppViewModel } from '../../viewmodel/AppViewModel';
import { DownloadState, SettingsViewModel } from '../../viewmodel/SettingsViewModel';
import { Size, Space, Type } from '../common/Tokens';
import { Footnote, NavRow, RadioRow, RowDivider, SectionHeader, SettingsCard, SettingsHeader } from './SettingsRows';
import { voiceRowRes } from './SettingsText';

function strategyRes(c: StrategyChoice): Resource {
  if (c === StrategyChoice.ZH) {
    return $r('app.string.voice_strategy_zh');
  }
  if (c === StrategyChoice.TEXT) {
    return $r('app.string.voice_strategy_text');
  }
  return $r('app.string.voice_strategy_auto');
}

@ComponentV2
export struct VoicePage {
  @Local app: AppViewModel = AppViewModel.get();
  @Local vm: SettingsViewModel = SettingsViewModel.get();

  aboutToAppear(): void {
    this.vm.refreshVoice();
  }

  private lauraStatus(): Resource {
    if (!this.vm.capsKnown) {
      return $r('app.string.onb_checking_voice');
    }
    if (this.vm.caps.en === VoiceState.INSTALLED) {
      return $r('app.string.settings_voice_installed');
    }
    if (this.vm.caps.en === VoiceState.DOWNLOADABLE) {
      return $r('app.string.settings_voice_downloadable');
    }
    return $r('app.string.settings_voice_unavailable');
  }

  @Builder
  laura() {
    SectionHeader({ label: $r('app.string.settings_voice_en_title') })
    SettingsCard() {
      NavRow({
        title: $r('app.string.voice_native'), subtitle: this.lauraStatus(), tappable: false, rowId: 'rowLaura',
        busy: !this.vm.capsKnown
      })
      if (this.vm.download === DownloadState.DOWNLOADING) {
        Column({ space: Space.S2 }) {
          Progress({ value: this.vm.downloadPct, total: 100, type: ProgressType.Linear })
            .color($r('app.color.accent'))
            .backgroundColor($r('app.color.divider'))
            .style({ strokeWidth: 4 })
            .width('100%')
          Text($r('app.string.voice_downloading', `${this.vm.downloadPct}%`))
            .fontSize(Type.CALLOUT)
            .lineHeight(Type.CALLOUT_LH)
            .fontColor($r('app.color.text_secondary'))
        }
        .id('rowDownloading')
        .alignItems(HorizontalAlign.Start)
        .width('100%')
        .padding({ left: Space.S4, right: Space.S4, bottom: Space.S3 })
        .accessibilityGroup(true)
      }
      if (this.vm.download === DownloadState.FAILED) {
        Column() {
          Text($r('app.string.voice_download_failed'))
            .id('txtDownloadFailed')
            .fontSize(Type.CALLOUT)
            .lineHeight(Type.CALLOUT_LH)
            .fontColor($r('app.color.text_primary'))
            .backgroundColor($r('app.color.signal_warning_bg'))
            .borderRadius(Space.S3)
            .padding(Space.S3)
            .width('100%')
        }
        .width('100%')
        .padding({ left: Space.S4, right: Space.S4, bottom: Space.S3 })
      }
      if (this.vm.canDownload()) {
        Column() {
          Button({ type: ButtonType.Capsule, buttonStyle: ButtonStyleMode.NORMAL }) {
            Row({ space: Space.S2 }) {
              SymbolGlyph($r('sys.symbol.arrow_down_circle'))
                .fontSize(18)
                .fontColor([$r('app.color.accent')])
              Text(this.vm.download === DownloadState.FAILED ? $r('app.string.settings_voice_try_again') :
                $r('app.string.voice_download'))
                .fontSize(Type.BODY)
                .fontWeight(FontWeight.Medium)
                .fontColor($r('app.color.accent'))
            }
          }
          .id('btnDownloadVoice')
          .width('100%')
          .constraintSize({ minHeight: Size.BUTTON_H })
          .backgroundColor($r('app.color.accent_subtle'))
          .onClick(() => {
            this.vm.downloadEnglish();
          })
        }
        .width('100%')
        .padding({ left: Space.S4, right: Space.S4, bottom: Space.S4 })
      }
    }
    Footnote({ text: $r('app.string.onb_fallback_note') })
  }

  @Builder
  strategy() {
    SectionHeader({ label: $r('app.string.settings_voice_strategy') })
    SettingsCard() {
      ForEach(STRATEGY_CHOICES, (c: StrategyChoice, i: number) => {
        if (i > 0) {
          RowDivider()
        }
        RadioRow({
          title: strategyRes(c), selected: this.vm.strategyChoice() === c, rowId: `radioStrategy${c}`,
          group: 'enStrategy', onSelect: () => this.vm.setStrategy(c)
        })
      }, (c: StrategyChoice) => c)
    }
    Footnote({ text: $r('app.string.settings_voice_strategy_note') })
  }

  build() {
    NavDestination() {
      Scroll() {
        Column() {
          SettingsHeader({ title: $r('app.string.settings_voice'), onBack: () => this.app.back() })
          Column({ space: Space.S5 }) {
            Column() {
              SectionHeader({ label: $r('app.string.settings_voice_now') })
              SettingsCard() {
                NavRow({
                  title: $r('app.string.settings_story_language'), value: voiceRowRes(this.vm.voiceRow),
                  tappable: false, rowId: 'rowVoiceNow'
                })
              }
            }

            Column() {
              this.laura()
            }

            Column() {
              this.strategy()
            }
          }
          .width('100%')
          .padding({ left: Space.S4, right: Space.S4, bottom: Space.S6 })
        }
        .width('100%')
        .constraintSize({ maxWidth: Size.PAGE_MAX_W })
      }
      .id('pageVoice')
      .scrollBar(BarState.Off)
      .align(Alignment.Top)
      .width('100%')
      .height('100%')
    }
    .hideTitleBar(true)
    .backgroundColor($r('app.color.bg_canvas'))
  }
}

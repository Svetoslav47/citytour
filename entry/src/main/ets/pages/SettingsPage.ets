/*
 * Settings (task B9, docs/DESIGN.md §3.11, mockup docs/design/mockups/Settings.dc.html). A NavDestination with its
 * own header (back + large title) and grouped cards: Narration, Walking, Sound and haptics, Offline data, Demo,
 * Permissions, About. Everything is persisted (UserSettings, PersistenceV2) and applied by SettingsViewModel.
 * Ids for the smoke/verification scripts: btnSettings (Home), rowStoryLanguage, rowAppLanguage, rowVoice,
 * segDetail<brief|standard|deep>, rowSpokenDirections, segTrigger<20|35|50>, rowVibrate, rowDemoWalk,
 * segSpeed<1|2|4|8>, rowLocation, rowNotifications, rowHowMade, rowSources, rowShowIntro.
 *
 * Honesty: "Mention places along the way" and "Arrival chime" have no engine behind them in this build, so their
 * rows are left out (DESIGN §3.11 lists them; the strings stay for when they ship).
 */
import { LocRow, NotifRow } from '../core/onboarding/OnboardingRules';
import { DetailLevel, TRIGGER_DISTANCES_M, DEMO_SPEEDS } from '../core/settings/SettingsRules';
import { Log } from '../app/Log';
import { LogEvents } from '../app/LogEvents';
import { AppViewModel, Routes } from '../viewmodel/AppViewModel';
import { SettingsViewModel } from '../viewmodel/SettingsViewModel';
import { SimulatedBadge } from '../views/common/SimulatedBadge';
import { Radius, Size, Space, Type } from '../views/common/Tokens';
import {
  Footnote, NavRow, RowDivider, SectionHeader, SegmentOption, SegmentRow, SettingsCard, SettingsHeader, ToggleRow
} from '../views/settings/SettingsRows';
import { storyLangRes, uiLangRes, voiceRowRes } from '../views/settings/SettingsText';
import { SafeArea } from '../viewmodel/SafeArea';

function detailNote(d: DetailLevel): Resource {
  if (d === DetailLevel.BRIEF) {
    return $r('app.string.settings_detail_brief_note');
  }
  if (d === DetailLevel.DEEP) {
    return $r('app.string.settings_detail_deep_note');
  }
  return $r('app.string.settings_detail_standard_note');
}

function locRes(r: LocRow): Resource {
  if (r === LocRow.ALLOWED) {
    return $r('app.string.settings_loc_allowed');
  }
  if (r === LocRow.APPROX) {
    return $r('app.string.settings_loc_approx');
  }
  if (r === LocRow.SWITCH_OFF) {
    return $r('app.string.settings_loc_switch_off');
  }
  if (r === LocRow.DENIED) {
    return $r('app.string.settings_loc_off');
  }
  return $r('app.string.settings_loc_ask');
}

function notifRes(r: NotifRow): Resource {
  if (r === NotifRow.ALLOWED) {
    return $r('app.string.settings_on');
  }
  if (r === NotifRow.DENIED) {
    return $r('app.string.settings_off');
  }
  return $r('app.string.settings_loc_ask');
}

const DETAIL_OPTIONS: SegmentOption[] = [
  new SegmentOption(DetailLevel.BRIEF, $r('app.string.settings_detail_brief')),
  new SegmentOption(DetailLevel.STANDARD, $r('app.string.settings_detail_standard')),
  new SegmentOption(DetailLevel.DEEP, $r('app.string.settings_detail_deep'))
];

const TRIGGER_OPTIONS: SegmentOption[] = TRIGGER_DISTANCES_M.map((m: number) =>
  new SegmentOption(`${m}`, $r('app.string.fmt_m', m)));

const SPEED_OPTIONS: SegmentOption[] = DEMO_SPEEDS.map((x: number) =>
  new SegmentOption(`${x}`, $r('app.string.settings_speed_x', x), $r('app.string.settings_speed_a11y', x)));

@ComponentV2
export struct SettingsPage {
  @Local app: AppViewModel = AppViewModel.get();
  @Local vm: SettingsViewModel = SettingsViewModel.get();
  /** Window avoid areas (edge-to-edge window, issue #63). */
  @Local sa: SafeArea = SafeArea.get();
  /** SERVER.md §2: Online studio voice (shown only when the build has a course server). */

  aboutToAppear(): void {
    Log.i(LogEvents.APP_PAGE, `page=Settings ${SettingsViewModel.summaryKv()}`);
  }

  private open(name: string, param: string): void {
    this.app.openSettingsPage(name, param);
  }

  @Builder
  narration() {
    SectionHeader({ label: $r('app.string.settings_narration') })
    SettingsCard() {
      NavRow({
        title: $r('app.string.settings_story_language'), value: storyLangRes(this.vm.storyLang(), this.vm.plSpoken()),
        rowId: 'rowStoryLanguage', onTap: () => this.open(Routes.SETTINGS_STORY_LANG, '')
      })
      RowDivider()
      NavRow({
        title: $r('app.string.settings_app_language'), value: uiLangRes(this.vm.uiLang()),
        rowId: 'rowAppLanguage', onTap: () => this.open(Routes.SETTINGS_APP_LANG, '')
      })
      RowDivider()
      NavRow({
        title: $r('app.string.settings_voice'), value: voiceRowRes(this.vm.voiceRow),
        rowId: 'rowVoice', onTap: () => this.open(Routes.SETTINGS_VOICE, '')
      })
      RowDivider()
      NavRow({
        title: $r('app.string.settings_guide'), value: this.vm.guideName, rowId: 'rowGuide', tappable: false
      })
      RowDivider()
      SegmentRow({
        title: $r('app.string.settings_detail_level'), options: DETAIL_OPTIONS, selected: this.vm.detailLevel(),
        idPrefix: 'segDetail', onSelect: (k: string) => this.vm.setDetailLevel(k as DetailLevel)
      })
    }
    Footnote({ text: detailNote(this.vm.detailLevel()) })
  }

  @Builder
  walking() {
    SectionHeader({ label: $r('app.string.settings_walking') })
    SettingsCard() {
      ToggleRow({
        title: $r('app.string.settings_spoken_directions'), subtitle: $r('app.string.settings_spoken_directions_note'),
        isOn: this.vm.settings.spokenDirections, rowId: 'rowSpokenDirections',
        onToggle: (on: boolean) => this.vm.setSpokenDirections(on)
      })
      RowDivider()
      SegmentRow({
        title: $r('app.string.settings_trigger'), options: TRIGGER_OPTIONS, selected: `${this.vm.triggerM()}`,
        idPrefix: 'segTrigger', onSelect: (k: string) => this.vm.setTriggerM(Number(k))
      })
    }
    Footnote({ text: $r('app.string.settings_trigger_note') })
  }

  @Builder
  sound() {
    SectionHeader({ label: $r('app.string.settings_sound_haptics') })
    SettingsCard() {
      ToggleRow({
        title: $r('app.string.settings_vibrate'), subtitle: $r('app.string.settings_vibrate_note'),
        isOn: this.vm.extras.vibrateOnArrival, rowId: 'rowVibrate', onToggle: (on: boolean) => this.vm.setVibrate(on)
      })
    }
  }

  @Builder
  offline() {
    SectionHeader({ label: $r('app.string.settings_offline_data') })
    SettingsCard() {
      if (!this.vm.packKnown) {
        NavRow({
          title: $r('app.string.settings_pack_title'), subtitle: $r('app.string.settings_pack_loading'),
          tappable: false, busy: true, rowId: 'rowPack'
        })
      } else if (!this.vm.hasCourse) {
        NavRow({
          title: $r('app.string.settings_pack_title'), subtitle: $r('app.string.settings_pack_none'),
          tappable: false, rowId: 'rowPack'
        })
      } else if (!this.vm.packOk) {
        NavRow({
          title: $r('app.string.settings_pack_title'), subtitle: $r('app.string.settings_pack_error'),
          tappable: false, rowId: 'rowPack'
        })
      } else {
        NavRow({
          title: $r('app.string.settings_pack_title'),
          subtitle: $r('app.string.settings_pack_line', this.vm.pack.places, this.vm.pack.stories),
          value: this.vm.pack.sizeMb > 0 ? $r('app.string.settings_pack_size', `${this.vm.pack.sizeMb}`) :
            $r('app.string.settings_pack_included'),
          tappable: false, rowId: 'rowPack'
        })
      }
    }
  }

  @Builder
  demo() {
    Row() {
      SectionHeader({ label: $r('app.string.settings_demo') })
        .layoutWeight(1)
      SimulatedBadge({ visible: this.vm.settings.useDemoWalk })
        .margin({ right: Space.S2, bottom: Space.S2 })
    }
    .width('100%')

    SettingsCard() {
      ToggleRow({
        title: $r('app.string.settings_demo_walk'),
        subtitle: this.vm.tourRunning ? $r('app.string.settings_demo_running_note') :
          (this.vm.settings.useDemoWalk ? $r('app.string.settings_demo_on_note') : ''),
        isOn: this.vm.settings.useDemoWalk, rowId: 'rowDemoWalk',
        onToggle: (on: boolean) => {
          this.vm.setDemoWalk(on);
        }
      })
      if (this.vm.settings.useDemoWalk) {
        RowDivider()
        SegmentRow({
          title: $r('app.string.settings_replay_speed'), options: SPEED_OPTIONS, selected: `${this.vm.demoSpeed()}`,
          idPrefix: 'segSpeed', onSelect: (k: string) => this.vm.setDemoSpeed(Number(k))
        })
      }
    }

    // The amber footnote (DESIGN §3.11, signal.simulated): amber = simulated, never brand.
    Text($r('app.string.settings_demo_walk_note'))
      .id('noteSimulated')
      .fontSize(Type.FOOTNOTE)
      .lineHeight(Type.FOOTNOTE_LH)
      .fontColor($r('app.color.signal_simulated_fg'))
      .backgroundColor($r('app.color.signal_simulated_bg'))
      .borderRadius(Radius.MD)
      .padding({ left: 14, right: 14, top: 10, bottom: 10 })
      .margin({ top: Space.S2 })
      .width('100%')
  }

  @Builder
  permissions() {
    SectionHeader({ label: $r('app.string.settings_permissions') })
    SettingsCard() {
      NavRow({
        title: $r('app.string.settings_location'), value: locRes(this.vm.loc), busy: this.vm.locBusy,
        rowId: 'rowLocation', tappable: this.vm.loc !== LocRow.ALLOWED, onTap: () => {
          this.vm.onLocationRow();
        }
      })
      RowDivider()
      NavRow({
        title: $r('app.string.settings_notifications'), value: notifRes(this.vm.notif), busy: this.vm.notifBusy,
        rowId: 'rowNotifications', tappable: this.vm.notif !== NotifRow.ALLOWED, onTap: () => {
          this.vm.onNotificationsRow();
        }
      })
    }
    Footnote({ text: $r('app.string.settings_perm_note') })
  }

  @Builder
  about() {
    SectionHeader({ label: $r('app.string.settings_about') })
    SettingsCard() {
      NavRow({
        title: $r('app.string.settings_how_made'), rowId: 'rowHowMade', onTap: () => this.app.openAbout()
      })
      RowDivider()
      NavRow({
        title: $r('app.string.settings_sources'), rowId: 'rowSources',
        onTap: () => this.app.openAbout()
      })
      RowDivider()
      NavRow({
        title: $r('app.string.settings_show_intro'), rowId: 'rowShowIntro',
        onTap: () => this.open(Routes.ONBOARDING, '')
      })
      RowDivider()
      NavRow({
        title: $r('app.string.settings_version'), value: $r('app.string.settings_version_value'), tappable: false,
        rowId: 'rowVersion'
      })
    }
  }

  build() {
    NavDestination() {
      Scroll() {
        Column() {
          SettingsHeader({ title: $r('app.string.settings_title'), onBack: () => this.app.back() })
          Column({ space: Space.S5 }) {
            Column() {
              this.narration()
            }

            Column() {
              this.walking()
            }

            Column() {
              this.sound()
            }

            Column() {
              this.offline()
            }

            if (this.vm.demoOffered || this.vm.settings.useDemoWalk) {
              Column() {
                this.demo()
              }
            }

            Column() {
              this.permissions()
            }

            Column() {
              this.about()
            }
          }
          .width('100%')
          .padding({ left: Space.S4, right: Space.S4, bottom: Space.S6 + this.sa.bottom })
        }
        .width('100%')
        .constraintSize({ maxWidth: Size.PAGE_MAX_W })
      }
      .id('pageSettings')
      .scrollBar(BarState.Off)
      .align(Alignment.Top)
      .width('100%')
      .height('100%')
    }
    .hideTitleBar(true)
    .backgroundColor($r('app.color.bg_canvas'))
    // The canvas runs under the status bar; the scroll viewport starts below it.
    .padding({ top: this.sa.top, left: this.sa.left, right: this.sa.right })
    .onShown(() => this.vm.refresh())
  }
}

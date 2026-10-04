// Suite: Onboarding.test - module under test: core/onboarding/OnboardingRules (task A12).
// Step navigation, the narration choice <-> UserSettings mapping, the English voice row (incl. the emulator path
// Laura DOWNLOADABLE -> download fails -> "Fallback voice"), the 中文 row and the permission rows.
import { describe, it, expect } from '@ohos/hypium';
import { Lang } from 'common';
import { PermissionState, SpeechCapabilities, VoiceState } from 'common';
import { EnVoiceStrategy, VoiceLang } from 'common';
import {
  canDownloadEnglish, choiceFor, clampStep, EnVoiceInput, EnVoiceRow, enVoiceRow, LocRow, locationRow, nextStep,
  NotifRow, notifRow, ONB_STEPS, percent, selectedRow, voiceLangForPlan, zhSpoken
} from 'common';

function caps(en: VoiceState, zh: VoiceState): SpeechCapabilities {
  const c: SpeechCapabilities = { en: en, zh: zh };
  return c;
}

function input(en: VoiceState, zh: VoiceState, strategy: EnVoiceStrategy, downloading: boolean,
  failed: boolean, known: boolean): EnVoiceInput {
  const i: EnVoiceInput = {
    capsKnown: known, caps: caps(en, zh), strategy: strategy, downloading: downloading, downloadFailed: failed
  };
  return i;
}

const AUTO: EnVoiceStrategy = EnVoiceStrategy.AUTO_NATIVE_THEN_ZH;

export default function onboardingTest() {
  describe('Onboarding', () => {
    it('steps_advance_and_finish_after_the_third', 0, () => {
      expect(ONB_STEPS).assertEqual(3);
      expect(nextStep(0)).assertEqual(1);
      expect(nextStep(1)).assertEqual(2);
      expect(nextStep(2)).assertEqual(-1);
      expect(nextStep(7)).assertEqual(-1);
      expect(clampStep(-3)).assertEqual(0);
      expect(clampStep(Number.NaN)).assertEqual(0);
      expect(clampStep(1.7)).assertEqual(1);
    });

    it('choice_maps_to_settings_and_back', 0, () => {
      const en = choiceFor(Lang.EN);
      expect(en.textLang as string).assertEqual(Lang.EN);
      expect(en.voiceLang as string).assertEqual(VoiceLang.EN);
      const zh = choiceFor(Lang.ZH);
      expect(zh.textLang as string).assertEqual(Lang.ZH);
      expect(zh.voiceLang as string).assertEqual(VoiceLang.ZH);
      const pl = choiceFor(Lang.PL);
      expect(pl.textLang as string).assertEqual(Lang.PL);
      expect(pl.voiceLang as string).assertEqual(VoiceLang.OFF);
      expect(selectedRow('zh') as string).assertEqual(Lang.ZH);
      expect(selectedRow('pl') as string).assertEqual(Lang.PL);
      expect(selectedRow('en') as string).assertEqual(Lang.EN);
      expect(selectedRow('xx') as string).assertEqual(Lang.EN);
    });

    it('voice_lang_for_plan_follows_text_unless_cross_language_or_off', 0, () => {
      expect(voiceLangForPlan('en', 'en') === undefined).assertTrue();
      expect(voiceLangForPlan('zh', 'zh') === undefined).assertTrue();
      expect(voiceLangForPlan('pl', 'off') === undefined).assertTrue();   // A13: Polish follows the text language
      expect(voiceLangForPlan('en', 'off') as string).assertEqual(VoiceLang.OFF);
      expect(voiceLangForPlan('pl', 'en') as string).assertEqual(VoiceLang.EN);
      expect(voiceLangForPlan('pl', 'zh') as string).assertEqual(VoiceLang.ZH);
    });

    it('emulator_path_laura_downloadable_then_failed_stays_fallback', 0, () => {
      // listVoices pending
      expect(enVoiceRow(input(VoiceState.DOWNLOADABLE, VoiceState.INSTALLED, AUTO, false, false, false)) as string)
        .assertEqual(EnVoiceRow.CHECKING);
      // Laura GA (downloadable), zh installed: Fallback voice, Download offered
      const idle = input(VoiceState.DOWNLOADABLE, VoiceState.INSTALLED, AUTO, false, false, true);
      expect(enVoiceRow(idle) as string).assertEqual(EnVoiceRow.FALLBACK);
      expect(canDownloadEnglish(idle)).assertTrue();
      // downloading
      const dl = input(VoiceState.DOWNLOADABLE, VoiceState.INSTALLED, AUTO, true, false, true);
      expect(enVoiceRow(dl) as string).assertEqual(EnVoiceRow.DOWNLOADING);
      expect(canDownloadEnglish(dl)).assertFalse();
      // 1002300008: still the Fallback voice, honest failure + Try again
      const failed = input(VoiceState.DOWNLOADABLE, VoiceState.INSTALLED, AUTO, false, true, true);
      expect(enVoiceRow(failed) as string).assertEqual(EnVoiceRow.DOWNLOAD_FAILED);
      expect(canDownloadEnglish(failed)).assertTrue();
    });

    it('laura_installed_is_native_and_needs_no_download', 0, () => {
      const i = input(VoiceState.INSTALLED, VoiceState.INSTALLED, AUTO, false, false, true);
      expect(enVoiceRow(i) as string).assertEqual(EnVoiceRow.NATIVE);
      expect(canDownloadEnglish(i)).assertFalse();
    });

    it('english_row_follows_the_strategy', 0, () => {
      expect(enVoiceRow(input(VoiceState.DOWNLOADABLE, VoiceState.INSTALLED,
        EnVoiceStrategy.AUTO_NATIVE_THEN_TEXT, false, false, true)) as string).assertEqual(EnVoiceRow.TEXT_ONLY);
      expect(enVoiceRow(input(VoiceState.INSTALLED, VoiceState.INSTALLED,
        EnVoiceStrategy.FORCE_ZH, false, false, true)) as string).assertEqual(EnVoiceRow.FALLBACK);
      expect(enVoiceRow(input(VoiceState.INSTALLED, VoiceState.INSTALLED,
        EnVoiceStrategy.TEXT_ONLY, false, false, true)) as string).assertEqual(EnVoiceRow.TEXT_ONLY);
      // no zh voice and no Laura: text only
      expect(enVoiceRow(input(VoiceState.DOWNLOADABLE, VoiceState.UNAVAILABLE, AUTO, false, false, true)) as string)
        .assertEqual(EnVoiceRow.TEXT_ONLY);
    });

    it('zh_row_spoken_unless_unavailable', 0, () => {
      expect(zhSpoken(false, caps(VoiceState.ERROR, VoiceState.ERROR))).assertTrue();
      expect(zhSpoken(true, caps(VoiceState.DOWNLOADABLE, VoiceState.INSTALLED))).assertTrue();
      expect(zhSpoken(true, caps(VoiceState.DOWNLOADABLE, VoiceState.ERROR))).assertTrue();
      expect(zhSpoken(true, caps(VoiceState.DOWNLOADABLE, VoiceState.UNAVAILABLE))).assertFalse();
    });

    it('percent_accepts_fraction_or_percent', 0, () => {
      expect(percent(0.4)).assertEqual(40);
      expect(percent(40)).assertEqual(40);
      expect(percent(250)).assertEqual(100);
      expect(percent(-1)).assertEqual(0);
      expect(percent(Number.NaN)).assertEqual(0);
    });

    it('location_row_states', 0, () => {
      expect(locationRow(PermissionState.UNKNOWN, false) as string).assertEqual(LocRow.ASK);
      expect(locationRow(PermissionState.GRANTED, true) as string).assertEqual(LocRow.ALLOWED);
      expect(locationRow(PermissionState.GRANTED, false) as string).assertEqual(LocRow.SWITCH_OFF);
      expect(locationRow(PermissionState.APPROX_ONLY, true) as string).assertEqual(LocRow.APPROX);
      expect(locationRow(PermissionState.DENIED, true) as string).assertEqual(LocRow.DENIED);
    });

    it('notification_row_states', 0, () => {
      expect(notifRow(true, false) as string).assertEqual(NotifRow.ALLOWED);
      expect(notifRow(true, true) as string).assertEqual(NotifRow.ALLOWED);
      expect(notifRow(false, false) as string).assertEqual(NotifRow.ASK);
      expect(notifRow(false, true) as string).assertEqual(NotifRow.DENIED);
    });
  });
}

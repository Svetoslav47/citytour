// Suite: Settings.test - module under test: core/settings/SettingsRules (task B9), plus the two engine knobs the
// Settings rows drive: TourConfig.triggerRadiusScale (trigger distance) and LingerInput.briefOnly (detail level).
import { describe, it, expect } from '@ohos/hypium';
import { Lang } from 'common';
import { EngineEvent, EngineEventType, TourPlan } from 'common';
import { FixSource, VoicePlan } from 'common';
import { EnVoiceStrategy, UiLang, VoiceLabel, VoiceLang } from 'common';
import {
  DetailLevel, detailKnobs, detailLevelOf, megabytes, normalizeSpeed, normalizeTriggerM, packLine, STORY_LANGS,
  StoryLang, storyLangOf, storyLangPair, StrategyChoice, strategyChoiceOf, strategyFor, triggerScale, uiLangOf,
  uiLangTag, validStrategy, VoiceRow, voiceRowFor
} from 'common';
import { TourConfig } from 'common';
import { TourEngine, TourInput, TourState } from 'common';
import { decideAfterTeaser, LingerInput, StopTrigger, StoryLength } from 'common';
import { MINI_BARBICAN, MINI_CLOTH_HALL, MINI_PERSONA_ID, MINI_ST_MARYS, MINI_TOUR_ID, miniPois, miniTour } from './fixtures/MiniPack';

function voicePlan(): VoicePlan {
  const v: VoicePlan = {
    textLang: Lang.EN, speechMode: 'text', engineLocale: '', person: 0, languageContext: '',
    label: VoiceLabel.TEXT_ONLY_USER, reason: 'test'
  };
  return v;
}

/** Radii of the planned stops after PLAN_READY with the given scale. */
function plannedRadii(scale: number): number[] {
  const inp: TourInput = {
    tour: miniTour(), pois: miniPois(), lang: Lang.EN, personaId: MINI_PERSONA_ID,
    narration: () => undefined, voice: voicePlan(), adaptiveLength: true, spokenDirections: true,
    source: FixSource.DEMO
  };
  const cfg = new TourConfig();
  cfg.triggerRadiusScale = scale;
  let st: TourState = TourEngine.init(inp, cfg);
  const e0: EngineEvent = { type: EngineEventType.START_PLANNING, nowMs: 1000 };
  st = TourEngine.reduce(st, e0).state;
  const p: TourPlan = {
    tourId: MINI_TOUR_ID, order: [MINI_BARBICAN, MINI_ST_MARYS, MINI_CLOTH_HALL], costS: 900, walkM: 700,
    savedM: 0, exact: true, algo: 'heldkarp', ms: 1, budgetS: 0, legs: []
  };
  const e1: EngineEvent = { type: EngineEventType.PLAN_READY, nowMs: 1000, plan: p };
  st = TourEngine.reduce(st, e1).state;
  return st.stops.map((s) => s.trigger.triggerRadiusM);
}

function linger(adaptive: boolean, brief: boolean, askedMore: boolean): LingerInput {
  const i: LingerInput = {
    speedMedianMps: 0.2, slowForMs: 0, waitedMs: 0, adaptiveLength: adaptive, userAskedMore: askedMore,
    briefOnly: brief
  };
  return i;
}

function insideStop(): StopTrigger {
  const t = new StopTrigger('p', 35);
  t.inside = true;
  return t;
}

export default function settingsTest() {
  describe('Settings', () => {
    it('story_language_rows_map_to_text_and_voice_and_back', 0, () => {
      for (const s of STORY_LANGS) {
        const p = storyLangPair(s);
        expect(storyLangOf(p.textLang, p.voiceLang) as string).assertEqual(s);
      }
      const listen = storyLangPair(StoryLang.PL_LISTEN_EN);
      expect(listen.textLang as string).assertEqual(Lang.PL);
      expect(listen.voiceLang as string).assertEqual(VoiceLang.EN);
      expect(storyLangPair(StoryLang.PL).voiceLang as string).assertEqual(VoiceLang.OFF);
      expect(storyLangPair(StoryLang.ZH).voiceLang as string).assertEqual(VoiceLang.ZH);
      expect(storyLangOf('xx', 'en') as string).assertEqual(StoryLang.EN);
      expect(storyLangOf('pl', 'zh') as string).assertEqual(StoryLang.PL);   // no row for pl + zh: text-only row
    });

    it('app_language_tags_for_setAppPreferredLanguage', 0, () => {
      expect(uiLangTag(UiLang.SYSTEM)).assertEqual('default');
      expect(uiLangTag(UiLang.EN)).assertEqual('en-US');
      expect(uiLangTag(UiLang.PL)).assertEqual('pl-PL');
      expect(uiLangTag(UiLang.ZH)).assertEqual('zh-Hans');
      expect(uiLangTag('??')).assertEqual('default');
      expect(uiLangOf('pl') as string).assertEqual(UiLang.PL);
      expect(uiLangOf('de') as string).assertEqual(UiLang.SYSTEM);
    });

    it('strategy_picker_round_trip_and_unknown_values', 0, () => {
      expect(strategyFor(StrategyChoice.AUTO) as string).assertEqual(EnVoiceStrategy.AUTO_NATIVE_THEN_ZH);
      expect(strategyFor(StrategyChoice.ZH) as string).assertEqual(EnVoiceStrategy.FORCE_ZH);
      expect(strategyFor(StrategyChoice.TEXT) as string).assertEqual(EnVoiceStrategy.TEXT_ONLY);
      expect(strategyChoiceOf(EnVoiceStrategy.FORCE_ZH) as string).assertEqual(StrategyChoice.ZH);
      expect(strategyChoiceOf(EnVoiceStrategy.TEXT_ONLY) as string).assertEqual(StrategyChoice.TEXT);
      expect(strategyChoiceOf(EnVoiceStrategy.AUTO_NATIVE_THEN_TEXT) as string).assertEqual(StrategyChoice.AUTO);
      expect(validStrategy('bogus', EnVoiceStrategy.AUTO_NATIVE_THEN_ZH) as string)
        .assertEqual(EnVoiceStrategy.AUTO_NATIVE_THEN_ZH);
      expect(validStrategy('force-zh', EnVoiceStrategy.AUTO_NATIVE_THEN_ZH) as string)
        .assertEqual(EnVoiceStrategy.FORCE_ZH);
    });

    it('voice_row_is_honest_about_what_is_heard', 0, () => {
      expect(voiceRowFor(VoiceLabel.NATIVE, 'en-US') as string).assertEqual(VoiceRow.LAURA);
      expect(voiceRowFor(VoiceLabel.NATIVE, 'zh-CN') as string).assertEqual(VoiceRow.ZH);
      expect(voiceRowFor(VoiceLabel.FALLBACK_ZH_READS_EN, 'zh-CN') as string).assertEqual(VoiceRow.FALLBACK);
      expect(voiceRowFor(VoiceLabel.TEXT_ONLY_USER, '') as string).assertEqual(VoiceRow.TEXT_USER);
      expect(voiceRowFor(VoiceLabel.TEXT_ONLY_PLATFORM, '') as string).assertEqual(VoiceRow.TEXT_PLATFORM);
      expect(voiceRowFor(VoiceLabel.PRERENDERED, '') as string).assertEqual(VoiceRow.PRERENDERED);
    });

    it('detail_levels_drive_real_engine_knobs', 0, () => {
      const b = detailKnobs(DetailLevel.BRIEF);
      expect(b.briefOnly).assertTrue();
      const s = detailKnobs(DetailLevel.STANDARD);
      expect(s.adaptiveLength).assertTrue();
      expect(s.briefOnly).assertFalse();
      const d = detailKnobs(DetailLevel.DEEP);
      expect(d.adaptiveLength).assertFalse();
      expect(d.briefOnly).assertFalse();
      expect(detailLevelOf('deep') as string).assertEqual(DetailLevel.DEEP);
      expect(detailLevelOf('') as string).assertEqual(DetailLevel.STANDARD);
    });

    it('brief_gives_the_teaser_even_when_standing_unless_asked_for_more', 0, () => {
      const cfg = new TourConfig();
      const standing = decideAfterTeaser(insideStop(), linger(true, false, false), cfg);
      expect(standing.length as string).assertEqual(StoryLength.FULL);
      const brief = decideAfterTeaser(insideStop(), linger(true, true, false), cfg);
      expect(brief.length as string).assertEqual(StoryLength.TEASER_ONLY);
      expect(brief.reason).assertEqual('brief');
      const more = decideAfterTeaser(insideStop(), linger(true, true, true), cfg);
      expect(more.length as string).assertEqual(StoryLength.FULL);
      const deep = decideAfterTeaser(insideStop(), linger(false, false, false), cfg);
      expect(deep.length as string).assertEqual(StoryLength.FULL);
    });

    it('trigger_distance_scales_the_curated_radii', 0, () => {
      expect(normalizeTriggerM(22)).assertEqual(20);
      expect(normalizeTriggerM(Number.NaN)).assertEqual(35);
      expect(normalizeTriggerM(100)).assertEqual(50);
      expect(triggerScale(35)).assertEqual(1);
      expect(Math.abs(triggerScale(20) - 20 / 35) < 1e-9).assertTrue();
      const base = plannedRadii(1);
      expect(base.length).assertEqual(3);
      const wide = plannedRadii(triggerScale(50));
      const tight = plannedRadii(triggerScale(20));
      for (let i = 0; i < base.length; i++) {
        expect(wide[i]).assertEqual(Math.round(base[i] * 50 / 35));
        expect(tight[i]).assertEqual(Math.round(base[i] * 20 / 35));
      }
      expect(plannedRadii(0)[0]).assertEqual(base[0]);   // a broken scale keeps the curated radius
    });

    it('demo_speed_and_pack_line', 0, () => {
      expect(normalizeSpeed(3)).assertEqual(2);
      expect(normalizeSpeed(8)).assertEqual(8);
      expect(normalizeSpeed(Number.NaN)).assertEqual(4);
      expect(megabytes(0)).assertEqual(0);
      expect(megabytes(1024)).assertEqual(0.1);
      expect(megabytes(5 * 1024 * 1024 + 300000)).assertEqual(5.3);
      expect(megabytes(48 * 1024 * 1024)).assertEqual(48);
      const l = packLine(3412, 11, [1024 * 1024, Number.NaN, -5, 1024 * 1024]);
      expect(l.places).assertEqual(3412);
      expect(l.stories).assertEqual(11);
      expect(l.sizeMb).assertEqual(2);
      expect(packLine(-1, Number.NaN, []).sizeMb).assertEqual(0);
    });
  });
}

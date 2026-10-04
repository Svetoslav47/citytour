// Suite: Phrases.test - module under test: core/content/Phrases (task A3; A9 adds the maneuver templates).
// Cases from docs/ARCHITECTURE.md §11.1 that A3 owns: every phrase key x language has a template, no `{}`
// left after formatting. Plus: every RelDir has wording in en/zh/pl, sentences are short and spoken-style
// (DESIGN §5.1: <= 20 words), end with a full stop, zh templates carry no Latin words, distance rounding
// (DESIGN §5.4), the arrival line with RelDir and the look clause, the G9 fallback without left/right,
// the simulated welcome line, and the localized-name fallback chain.
import { describe, it, expect } from '@ohos/hypium';
import {
  ALL_LANGS, ALL_MANEUVERS, ALL_MODIFIERS, ALL_PHRASE_KEYS, ALL_REL_DIRS, PhraseKey, actionWithStreet,
  approachSentence, arrivalSentences, distancePhrase, finishSentences, gpsLostSentence, localized, maneuverAction,
  nextStopSentence, phrase, phraseTemplate, relDirPhrase, welcomeSentences
} from 'common';
import { RelDir } from 'common';
import { Lang, LocalizedText, LookDir, Maneuver, RouteStep, ViewHint } from 'common';
import { maneuverUiText, nowText, prepareText } from 'common';

const LONG_NAME: string = 'Saint Mary\'s Basilica';

function wordCount(s: string): number {
  return s.split(/\s+/).filter((w: string) => w.length > 0).length;
}

function towerView(look: LookDir): ViewHint {
  const v: ViewHint = { look: look, feature: { en: 'the taller tower', zh: '较高的塔楼', pl: 'wyższa wieża' } };
  return v;
}

/** Every phrase of every key in a language, filled with realistic values. */
function allFilled(lang: Lang): string[] {
  const out: string[] = [];
  for (const k of ALL_PHRASE_KEYS) {
    out.push(phrase(k, lang, {
      name: LONG_NAME, dir: relDirPhrase(RelDir.BEHIND_RIGHT, lang), dist: distancePhrase(430, lang, 1.3),
      feature: 'the taller tower', tour: 'The Royal Route',
      action: maneuverAction(Maneuver.END_OF_ROAD, 'sharp left', lang),
      next: maneuverAction(Maneuver.FORK, 'slight right', lang), street: 'Floriańska'
    }));
  }
  return out;
}

export default function phrasesTest() {
  describe('Phrases', () => {
    it('every_key_and_reldir_has_text_in_every_language', 0, () => {
      for (const lang of ALL_LANGS) {
        for (const k of ALL_PHRASE_KEYS) {
          expect(phraseTemplate(k, lang).length).assertLarger(0);
        }
        const seen: Set<string> = new Set<string>();
        for (const d of ALL_REL_DIRS) {
          const p: string = relDirPhrase(d, lang);
          expect(p.length).assertLarger(0);
          seen.add(p);
        }
        expect(seen.size).assertEqual(ALL_REL_DIRS.length);   // all nine distinct
      }
    });

    it('no_placeholder_left_after_formatting', 0, () => {
      for (const lang of ALL_LANGS) {
        for (const s of allFilled(lang)) {
          expect(s.indexOf('{') < 0 && s.indexOf('}') < 0).assertTrue();
        }
      }
      // the helper functions fill everything too
      const helpers: string[] = [
        approachSentence(Lang.EN, LONG_NAME, RelDir.LEFT, 80, 1.3, true),
        approachSentence(Lang.ZH, LONG_NAME, RelDir.HERE, 80, 1.3, true),
        nextStopSentence(Lang.PL, LONG_NAME, Number.NaN, 1.3),
        gpsLostSentence(Lang.ZH)
      ];
      for (const s of helpers) {
        expect(s.indexOf('{') < 0).assertTrue();
      }
    });

    it('sentences_are_short_and_end_with_a_full_stop', 0, () => {
      for (const lang of [Lang.EN, Lang.PL]) {
        for (const s of allFilled(lang)) {
          expect(wordCount(s)).assertLessOrEqual(20);
          const last: string = s.charAt(s.length - 1);
          expect(last === '.' || last === '!').assertTrue();
        }
      }
      for (const s of allFilled(Lang.ZH)) {
        expect(s.length).assertLessOrEqual(60);
        expect(s.charAt(s.length - 1)).assertEqual('。');
      }
    });

    it('zh_templates_have_no_latin_words', 0, () => {
      for (const k of ALL_PHRASE_KEYS) {
        const t: string = phraseTemplate(k, Lang.ZH).replace(/\{[a-z]+\}/g, '').replace('GPS', '');
        expect(/[A-Za-z]/.test(t)).assertFalse();
      }
    });

    it('distance_rounding_rules', 0, () => {
      expect(distancePhrase(3, Lang.EN, 1.3)).assertEqual('10 metres');     // at least 10
      expect(distancePhrase(43, Lang.EN, 1.3)).assertEqual('40 metres');    // < 100: to 10
      expect(distancePhrase(45, Lang.EN, 1.3)).assertEqual('50 metres');
      expect(distancePhrase(120, Lang.EN, 1.3)).assertEqual('100 metres');  // < 500: to 50
      expect(distancePhrase(230, Lang.EN, 1.3)).assertEqual('250 metres');
      expect(distancePhrase(600, Lang.EN, 1.3)).assertEqual('8 minutes');   // 600 / 1.3 / 60 = 7.7
      expect(distancePhrase(600, Lang.EN, 10)).assertEqual('1 minute');
      expect(distancePhrase(80, Lang.ZH, 1.3)).assertEqual('80米');
      expect(distancePhrase(600, Lang.ZH, 1.3)).assertEqual('8分钟');
      expect(distancePhrase(80, Lang.PL, 1.3)).assertEqual('80 metrów');
      expect(distancePhrase(600, Lang.PL, 1.3)).assertEqual('8 minut');
      expect(distancePhrase(600, Lang.PL, 10)).assertEqual('minuty');       // "około minuty"
    });

    it('arrival_line_with_direction_and_look_clause', 0, () => {
      const en: string[] = arrivalSentences(Lang.EN, LONG_NAME, RelDir.LEFT, towerView(LookDir.UP), true);
      expect(en.length).assertEqual(2);
      expect(en[0]).assertEqual('Saint Mary\'s Basilica is on your left.');
      expect(en[1]).assertEqual('Look up at the taller tower.');
      const zh: string[] = arrivalSentences(Lang.ZH, '圣玛丽大教堂', RelDir.AHEAD_RIGHT, towerView(LookDir.UP), true);
      expect(zh[0]).assertEqual('圣玛丽大教堂在右前方。');
      expect(zh[1]).assertEqual('请抬头看较高的塔楼。');
      const pl: string[] = arrivalSentences(Lang.PL, 'Bazylika Mariacka', RelDir.BEHIND, towerView(LookDir.DOWN), true);
      expect(pl[0]).assertEqual('Bazylika Mariacka jest za Tobą.');
      expect(pl[1]).assertEqual('Spójrz w dół: wyższa wieża.');
      // HERE (closer than 15 m or course unknown) and no view
      const here: string[] = arrivalSentences(Lang.EN, 'Cloth Hall', RelDir.HERE, undefined, true);
      expect(here.length).assertEqual(1);
      expect(here[0]).assertEqual('You\'re at Cloth Hall.');
    });

    it('g9_fallback_has_no_left_or_right', 0, () => {
      const s: string[] = arrivalSentences(Lang.EN, LONG_NAME, RelDir.LEFT, towerView(LookDir.UP), false);
      expect(s[0]).assertEqual('You\'re at Saint Mary\'s Basilica.');
      expect(s[1]).assertEqual('Look for the taller tower.');
      const joined: string = s.join(' ');
      expect(joined.indexOf('left') < 0 && joined.indexOf('right') < 0).assertTrue();
      expect(approachSentence(Lang.EN, 'Cloth Hall', RelDir.RIGHT, 90, 1.3, false))
        .assertEqual('In about 90 metres: Cloth Hall.');
    });

    it('approach_next_welcome_finish_lines', 0, () => {
      expect(approachSentence(Lang.EN, LONG_NAME, RelDir.LEFT, 78, 1.3, true))
        .assertEqual('In about 80 metres, on your left: Saint Mary\'s Basilica.');
      expect(approachSentence(Lang.ZH, '圣玛丽大教堂', RelDir.LEFT, 78, 1.3, true))
        .assertEqual('再走大约80米，圣玛丽大教堂在您左侧。');
      expect(nextStopSentence(Lang.EN, 'Cloth Hall', 240, 1.3))
        .assertEqual('Next stop: Cloth Hall, about 250 metres from here.');
      expect(nextStopSentence(Lang.EN, 'Cloth Hall', Number.NaN, 1.3)).assertEqual('Next stop: Cloth Hall.');
      const sim: string[] = welcomeSentences(Lang.EN, 'The Royal Route', true);
      expect(sim.length).assertEqual(3);
      expect(sim[2].indexOf('simulated') >= 0).assertTrue();
      expect(welcomeSentences(Lang.ZH, '皇家之路', false).length).assertEqual(2);
      expect(finishSentences(Lang.PL).length).assertEqual(2);
      expect(gpsLostSentence(Lang.EN)).assertEqual('I\'ve lost the GPS signal. I\'ll continue when it\'s back.');
      expect(phrase(PhraseKey.WELCOME, Lang.EN, { tour: 'The Royal Route' }))
        .assertEqual('Welcome! Today\'s walk: The Royal Route.');
    });

    it('every_maneuver_x_modifier_x_lang_has_a_short_action', 0, () => {
      for (const lang of ALL_LANGS) {
        for (const m of ALL_MANEUVERS) {
          for (const mod of ALL_MODIFIERS) {
            const a: string = maneuverAction(m, mod, lang);
            expect(a.length).assertLarger(0);
            expect(a.indexOf('{') < 0 && a.indexOf('}') < 0).assertTrue();
            if (lang === Lang.ZH) {
              expect(/[A-Za-z]/.test(a)).assertFalse();
              expect(a.length).assertLessOrEqual(12);
            } else {
              expect(wordCount(a)).assertLessOrEqual(9);
            }
            const st: RouteStep = {
              maneuver: m, modifier: mod, streetName: 'Floriańska', distanceM: 40, durationS: 30, geomIndex: 0, x: 0,
              y: 0
            };
            const lines: string[] = [prepareText(lang, st, 28, 1.3, undefined), nowText(lang, st, st),
              maneuverUiText(lang, st, 120, 1.3, 8)];
            for (const l of lines) {
              expect(l.indexOf('{') < 0).assertTrue();
            }
          }
        }
        // left and right never read the same
        expect(maneuverAction(Maneuver.TURN, 'left', lang) === maneuverAction(Maneuver.TURN, 'right', lang))
          .assertFalse();
        expect(maneuverAction(Maneuver.FORK, 'slight left', lang) ===
          maneuverAction(Maneuver.FORK, 'slight right', lang)).assertFalse();
      }
    });

    it('zh_omits_polish_street_names_en_and_pl_keep_them', 0, () => {
      const st: RouteStep = {
        maneuver: Maneuver.TURN, modifier: 'left', streetName: 'Floriańska', distanceM: 40, durationS: 30, geomIndex: 0,
        x: 0, y: 0
      };
      expect(prepareText(Lang.ZH, st, 30, 1.3, undefined).indexOf('Floriańska') < 0).assertTrue();
      expect(nowText(Lang.ZH, st, undefined)).assertEqual('现在左转。');
      expect(nowText(Lang.EN, st, undefined)).assertEqual('Now turn left onto Floriańska.');
      expect(nowText(Lang.PL, st, undefined)).assertEqual('Teraz skręć w lewo (Floriańska).');
      expect(actionWithStreet('左转', 'Floriańska', Lang.ZH)).assertEqual('左转');
      expect(actionWithStreet('turn left', '', Lang.EN)).assertEqual('turn left');
    });

    it('localized_falls_back_en_pl_zh', 0, () => {
      const plOnly: LocalizedText = { pl: 'Sukiennice' };
      const enPl: LocalizedText = { en: 'Cloth Hall', pl: 'Sukiennice' };
      const all: LocalizedText = { en: 'Cloth Hall', pl: 'Sukiennice', zh: '纺织会馆' };
      const zhOnly: LocalizedText = { en: '', zh: '纺织会馆' };
      expect(localized(plOnly, Lang.EN)).assertEqual('Sukiennice');
      expect(localized(enPl, Lang.ZH)).assertEqual('Cloth Hall');
      expect(localized(all, Lang.ZH)).assertEqual('纺织会馆');
      expect(localized(zhOnly, Lang.PL)).assertEqual('纺织会馆');
      expect(localized(undefined, Lang.EN)).assertEqual('');
    });
  });
}

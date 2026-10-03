// Suite: NotifyText.test - module under test: core/notify/NotifyText (task A8).
// Cases: the next-stop notification text ("Next: X" / "240 m · ~3 min · on your left" / "k/n"), the text-only
// arrival text, SIMULATED wording in demo mode (en/pl/zh), no emoji, length bounds, distance/ETA rounding,
// notice kind detection from the live snapshot, the >= 50 m refresh rule, and the haptic preset/fallback choice.
import { describe, it, expect } from '@ohos/hypium';
import {
  HapticPlan, NOTIFY_TEXT_MAX, NOTIFY_TITLE_MAX, NoticeKind, NotifyContext, NotifyText, ShownNotice,
  contextFromSnapshot, formatNotice, hapticPlan, isTourLive, noticeKind, sanitizeNotifyText, shortDistance, shortEta,
  shouldRefresh, shownDistance
} from '../main/ets/core/notify/NotifyText';
import {
  EngineSnapshot, HapticKind, NextNotice, PlatformStatus, RelDir, SignalQuality, StopProgress, StopStatus,
  TourPhase
} from '../main/ets/contracts/EngineTypes';
import { FixSource } from '../main/ets/contracts/Ports';
import { Lang } from '../main/ets/contracts/Model';
import { VoiceLabel } from '../main/ets/contracts/Settings';

const IDS: string[] = ['barbican', 'florian', 'stmary', 'cloth', 'wawel'];

function snap(phase: TourPhase, currentIdx: number, source: FixSource, nextIdx: number, d: number,
  dir: RelDir): EngineSnapshot {
  const stops: StopProgress[] = IDS.map((id: string, i: number): StopProgress => {
    const p: StopProgress = { poiId: id, order: i, status: StopStatus.PENDING };
    return p;
  });
  const platform: PlatformStatus = {
    bgRunning: false, avsActive: false, ttsEngine: 'none', sourceKind: source, realGpsAccuracyM: Number.NaN,
    demoHold: false
  };
  const s: EngineSnapshot = {
    phase: phase, tourId: 'royal', stops: stops, currentStopIdx: currentIdx,
    next: nextIdx < 0 ? undefined : {
      poiId: IDS[nextIdx], distanceM: d, etaS: d / 1.3, relDir: dir, bearingDeg: 0, maneuverText: '',
      maneuverDistM: Number.NaN
    },
    signal: SignalQuality.GOOD, offRoute: false, paused: false, speechText: false, plannedOrder: IDS, walkedM: 0,
    remainingM: 0, issues: [], voiceLabel: VoiceLabel.NATIVE, source: source, platform: platform
  };
  return s;
}

function walking(lang: Lang, demo: boolean, d: number, dir: RelDir): NotifyContext {
  return contextFromSnapshot(snap(TourPhase.WALKING, 4, demo ? FixSource.DEMO : FixSource.REAL, 4, d, dir), lang);
}

function notice(id: string, title: string, text: string, d: number): NextNotice {
  const n: NextNotice = { poiId: id, title: title, text: text, distanceM: d };
  return n;
}

const EMOJI_RE: RegExp = /[\u{1F000}-\u{1FAFF}\u{2600}-\u{27BF}\u{FE0F}\u{200D}]/u;

export default function notifyTextTest() {
  describe('NotifyText', () => {
    it('next_stop_en_matches_architecture_example', 0, () => {
      const t: NotifyText = formatNotice(notice('wawel', 'Wawel Cathedral', 'Next stop: Wawel Cathedral.', 240),
        NoticeKind.NEXT, walking(Lang.EN, false, 238, RelDir.LEFT));
      expect(t.title).assertEqual('Next: Wawel Cathedral');
      expect(t.text).assertEqual('240 m · ~3 min · on your left');
      expect(t.additionalText).assertEqual('5/5');
    });

    it('demo_walk_says_simulated_in_every_language', 0, () => {
      const n: NextNotice = notice('wawel', 'Wawel', 'x', 240);
      expect(formatNotice(n, NoticeKind.NEXT, walking(Lang.EN, true, 240, RelDir.HERE)).text)
        .assertEqual('SIMULATED · 240 m · ~3 min');
      expect(formatNotice(n, NoticeKind.NEXT, walking(Lang.PL, true, 240, RelDir.HERE)).text.startsWith('SYMULACJA · '))
        .assertTrue();
      expect(formatNotice(n, NoticeKind.NEXT, walking(Lang.ZH, true, 240, RelDir.HERE)).text.startsWith('模拟 · '))
        .assertTrue();
      expect(formatNotice(n, NoticeKind.NEXT, walking(Lang.EN, false, 240, RelDir.HERE)).text.indexOf('SIMULATED'))
        .assertEqual(-1);
    });

    it('pl_and_zh_titles', 0, () => {
      const n: NextNotice = notice('wawel', 'Katedra Wawelska', 'x', 1240);
      const pl: NotifyText = formatNotice(n, NoticeKind.NEXT, walking(Lang.PL, false, 1240, RelDir.HERE));
      expect(pl.title).assertEqual('Dalej: Katedra Wawelska');
      expect(pl.text).assertEqual('1,2 km · ~16 min');
      const zh: NotifyText = formatNotice(notice('wawel', '瓦维尔主教座堂', 'x', 240), NoticeKind.NEXT,
        walking(Lang.ZH, false, 240, RelDir.RIGHT));
      expect(zh.title).assertEqual('下一站：瓦维尔主教座堂');
      expect(zh.text).assertEqual('240 米 · 约3分钟 · 在您右侧');
    });

    it('text_only_arrival_uses_the_arrival_line', 0, () => {
      const ctx: NotifyContext = contextFromSnapshot(
        snap(TourPhase.AT_STOP, 2, FixSource.DEMO, 3, 120, RelDir.AHEAD), Lang.PL);
      const n: NextNotice = notice('stmary', 'Kościół Mariacki', 'Jesteś na miejscu: Kościół Mariacki.', 8);
      expect(noticeKind(n, ctx)).assertEqual(NoticeKind.ARRIVAL);
      const t: NotifyText = formatNotice(n, NoticeKind.ARRIVAL, ctx);
      expect(t.title).assertEqual('Jesteś przy: Kościół Mariacki');
      expect(t.text).assertEqual('SYMULACJA · Jesteś na miejscu: Kościół Mariacki.');
      expect(t.additionalText).assertEqual('3/5');
      expect(shownDistance(n, NoticeKind.ARRIVAL, ctx)).assertNaN();
    });

    it('notice_kind_is_next_unless_at_that_stop', 0, () => {
      const atStop: NotifyContext = contextFromSnapshot(
        snap(TourPhase.AT_STOP, 2, FixSource.REAL, 3, 120, RelDir.AHEAD), Lang.EN);
      expect(noticeKind(notice('cloth', 'Cloth Hall', 'x', 120), atStop)).assertEqual(NoticeKind.NEXT); // re-plan
      const walk: NotifyContext = walking(Lang.EN, false, 300, RelDir.AHEAD);
      expect(noticeKind(notice('wawel', 'Wawel', 'x', 300), walk)).assertEqual(NoticeKind.NEXT);
    });

    it('unknown_distance_falls_back_to_the_spoken_sentence', 0, () => {
      const ctx: NotifyContext = contextFromSnapshot(
        snap(TourPhase.WALKING, 0, FixSource.REAL, 0, Number.NaN, RelDir.HERE), Lang.EN);
      const t: NotifyText = formatNotice(notice('barbican', 'Barbican', 'Next stop: Barbican.', -1),
        NoticeKind.NEXT, ctx);
      expect(t.text).assertEqual('Next stop: Barbican.');
      expect(shownDistance(notice('barbican', 'Barbican', '', -1), NoticeKind.NEXT, ctx)).assertNaN();
    });

    it('no_emoji_and_bounded_length', 0, () => {
      const name: string = 'Wawel \u{1F3F0}\u{FE0F} Castle \u{1F600}';
      const t: NotifyText = formatNotice(notice('wawel', name, 'x', 240), NoticeKind.NEXT,
        walking(Lang.EN, true, 240, RelDir.HERE));
      expect(EMOJI_RE.test(t.title)).assertFalse();
      expect(t.title).assertEqual('Next: Wawel Castle');
      const long: string = 'A'.repeat(500);
      const a: NotifyText = formatNotice(notice('wawel', long, long, 1), NoticeKind.ARRIVAL,
        walking(Lang.EN, false, 1, RelDir.HERE));
      expect(Array.from(a.title).length <= NOTIFY_TITLE_MAX).assertTrue();
      expect(Array.from(a.text).length <= NOTIFY_TEXT_MAX).assertTrue();
      expect(a.title.endsWith('...')).assertTrue();
      expect(sanitizeNotifyText('  Grodzka\n\tStreet  ', 50)).assertEqual('Grodzka Street');
      expect(sanitizeNotifyText('Kraków 克拉科夫', 50)).assertEqual('Kraków 克拉科夫');
    });

    it('distance_and_eta_rounding', 0, () => {
      expect(shortDistance(3, Lang.EN)).assertEqual('10 m');
      expect(shortDistance(244, Lang.EN)).assertEqual('240 m');
      expect(shortDistance(996, Lang.EN)).assertEqual('1.0 km');
      expect(shortDistance(2497, Lang.PL)).assertEqual('2,5 km');
      expect(shortDistance(Number.NaN, Lang.EN)).assertEqual('');
      expect(shortEta(10, Lang.EN)).assertEqual('~1 min');
      expect(shortEta(185, Lang.ZH)).assertEqual('约3分钟');
      expect(shortEta(Number.NaN, Lang.EN)).assertEqual('');
    });

    it('refresh_every_50_m_on_the_same_stop_only', 0, () => {
      const n: NextNotice = notice('wawel', 'Wawel', 'x', 400);
      const shown: ShownNotice = { kind: NoticeKind.NEXT, notice: n, distanceM: 400, atMs: 0 };
      expect(shouldRefresh(shown, walking(Lang.EN, false, 360, RelDir.AHEAD), 10000)).assertFalse();
      expect(shouldRefresh(shown, walking(Lang.EN, false, 350, RelDir.AHEAD), 10000)).assertTrue();
      expect(shouldRefresh(shown, walking(Lang.EN, false, 300, RelDir.AHEAD), 1000)).assertFalse(); // < 3 s
      const other: NotifyContext = contextFromSnapshot(
        snap(TourPhase.WALKING, 3, FixSource.REAL, 3, 100, RelDir.AHEAD), Lang.EN);
      expect(shouldRefresh(shown, other, 10000)).assertFalse();   // stop changes come from the engine
      const arrival: ShownNotice = { kind: NoticeKind.ARRIVAL, notice: n, distanceM: Number.NaN, atMs: 0 };
      expect(shouldRefresh(arrival, walking(Lang.EN, false, 100, RelDir.AHEAD), 10000)).assertFalse();
      expect(shouldRefresh(undefined, walking(Lang.EN, false, 100, RelDir.AHEAD), 10000)).assertFalse();
      const noDist: ShownNotice = { kind: NoticeKind.NEXT, notice: n, distanceM: Number.NaN, atMs: 0 };
      expect(shouldRefresh(noDist, walking(Lang.EN, false, 390, RelDir.AHEAD), 10000)).assertTrue();
    });

    it('live_phases', 0, () => {
      expect(isTourLive(TourPhase.WALKING)).assertTrue();
      expect(isTourLive(TourPhase.APPROACHING)).assertTrue();
      expect(isTourLive(TourPhase.AT_STOP)).assertTrue();
      expect(isTourLive(TourPhase.READY)).assertFalse();
      expect(isTourLive(TourPhase.FINISHED)).assertFalse();
      expect(isTourLive(TourPhase.ABORTED)).assertFalse();
      expect(isTourLive(TourPhase.IDLE)).assertFalse();
    });

    it('haptic_preset_when_supported_else_timed_fallback', 0, () => {
      const yes: HapticPlan = hapticPlan(HapticKind.ARRIVE, (id: string) => id === 'haptic.notice.success');
      expect(yes.effectId).assertEqual('haptic.notice.success');
      expect(yes.count).assertEqual(1);
      const no: HapticPlan = hapticPlan(HapticKind.ARRIVE, (id: string) => false);
      expect(no.effectId).assertEqual('');
      expect(no.durationMs).assertEqual(80);
      const throws: HapticPlan = hapticPlan(HapticKind.OFF_ROUTE, (id: string): boolean => {
        throw new Error('801');
      });
      expect(throws.effectId).assertEqual('');
      expect(throws.count).assertEqual(1);
      const off: HapticPlan = hapticPlan(HapticKind.OFF_ROUTE, (id: string) => true);
      expect(off.effectId).assertEqual('haptic.clock.timer');
      expect(off.count).assertEqual(2);
    });
  });
}

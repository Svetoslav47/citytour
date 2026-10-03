/*
 * Developer-only page (A-owned). Opened with:
 *   hdc shell aa start -a EntryAbility -b com.hackyeah.citytour --ps page dev
 * Location sources (A5): LocationDevSection in DevPanelLocation.ets.
 *
 * A4 speech buttons exercise the real stack through AppContainer.speech() / voice():
 *   "EN sample (3 sentences)"  English text, voice chosen by the strategy (emulator: zh voice = "Fallback voice")
 *   "ZH sample"                Chinese text, built-in zh-CN voice
 *   "Text-only sample (PL)"    Polish text: no Polish voice, start/done on a reading timer
 *   "Strategy: ... (cycle)"    cycles EnVoiceStrategy at runtime (default from AppConfig)
 *   "Fallback ctx: ..."        languageContext en-US <-> zh-CN for the zh voice reading English (gate G1 A/B)
 *   "Download English voice"   real downloadVoice path (emulator: 1002300008, plan stays fallback-zh)
 *   "Pause" / "Resume" / "Stop"
 * The sample runner below plays the role TourController (A7) will have: speak n, prefetch n+1, next on done.
 *
 * A6 background + AVSession buttons (AppContainer.background() / mediaSession()):
 *   "Start continuous task" / "Stop continuous task"   ['location','audioPlayback'] (BG_START / BG_STOP)
 *   "Start AVSession" / "Destroy AVSession"            Control Center + lock-screen card (AVS_META event=active)
 *   "Meta: ... (toggle)"                               "Walking to Cloth Hall" <-> "Next: Cloth Hall · 120 m"
 *   "Narration loop"                                   EN sample every 45 s, for the screen-off test (UTT_START)
 * Card commands (AVS_CMD) drive the speech stack the way TourController (A7) will drive the engine:
 *   play -> resume, pause/stop -> pause, playNext -> skip the sentence, playPrevious -> replay the sample,
 *   toggleFavorite ("Tell me more") -> the "more" sample. The card text is DEV TEST DATA, so the artist line
 *   carries " · DEMO".
 * A7 "Demo tour" section (DemoTourSection, first on the page): the real TourController via
 * AppContainer.tourControl(): "Start demo tour" = setSource(DEMO) -> plan(first tour) -> start(); "End tour";
 * "Demo xN (cycle)" and "Jump to next stop" (Demo assist). A status line shows phase, SIMULATED, next stop,
 * voice label and platform flags; the caption line shows the sentence being said.
 * Developer page: literal strings on purpose (resource strings are B-owned and this page is not user-facing).
 */
import { Lang, Tour } from '../contracts/Model';
import { EnVoiceStrategy, VoiceLabel } from '../contracts/Settings';
import {
  BackgroundListener, FixSource, MediaCommand, SpeechCapabilities, SpeechListener, TourControl, Utterance, VoicePlan
} from '../contracts/Ports';
import { EngineSnapshot, MediaMeta, MediaPlayState, NextInfo, TourPlan } from '../contracts/EngineTypes';
import { stripPauseMarkup } from '../core/speech/VoicePolicy';
import { AppContainer } from '../app/AppContainer';
import { Log } from '../app/Log';
import { LogEvents } from '../app/LogEvents';
import { LocationDevSection } from './DevPanelLocation';
import { SafeArea } from '../viewmodel/SafeArea';

const EN_SAMPLE: string[] = [
  'Welcome to the Main Market Square in Krakow.[p300]',
  'Look to your left: Saint Mary\'s Basilica was built in the fourteenth century, and its taller tower is 81 metres high.',
  'Every hour, a trumpeter plays a short melody from that tower and stops in the middle of a note.'
];
const ZH_SAMPLE: string[] = [
  '欢迎来到克拉科夫中央广场。[p300]',
  '请看你的左边，那是圣玛利亚教堂，建于十四世纪，高塔高81米。'
];
const PL_SAMPLE: string[] = [
  'Witamy na Rynku Głównym w Krakowie.',
  'Spójrz w lewo: to Bazylika Mariacka z XIV wieku.'
];

const EN_MORE: string[] = [
  'Tell me more: the trumpeter\'s tune, the Hejnał, breaks off to remember a watchman who, legend says, was shot ' +
    'while sounding the alarm.'
];

const AVS_TITLES: string[] = ['Walking to Cloth Hall', 'Next: Cloth Hall · 120 m'];
const NARRATION_LOOP_MS: number = 45000;

const STRATEGY_CYCLE: EnVoiceStrategy[] = [
  EnVoiceStrategy.AUTO_NATIVE_THEN_ZH, EnVoiceStrategy.AUTO_NATIVE_THEN_TEXT, EnVoiceStrategy.FORCE_ZH,
  EnVoiceStrategy.TEXT_ONLY
];

function labelText(l: VoiceLabel): string {
  if (l === VoiceLabel.NATIVE) {
    return 'Native voice';
  }
  if (l === VoiceLabel.FALLBACK_ZH_READS_EN) {
    return 'Fallback voice';
  }
  if (l === VoiceLabel.TEXT_ONLY_PLATFORM) {
    return 'Text only (no voice for this language)';
  }
  return 'Text only (your choice)';
}

/** Sequences a sample like the tour will: speak n, prefetch n+1, next on done or error. */
class SampleRunner implements SpeechListener {
  onLine: (line: string) => void = (line: string) => {};
  onCaption: (text: string) => void = (text: string) => {};
  onFinished: () => void = () => {};
  private items: Utterance[] = [];
  private lastName: string = '';
  private lastTexts: string[] = [];
  private lastLang: Lang = Lang.EN;
  private idx: number = -1;
  private run: number = 0;

  start(name: string, texts: string[], lang: Lang): void {
    this.run++;
    this.lastName = name;
    this.lastTexts = texts;
    this.lastLang = lang;
    const items: Utterance[] = [];
    for (let i = 0; i < texts.length; i++) {
      const u: Utterance = {
        id: `${name}-r${this.run}-${i + 1}`, itemId: `sample-${name}`, text: texts[i], lang: lang,
        personaId: 'historian'
      };
      items.push(u);
    }
    this.items = items;
    this.idx = -1;
    Log.i(LogEvents.STORY_QUEUE, `event=dev_sample name=${name} run=${this.run} n=${texts.length} lang=${lang}`);
    this.next();
  }

  stop(): void {
    this.run++;
    this.items = [];
    this.idx = -1;
  }

  isActive(): boolean {
    return this.idx >= 0 && this.idx < this.items.length;
  }

  /** AVSession playNext: drop the rest of the current sentence and go on with the next one. */
  skip(): void {
    if (!this.isActive()) {
      return;
    }
    AppContainer.speech().stopNow();
    this.onLine(`skipped ${this.items[this.idx].id}`);
    this.next();
  }

  /** AVSession playPrevious: replay the last sample from its start. */
  replay(): boolean {
    if (this.lastTexts.length === 0) {
      return false;
    }
    AppContainer.speech().stopNow();
    this.start(this.lastName, this.lastTexts, this.lastLang);
    return true;
  }

  onUtteranceStart(id: string): void {
    const u = this.find(id);
    if (u !== undefined) {
      this.onCaption(stripPauseMarkup(u.text));
      this.onLine(`speaking ${id}`);
    }
  }

  onUtteranceDone(id: string): void {
    if (this.isCurrent(id)) {
      this.onLine(`done ${id}`);
      this.next();
    }
  }

  onUtteranceError(id: string, code: number): void {
    if (this.isCurrent(id)) {
      this.onLine(`error ${id} code=${code}`);
      this.next();
    }
  }

  private isCurrent(id: string): boolean {
    return this.idx >= 0 && this.idx < this.items.length && this.items[this.idx].id === id;
  }

  private find(id: string): Utterance | undefined {
    for (const u of this.items) {
      if (u.id === id) {
        return u;
      }
    }
    return undefined;
  }

  private next(): void {
    this.idx++;
    if (this.idx >= this.items.length) {
      if (this.items.length > 0) {
        this.onLine(`sample finished (${this.items.length} sentences)`);
        this.onCaption('');
        this.onFinished();
      }
      return;
    }
    const sp = AppContainer.speech();
    sp.speak(this.items[this.idx]);
    if (this.idx + 1 < this.items.length) {
      sp.prefetch(this.items[this.idx + 1]);
    }
  }
}

/** Refreshes the A6 status lines when the system cancels or suspends the continuous task. */
class DevBgListener implements BackgroundListener {
  private readonly cancelled: () => void;
  private readonly suspended: () => void;

  constructor(cancelled: () => void, suspended: () => void) {
    this.cancelled = cancelled;
    this.suspended = suspended;
  }

  onCancelled(reason: string): void {
    this.cancelled();
  }

  onSuspended(reason: string): void {
    this.suspended();
  }
}

const DEMO_SPEED_CYCLE: number[] = [8, 4, 2, 1];

/** A7: drives the real TourController with the Demo walk (SIMULATED). */
@ComponentV2
struct DemoTourSection {
  @Local line: string = 'tour: idle';
  @Local caption: string = '';
  @Local speed: number = 8;
  private unsub: (() => void) | undefined = undefined;

  aboutToAppear(): void {
    try {
      this.unsub = AppContainer.tourControl().subscribe((s: EngineSnapshot) => this.render(s));
    } catch (e) {
      this.line = `tour: subscribe failed ${Log.errKv(e as Object)}`;
    }
  }

  aboutToDisappear(): void {
    if (this.unsub !== undefined) {
      this.unsub();
      this.unsub = undefined;
    }
  }

  private render(s: EngineSnapshot): void {
    const n: NextInfo | undefined = s.next;
    const next: string = n === undefined ? '-' :
      `${n.poiId} ${Number.isFinite(n.distanceM) ? Math.round(n.distanceM) + ' m' : '?'}`;
    this.line = `${s.phase}${s.paused ? ' (paused)' : ''} | ${s.source === FixSource.DEMO ? 'SIMULATED demo walk' : 'real GPS'}` +
      ` | next ${next} | voice ${s.voiceLabel} | bg=${s.platform.bgRunning ? 1 : 0} avs=${s.platform.avsActive ? 1 : 0}` +
      `${s.platform.demoHold ? ' | Demo assist: holding' : ''} | issues ${s.issues.map((i) => i.code).join(',')}`;
    this.caption = s.nowPlaying !== undefined ? s.nowPlaying.caption : '';
  }

  private startDemo(): void {
    const tc: TourControl = AppContainer.tourControl();
    const tours: Tour[] = AppContainer.packRepository().tours();
    const tourId: string = tours.length > 0 ? tours[0].id : '';
    this.line = 'tour: planning...';
    tc.setSource(FixSource.DEMO).then(() => tc.plan(tourId, 0)).then((p: TourPlan) => {
      tc.setDemoSpeed(this.speed);
      return tc.start();
    }).catch((e: Object) => {
      this.line = `tour: start failed ${Log.errKv(e)}`;
    });
  }

  private cycleSpeed(): void {
    const i: number = DEMO_SPEED_CYCLE.indexOf(this.speed);
    this.speed = DEMO_SPEED_CYCLE[(i + 1) % DEMO_SPEED_CYCLE.length];
    AppContainer.tourControl().setDemoSpeed(this.speed);
  }

  build() {
    Column({ space: 8 }) {
      Text('Demo tour (A7)').fontSize(18).fontWeight(FontWeight.Medium)
      Text(this.line).id('tourStatus').fontSize(12)
      Text(this.caption).id('tourCaption').fontSize(15).fontStyle(FontStyle.Italic)
      Button('Start demo tour').id('btnDevDemoTour').width('100%').onClick(() => this.startDemo())
      Row({ space: 8 }) {
        Button(`Demo x${this.speed}`).id('btnDevDemoSpeed').layoutWeight(1).onClick(() => this.cycleSpeed())
        Button('Jump to next stop').id('btnDevDemoJump').layoutWeight(1)
          .onClick(() => AppContainer.tourControl().demoJumpToNext())
        Button('End tour').id('btnDevEndTour').layoutWeight(1).onClick(() => AppContainer.tourControl().end())
      }.width('100%')
    }
    .width('100%')
  }
}

@Entry
@ComponentV2
struct DevPanel {
  /** Window avoid areas (edge-to-edge window, issue #63). */
  @Local sa: SafeArea = SafeArea.get();
  @Local status: string = 'speech: initialising...';
  @Local capsLine: string = 'voices: ?';
  @Local planLine: string = 'EN plan: ?';
  @Local chip: string = '';
  @Local caption: string = '';
  @Local strategy: string = '';
  @Local ctx: string = '';
  @Local dlLine: string = '';
  @Local bgLine: string = 'bg: stopped';
  @Local avsLine: string = 'avs: inactive';
  @Local avsCmdLine: string = '';
  @Local metaIdx: number = 0;
  @Local loopOn: boolean = false;
  private runner: SampleRunner = new SampleRunner();
  private loopTimer: number = -1;

  aboutToAppear(): void {
    this.runner.onLine = (l: string) => {
      this.status = l;
    };
    this.runner.onCaption = (t: string) => {
      this.caption = t;
    };
    this.runner.onFinished = () => {
      // Between stories the tour is still "playing" while the loop runs; otherwise the card shows paused.
      AppContainer.mediaSession().setState(this.loopOn ? MediaPlayState.PLAY : MediaPlayState.PAUSE);
    };
    AppContainer.background().setListener(new DevBgListener(() => {
      this.stopLoop();
      this.refreshPlatformLines();
    }, () => this.refreshPlatformLines()));
    this.refreshPlatformLines();
    try {
      AppContainer.speech().setListener(this.runner);
      this.refreshVoiceLines();
      AppContainer.speech().init().then((c: SpeechCapabilities) => {
        this.capsLine = `voices: en=${c.en} zh=${c.zh}`;
        this.status = 'speech ready';
        this.refreshVoiceLines();
      }).catch((e: Object) => {
        this.status = `speech init failed ${Log.errKv(e)}`;
      });
    } catch (e) {
      this.status = `speech init threw ${Log.errKv(e as Object)}`;
    }
  }

  aboutToDisappear(): void {
    this.stopLoop();
  }

  // ---------- A6: continuous task + AVSession ----------

  private refreshPlatformLines(): void {
    const bg = AppContainer.backgroundRunner();
    const issue = bg.lastIssueLine();
    this.bgLine = `bg: ${bg.isRunning() ? 'running [location,audioPlayback]' : 'stopped'}` +
      (issue !== '' ? ` | last: ${issue}` : '');
    const avs = AppContainer.mediaSessionService();
    this.avsLine = `avs: ${avs.isActive() ? 'active' : 'inactive'} | title: ${AVS_TITLES[this.metaIdx]}`;
    const cmd = avs.lastCommandLine();
    this.avsCmdLine = cmd !== '' ? `last card command: ${cmd}` : 'last card command: -';
  }

  private startBg(): void {
    this.bgLine = 'bg: starting...';
    AppContainer.background().start().then((ok: boolean) => {
      this.refreshPlatformLines();
      if (!ok) {
        this.bgLine = `${this.bgLine} (start failed, see BG_FAIL; the tour would continue in the foreground)`;
      }
    }).catch((e: Object) => {
      this.bgLine = `bg: start error ${Log.errKv(e)}`;
    });
  }

  private stopBg(): void {
    this.stopLoop();
    this.runner.stop();
    AppContainer.background().stop().then(() => {
      this.refreshPlatformLines();
    }).catch((e: Object) => {
      this.bgLine = `bg: stop error ${Log.errKv(e)}`;
    });
  }

  private currentMeta(): MediaMeta {
    const label = AppContainer.voiceManager().plan(Lang.EN).label;
    const m: MediaMeta = { title: AVS_TITLES[this.metaIdx], artist: '', voiceLabel: label, demo: true };
    return m;
  }

  private startAvs(): void {
    this.avsLine = 'avs: starting...';
    const avs = AppContainer.mediaSession();
    avs.setMeta(this.currentMeta());
    avs.setState(AppContainer.speech().isSpeaking() || this.loopOn ? MediaPlayState.PLAY : MediaPlayState.PAUSE);
    avs.init((cmd: MediaCommand) => this.onCardCommand(cmd)).then((ok: boolean) => {
      this.refreshPlatformLines();
      if (!ok) {
        this.avsLine = 'avs: failed (see AVS_FAIL); in-app controls only';
      }
    }).catch((e: Object) => {
      this.avsLine = `avs: error ${Log.errKv(e)}`;
    });
  }

  private destroyAvs(): void {
    AppContainer.mediaSession().destroy().then(() => {
      this.refreshPlatformLines();
    }).catch((e: Object) => {
      this.avsLine = `avs: destroy error ${Log.errKv(e)}`;
    });
  }

  private toggleMeta(): void {
    this.metaIdx = (this.metaIdx + 1) % AVS_TITLES.length;
    AppContainer.mediaSession().setMeta(this.currentMeta());
    this.refreshPlatformLines();
  }

  /** What TourController (A7) will do with USER_* events, done here on the speech stack. */
  private onCardCommand(cmd: MediaCommand): void {
    const sp = AppContainer.speech();
    const avs = AppContainer.mediaSession();
    if (cmd === MediaCommand.PLAY) {
      sp.resume();
      avs.setState(MediaPlayState.PLAY);
      this.status = 'card: resume';
    } else if (cmd === MediaCommand.PAUSE || cmd === MediaCommand.STOP) {
      sp.pause();
      avs.setState(MediaPlayState.PAUSE);
      this.status = `card: ${cmd} -> paused`;
    } else if (cmd === MediaCommand.NEXT) {
      this.runner.skip();
      avs.setState(MediaPlayState.PLAY);
    } else if (cmd === MediaCommand.PREVIOUS) {
      if (this.runner.replay()) {
        avs.setState(MediaPlayState.PLAY);
        this.status = 'card: replay';
      }
    } else if (cmd === MediaCommand.FAVORITE) {
      this.play('more', EN_MORE, Lang.EN);
      this.status = 'card: tell me more';
    }
    this.refreshPlatformLines();
  }

  private toggleLoop(): void {
    if (this.loopOn) {
      this.stopLoop();
      AppContainer.mediaSession().setState(MediaPlayState.PAUSE);
      return;
    }
    this.loopOn = true;
    this.loopTick();
    this.loopTimer = setInterval(() => this.loopTick(), NARRATION_LOOP_MS);
    Log.i(LogEvents.STORY_QUEUE, `event=dev_loop on=1 everyMs=${NARRATION_LOOP_MS}`);
  }

  private stopLoop(): void {
    if (this.loopTimer !== -1) {
      clearInterval(this.loopTimer);
      this.loopTimer = -1;
      Log.i(LogEvents.STORY_QUEUE, 'event=dev_loop on=0');
    }
    this.loopOn = false;
  }

  private loopTick(): void {
    try {
      const sp = AppContainer.speech();
      if (this.runner.isActive() || sp.isSpeaking()) {
        return; // the previous sample is still running (or paused from the card)
      }
      this.play('en', EN_SAMPLE, Lang.EN);
      AppContainer.mediaSession().setState(MediaPlayState.PLAY);
      this.refreshPlatformLines();
    } catch (e) {
      Log.e(LogEvents.UNCAUGHT, `where=DevPanel.loopTick ${Log.errKv(e as Object)}`);
    }
  }

  private refreshVoiceLines(): void {
    const vm = AppContainer.voiceManager();
    this.strategy = vm.strategy();
    this.ctx = vm.fallbackEnContext();
    const p: VoicePlan = vm.plan(Lang.EN);
    this.chip = labelText(p.label);
    this.planLine = `EN plan: ${p.speechMode} ${p.engineLocale !== '' ? p.engineLocale : '-'}/${p.person}` +
      ` ctx=${p.languageContext !== '' ? p.languageContext : '-'} (${p.reason})`;
  }

  private play(name: string, texts: string[], lang: Lang): void {
    try {
      this.refreshVoiceLines();
      this.caption = '';
      this.runner.start(name, texts, lang);
    } catch (e) {
      this.status = `sample failed ${Log.errKv(e as Object)}`;
    }
  }

  private cycleStrategy(): void {
    const vm = AppContainer.voiceManager();
    const i = STRATEGY_CYCLE.indexOf(vm.strategy());
    vm.setStrategy(STRATEGY_CYCLE[(i + 1) % STRATEGY_CYCLE.length]);
    this.refreshVoiceLines();
  }

  private toggleCtx(): void {
    const vm = AppContainer.voiceManager();
    vm.setFallbackEnContext(vm.fallbackEnContext() === 'en-US' ? 'zh-CN' : 'en-US');
    this.refreshVoiceLines();
  }

  private download(): void {
    this.dlLine = 'download: waiting for the system dialog...';
    AppContainer.voice().downloadEnglish((pct: number) => {
      this.dlLine = `download: ${pct}%`;
    }).then((ok: boolean) => {
      const code = AppContainer.voiceManager().lastDownloadCode();
      this.dlLine = ok ? 'download: English voice installed' :
        `download failed (code ${code}), English stays on the fallback`;
      const c = AppContainer.voiceManager().lastCaps();
      this.capsLine = `voices: en=${c.en} zh=${c.zh}`;
      this.refreshVoiceLines();
    }).catch((e: Object) => {
      this.dlLine = `download error ${Log.errKv(e)}`;
    });
  }

  private stopAll(): void {
    this.runner.stop();
    AppContainer.speech().stopNow();
    this.status = 'stopped';
    this.caption = '';
  }

  build() {
    Scroll() {
      Column({ space: 8 }) {
        Text('CityTour DevPanel')
          .id('devPanelTitle')
          .fontSize(24)
          .fontWeight(FontWeight.Bold)
          .margin({ top: 48 })
        DemoTourSection()
        LocationDevSection()
        Text('Speech (A4)').fontSize(18).fontWeight(FontWeight.Medium)
        Text(this.chip)
          .id('voiceChip')
          .fontSize(13)
          .padding({ left: 10, right: 10, top: 4, bottom: 4 })
          .borderRadius(12)
          .backgroundColor('#33808080')
        Text(this.capsLine).id('voiceCaps').fontSize(12)
        Text(this.planLine).id('voicePlan').fontSize(12)
        Text(`strategy: ${this.strategy} | fallback ctx: ${this.ctx}`).id('voiceStrategy').fontSize(12)
        Text(this.status).id('speechStatus').fontSize(12)
        Text(this.dlLine).id('dlStatus').fontSize(12)
        Text(this.caption).id('speechCaption').fontSize(15).fontStyle(FontStyle.Italic)
        Button('EN sample (3 sentences)').id('btnEnSample').width('100%')
          .onClick(() => this.play('en', EN_SAMPLE, Lang.EN))
        Button('ZH sample').id('btnZhSample').width('100%')
          .onClick(() => this.play('zh', ZH_SAMPLE, Lang.ZH))
        Button('Text-only sample (PL)').id('btnTextSample').width('100%')
          .onClick(() => this.play('pl', PL_SAMPLE, Lang.PL))
        Button(`Strategy: ${this.strategy} (cycle)`).id('btnStrategy').width('100%')
          .onClick(() => this.cycleStrategy())
        Button(`Fallback ctx: ${this.ctx} (toggle)`).id('btnCtx').width('100%')
          .onClick(() => this.toggleCtx())
        Button('Download English voice').id('btnDlEn').width('100%')
          .onClick(() => this.download())
        Row({ space: 8 }) {
          Button('Pause').id('btnPause').layoutWeight(1).onClick(() => AppContainer.speech().pause())
          Button('Resume').id('btnResume').layoutWeight(1).onClick(() => AppContainer.speech().resume())
          Button('Stop').id('btnStop').layoutWeight(1).onClick(() => this.stopAll())
        }.width('100%')
        Text('Background + lock screen (A6)').fontSize(18).fontWeight(FontWeight.Medium).margin({ top: 12 })
        Text(this.bgLine).id('bgStatus').fontSize(12)
        Text(this.avsLine).id('avsStatus').fontSize(12)
        Text(this.avsCmdLine).id('avsCmd').fontSize(12)
        Row({ space: 8 }) {
          Button('Start continuous task').id('btnBgStart').layoutWeight(1).onClick(() => this.startBg())
          Button('Stop continuous task').id('btnBgStop').layoutWeight(1).onClick(() => this.stopBg())
        }.width('100%')
        Row({ space: 8 }) {
          Button('Start AVSession').id('btnAvsStart').layoutWeight(1).onClick(() => this.startAvs())
          Button('Destroy AVSession').id('btnAvsStop').layoutWeight(1).onClick(() => this.destroyAvs())
        }.width('100%')
        Button(`Meta: ${AVS_TITLES[this.metaIdx]} (toggle)`).id('btnAvsMeta').width('100%')
          .onClick(() => this.toggleMeta())
        Button(this.loopOn ? 'Narration loop: ON (tap to stop)' : 'Narration loop: OFF (EN sample every 45 s)')
          .id('btnNarrLoop').width('100%')
          .onClick(() => this.toggleLoop())
        Text('Card text is dev test data (SIMULATED), artist line shows DEMO.').fontSize(11).fontColor('#888888')
      }
      .width('100%')
      .padding({ left: 16, right: 16, bottom: 32 + this.sa.bottom })
    }
    .width('100%')
    .height('100%')
    .padding({ top: this.sa.top, left: this.sa.left, right: this.sa.right })
  }
}

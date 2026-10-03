/*
 * Developer-only page (A-owned). Opened with:
 *   hdc shell aa start -a EntryAbility -b com.hackyeah.citytour --ps page dev
 * Later tasks add buttons for location sources (A5) and background/AVSession (A6).
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
 * Developer page: literal strings on purpose (resource strings are B-owned and this page is not user-facing).
 */
import { Lang } from '../contracts/Model';
import { EnVoiceStrategy, VoiceLabel } from '../contracts/Settings';
import { SpeechCapabilities, SpeechListener, Utterance, VoicePlan } from '../contracts/Ports';
import { stripPauseMarkup } from '../core/speech/VoicePolicy';
import { AppContainer } from '../app/AppContainer';
import { Log } from '../app/Log';
import { LogEvents } from '../app/LogEvents';

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
  private items: Utterance[] = [];
  private idx: number = -1;
  private run: number = 0;

  start(name: string, texts: string[], lang: Lang): void {
    this.run++;
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

@Entry
@ComponentV2
struct DevPanel {
  @Local status: string = 'speech: initialising...';
  @Local capsLine: string = 'voices: ?';
  @Local planLine: string = 'EN plan: ?';
  @Local chip: string = '';
  @Local caption: string = '';
  @Local strategy: string = '';
  @Local ctx: string = '';
  @Local dlLine: string = '';
  private runner: SampleRunner = new SampleRunner();

  aboutToAppear(): void {
    this.runner.onLine = (l: string) => {
      this.status = l;
    };
    this.runner.onCaption = (t: string) => {
      this.caption = t;
    };
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
      }
      .width('100%')
      .padding({ left: 16, right: 16, bottom: 32 })
    }
    .width('100%')
    .height('100%')
  }
}

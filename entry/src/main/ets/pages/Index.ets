// THROWAWAY risk spike (exp/risk-spikes). Not product code.
import { textToSpeech } from '@kit.CoreSpeechKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { geoLocationManager } from '@kit.LocationKit';
import { abilityAccessCtrl, common, Permissions, wantAgent, WantAgent } from '@kit.AbilityKit';
import { backgroundTaskManager } from '@kit.BackgroundTasksKit';
import { avSession } from '@kit.AVSessionKit';
import { audio } from '@kit.AudioKit';

const D: number = 0xC170;
const T: string = 'SPIKE';

function log(msg: string): void {
  hilog.info(D, T, '%{public}s', msg);
}

function err(msg: string): void {
  hilog.error(D, T, '%{public}s', msg);
}

class PcmPlayer {
  private renderer: audio.AudioRenderer | null = null;
  private data: Uint8Array = new Uint8Array(0);
  private offset: number = 0;

  async play(buf: ArrayBuffer, sampleRate: number): Promise<void> {
    this.data = new Uint8Array(buf);
    this.offset = 0;
    if (this.renderer !== null) {
      await this.renderer.release();
      this.renderer = null;
    }
    const opts: audio.AudioRendererOptions = {
      streamInfo: {
        samplingRate: sampleRate as audio.AudioSamplingRate,
        channels: audio.AudioChannel.CHANNEL_1,
        sampleFormat: audio.AudioSampleFormat.SAMPLE_FORMAT_S16LE,
        encodingType: audio.AudioEncodingType.ENCODING_TYPE_RAW
      },
      rendererInfo: { usage: audio.StreamUsage.STREAM_USAGE_AUDIOBOOK, rendererFlags: 0 }
    };
    const r = await audio.createAudioRenderer(opts);
    this.renderer = r;
    r.on('writeData', (out: ArrayBuffer): audio.AudioDataCallbackResult => {
      const dst = new Uint8Array(out);
      const n = Math.min(dst.length, this.data.length - this.offset);
      if (n <= 0) {
        dst.fill(0);
        return audio.AudioDataCallbackResult.VALID;
      }
      dst.set(this.data.subarray(this.offset, this.offset + n));
      if (n < dst.length) {
        dst.fill(0, n);
      }
      this.offset += n;
      return audio.AudioDataCallbackResult.VALID;
    });
    r.on('stateChange', (s: audio.AudioState) => log(`PCM renderer state=${s}`));
    r.on('audioInterrupt', (e: audio.InterruptEvent) =>
      log(`PCM interrupt hint=${e.hintType} force=${e.forceType} type=${e.eventType}`));
    await r.start();
    log(`PCM renderer started, bytes=${this.data.length} rate=${sampleRate}`);
    const ms = Math.ceil(this.data.length / 2 / sampleRate * 1000) + 500;
    setTimeout(() => {
      r.stop().then(() => log('PCM renderer stopped (done)')).catch((e: BusinessError) => err(`PCM stop ${e.code}`));
    }, ms);
  }
}

@Entry
@Component
struct Index {
  @State status: string = 'spike ready';
  @State locStatus: string = '-';
  @State tick: number = 0;
  private engines: Map<string, textToSpeech.TextToSpeechEngine> = new Map();
  private reqSeq: number = 0;
  private pcmChunks: ArrayBuffer[] = [];
  private pcmRate: number = 16000;
  private player: PcmPlayer = new PcmPlayer();
  private locCount: number = 0;
  private session: avSession.AVSession | null = null;
  private timer: number = -1;
  private pcmTicker: boolean = false;

  private ctx(): common.UIAbilityContext {
    return this.getUIContext().getHostContext() as common.UIAbilityContext;
  }

  private rid(): string {
    this.reqSeq++;
    return `r${Date.now()}_${this.reqSeq}`;
  }

  private setStatus(s: string): void {
    this.status = s;
    log(`STATUS ${s}`);
  }

  private listener(lang: string): textToSpeech.SpeakListener {
    const l: textToSpeech.SpeakListener = {
      onStart: (id: string, r: textToSpeech.StartResponse) => log(`TTS[${lang}] onStart ${id} ${JSON.stringify(r)}`),
      onComplete: (id: string, r: textToSpeech.CompleteResponse) => {
        log(`TTS[${lang}] onComplete ${id} ${JSON.stringify(r)} pcmChunks=${this.pcmChunks.length}`);
        if (this.pcmChunks.length > 0) {
          this.playPcm();
        }
      },
      onStop: (id: string, r: textToSpeech.StopResponse) => log(`TTS[${lang}] onStop ${id} ${JSON.stringify(r)}`),
      onData: (id: string, a: ArrayBuffer, r: textToSpeech.SynthesisResponse) => {
        this.pcmChunks.push(a);
        if (this.pcmChunks.length <= 2) {
          log(`TTS[${lang}] onData ${id} bytes=${a.byteLength} ${JSON.stringify(r)}`);
        }
      },
      onError: (id: string, code: number, msg: string) => {
        err(`TTS[${lang}] onError ${id} code=${code} msg=${msg}`);
        this.setStatus(`TTS ${lang} error ${code} ${msg}`);
      }
    };
    return l;
  }

  private playPcm(): void {
    let total = 0;
    this.pcmChunks.forEach((b: ArrayBuffer) => total += b.byteLength);
    const allBuf = new ArrayBuffer(total);
    const all = new Uint8Array(allBuf);
    let off = 0;
    this.pcmChunks.forEach((b: ArrayBuffer) => {
      all.set(new Uint8Array(b), off);
      off += b.byteLength;
    });
    this.pcmChunks = [];
    log(`PCM total bytes=${total}`);
    this.player.play(allBuf, this.pcmRate).catch((e: BusinessError) => err(`PCM play fail ${e.code} ${e.message}`));
  }

  private createEngine(lang: string, person: number): void {
    const extra: Record<string, Object> = { 'style': 'interaction-broadcast', 'locate': 'CN', 'name': `spike_${lang}`, 'isBackStage': true };
    const p: textToSpeech.CreateEngineParams = { language: lang, person: person, online: 1, extraParams: extra };
    const t0 = Date.now();
    try {
      textToSpeech.createEngine(p, (e: BusinessError, eng: textToSpeech.TextToSpeechEngine) => {
        if (e) {
          err(`createEngine ${lang}/${person} FAIL code=${e.code} msg=${e.message}`);
          this.setStatus(`createEngine ${lang} FAIL ${e.code} ${e.message}`);
          return;
        }
        eng.setListener(this.listener(lang));
        this.engines.set(lang, eng);
        this.setStatus(`createEngine ${lang}/${person} OK in ${Date.now() - t0}ms`);
      });
    } catch (e) {
      const be = e as BusinessError;
      err(`createEngine threw ${lang} code=${be.code} msg=${be.message}`);
      this.setStatus(`createEngine threw ${be.code} ${be.message}`);
    }
  }

  private listVoices(): void {
    const q: textToSpeech.VoiceQuery = { requestId: this.rid(), online: 1 };
    try {
      textToSpeech.listVoices(q).then((v: textToSpeech.VoiceInfo[]) => {
        log(`listVoices OK ${JSON.stringify(v)}`);
        this.setStatus(`voices: ${v.map((x: textToSpeech.VoiceInfo) => `${x.language}/${x.person}/${x.status}`).join(', ')}`);
      }).catch((e: BusinessError) => {
        err(`listVoices FAIL ${e.code} ${e.message}`);
        this.setStatus(`listVoices FAIL ${e.code} ${e.message}`);
      });
    } catch (e) {
      const be = e as BusinessError;
      this.setStatus(`listVoices threw ${be.code} ${be.message}`);
    }
  }

  private downloadEn(): void {
    const d: textToSpeech.VoiceDownload = { requestId: this.rid(), language: 'en-US', person: 8, style: 'interaction-broadcast' };
    try {
      textToSpeech.downloadVoice(d, (e: BusinessError, resp: textToSpeech.DownloadResponse) => {
        if (e) {
          this.setStatus(`downloadVoice FAIL ${e.code} ${e.message}`);
          return;
        }
        resp.on('start', (i: string) => log(`dl start ${i}`));
        resp.on('progress', (i: string) => log(`dl progress ${i}`));
        resp.on('complete', (v: textToSpeech.VoiceInfo) => this.setStatus(`dl complete ${JSON.stringify(v)}`));
        resp.on('cancel', (i: string) => this.setStatus(`dl cancel ${i}`));
        resp.on('error', (x: BusinessError) => this.setStatus(`dl error ${x.code} ${x.message}`));
      });
    } catch (e) {
      const be = e as BusinessError;
      this.setStatus(`downloadVoice threw ${be.code} ${be.message}`);
    }
  }

  private speak(lang: string, text: string, pcm: boolean): void {
    const eng = this.engines.get(lang);
    if (!eng) {
      this.setStatus(`no engine ${lang}`);
      return;
    }
    this.pcmChunks = [];
    const extra: Record<string, Object> = { 'queueMode': 0, 'speed': 1, 'volume': 2, 'pitch': 1,
      'languageContext': lang, 'audioType': 'pcm', 'playType': pcm ? 0 : 1 };
    const sp: textToSpeech.SpeakParams = { requestId: this.rid(), extraParams: extra };
    try {
      eng.speak(text, sp);
      log(`speak(${lang}, pcm=${pcm}) called: ${text}`);
    } catch (e) {
      const be = e as BusinessError;
      this.setStatus(`speak threw ${be.code} ${be.message}`);
    }
  }

  private async requestLoc(): Promise<void> {
    const perms: Permissions[] = ['ohos.permission.APPROXIMATELY_LOCATION', 'ohos.permission.LOCATION'];
    try {
      const atm = abilityAccessCtrl.createAtManager();
      const r = await atm.requestPermissionsFromUser(this.ctx(), perms);
      this.setStatus(`perm result ${JSON.stringify(r.authResults)} dialogShown=${JSON.stringify(r.dialogShownResults)}`);
    } catch (e) {
      const be = e as BusinessError;
      this.setStatus(`perm threw ${be.code} ${be.message}`);
    }
  }

  private async locSwitch(): Promise<void> {
    try {
      const atm = abilityAccessCtrl.createAtManager();
      const ok = await atm.requestGlobalSwitch(this.ctx(), abilityAccessCtrl.SwitchType.LOCATION);
      this.setStatus(`requestGlobalSwitch(LOCATION)=${ok} enabled=${geoLocationManager.isLocationEnabled()}`);
    } catch (e) {
      const be = e as BusinessError;
      this.setStatus(`requestGlobalSwitch threw ${be.code} ${be.message}`);
    }
  }

  private locOnce(): void {
    try {
      log(`isLocationEnabled=${geoLocationManager.isLocationEnabled()}`);
      const req: geoLocationManager.SingleLocationRequest = {
        locatingPriority: geoLocationManager.LocatingPriority.PRIORITY_LOCATING_SPEED, locatingTimeoutMs: 10000
      };
      const t0 = Date.now();
      geoLocationManager.getCurrentLocation(req).then((l: geoLocationManager.Location) => {
        this.locStatus = `once ${l.latitude.toFixed(5)},${l.longitude.toFixed(5)} acc=${l.accuracy} src=${l.sourceType}`;
        log(`getCurrentLocation OK in ${Date.now() - t0}ms ${JSON.stringify(l)}`);
      }).catch((e: BusinessError) => {
        this.locStatus = `once FAIL ${e.code} ${e.message}`;
        err(`getCurrentLocation FAIL ${e.code} ${e.message} after ${Date.now() - t0}ms`);
      });
    } catch (e) {
      const be = e as BusinessError;
      this.locStatus = `once threw ${be.code} ${be.message}`;
      err(this.locStatus);
    }
  }

  private locWatch(): void {
    const req: geoLocationManager.ContinuousLocationRequest = {
      interval: 1, locationScenario: geoLocationManager.UserActivityScenario.NAVIGATION
    };
    try {
      geoLocationManager.on('locationChange', req, (l: geoLocationManager.Location) => {
        this.locCount++;
        this.locStatus = `#${this.locCount} ${l.latitude.toFixed(5)},${l.longitude.toFixed(5)} dir=${l.direction} spd=${l.speed}`;
        log(`locationChange #${this.locCount} lat=${l.latitude} lon=${l.longitude} acc=${l.accuracy} dir=${l.direction} speed=${l.speed} src=${l.sourceType}`);
      });
      geoLocationManager.on('locationError', (code: geoLocationManager.LocationError) => {
        err(`locationError ${code}`);
        this.locStatus = `locationError ${code}`;
      });
      this.setStatus('locationChange subscribed');
    } catch (e) {
      const be = e as BusinessError;
      this.setStatus(`locWatch threw ${be.code} ${be.message}`);
    }
  }

  private async startBg2(): Promise<void> {
    try {
      const info: wantAgent.WantAgentInfo = {
        wants: [{ bundleName: 'com.hackyeah.citytour', abilityName: 'EntryAbility' }],
        actionType: wantAgent.OperationType.START_ABILITY,
        requestCode: 0,
        actionFlags: [wantAgent.WantAgentFlags.UPDATE_PRESENT_FLAG]
      };
      const wa: WantAgent = await wantAgent.getWantAgent(info);
      const r = await backgroundTaskManager.startBackgroundRunning(this.ctx(), ['location', 'audioPlayback'], wa);
      this.setStatus(`startBackgroundRunning([location,audioPlayback]) OK ${JSON.stringify(r)}`);
      backgroundTaskManager.on('continuousTaskCancel', (i: backgroundTaskManager.ContinuousTaskCancelInfo) =>
        err(`continuousTaskCancel ${JSON.stringify(i)}`));
    } catch (e) {
      const be = e as BusinessError;
      this.setStatus(`startBackgroundRunning2 FAIL ${be.code} ${be.message}`);
    }
  }

  private async startBg(): Promise<void> {
    try {
      const info: wantAgent.WantAgentInfo = {
        wants: [{ bundleName: 'com.hackyeah.citytour', abilityName: 'EntryAbility' }],
        actionType: wantAgent.OperationType.START_ABILITY,
        requestCode: 0,
        actionFlags: [wantAgent.WantAgentFlags.UPDATE_PRESENT_FLAG]
      };
      const wa: WantAgent = await wantAgent.getWantAgent(info);
      await backgroundTaskManager.startBackgroundRunning(this.ctx(), backgroundTaskManager.BackgroundMode.LOCATION, wa);
      this.setStatus('startBackgroundRunning(LOCATION) OK');
      backgroundTaskManager.on('continuousTaskCancel', (i: backgroundTaskManager.ContinuousTaskCancelInfo) =>
        err(`continuousTaskCancel ${JSON.stringify(i)}`));
    } catch (e) {
      const be = e as BusinessError;
      this.setStatus(`startBackgroundRunning FAIL ${be.code} ${be.message}`);
    }
  }

  private async startAvs(): Promise<void> {
    try {
      const s = await avSession.createAVSession(this.ctx(), 'CityTourSpike', 'audio');
      this.session = s;
      await s.setAVMetadata({ assetId: 'stop-1', title: 'Main Market Square', artist: 'CityTour spike', duration: 60000 });
      await s.setAVPlaybackState({ state: avSession.PlaybackState.PLAYBACK_STATE_PLAY, position: { elapsedTime: 0, updateTime: Date.now() } });
      s.on('play', () => log('AVSession cmd play'));
      s.on('pause', () => log('AVSession cmd pause'));
      s.on('playNext', () => log('AVSession cmd next'));
      s.on('playPrevious', () => log('AVSession cmd prev'));
      await s.activate();
      this.setStatus(`AVSession active id=${s.sessionId}`);
    } catch (e) {
      const be = e as BusinessError;
      this.setStatus(`AVSession FAIL ${be.code} ${be.message}`);
    }
  }

  private startTicker(): void {
    if (this.timer >= 0) {
      return;
    }
    this.timer = setInterval(() => {
      this.tick++;
      log(`TICK ${this.tick} locCount=${this.locCount} engines=${this.engines.size}`);
      if (this.tick % 2 === 0 && this.engines.has('zh-CN')) {
        this.speak('zh-CN', `第${this.tick}次`, this.pcmTicker);
      }
    }, 10000);
    this.setStatus('ticker started (10s, speaks zh every 20s)');
  }

  build() {
    Scroll() {
      Column({ space: 6 }) {
        Button('ticker PCM').id('btnTickPcmTop').onClick(() => { this.pcmTicker = true; this.startTicker(); })
        Button('bg LOC+AUDIO').id('btnBg2Top').onClick(() => { this.startBg2(); })
        Button('bg LOCATION').id('btnBgTop').onClick(() => { this.startBg(); })
        Text('RISK SPIKE (throwaway)').fontSize(18).fontWeight(FontWeight.Bold)
        Text(this.status).id('status').fontSize(12)
        Text(this.locStatus).id('locStatus').fontSize(12)
        Text(`tick ${this.tick}`).fontSize(12)
        Button('TTS zh engine').id('btnZh').onClick(() => this.createEngine('zh-CN', 13))
        Button('TTS en engine').id('btnEn').onClick(() => this.createEngine('en-US', 8))
        Button('listVoices').id('btnVoices').onClick(() => this.listVoices())
        Button('download en voice').id('btnDl').onClick(() => this.downloadEn())
        Button('speak zh default').id('btnSpeakZh').onClick(() => this.speak('zh-CN', '欢迎来到克拉科夫中央广场。请看你的左边。', false))
        Button('speak en default').id('btnSpeakEn').onClick(() => this.speak('en-US', 'Welcome to the Main Market Square in Krakow. Look to your left.', false))
        Button('speak zh PCM').id('btnPcmZh').onClick(() => this.speak('zh-CN', '欢迎来到克拉科夫中央广场。', true))
        Button('zh engine speaks English').id('btnZhEn').onClick(() => this.speak('zh-CN', 'Welcome to the Main Market Square in Krakow. Look to your left, at Saint Mary\'s Basilica, built in the fourteenth century.', false))
        Button('speak en PCM').id('btnPcmEn').onClick(() => this.speak('en-US', 'Welcome to the Main Market Square in Krakow.', true))
        Button('loc permission').id('btnPerm').onClick(() => { this.requestLoc(); })
        Button('loc switch').id('btnSwitch').onClick(() => { this.locSwitch(); })
        Button('loc once').id('btnLocOnce').onClick(() => this.locOnce())
        Button('loc watch').id('btnLocWatch').onClick(() => this.locWatch())
        Button('bg task LOCATION').id('btnBg').onClick(() => { this.startBg(); })
        Button('AVSession').id('btnAvs').onClick(() => { this.startAvs(); })
        Button('ticker').id('btnTick').onClick(() => this.startTicker())
        Button('ticker PCM').id('btnTickPcm').onClick(() => { this.pcmTicker = true; this.startTicker(); })
        Button('bg LOC+AUDIO').id('btnBg2').onClick(() => { this.startBg2(); })
      }.width('100%').padding(12)
    }.height('100%').width('100%')
  }
}

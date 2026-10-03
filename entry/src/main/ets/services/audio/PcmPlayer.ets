/*
 * Our own PCM output for TTS playType 0 (docs/ARCHITECTURE.md §2.5, RISKS a7, task A4).
 *
 * One AudioRenderer, 16 kHz mono S16LE, STREAM_USAGE_AUDIOBOOK (media volume keys, normal audio focus; not the
 * Xiaoyi voice-assistant channel, FAQ faqs-core-speech-10). TTS chunks are appended to a "segment" (one sentence)
 * in `sequence` order; only the armed segment plays; others wait (prefetch). writeData copies the armed
 * segment's bytes and zero-fills the rest.
 *
 * Playback end is ours (no end-of-stream API, FAQ faqs-audio-56): when the armed segment's bytes are all handed to
 * writeData AND its synthesis is complete, onSegmentDone fires after the renderer buffer drains
 * (getBufferSizeSync() / 32 B per ms) plus a small margin.
 * Listener calls are posted with setTimeout(0): the docs forbid calling AudioRenderer APIs inside writeData.
 * The renderer stops after IDLE_STOP_MS without an armed segment (releases audio focus between stories) and
 * starts again on the next play().
 *
 * audioInterrupt and outputDeviceChangeWithInfo are forwarded to the listener; NarrationPlayer decides.
 * Docs: API参考/Audio_Kit_音频服务/ArkTS_API/ohos_multimedia_audio_音频管理_/Interface_AudioRenderer/
 *   arkts-apis-audio-audiorenderer (on('writeData') 11+, AudioDataCallbackResult return 12+, getBufferSizeSync 10+,
 *   on('audioInterrupt') 9+, on('outputDeviceChangeWithInfo') 11+, flush 11+), FAQ faqs-audio-56 (end detection),
 *   开发指南/Audio_Kit_音频服务/音频播放/使用AudioRenderer开发音频播放功能_ArkTS/using-audiorenderer-for-playback.
 *   All at or below API 20, no guard needed.
 */
import { audio } from '@kit.AudioKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { Log } from '../../app/Log';
import { LogEvents } from '../../app/LogEvents';

export const PCM_SAMPLE_RATE: number = 16000;
export const IDLE_STOP_MS: number = 3000;
export const DRAIN_MARGIN_MS: number = 120;
const CREATE_TIMEOUT_MS: number = 4000;

export interface PcmPlayerListener {
  onSegmentStart: (id: string) => void;
  onSegmentDone: (id: string, bytes: number) => void;
  onInterrupt: (hint: number, forceType: number) => void;      // audio.InterruptHint, audio.InterruptForceType
  onRouteChange: (reason: number, devices: string) => void;    // audio.AudioStreamDeviceChangeReason
  onRendererError: (id: string, code: number, where: string) => void;
}

class Segment {
  id: string;
  pending: Map<number, ArrayBuffer> = new Map<number, ArrayBuffer>();
  nextSeq: number = 0;
  ready: Uint8Array[] = [];
  allChunks: Uint8Array[] = [];   // kept so resume() can replay the sentence from its start
  chunkIdx: number = 0;
  chunkOff: number = 0;
  totalBytes: number = 0;
  consumedBytes: number = 0;
  synthDone: boolean = false;
  armed: boolean = false;
  started: boolean = false;
  draining: boolean = false;

  constructor(id: string) {
    this.id = id;
  }

  /** Moves chunks whose sequence is next into `ready`; when synthesis is done, flushes gaps in order. */
  promote(): void {
    while (this.pending.has(this.nextSeq)) {
      const b = this.pending.get(this.nextSeq) as ArrayBuffer;
      this.pending.delete(this.nextSeq);
      const u = new Uint8Array(b);
      this.ready.push(u);
      this.allChunks.push(u);
      this.nextSeq++;
    }
    if (this.synthDone && this.pending.size > 0) {
      const keys: number[] = Array.from(this.pending.keys()).sort((a: number, b: number) => a - b);
      Log.w(LogEvents.TTS_ERR, `where=pcm_seq_gap id=${this.id} expected=${this.nextSeq} have=${keys.join('|')}`);
      for (const k of keys) {
        const u = new Uint8Array(this.pending.get(k) as ArrayBuffer);
        this.ready.push(u);
        this.allChunks.push(u);
      }
      this.pending.clear();
      this.nextSeq = keys[keys.length - 1] + 1;
    }
  }

  fullyConsumed(): boolean {
    return this.synthDone && this.pending.size === 0 && this.chunkIdx >= this.ready.length;
  }

  rewind(): void {
    this.ready = this.allChunks.slice(0);
    this.chunkIdx = 0;
    this.chunkOff = 0;
    this.consumedBytes = 0;
    this.draining = false;
  }
}

export class PcmPlayer {
  private renderer: audio.AudioRenderer | undefined = undefined;
  private creating: Promise<audio.AudioRenderer> | undefined = undefined;
  private segments: Map<string, Segment> = new Map<string, Segment>();
  private current: Segment | undefined = undefined;
  private listener: PcmPlayerListener | undefined = undefined;
  private running: boolean = false;
  private paused: boolean = false;
  private bufferMs: number = 0;
  private idleTimer: number = -1;
  private drainTimer: number = -1;
  private channels: number = 1;

  setListener(l: PcmPlayerListener): void {
    this.listener = l;
  }

  /** Creates the renderer early so the first sentence does not pay for it. Never throws. */
  warmUp(): Promise<boolean> {
    return this.ensureRenderer().then(() => true).catch(() => false);
  }

  /** ARCHITECTURE §2.5: assert mono; recreate with CHANNEL_2 if TTS ever reports stereo. */
  setChannels(n: number): void {
    const want = n === 2 ? 2 : 1;
    if (want === this.channels) {
      return;
    }
    Log.w(LogEvents.AUDIO_ROUTE, `event=channels_changed from=${this.channels} to=${want}`);
    this.channels = want;
    this.releaseRenderer();
  }

  open(id: string): void {
    if (!this.segments.has(id)) {
      this.segments.set(id, new Segment(id));
    }
  }

  append(id: string, buf: ArrayBuffer, sequence: number): void {
    const s = this.segments.get(id);
    if (s === undefined || buf === undefined || buf.byteLength === 0) {
      return;
    }
    s.pending.set(sequence, buf);
    s.totalBytes += buf.byteLength;
    s.promote();
  }

  /** Synthesis for this segment is complete. */
  finish(id: string): void {
    const s = this.segments.get(id);
    if (s === undefined) {
      return;
    }
    s.synthDone = true;
    s.promote();
  }

  bytesOf(id: string): number {
    const s = this.segments.get(id);
    return s !== undefined ? s.totalBytes : 0;
  }

  /** Arms the segment and makes sure the renderer runs. Any previously armed segment is dropped. */
  play(id: string): void {
    const s = this.segments.get(id);
    if (s === undefined) {
      return;
    }
    if (this.current !== undefined && this.current.id !== id) {
      this.drop(this.current.id);
    }
    this.cancelIdle();
    s.armed = true;
    this.current = s;
    this.paused = false;
    this.startRenderer(id);
  }

  /** Removes a segment (preempted, stopped or prefetch dropped). */
  drop(id: string): void {
    const s = this.segments.get(id);
    this.segments.delete(id);
    if (s !== undefined && this.current === s) {
      this.current = undefined;
      this.clearDrain();
      this.scheduleIdle();
    }
  }

  clear(): void {
    this.segments.clear();
    this.current = undefined;
    this.clearDrain();
    this.scheduleIdle();
  }

  isPaused(): boolean {
    return this.paused;
  }

  pause(): void {
    this.paused = true;
    this.clearDrain();
    const r = this.renderer;
    if (r === undefined || !this.running) {
      return;
    }
    this.running = false;
    try {
      r.pause().catch((e: BusinessError) => Log.w(LogEvents.TTS_ERR, `where=renderer.pause ${Log.errKv(e)}`));
    } catch (e) {
      Log.w(LogEvents.TTS_ERR, `where=renderer.pause ${Log.errKv(e as Object)}`);
    }
  }

  /** rewind=true replays the current sentence from its start (ARCHITECTURE §2.5 interrupt RESUME). */
  resume(rewind: boolean): void {
    this.paused = false;
    if (this.current === undefined) {
      return;
    }
    if (rewind) {
      this.current.rewind();
    }
    this.startRenderer(this.current.id);
  }

  release(): void {
    this.clear();
    this.cancelIdle();
    this.releaseRenderer();
  }

  // ---------- renderer ----------

  private options(): audio.AudioRendererOptions {
    const o: audio.AudioRendererOptions = {
      streamInfo: {
        samplingRate: audio.AudioSamplingRate.SAMPLE_RATE_16000,
        channels: this.channels === 2 ? audio.AudioChannel.CHANNEL_2 : audio.AudioChannel.CHANNEL_1,
        sampleFormat: audio.AudioSampleFormat.SAMPLE_FORMAT_S16LE,
        encodingType: audio.AudioEncodingType.ENCODING_TYPE_RAW
      },
      rendererInfo: { usage: audio.StreamUsage.STREAM_USAGE_AUDIOBOOK, rendererFlags: 0 }
    };
    return o;
  }

  private ensureRenderer(): Promise<audio.AudioRenderer> {
    if (this.renderer !== undefined) {
      return Promise.resolve(this.renderer);
    }
    if (this.creating !== undefined) {
      return this.creating;
    }
    const t0 = Date.now();
    let p: Promise<audio.AudioRenderer>;
    try {
      p = audio.createAudioRenderer(this.options());
    } catch (e) {
      p = Promise.reject(e);
    }
    const timeout = new Promise<audio.AudioRenderer>((resolve, reject) => {
      setTimeout(() => {
        const err: BusinessError = { code: -2, message: 'createAudioRenderer timeout', name: 'Timeout' };
        reject(err);
      }, CREATE_TIMEOUT_MS);
    });
    this.creating = Promise.race([p, timeout]).then((r: audio.AudioRenderer) => {
      this.creating = undefined;
      this.renderer = r;
      this.attach(r);
      try {
        const bytes = r.getBufferSizeSync();
        this.bufferMs = Math.ceil(bytes / (PCM_SAMPLE_RATE * 2 * this.channels / 1000));
      } catch (e) {
        this.bufferMs = 40;
      }
      Log.i(LogEvents.AUDIO_ROUTE, `event=renderer_created rate=16000 ch=${this.channels} usage=AUDIOBOOK` +
        ` bufferMs=${this.bufferMs} ms=${Date.now() - t0}`);
      return r;
    }).catch((e: Object) => {
      this.creating = undefined;
      Log.e(LogEvents.TTS_ERR, `where=createAudioRenderer ${Log.errKv(e)}`);
      return Promise.reject(e);
    });
    return this.creating;
  }

  private attach(r: audio.AudioRenderer): void {
    try {
      r.on('writeData', (out: ArrayBuffer): audio.AudioDataCallbackResult => this.onWrite(out));
      r.on('audioInterrupt', (e: audio.InterruptEvent) => {
        Log.i(LogEvents.AUDIO_INTERRUPT, `hint=${e.hintType} force=${e.forceType} type=${e.eventType}`);
        if (e.forceType === audio.InterruptForceType.INTERRUPT_FORCE &&
          (e.hintType === audio.InterruptHint.INTERRUPT_HINT_PAUSE ||
            e.hintType === audio.InterruptHint.INTERRUPT_HINT_STOP)) {
          this.running = false; // the system already paused/stopped the stream
        }
        const hint = e.hintType as number;
        const force = e.forceType as number;
        setTimeout(() => this.listener?.onInterrupt(hint, force), 0);
      });
      r.on('outputDeviceChangeWithInfo', (info: audio.AudioStreamDeviceChangeInfo) => {
        let names = '';
        try {
          const parts: string[] = [];
          for (let i = 0; i < info.devices.length; i++) {
            parts.push(`${info.devices[i].deviceType}`);
          }
          names = parts.join('|');
        } catch (e) {
          names = '?';
        }
        const reason = info.changeReason as number;
        Log.i(LogEvents.AUDIO_ROUTE, `event=device_change reason=${reason} devices=${names}`);
        setTimeout(() => this.listener?.onRouteChange(reason, names), 0);
      });
      r.on('stateChange', (st: audio.AudioState) => Log.d(LogEvents.AUDIO_ROUTE, `event=state state=${st}`));
    } catch (e) {
      Log.e(LogEvents.TTS_ERR, `where=renderer.on ${Log.errKv(e as Object)}`);
    }
  }

  private startRenderer(id: string): void {
    if (this.paused) {
      return;
    }
    this.ensureRenderer().then((r: audio.AudioRenderer) => {
      if (this.running || this.paused || this.current === undefined) {
        return;
      }
      this.running = true;
      r.start().catch((e: BusinessError) => {
        this.running = false;
        Log.e(LogEvents.TTS_ERR, `where=renderer.start ${Log.errKv(e)}`);
        this.listener?.onRendererError(id, e.code, 'start');
      });
    }).catch((e: Object) => {
      const be = e as BusinessError;
      this.listener?.onRendererError(id, typeof be.code === 'number' ? be.code : -5, 'create');
    });
  }

  private stopRenderer(): void {
    const r = this.renderer;
    if (r === undefined || !this.running) {
      return;
    }
    this.running = false;
    r.stop().then(() => Log.d(LogEvents.AUDIO_ROUTE, 'event=renderer_idle_stop'))
      .catch((e: BusinessError) => Log.w(LogEvents.TTS_ERR, `where=renderer.stop ${Log.errKv(e)}`));
  }

  private releaseRenderer(): void {
    const r = this.renderer;
    this.renderer = undefined;
    this.running = false;
    if (r === undefined) {
      return;
    }
    try {
      r.off('writeData');
      r.off('audioInterrupt');
      r.off('outputDeviceChangeWithInfo');
      r.off('stateChange');
    } catch (e) {
      Log.w(LogEvents.TTS_ERR, `where=renderer.off ${Log.errKv(e as Object)}`);
    }
    r.release().catch((e: BusinessError) => Log.w(LogEvents.TTS_ERR, `where=renderer.release ${Log.errKv(e)}`));
  }

  // ---------- writeData (no AudioRenderer calls in here) ----------

  private onWrite(out: ArrayBuffer): audio.AudioDataCallbackResult {
    const dst = new Uint8Array(out);
    let written = 0;
    const s = this.current;
    try {
      if (s !== undefined && s.armed && !this.paused) {
        while (written < dst.length && s.chunkIdx < s.ready.length) {
          const chunk = s.ready[s.chunkIdx];
          const n = Math.min(dst.length - written, chunk.length - s.chunkOff);
          dst.set(chunk.subarray(s.chunkOff, s.chunkOff + n), written);
          written += n;
          s.chunkOff += n;
          s.consumedBytes += n;
          if (s.chunkOff >= chunk.length) {
            s.chunkIdx++;
            s.chunkOff = 0;
          }
        }
        if (written > 0 && !s.started) {
          s.started = true;
          const id = s.id;
          setTimeout(() => this.listener?.onSegmentStart(id), 0);
        }
        if (!s.draining && s.fullyConsumed()) {
          s.draining = true;
          const id = s.id;
          const bytes = s.totalBytes;
          if (!s.started) {
            s.started = true; // empty synthesis: still report start before done
            setTimeout(() => this.listener?.onSegmentStart(id), 0);
          }
          const delay = this.bufferMs + DRAIN_MARGIN_MS;
          this.drainTimer = setTimeout(() => {
            this.drainTimer = -1;
            this.onDrained(id, bytes);
          }, delay);
        }
      }
    } catch (e) {
      Log.e(LogEvents.TTS_ERR, `where=writeData ${Log.errKv(e as Object)}`);
    }
    if (written < dst.length) {
      dst.fill(0, written);
    }
    return audio.AudioDataCallbackResult.VALID;
  }

  private onDrained(id: string, bytes: number): void {
    const s = this.segments.get(id);
    if (s === undefined || this.current !== s || !s.draining || this.paused) {
      return; // dropped, replaced or paused meanwhile (resume re-drains)
    }
    this.segments.delete(id);
    this.current = undefined;
    this.scheduleIdle();
    this.listener?.onSegmentDone(id, bytes);
  }

  private clearDrain(): void {
    if (this.drainTimer >= 0) {
      clearTimeout(this.drainTimer);
      this.drainTimer = -1;
    }
    if (this.current !== undefined) {
      this.current.draining = false;
    }
  }

  private scheduleIdle(): void {
    this.cancelIdle();
    this.idleTimer = setTimeout(() => {
      this.idleTimer = -1;
      if (this.current === undefined) {
        this.stopRenderer();
      }
    }, IDLE_STOP_MS);
  }

  private cancelIdle(): void {
    if (this.idleTimer >= 0) {
      clearTimeout(this.idleTimer);
      this.idleTimer = -1;
    }
  }
}

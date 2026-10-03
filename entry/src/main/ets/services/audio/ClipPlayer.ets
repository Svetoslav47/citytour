/*
 * Plays pre-rendered sentence clips from rawfile with AVPlayer (task A13). One AVPlayer per clip "slot" (keyed by
 * NarrationPlayer's segment id), so the next sentence can be prepared while the current one plays, like the PCM
 * prefetch. A slot is released when its clip completes, fails or is dropped; nothing is kept between sentences.
 *
 * Flow per slot: createAVPlayer -> resourceManager.getRawFd(path) -> fdSrc -> 'initialized' (set
 * audioRendererInfo STREAM_USAGE_AUDIOBOOK, same usage as PcmPlayer) -> prepare() -> 'prepared'
 * -> play() once armed -> 'playing' (onClipStart) -> 'completed' (onClipDone).
 * Every failure (no context, missing rawfile, decoder error, prepare timeout) reports onClipError exactly once, so
 * NarrationPlayer can fall back to native TTS for that sentence. Nothing here throws.
 * pause() pauses; resume() restarts the sentence from 0 (a mid-word resume sounds broken; same rule as PcmPlayer).
 * audioInterrupt is forwarded like PcmPlayer's, so NarrationPlayer decides pause/resume in one place.
 * getRawFd fds are reference-counted per path and closed with closeRawFd after the last player using the path is
 * released (the caller owns AVFileDescriptor fds).
 * Docs: API参考/Media_Kit_媒体服务/ArkTS_API/ohos_multimedia_media_媒体服务_/Interface_AVPlayer (fdSrc 9+,
 *   audioRendererInfo 12+ settable in 'initialized', on('stateChange'|'error'|'audioInterrupt') 9+), API参考/
 *   Localization_Kit/resourceManager getRawFd/closeRawFd 9+, 开发指南/Media_Kit/音频播放/使用AVPlayer播放音频.
 *   All at or below our minimum API 20, so no canIUse guard is needed.
 */
import { media } from '@kit.MediaKit';
import { audio } from '@kit.AudioKit';
import { common } from '@kit.AbilityKit';
import { resourceManager } from '@kit.LocalizationKit';
import { util } from '@kit.ArkTS';
import { BusinessError } from '@kit.BasicServicesKit';
import { Log } from '../../app/Log';
import { LogEvents } from '../../app/LogEvents';

export const CLIP_PREPARE_TIMEOUT_MS: number = 4000;

/** Our error codes (negative, never collide with Media Kit codes). */
export class ClipErr {
  static readonly NO_CONTEXT: number = -11;
  static readonly OPEN: number = -12;        // getRawFd failed (clip missing from the HAP)
  static readonly PREPARE_TIMEOUT: number = -13;
  static readonly PLAYER: number = -14;      // AVPlayer error without a code
}

export type ClipContextProvider = () => common.Context | undefined;

export interface ClipPlayerListener {
  onClipStart: (id: string) => void;
  onClipDone: (id: string) => void;
  onClipError: (id: string, code: number, where: string) => void;
  onInterrupt: (hint: number, forceType: number) => void;
}

class ClipSlot {
  id: string;
  path: string;
  player: media.AVPlayer | undefined = undefined;
  fdHeld: boolean = false;
  prepared: boolean = false;
  armed: boolean = false;
  paused: boolean = false;
  started: boolean = false;
  ended: boolean = false;      // completed, failed or dropped: no more callbacks
  durationMs: number = 0;
  timer: number = -1;
  t0: number = 0;

  constructor(id: string, path: string) {
    this.id = id;
    this.path = path;
  }
}

function codeOf(e: Object | undefined | null): number {
  if (e === undefined || e === null) {
    return ClipErr.PLAYER;
  }
  const c = (e as BusinessError).code;
  return typeof c === 'number' ? c : ClipErr.PLAYER;
}

export class ClipPlayer {
  private ctxOf: ClipContextProvider;
  private listener: ClipPlayerListener | undefined = undefined;
  private slots: Map<string, ClipSlot> = new Map<string, ClipSlot>();
  private fdRefs: Map<string, number> = new Map<string, number>();

  constructor(ctxOf: ClipContextProvider) {
    this.ctxOf = ctxOf;
  }

  setListener(l: ClipPlayerListener): void {
    this.listener = l;
  }

  /** rawfile text (UTF-8), or '' when the file is absent/unreadable. Never rejects. */
  readRawText(path: string): Promise<string> {
    const ctx = this.ctxOf();
    if (ctx === undefined) {
      return Promise.resolve('');
    }
    try {
      return ctx.resourceManager.getRawFileContent(path).then((bytes: Uint8Array) => {
        const decoder = util.TextDecoder.create('utf-8', { ignoreBOM: true });
        return decoder.decodeToString(bytes, { stream: false });
      }).catch((e: Object) => {
        Log.d(LogEvents.NARR_AUDIO, `event=raw_missing path=${path} ${Log.errKv(e)}`);
        return '';
      });
    } catch (e) {
      return Promise.resolve('');
    }
  }

  has(id: string): boolean {
    return this.slots.has(id);
  }

  /** Creates the player and prepares the clip without playing it (prefetch). Idempotent per id. */
  load(id: string, path: string): void {
    if (this.slots.has(id)) {
      return;
    }
    const slot = new ClipSlot(id, path);
    slot.t0 = Date.now();
    this.slots.set(id, slot);
    this.armTimer(slot);
    const ctx = this.ctxOf();
    if (ctx === undefined) {
      this.fail(slot, ClipErr.NO_CONTEXT, 'no_context');
      return;
    }
    let created: Promise<media.AVPlayer>;
    try {
      created = media.createAVPlayer();
    } catch (e) {
      created = Promise.reject(e);
    }
    created.then((p: media.AVPlayer) => {
      if (slot.ended) {
        p.release().catch((e: BusinessError) => Log.w(LogEvents.NARR_AUDIO, `where=release_late ${Log.errKv(e)}`));
        return;
      }
      slot.player = p;
      p.on('stateChange', (state: media.AVPlayerState, reason: media.StateChangeReason) => {
        this.onState(slot, state);
      });
      p.on('error', (err: BusinessError) => {
        this.fail(slot, codeOf(err), `avplayer:${err.message}`);
      });
      p.on('audioInterrupt', (ev: audio.InterruptEvent) => {
        if (!slot.ended && slot.armed) {
          Log.i(LogEvents.AUDIO_INTERRUPT, `src=clip hint=${ev.hintType} force=${ev.forceType} id=${slot.id}`);
          this.listener?.onInterrupt(ev.hintType, ev.forceType);
        }
      });
      this.openFd(ctx, slot, p);
    }).catch((e: Object) => {
      this.fail(slot, codeOf(e), 'create');
    });
  }

  /** Plays the clip (loading it first if needed); starts as soon as it is prepared. */
  play(id: string, path: string): void {
    if (!this.slots.has(id)) {
      this.load(id, path);
    }
    const slot = this.slots.get(id);
    if (slot === undefined || slot.ended) {
      return;
    }
    slot.armed = true;
    slot.paused = false;
    if (slot.prepared) {
      this.start(slot);
    }
  }

  pause(id: string): void {
    const slot = this.slots.get(id);
    if (slot === undefined || slot.ended) {
      return;
    }
    slot.paused = true;
    if (slot.player !== undefined && slot.started) {
      slot.player.pause().catch((e: BusinessError) => Log.w(LogEvents.NARR_AUDIO, `where=pause ${Log.errKv(e)}`));
    }
  }

  /** Restarts the sentence from its beginning. */
  resume(id: string): void {
    const slot = this.slots.get(id);
    if (slot === undefined || slot.ended) {
      return;
    }
    slot.paused = false;
    if (!slot.armed || !slot.prepared || slot.player === undefined) {
      return;  // it starts on 'prepared'
    }
    try {
      if (slot.started) {
        slot.player.seek(0);
      }
    } catch (e) {
      Log.w(LogEvents.NARR_AUDIO, `where=seek ${Log.errKv(e as Object)}`);
    }
    this.start(slot);
  }

  durationMs(id: string): number {
    const slot = this.slots.get(id);
    return slot !== undefined ? slot.durationMs : 0;
  }

  /** Stops and releases one clip; no callback follows. */
  drop(id: string): void {
    const slot = this.slots.get(id);
    if (slot !== undefined) {
      this.release(slot);
    }
  }

  clear(): void {
    const all: ClipSlot[] = Array.from(this.slots.values());
    for (const s of all) {
      this.release(s);
    }
  }

  // ---------- internals ----------

  private openFd(ctx: common.Context, slot: ClipSlot, p: media.AVPlayer): void {
    let fdP: Promise<resourceManager.RawFileDescriptor>;
    try {
      fdP = ctx.resourceManager.getRawFd(slot.path);
    } catch (e) {
      fdP = Promise.reject(e);
    }
    fdP.then((fd: resourceManager.RawFileDescriptor) => {
      slot.fdHeld = true;
      this.fdRefs.set(slot.path, (this.fdRefs.get(slot.path) ?? 0) + 1);
      if (slot.ended) {
        this.releaseFd(slot);
        return;
      }
      const src: media.AVFileDescriptor = { fd: fd.fd, offset: fd.offset, length: fd.length };
      p.fdSrc = src;   // -> 'initialized'
    }).catch((e: Object) => {
      this.fail(slot, codeOf(e) === ClipErr.PLAYER ? ClipErr.OPEN : codeOf(e), 'open_rawfile');
    });
  }

  private onState(slot: ClipSlot, state: media.AVPlayerState): void {
    if (slot.ended || slot.player === undefined) {
      return;
    }
    const p: media.AVPlayer = slot.player;
    try {
      if (state === 'initialized') {
        const info: audio.AudioRendererInfo = { usage: audio.StreamUsage.STREAM_USAGE_AUDIOBOOK, rendererFlags: 0 };
        p.audioRendererInfo = info;
        p.prepare().catch((e: BusinessError) => this.fail(slot, codeOf(e), 'prepare'));
      } else if (state === 'prepared') {
        slot.prepared = true;
        slot.durationMs = p.duration > 0 ? p.duration : 0;
        Log.d(LogEvents.NARR_AUDIO, `event=clip_prepared id=${slot.id} durMs=${slot.durationMs}` +
          ` ms=${Date.now() - slot.t0}`);
        if (!slot.armed) {
          this.clearTimer(slot);   // prefetched: waits for play() without a deadline
        } else if (!slot.paused) {
          this.start(slot);
        }
      } else if (state === 'playing') {
        this.clearTimer(slot);
        if (!slot.started) {
          slot.started = true;
          this.listener?.onClipStart(slot.id);
        }
      } else if (state === 'completed') {
        slot.ended = true;
        const id = slot.id;
        this.release(slot);
        this.listener?.onClipDone(id);
      }
    } catch (e) {
      this.fail(slot, codeOf(e as Object), `state_${state}`);
    }
  }

  private start(slot: ClipSlot): void {
    if (slot.player === undefined || slot.ended) {
      return;
    }
    if (!slot.started) {
      this.armTimer(slot);   // play() must reach 'playing' in time, or we fall back
    }
    slot.player.play().catch((e: BusinessError) => this.fail(slot, codeOf(e), 'play'));
  }

  private armTimer(slot: ClipSlot): void {
    this.clearTimer(slot);
    slot.timer = setTimeout(() => {
      slot.timer = -1;
      // A paused, prepared slot waits for resume() (which re-arms this timer via start()).
      if (!slot.ended && !slot.started && !(slot.paused && slot.prepared) && (slot.armed || !slot.prepared)) {
        this.fail(slot, ClipErr.PREPARE_TIMEOUT, `timeout_${CLIP_PREPARE_TIMEOUT_MS}ms`);
      }
    }, CLIP_PREPARE_TIMEOUT_MS);
  }

  private clearTimer(slot: ClipSlot): void {
    if (slot.timer >= 0) {
      clearTimeout(slot.timer);
      slot.timer = -1;
    }
  }

  private fail(slot: ClipSlot, code: number, where: string): void {
    if (slot.ended) {
      return;
    }
    Log.w(LogEvents.NARR_AUDIO, `event=clip_error id=${slot.id} path=${slot.path} code=${code} where=${where}`);
    const id = slot.id;
    this.release(slot);
    try {
      this.listener?.onClipError(id, code, where);
    } catch (e) {
      Log.e(LogEvents.UNCAUGHT, `where=ClipPlayer.onClipError ${Log.errKv(e as Object)}`);
    }
  }

  private release(slot: ClipSlot): void {
    slot.ended = true;
    this.clearTimer(slot);
    if (this.slots.get(slot.id) === slot) {
      this.slots.delete(slot.id);
    }
    const p = slot.player;
    slot.player = undefined;
    if (p === undefined) {
      this.releaseFd(slot);
      return;
    }
    try {
      p.off('stateChange');
      p.off('error');
      p.off('audioInterrupt');
    } catch (e) {
      Log.w(LogEvents.NARR_AUDIO, `where=off ${Log.errKv(e as Object)}`);
    }
    p.release().catch((e: BusinessError) => {
      Log.w(LogEvents.NARR_AUDIO, `where=release ${Log.errKv(e)}`);
    }).finally(() => this.releaseFd(slot));
  }

  private releaseFd(slot: ClipSlot): void {
    if (!slot.fdHeld) {
      return;
    }
    slot.fdHeld = false;
    const n = (this.fdRefs.get(slot.path) ?? 1) - 1;
    if (n > 0) {
      this.fdRefs.set(slot.path, n);
      return;
    }
    this.fdRefs.delete(slot.path);
    const ctx = this.ctxOf();
    if (ctx === undefined) {
      return;
    }
    try {
      ctx.resourceManager.closeRawFd(slot.path).catch((e: BusinessError) => {
        Log.w(LogEvents.NARR_AUDIO, `where=closeRawFd ${Log.errKv(e)}`);
      });
    } catch (e) {
      Log.w(LogEvents.NARR_AUDIO, `where=closeRawFd ${Log.errKv(e as Object)}`);
    }
  }
}

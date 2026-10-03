/*
 * MediaSessionPort implementation (docs/ARCHITECTURE.md §2.6, task A6): an AVSession of type 'audio' gives the
 * guide a Control Center / lock-screen media card with play-pause, previous, next and favorite, and justifies
 * background speech together with the AUDIO_PLAYBACK continuous task (§2.4). Verified in RISKS §1 d1.
 *
 * Docs (devecocli docs read):
 * - 开发指南/AVSession_Kit_音视频播控服务/本地媒体会话/媒体会话提供方_ArkTS/using-avsession-developer:
 *   one session per UIAbility; keep the object alive while playing in the background; register only commands
 *   we really handle; set metadata + at least one command so the card shows (FAQ faqs-avsession-24);
 *   off() + destroy() at the end.
 * - API参考/AVSession_Kit_音视频播控服务/ArkTS_API/ohos_multimedia_avsession_媒体会话管理_/Interface_AVSession/
 *   arkts-apis-avsession-avsession: createAVSession/setAVMetadata/setAVPlaybackState/setLaunchAbility/activate/
 *   destroy and on('play'|'pause'|'stop'|'playNext'|'playPrevious'|'toggleFavorite') are all API 10 (< 20, no guard).
 * - API参考/…/Interfaces_其他/arkts-apis-avsession-i (AVMetadata: assetId required, empty -> 6600101;
 *   AVPlaybackState) and …/Enums/arkts-apis-avsession-e (PlaybackState PLAY=2, PAUSE=3, STOP=6).
 * - FAQ/音频和视频/音视频播控_AVSession/播控中心的播放状态错误/faqs-avsession-28: the card shows exactly the state
 *   we report, so setState() must mirror the engine.
 * Commands are registered BEFORE activate() (verified order, ARCHITECTURE §2.6). Every platform call is wrapped;
 * failures log AVS_FAIL and the tour continues with in-app controls only (§9 row 15).
 */
import { avSession } from '@kit.AVSessionKit';
import { common, wantAgent } from '@kit.AbilityKit';
import { EngineEventType, MediaMeta, MediaPlayState } from '../../contracts/EngineTypes';
import { MediaCommand, MediaCommandListener, MediaSessionPort } from '../../contracts/Ports';
import { VoiceLabel } from '../../contracts/Settings';
import { Log } from '../../app/Log';
import { LogEvents } from '../../app/LogEvents';

export const AVS_TAG: string = 'CityTour';
export const AVS_ARTIST_BASE: string = 'CityTour · Historian';
const ASSET_ID: string = 'citytour-guide';

export type MediaContextProvider = () => common.UIAbilityContext | undefined;

/** ARCHITECTURE §2.6 command table. TourController (A7) dispatches these; `stop` only pauses the tour. */
export function engineEventForCommand(cmd: MediaCommand): EngineEventType {
  switch (cmd) {
    case MediaCommand.PLAY:
      return EngineEventType.USER_RESUME;
    case MediaCommand.NEXT:
      return EngineEventType.USER_SKIP;
    case MediaCommand.PREVIOUS:
      return EngineEventType.USER_REPLAY;
    case MediaCommand.FAVORITE:
      return EngineEventType.USER_MORE;
    default:
      return EngineEventType.USER_PAUSE; // PAUSE and STOP: we never end a tour from the lock screen
  }
}

/** "CityTour · Historian" + " · Fallback voice" (zh voice reads English) or " · Studio voice" (A13 clips) + " · DEMO". */
export function artistLine(meta: MediaMeta): string {
  let a = meta.artist !== undefined && meta.artist.length > 0 ? meta.artist : AVS_ARTIST_BASE;
  if (meta.voiceLabel === VoiceLabel.FALLBACK_ZH_READS_EN) {
    a += ' · Fallback voice';
  } else if (meta.voiceLabel === VoiceLabel.PRERENDERED) {
    a += ' · Studio voice';
  }
  if (meta.demo) {
    a += ' · DEMO';
  }
  return a;
}

function toPlaybackState(s: MediaPlayState): avSession.PlaybackState {
  if (s === MediaPlayState.PLAY) {
    return avSession.PlaybackState.PLAYBACK_STATE_PLAY;
  }
  if (s === MediaPlayState.PAUSE) {
    return avSession.PlaybackState.PLAYBACK_STATE_PAUSE;
  }
  return avSession.PlaybackState.PLAYBACK_STATE_STOP;
}

const COMMANDS: MediaCommand[] = [
  MediaCommand.PLAY, MediaCommand.PAUSE, MediaCommand.NEXT, MediaCommand.PREVIOUS, MediaCommand.FAVORITE,
  MediaCommand.STOP
];

export class MediaSessionService implements MediaSessionPort {
  private readonly ctxOf: MediaContextProvider;
  private session: avSession.AVSession | undefined = undefined; // held for the whole tour (must not be GC'd)
  private active: boolean = false;
  private initing: Promise<boolean> | undefined = undefined;
  private onCommand: MediaCommandListener = (cmd: MediaCommand) => {};
  private lastTitle: string = '';
  private lastArtist: string = '';
  private lastState: MediaPlayState | undefined = undefined;
  private pendingMeta: MediaMeta | undefined = undefined;
  private pendingState: MediaPlayState | undefined = undefined;
  private lastCmd: string = '';

  constructor(ctxOf: MediaContextProvider) {
    this.ctxOf = ctxOf;
  }

  isActive(): boolean {
    return this.active;
  }

  /** Last command as "cmd=… n=…" for the DevPanel, '' if none yet. */
  lastCommandLine(): string {
    return this.lastCmd;
  }

  init(onCommand: MediaCommandListener): Promise<boolean> {
    this.onCommand = onCommand;
    if (this.active) {
      return Promise.resolve(true);
    }
    if (this.initing !== undefined) {
      return this.initing;
    }
    const p = this.doInit().catch((e: Object) => {
      Log.e(LogEvents.AVS_FAIL, `where=init ${Log.errKv(e)}`);
      return false;
    });
    this.initing = p;
    p.then(() => {
      this.initing = undefined;
    }).catch(() => {
      this.initing = undefined;
    });
    return p;
  }

  private async doInit(): Promise<boolean> {
    const ctx = this.ctxOf();
    if (ctx === undefined) {
      Log.e(LogEvents.AVS_FAIL, 'where=init code=-1 msg=no_context');
      return false;
    }
    let s: avSession.AVSession;
    try {
      s = await avSession.createAVSession(ctx, AVS_TAG, 'audio');
    } catch (e) {
      Log.e(LogEvents.AVS_FAIL, `where=createAVSession ${Log.errKv(e as Object)}`);
      return false;
    }
    this.session = s;
    this.registerCommands(s);
    await this.setLaunchAbility(s, ctx);
    // The card needs metadata to show; use the caller's meta if setMeta() ran before init finished.
    const meta: MediaMeta = this.pendingMeta !== undefined ? this.pendingMeta :
      { title: 'CityTour', artist: AVS_ARTIST_BASE, voiceLabel: VoiceLabel.NATIVE, demo: false };
    await this.applyMeta(s, meta);
    await this.applyState(s, this.pendingState !== undefined ? this.pendingState : MediaPlayState.PAUSE);
    try {
      await s.activate();
    } catch (e) {
      Log.e(LogEvents.AVS_FAIL, `where=activate ${Log.errKv(e as Object)}`);
      await this.destroy();
      return false;
    }
    this.active = true;
    Log.i(LogEvents.AVS_META, `event=active session=${s.sessionId} type=audio cmds=${COMMANDS.join(',')}`);
    return true;
  }

  private registerCommands(s: avSession.AVSession): void {
    // Each listener is registered separately so one failure does not lose the others.
    try {
      s.on('play', () => this.dispatch(MediaCommand.PLAY));
    } catch (e) {
      Log.w(LogEvents.AVS_FAIL, `where=on_play ${Log.errKv(e as Object)}`);
    }
    try {
      s.on('pause', () => this.dispatch(MediaCommand.PAUSE));
    } catch (e) {
      Log.w(LogEvents.AVS_FAIL, `where=on_pause ${Log.errKv(e as Object)}`);
    }
    try {
      s.on('playNext', () => this.dispatch(MediaCommand.NEXT));
    } catch (e) {
      Log.w(LogEvents.AVS_FAIL, `where=on_playNext ${Log.errKv(e as Object)}`);
    }
    try {
      s.on('playPrevious', () => this.dispatch(MediaCommand.PREVIOUS));
    } catch (e) {
      Log.w(LogEvents.AVS_FAIL, `where=on_playPrevious ${Log.errKv(e as Object)}`);
    }
    try {
      s.on('toggleFavorite', (assetId: string) => this.dispatch(MediaCommand.FAVORITE));
    } catch (e) {
      Log.w(LogEvents.AVS_FAIL, `where=on_toggleFavorite ${Log.errKv(e as Object)}`);
    }
    try {
      s.on('stop', () => this.dispatch(MediaCommand.STOP));
    } catch (e) {
      Log.w(LogEvents.AVS_FAIL, `where=on_stop ${Log.errKv(e as Object)}`);
    }
  }

  private async setLaunchAbility(s: avSession.AVSession, ctx: common.UIAbilityContext): Promise<void> {
    try {
      const info: wantAgent.WantAgentInfo = {
        wants: [{ bundleName: ctx.abilityInfo.bundleName, abilityName: ctx.abilityInfo.name }],
        actionType: wantAgent.OperationType.START_ABILITY,
        requestCode: 1,
        actionFlags: [wantAgent.WantAgentFlags.UPDATE_PRESENT_FLAG]
      };
      const agent = await wantAgent.getWantAgent(info);
      await s.setLaunchAbility(agent);
    } catch (e) {
      // Optional: the card still works, tapping it just does not open the app.
      Log.w(LogEvents.AVS_FAIL, `where=setLaunchAbility ${Log.errKv(e as Object)}`);
    }
  }

  private dispatch(cmd: MediaCommand): void {
    this.lastCmd = `cmd=${cmd} ev=${engineEventForCommand(cmd)}`;
    Log.i(LogEvents.AVS_CMD, `cmd=${cmd} ev=${engineEventForCommand(cmd)}`);
    try {
      this.onCommand(cmd);
    } catch (e) {
      Log.e(LogEvents.UNCAUGHT, `where=MediaSessionService.onCommand cmd=${cmd} ${Log.errKv(e as Object)}`);
    }
  }

  setMeta(meta: MediaMeta): void {
    this.pendingMeta = meta;
    const s = this.session;
    if (s === undefined || !this.active) {
      return; // applied by init()
    }
    this.applyMeta(s, meta).catch((e: Object) => {
      Log.e(LogEvents.AVS_FAIL, `where=setMeta ${Log.errKv(e)}`);
    });
  }

  private async applyMeta(s: avSession.AVSession, meta: MediaMeta): Promise<void> {
    const artist = artistLine(meta);
    if (meta.title === this.lastTitle && artist === this.lastArtist) {
      return;
    }
    const md: avSession.AVMetadata = {
      assetId: ASSET_ID, title: meta.title, artist: artist, album: 'Kraków · Royal Route', duration: -1
    };
    try {
      await s.setAVMetadata(md);
      this.lastTitle = meta.title;
      this.lastArtist = artist;
      Log.i(LogEvents.AVS_META, `title="${meta.title}" artist="${artist}"`);
    } catch (e) {
      Log.e(LogEvents.AVS_FAIL, `where=setAVMetadata ${Log.errKv(e as Object)}`);
    }
  }

  setState(state: MediaPlayState): void {
    this.pendingState = state;
    const s = this.session;
    if (s === undefined || !this.active) {
      return; // applied by init()
    }
    this.applyState(s, state).catch((e: Object) => {
      Log.e(LogEvents.AVS_FAIL, `where=setState ${Log.errKv(e)}`);
    });
  }

  private async applyState(s: avSession.AVSession, state: MediaPlayState): Promise<void> {
    if (state === this.lastState) {
      return;
    }
    const ps: avSession.AVPlaybackState = {
      state: toPlaybackState(state), isFavorite: false, position: { elapsedTime: 0, updateTime: Date.now() }
    };
    try {
      await s.setAVPlaybackState(ps);
      this.lastState = state;
      Log.i(LogEvents.AVS_META, `state=${state}`);
    } catch (e) {
      Log.e(LogEvents.AVS_FAIL, `where=setAVPlaybackState ${Log.errKv(e as Object)}`);
    }
  }

  async destroy(): Promise<void> {
    const s = this.session;
    this.session = undefined;
    this.active = false;
    this.lastTitle = '';
    this.lastArtist = '';
    this.lastState = undefined;
    this.pendingMeta = undefined;
    this.pendingState = undefined;
    if (s === undefined) {
      return;
    }
    for (const c of COMMANDS) {
      this.offCommand(s, c);
    }
    try {
      await s.destroy();
      Log.i(LogEvents.AVS_META, 'event=destroyed');
    } catch (e) {
      Log.w(LogEvents.AVS_FAIL, `where=destroy ${Log.errKv(e as Object)}`);
    }
  }

  private offCommand(s: avSession.AVSession, c: MediaCommand): void {
    try {
      switch (c) {
        case MediaCommand.PLAY:
          s.off('play');
          break;
        case MediaCommand.PAUSE:
          s.off('pause');
          break;
        case MediaCommand.NEXT:
          s.off('playNext');
          break;
        case MediaCommand.PREVIOUS:
          s.off('playPrevious');
          break;
        case MediaCommand.FAVORITE:
          s.off('toggleFavorite');
          break;
        default:
          s.off('stop');
      }
    } catch (e) {
      Log.w(LogEvents.AVS_FAIL, `where=off_${c} ${Log.errKv(e as Object)}`);
    }
  }
}

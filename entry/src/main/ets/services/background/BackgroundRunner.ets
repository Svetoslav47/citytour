/*
 * BackgroundPort implementation (docs/ARCHITECTURE.md §2.4, task A6): ONE continuous task with both modes,
 * startBackgroundRunning(ctx, ['location','audioPlayback'], wantAgent), so the guide keeps tracking and talking
 * with the screen locked. Verified on the Pura 90 emulator in docs/RISKS.md §1 c1-c5; the emulator does not
 * freeze background apps, so this proves the wiring, not real-phone behaviour.
 *
 * Docs (devecocli docs read):
 * - API参考/Background_Tasks_Kit_后台任务开发服务/ArkTS_API/ohos_resourceschedule_backgroundTaskManager_后台任务管理_/
 *   js-apis-resourceschedule-backgroundtaskmanager
 *   startBackgroundRunning(ctx, string[], WantAgent) 12+ (one task per UIAbility; a second request fails, seen as
 *   9800005 on the emulator, RISKS c5), stopBackgroundRunning(ctx) 9, on/off('continuousTaskCancel') 15+,
 *   on/off('continuousTaskSuspend') 20+ (= our minimum, so no version guard; still wrapped in try/catch).
 *   Registering the suspend listener makes the system mark the task suspended first instead of cancelling it.
 * - 开发指南/Background_Tasks_Kit_后台任务开发服务/长时任务_ArkTS/continuous-task: stop or pause the audio stream
 *   together with the task, otherwise the system kills the app -> the stopAudio hook runs before every stop and
 *   on cancel.
 * - API参考/Ability_Kit_程序框架服务/ArkTS_API/接口依赖的元素及定义/wantAgent/WantAgentInfo/
 *   js-apis-inner-wantagent-wantagentinfo (actionType / actionFlags 11+): tapping the task notification opens
 *   EntryAbility.
 * Every platform call is wrapped in try/catch and Promise.catch; failures log BG_FAIL and return false (ARCHITECTURE
 * §9 row 14: the tour continues in the foreground).
 */
import { backgroundTaskManager } from '@kit.BackgroundTasksKit';
import { common, wantAgent, WantAgent } from '@kit.AbilityKit';
import { BackgroundListener, BackgroundPort } from 'common';
import { AppConfig } from '../../app/AppConfig';
import { Log } from '../../app/Log';
import { LogEvents } from 'common';

export const BG_MODES: string[] = ['location', 'audioPlayback'];

/** "already applied for a continuous task" on the emulator (RISKS c5); the contract counts it as success. */
export const BG_ERR_ALREADY_RUNNING: number = 9800005;

export type ContextProvider = () => common.UIAbilityContext | undefined;

function errCode(e: Object | undefined | null): number {
  if (e === undefined || e === null) {
    return -1;
  }
  try {
    const c = (e as Record<string, Object>)['code'];
    return typeof c === 'number' ? c as number : -1;
  } catch (x) {
    return -1;
  }
}

function cancelReasonName(r: number): string {
  switch (r) {
    case 1:
      return 'USER_CANCEL';
    case 2:
      return 'SYSTEM_CANCEL';
    case 3:
      return 'USER_CANCEL_REMOVE_NOTIFICATION';
    case 5:
      return 'AUDIO_PLAYBACK_NOT_USE_AVSESSION';
    case 6:
      return 'AUDIO_PLAYBACK_NOT_RUNNING';
    case 8:
      return 'NOT_USE_LOCATION';
    default:
      return `R${r}`;
  }
}

function suspendReasonName(r: number): string {
  switch (r) {
    case 5:
      return 'AUDIO_PLAYBACK_NOT_USE_AVSESSION';
    case 6:
      return 'AUDIO_PLAYBACK_NOT_RUNNING';
    case 8:
      return 'LOCATION_NOT_USED';
    case 12:
      return 'SYSTEM_LOAD_WARNING';
    default:
      return `R${r}`;
  }
}

export class BackgroundRunner implements BackgroundPort {
  private readonly ctxOf: ContextProvider;
  private readonly stopAudio: () => void;
  private listener: BackgroundListener | undefined = undefined;
  private running: boolean = false;
  private starting: Promise<boolean> | undefined = undefined;
  private callbacksOn: boolean = false;
  private taskId: number = -1;
  private lastIssue: string = '';
  private readonly onCancel = (info: backgroundTaskManager.ContinuousTaskCancelInfo): void => {
    this.handleCancel(info);
  };
  private readonly onSuspend = (info: backgroundTaskManager.ContinuousTaskSuspendInfo): void => {
    this.handleSuspend(info);
  };

  /** stopAudio runs before every stop and when the system cancels the task (continuous-task guide). */
  constructor(ctxOf: ContextProvider, stopAudio: () => void) {
    this.ctxOf = ctxOf;
    this.stopAudio = stopAudio;
  }

  setListener(l: BackgroundListener): void {
    this.listener = l;
  }

  isRunning(): boolean {
    return this.running;
  }

  /** Last cancel/suspend/failure as "BG_xxx k=v", '' if none. For the DevPanel and the HUD. */
  lastIssueLine(): string {
    return this.lastIssue;
  }

  start(): Promise<boolean> {
    if (this.running) {
      return Promise.resolve(true);
    }
    if (this.starting !== undefined) {
      return this.starting;
    }
    const p = this.doStart().catch((e: Object) => {
      this.fail('start', e);
      return false;
    });
    this.starting = p;
    p.then(() => {
      this.starting = undefined;
    }).catch(() => {
      this.starting = undefined;
    });
    return p;
  }

  private async doStart(): Promise<boolean> {
    const ctx = this.ctxOf();
    if (ctx === undefined) {
      Log.e(LogEvents.BG_FAIL, 'code=-1 msg=no_context');
      this.lastIssue = 'BG_FAIL no_context';
      return false;
    }
    if (AppConfig.DEBUG_FAIL_BG_START) {
      // §9 row 14 demo: behave as if the system refused the continuous task.
      const sim: Record<string, Object> = { 'code': -99, 'message': 'simulated src=debug (AppConfig.DEBUG_FAIL_BG_START)' };
      this.fail('startBackgroundRunning', sim);
      return false;
    }
    const agent = await this.launchAgent(ctx);
    if (agent === undefined) {
      return false;
    }
    try {
      const n = await backgroundTaskManager.startBackgroundRunning(ctx, BG_MODES, agent);
      this.taskId = n !== undefined && n !== null && n.continuousTaskId !== undefined ? n.continuousTaskId : -1;
      this.running = true;
      this.lastIssue = '';
      this.registerCallbacks();
      Log.i(LogEvents.BG_START, `modes=${BG_MODES.join(',')} id=${this.taskId}` +
        ` notif=${n !== undefined && n !== null ? n.notificationId : -1}`);
      return true;
    } catch (e) {
      const code = errCode(e as Object);
      if (code === BG_ERR_ALREADY_RUNNING) {
        // One task per UIAbility: a previous start (e.g. before a page reload) still owns it.
        this.running = true;
        this.registerCallbacks();
        Log.w(LogEvents.BG_START, `modes=${BG_MODES.join(',')} already=1 ${Log.errKv(e as Object)}`);
        return true;
      }
      this.fail('startBackgroundRunning', e as Object);
      return false;
    }
  }

  private async launchAgent(ctx: common.UIAbilityContext): Promise<WantAgent | undefined> {
    try {
      const info: wantAgent.WantAgentInfo = {
        wants: [{ bundleName: ctx.abilityInfo.bundleName, abilityName: ctx.abilityInfo.name }],
        actionType: wantAgent.OperationType.START_ABILITY,
        requestCode: 0,
        actionFlags: [wantAgent.WantAgentFlags.UPDATE_PRESENT_FLAG]
      };
      return await wantAgent.getWantAgent(info);
    } catch (e) {
      this.fail('getWantAgent', e as Object);
      return undefined;
    }
  }

  async stop(): Promise<void> {
    this.safeStopAudio('stop');
    const ctx = this.ctxOf();
    const wasRunning = this.running;
    this.running = false;
    this.unregisterCallbacks();
    if (ctx === undefined) {
      Log.w(LogEvents.BG_STOP, `ok=0 reason=no_context wasRunning=${wasRunning ? 1 : 0}`);
      return;
    }
    try {
      await backgroundTaskManager.stopBackgroundRunning(ctx);
      Log.i(LogEvents.BG_STOP, `ok=1 id=${this.taskId} wasRunning=${wasRunning ? 1 : 0}`);
    } catch (e) {
      // Stopping when nothing runs is harmless; log it and carry on.
      Log.w(LogEvents.BG_STOP, `ok=0 ${Log.errKv(e as Object)}`);
    }
    this.taskId = -1;
  }

  private registerCallbacks(): void {
    if (this.callbacksOn) {
      return;
    }
    try {
      backgroundTaskManager.on('continuousTaskCancel', this.onCancel);
    } catch (e) {
      Log.w(LogEvents.BG_FAIL, `where=on_cancel ${Log.errKv(e as Object)}`);
    }
    try {
      backgroundTaskManager.on('continuousTaskSuspend', this.onSuspend); // API 20 = our minimum
    } catch (e) {
      Log.w(LogEvents.BG_FAIL, `where=on_suspend ${Log.errKv(e as Object)}`);
    }
    this.callbacksOn = true;
  }

  private unregisterCallbacks(): void {
    if (!this.callbacksOn) {
      return;
    }
    try {
      backgroundTaskManager.off('continuousTaskCancel', this.onCancel);
    } catch (e) {
      Log.w(LogEvents.BG_FAIL, `where=off_cancel ${Log.errKv(e as Object)}`);
    }
    try {
      backgroundTaskManager.off('continuousTaskSuspend', this.onSuspend);
    } catch (e) {
      Log.w(LogEvents.BG_FAIL, `where=off_suspend ${Log.errKv(e as Object)}`);
    }
    this.callbacksOn = false;
  }

  private handleCancel(info: backgroundTaskManager.ContinuousTaskCancelInfo): void {
    try {
      const reason = cancelReasonName(info.reason);
      Log.w(LogEvents.BG_CANCEL, `reason=${reason} id=${info.id}`);
      this.lastIssue = `BG_CANCEL reason=${reason}`;
      this.running = false;
      this.safeStopAudio('cancel');
      this.unregisterCallbacks();
      if (this.listener !== undefined) {
        this.listener.onCancelled(reason);
      }
    } catch (e) {
      Log.e(LogEvents.UNCAUGHT, `where=BackgroundRunner.cancel ${Log.errKv(e as Object)}`);
    }
  }

  private handleSuspend(info: backgroundTaskManager.ContinuousTaskSuspendInfo): void {
    try {
      const reason = suspendReasonName(info.suspendReason);
      Log.w(LogEvents.BG_SUSPEND, `reason=${reason} suspended=${info.suspendState ? 1 : 0} id=${info.continuousTaskId}`);
      this.lastIssue = `BG_SUSPEND reason=${reason} suspended=${info.suspendState ? 1 : 0}`;
      if (info.suspendState && this.listener !== undefined) {
        this.listener.onSuspended(reason);
      }
    } catch (e) {
      Log.e(LogEvents.UNCAUGHT, `where=BackgroundRunner.suspend ${Log.errKv(e as Object)}`);
    }
  }

  private safeStopAudio(why: string): void {
    try {
      this.stopAudio();
    } catch (e) {
      Log.e(LogEvents.UNCAUGHT, `where=BackgroundRunner.stopAudio why=${why} ${Log.errKv(e as Object)}`);
    }
  }

  private fail(where: string, e: Object): void {
    Log.e(LogEvents.BG_FAIL, `where=${where} ${Log.errKv(e)}`);
    this.lastIssue = `BG_FAIL where=${where} code=${errCode(e)}`;
  }
}

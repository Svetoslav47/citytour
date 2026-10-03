/*
 * NotifierPort implementation (task A8, docs/ARCHITECTURE.md §2.7, DESIGN §3.12.3): ONE CityTour notification,
 * id 1001, updated in place: "Next: Wawel Cathedral" / "240 m · ~3 min · on your left" / "5/11" while walking and,
 * in text-only mode, "You're at St Mary's Basilica" + the arrival line when the engine reaches a stop. It is the
 * glanceable surface for a locked screen. The system continuous-task notification cannot be customised
 * (DESIGN §3.12.2), and the AVSession card carries the audio controls, so this is the only text we own there.
 *
 * - Consent: the first NOTIFY_NEXT of a tour (emitted on START_TOUR, i.e. right after the user taps Start, with
 *   the UI loaded) asks once per app session: isNotificationEnabled() -> requestEnableNotification(ctx). Refusal
 *   (1600004) logs NOTIF_DENIED and the tour goes on without the notification (§9 row 16). requestEnable() is
 *   public so Onboarding (A12) can ask in its permission step instead; the tour start then asks nothing.
 * - Updates: every engine NOTIFY_NEXT publishes (stop change, re-plan, text-only arrival). attach() subscribes to the
 *   controller's snapshots for the distance refresh (>= 50 m, >= 3 s apart) and cancels the notification as soon as
 *   the tour is no longer live (finished, aborted, re-planned, idle). AppContainer.shutdown() cancels it too.
 * - isAlertOnce: only the first publish of the tour alerts; updates are silent (the arrival haptic is the cue).
 * - Slot SERVICE_INFORMATION: per the slot table it shows on the lock screen (OTHER_TYPES does not), which is
 *   the screen-off use case.
 * - Demo walk: the text starts with SIMULATED (logs src=demo). No emoji (core/notify/NotifyText sanitises).
 *
 * Docs (devecocli docs read):
 * - 开发指南/Notification_Kit_用户通知服务/请求通知授权/notification-enable (isNotificationEnabled,
 *   requestEnableNotification(UIAbilityContext), 1600004 = refused, the dialog shows only once).
 * - API参考/Notification_Kit_用户通知服务/ArkTS_API/ohos_notificationManager_NotificationManager模块_/
 *   js-apis-notificationmanager (publish 9+, cancel(id) 9+, addSlot 9+, isNotificationEnabled() 11+,
 *   requestEnableNotification(context) 10+ "only after loadContent", SlotType; errors 1600001/1600004/1600012).
 * - API参考/Notification_Kit_用户通知服务/ArkTS_API/notification/NotificationRequest/
 *   js-apis-inner-notification-notificationrequest (same id updates in place, isAlertOnce, notificationSlotType 11+,
 *   wantAgent; isOngoing "reserved, not supported", so the notification stays dismissible).
 * - 开发指南/Notification_Kit_用户通知服务/管理通知渠道/notification-slot (SERVICE_INFORMATION: shade, banner,
 *   lock screen; OTHER_TYPES: shade only).
 * - 开发指南/Notification_Kit_用户通知服务/发布通知/发布文本类型通知/text-notification (BASIC_TEXT content).
 * - API参考/Ability_Kit_程序框架服务/ArkTS_API/接口依赖的元素及定义/wantAgent/WantAgentInfo/
 *   js-apis-inner-wantagent-wantagentinfo (tap opens EntryAbility, which keeps the Now Walking page).
 * All APIs are <= API 20 (the minimum), so there is no version guard; every call is wrapped and never throws out.
 */
import { notificationManager } from '@kit.NotificationKit';
import { common, wantAgent, WantAgent } from '@kit.AbilityKit';
import { EngineSnapshot, NextNotice } from '../../contracts/EngineTypes';
import { NotifierPort, TourControl } from '../../contracts/Ports';
import { Lang } from '../../contracts/Model';
import {
  NOTIFY_ID, NoticeKind, NotifyContext, NotifyText, ShownNotice, contextFromSnapshot, formatNotice, isTourLive,
  noticeKind, shouldRefresh, shownDistance
} from '../../core/notify/NotifyText';
import { Log } from '../../app/Log';
import { LogEvents } from '../../app/LogEvents';

export type NotifierContextProvider = () => common.UIAbilityContext | undefined;

/** requestEnableNotification: the user refused (notification-enable guide). publish: notifications disabled. */
export const NOTIF_ERR_DISABLED: number = 1600004;

enum Consent { UNKNOWN = 'unknown', GRANTED = 'granted', DENIED = 'denied' }

function errCode(e: Object | undefined | null): number {
  if (e === undefined || e === null) {
    return -1;
  }
  try {
    const c = (e as Record<string, Object>)['code'];
    return c === undefined ? -1 : Number(c);
  } catch (err) {
    return -1;
  }
}

export class TourNotifier implements NotifierPort {
  private readonly ctxOf: NotifierContextProvider;
  private control: TourControl | undefined = undefined;
  private langOf: () => Lang = () => Lang.EN;
  private unsubscribe: (() => void) | undefined = undefined;
  private consent: Consent = Consent.UNKNOWN;
  private consentAsk: Promise<boolean> | undefined = undefined;
  private deniedLogged: boolean = false;
  private slotReady: boolean = false;
  private agent: WantAgent | undefined = undefined;
  private shown: ShownNotice | undefined = undefined;  // last successful publish, undefined = nothing on screen
  private seq: number = 0;                             // bumps on every engine notice and every cancel
  private cancelledLast: boolean = false;              // the newest seq bump was a cancel
  private inFlight: boolean = false;

  constructor(ctxOf: NotifierContextProvider) {
    this.ctxOf = ctxOf;
  }

  /** Live tour context (snapshot + text language) and the snapshot stream for refreshes and the end of a tour. */
  attach(control: TourControl, langOf: () => Lang): void {
    try {
      if (this.unsubscribe !== undefined) {
        this.unsubscribe();
      }
      this.control = control;
      this.langOf = langOf;
      this.unsubscribe = control.subscribe((s: EngineSnapshot) => this.onSnapshot(s));
    } catch (e) {
      Log.e(LogEvents.UNCAUGHT, `where=TourNotifier.attach ${Log.errKv(e as Object)}`);
    }
  }

  detach(): void {
    try {
      if (this.unsubscribe !== undefined) {
        this.unsubscribe();
      }
    } catch (e) {
      Log.e(LogEvents.UNCAUGHT, `where=TourNotifier.detach ${Log.errKv(e as Object)}`);
    }
    this.unsubscribe = undefined;
    this.control = undefined;
  }

  /** Once per app session at most; resolves true when notifications are allowed. Never rejects. */
  requestEnable(): Promise<boolean> {
    if (this.consent === Consent.GRANTED) {
      return Promise.resolve(true);
    }
    if (this.consent === Consent.DENIED) {
      return Promise.resolve(false);
    }
    if (this.consentAsk === undefined) {
      this.consentAsk = this.askConsent().then((ok: boolean) => {
        this.consentAsk = undefined;
        return ok;
      });
    }
    return this.consentAsk;
  }

  publishNext(notice: NextNotice): Promise<void> {
    this.seq++;
    this.cancelledLast = false;
    const mySeq: number = this.seq;
    return this.requestEnable().then((ok: boolean) => {
      if (!ok) {
        this.logDeniedOnce('publish');
        return;
      }
      if (mySeq !== this.seq) {
        return;                          // a newer notice or a cancel arrived while consent was pending
      }
      const ctx: NotifyContext | undefined = this.context();
      if (ctx === undefined || !isTourLive(ctx.phase)) {
        Log.i(LogEvents.NOTIF_PUBLISH, `id=${NOTIFY_ID} poi=${notice.poiId} skipped=tour_not_live`);
        return;
      }
      return this.publish(notice, noticeKind(notice, ctx), ctx, 'engine');
    }).catch((e: Object) => {
      Log.e(LogEvents.NOTIF_FAIL, `where=publishNext ${Log.errKv(e)}`);
    });
  }

  cancel(): Promise<void> {
    return this.cancelWhy('port');
  }

  // ---------------------------------------------------------------- internals

  private async askConsent(): Promise<boolean> {
    try {
      const enabled: boolean = await notificationManager.isNotificationEnabled();
      if (enabled) {
        this.consent = Consent.GRANTED;
        Log.i(LogEvents.NOTIF_PERM, 'enabled=1 asked=0');
        return true;
      }
    } catch (e) {
      Log.w(LogEvents.NOTIF_PERM, `where=isNotificationEnabled ${Log.errKv(e as Object)}`);
    }
    const ctx: common.UIAbilityContext | undefined = this.ctxOf();
    if (ctx === undefined) {
      Log.w(LogEvents.NOTIF_PERM, 'enabled=0 asked=0 reason=no_context');
      return false;                      // not cached: ask again once a context exists
    }
    try {
      await notificationManager.requestEnableNotification(ctx);
      this.consent = Consent.GRANTED;
      Log.i(LogEvents.NOTIF_PERM, 'enabled=1 asked=1');
      return true;
    } catch (e) {
      const code: number = errCode(e as Object);
      if (code === NOTIF_ERR_DISABLED) {
        this.consent = Consent.DENIED;   // the system shows this dialog only once
        this.deniedLogged = true;
        Log.i(LogEvents.NOTIF_DENIED, `code=${code} where=requestEnableNotification`);
      } else {
        Log.w(LogEvents.NOTIF_PERM, `enabled=0 asked=1 ${Log.errKv(e as Object)}`);
      }
      return false;
    }
  }

  private logDeniedOnce(where: string): void {
    if (!this.deniedLogged) {
      this.deniedLogged = true;
      Log.i(LogEvents.NOTIF_DENIED, `where=${where}`);
    }
  }

  private context(): NotifyContext | undefined {
    if (this.control === undefined) {
      return undefined;
    }
    try {
      return contextFromSnapshot(this.control.current(), this.langOf());
    } catch (e) {
      Log.e(LogEvents.UNCAUGHT, `where=TourNotifier.context ${Log.errKv(e as Object)}`);
      return undefined;
    }
  }

  private onSnapshot(s: EngineSnapshot): void {
    try {
      const ctx: NotifyContext = contextFromSnapshot(s, this.langOf());
      if (!isTourLive(ctx.phase)) {
        if (this.shown !== undefined || this.inFlight) {
          this.cancelWhy(`phase=${ctx.phase}`);
        }
        return;
      }
      const shown: ShownNotice | undefined = this.shown;
      if (shown !== undefined && !this.inFlight && this.consent === Consent.GRANTED &&
        shouldRefresh(shown, ctx, Date.now())) {
        this.publish(shown.notice, NoticeKind.NEXT, ctx, 'refresh');
      }
    } catch (e) {
      Log.e(LogEvents.UNCAUGHT, `where=TourNotifier.onSnapshot ${Log.errKv(e as Object)}`);
    }
  }

  private async publish(notice: NextNotice, kind: NoticeKind, ctx: NotifyContext, why: string): Promise<void> {
    const mySeq: number = this.seq;
    this.inFlight = true;
    try {
      const t: NotifyText = formatNotice(notice, kind, ctx);
      await this.ensureSlot();
      const agent: WantAgent | undefined = await this.launchAgent();
      if (mySeq !== this.seq) {
        return;                          // superseded while preparing
      }
      const request: notificationManager.NotificationRequest = {
        id: NOTIFY_ID,
        notificationSlotType: notificationManager.SlotType.SERVICE_INFORMATION,
        isAlertOnce: true,
        content: {
          notificationContentType: notificationManager.ContentType.NOTIFICATION_CONTENT_BASIC_TEXT,
          normal: { title: t.title, text: t.text, additionalText: t.additionalText }
        }
      };
      if (agent !== undefined) {
        request.wantAgent = agent;
      }
      await notificationManager.publish(request);
      if (mySeq !== this.seq) {
        if (this.cancelledLast) {        // the tour ended while this publish was on its way: take it down again
          await this.cancelWhy('late_publish');
        }
        return;
      }
      const d: number = shownDistance(notice, kind, ctx);
      this.shown = { kind: kind, notice: notice, distanceM: d, atMs: Date.now() };
      Log.i(LogEvents.NOTIF_PUBLISH, `id=${NOTIFY_ID} kind=${kind} why=${why} poi=${notice.poiId} ` +
        `d=${Number.isFinite(d) ? Math.round(d) : -1} k=${t.additionalText} src=${ctx.demo ? 'demo' : 'real'} ` +
        `lang=${ctx.lang}`);
    } catch (e) {
      const code: number = errCode(e as Object);
      if (code === NOTIF_ERR_DISABLED) {
        this.consent = Consent.DENIED;   // switched off in Settings during the tour
        Log.i(LogEvents.NOTIF_DENIED, `code=${code} where=publish`);
      } else {
        Log.e(LogEvents.NOTIF_FAIL, `where=publish kind=${kind} ${Log.errKv(e as Object)}`);
      }
    } finally {
      this.inFlight = false;
    }
  }

  private async cancelWhy(why: string): Promise<void> {
    this.seq++;
    this.cancelledLast = true;
    const had: boolean = this.shown !== undefined || why === 'late_publish';
    this.shown = undefined;
    if (!had && why !== 'shutdown') {
      return;
    }
    try {
      await notificationManager.cancel(NOTIFY_ID);
      Log.i(LogEvents.NOTIF_CANCEL, `id=${NOTIFY_ID} why=${why}`);
    } catch (e) {
      Log.w(LogEvents.NOTIF_FAIL, `where=cancel why=${why} ${Log.errKv(e as Object)}`);
    }
  }

  /** AppContainer.shutdown: the notification must not outlive the app process. */
  shutdown(): Promise<void> {
    this.detach();
    return this.cancelWhy('shutdown');
  }

  private async ensureSlot(): Promise<void> {
    if (this.slotReady) {
      return;
    }
    try {
      await notificationManager.addSlot(notificationManager.SlotType.SERVICE_INFORMATION);
    } catch (e) {
      Log.w(LogEvents.NOTIF_FAIL, `where=addSlot ${Log.errKv(e as Object)}`);   // publish still tries
    }
    this.slotReady = true;
  }

  private async launchAgent(): Promise<WantAgent | undefined> {
    if (this.agent !== undefined) {
      return this.agent;
    }
    const ctx: common.UIAbilityContext | undefined = this.ctxOf();
    if (ctx === undefined) {
      return undefined;
    }
    try {
      const info: wantAgent.WantAgentInfo = {
        wants: [{ bundleName: ctx.abilityInfo.bundleName, abilityName: ctx.abilityInfo.name }],
        actionType: wantAgent.OperationType.START_ABILITY,
        requestCode: 1,
        actionFlags: [wantAgent.WantAgentFlags.UPDATE_PRESENT_FLAG]
      };
      this.agent = await wantAgent.getWantAgent(info);
    } catch (e) {
      Log.w(LogEvents.NOTIF_FAIL, `where=getWantAgent ${Log.errKv(e as Object)}`);
    }
    return this.agent;
  }
}

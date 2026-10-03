/*
 * HapticsPort implementation (task A8, docs/ARCHITECTURE.md §2.8): a short vibration on arrival (and on finish,
 * approach, off-route), the eyes-free cue that matters most in text-only mode (Polish, or no voice).
 *
 * Docs (devecocli docs read):
 * - API参考/硬件/Sensor_Service_Kit_传感器服务/ArkTS_API/ohos_vibrator_振动_/js-apis-vibrator:
 *   startVibration(effect, attribute): Promise<void> 9+ (needs ohos.permission.VIBRATE, declared in module.json5;
 *   errors 201/401/801/14600101 are thrown or rejected); VibratePreset {type:'preset', effectId, count} 9+;
 *   VibrateTime {type:'time', duration} 9+; isSupportEffectSync(effectId) 12+ (blocks the calling thread, so the
 *   answer is cached per effect id); preset ids 'haptic.notice.success' (18+), 'haptic.effect.soft' (12+),
 *   'haptic.clock.timer'; VibrateAttribute.usage 'notification' (governed by the system notification vibration
 *   switch). Every API used is <= API 20, the minimum, so there is no version guard; all calls are still wrapped.
 * - 开发指南/硬件/Sensor_Service_Kit_传感器服务/振动/振动开发指导_ArkTS/vibrator-guidelines: prefer presets,
 *   check support first.
 * The pure choice (preset vs timed fallback, counts, durations) is core/notify/NotifyText.hapticPlan (unit-tested).
 * The emulator has no vibration motor we can feel: there the call may succeed silently or fail with 801/14600101.
 * Either way the HAPTIC log line records what was attempted (ok=1|0), and a failure never reaches the tour.
 */
import { vibrator } from '@kit.SensorServiceKit';
import { HapticKind } from '../../contracts/EngineTypes';
import { HapticsPort } from '../../contracts/Ports';
import { HapticPlan, hapticPlan } from '../../core/notify/NotifyText';
import { Log } from '../../app/Log';
import { LogEvents } from '../../app/LogEvents';

/** One buzz per kind within this window: a re-entered state must not rattle the phone. */
const MIN_GAP_MS: number = 800;

export class Haptics implements HapticsPort {
  private supportCache: Map<string, boolean> = new Map<string, boolean>();
  private lastAt: Map<string, number> = new Map<string, number>();
  private unsupportedLogged: boolean = false;

  play(kind: HapticKind): void {
    try {
      const now: number = Date.now();
      const last: number | undefined = this.lastAt.get(kind);
      if (last !== undefined && now - last < MIN_GAP_MS) {
        Log.i(LogEvents.HAPTIC, `kind=${kind} skipped=debounce`);
        return;
      }
      this.lastAt.set(kind, now);
      const plan: HapticPlan = hapticPlan(kind, (id: string) => this.isSupported(id));
      this.start(plan);
    } catch (e) {
      Log.e(LogEvents.HAPTIC, `kind=${kind} ok=0 where=play ${Log.errKv(e as Object)}`);
    }
  }

  /** Cached isSupportEffectSync; any error counts as "not supported" (timed fallback). */
  private isSupported(effectId: string): boolean {
    const cached: boolean | undefined = this.supportCache.get(effectId);
    if (cached !== undefined) {
      return cached;
    }
    let ok: boolean = false;
    try {
      ok = vibrator.isSupportEffectSync(effectId);
    } catch (e) {
      ok = false;
      if (!this.unsupportedLogged) {
        this.unsupportedLogged = true;
        Log.w(LogEvents.HAPTIC, `where=isSupportEffectSync effect=${effectId} ${Log.errKv(e as Object)}`);
      }
    }
    this.supportCache.set(effectId, ok);
    return ok;
  }

  private start(plan: HapticPlan): void {
    const attr: vibrator.VibrateAttribute = { id: 0, usage: 'notification' };
    const preset: boolean = plan.effectId.length > 0;
    const mode: string = preset ? `preset effect=${plan.effectId} count=${plan.count}` : `time ms=${plan.durationMs}`;
    try {
      let p: Promise<void>;
      if (preset) {
        const effect: vibrator.VibratePreset = { type: 'preset', effectId: plan.effectId, count: plan.count };
        p = vibrator.startVibration(effect, attr);
      } else {
        const effect: vibrator.VibrateTime = { type: 'time', duration: plan.durationMs };
        p = vibrator.startVibration(effect, attr);
      }
      p.then(() => {
        Log.i(LogEvents.HAPTIC, `kind=${plan.kind} mode=${mode} ok=1`);
      }).catch((e: Object) => {
        Log.w(LogEvents.HAPTIC, `kind=${plan.kind} mode=${mode} ok=0 ${Log.errKv(e)}`);
      });
    } catch (e) {
      // 201 / 401 / 801 / 14600101 may be thrown synchronously (vibrator API doc)
      Log.w(LogEvents.HAPTIC, `kind=${plan.kind} mode=${mode} ok=0 ${Log.errKv(e as Object)}`);
    }
  }
}

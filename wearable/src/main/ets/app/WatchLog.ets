/*
 * Logging for the watch HAP. Same domain, tag and format as the phone's app/Log.ets (0xC17A, "CityTour <EVENT> k=v"),
 * so `devecocli log --keyword CityTour` shows phone and watch events alike. Watch events start with WATCH_.
 */
import { hilog } from '@kit.PerformanceAnalysisKit';

const LOG_DOMAIN: number = 0xC17A;
const LOG_TAG: string = 'CityTour';
const LOG_FORMAT: string = 'CityTour %{public}s %{public}s';

export class WatchLog {
  static i(event: string, kv: string = ''): void {
    try {
      hilog.info(LOG_DOMAIN, LOG_TAG, LOG_FORMAT, event, kv);
    } catch (e) {
      // logging must never crash the app
    }
  }

  static w(event: string, kv: string = ''): void {
    try {
      hilog.warn(LOG_DOMAIN, LOG_TAG, LOG_FORMAT, event, kv);
    } catch (e) {
      // logging must never crash the app
    }
  }

  static e(event: string, kv: string = ''): void {
    try {
      hilog.error(LOG_DOMAIN, LOG_TAG, LOG_FORMAT, event, kv);
    } catch (e) {
      // logging must never crash the app
    }
  }

  static errKv(err: Object): string {
    const be = err as Record<string, Object>;
    const code = be['code'] !== undefined ? String(be['code']) : 'none';
    const msg = be['message'] !== undefined ? String(be['message']) : String(err);
    return `code=${code} msg=${msg.replace(/\s+/g, '_').slice(0, 80)}`;
  }
}

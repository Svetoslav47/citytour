/*
 * The only logging entry point of CityTour (docs/ARCHITECTURE.md §10, PLAN §0.3 rule 5).
 * Wraps hilog from @kit.PerformanceAnalysisKit (doc: API参考/调测调优/Performance_Analysis_Kit_性能分析服务/
 * ArkTS_API/ohos_hilog_HiLog日志打印_/js-apis-hilog; info/warn/error since API 7, domain 0x0..0xFFFF).
 * Domain 0xC17A, tag CityTour, format "%{public}s %{public}s" -> "<EVENT> k=v k=v".
 * Never log free-text user data; round real coordinates to 4 decimals.
 */
import { hilog } from '@kit.PerformanceAnalysisKit';
import { LoggerPort } from '../contracts/Ports';

export const LOG_DOMAIN: number = 0xC17A;
export const LOG_TAG: string = 'CityTour';
const LOG_FORMAT: string = '%{public}s %{public}s';

export class Log {
  static d(event: string, kv: string = ''): void {
    try {
      hilog.debug(LOG_DOMAIN, LOG_TAG, LOG_FORMAT, event, kv);
    } catch (e) {
      // logging must never crash the app
    }
  }

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

  /** "code=… msg=…" for a caught error of unknown shape. */
  static errKv(err: Object | undefined | null): string {
    if (err === undefined || err === null) {
      return 'code=-1 msg=unknown';
    }
    try {
      const be = err as Error;
      const code = (err as Record<string, Object>)['code'];
      const msg = be.message !== undefined ? be.message : JSON.stringify(err);
      return `code=${code !== undefined ? String(code) : '-1'} msg=${msg}`;
    } catch (e) {
      return 'code=-1 msg=unprintable';
    }
  }
}

/** LoggerPort adapter for code that receives a logger by injection (core/, TourController). */
export class HilogLogger implements LoggerPort {
  info(event: string, kv: string): void {
    Log.i(event, kv);
  }

  warn(event: string, kv: string): void {
    Log.w(event, kv);
  }

  error(event: string, kv: string): void {
    Log.e(event, kv);
  }
}

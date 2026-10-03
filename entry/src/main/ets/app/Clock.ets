/*
 * System clock behind the contracts Clock port, so core/ and tests can inject a fake clock.
 */
import { Clock } from '../contracts/Ports';

export class SystemClock implements Clock {
  nowMs(): number {
    return Date.now();
  }
}

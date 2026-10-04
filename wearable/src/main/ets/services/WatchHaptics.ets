/*
 * The watch's HapticsPort: the user-approved cue language (docs/research/WATCH.md §5) on the wrist.
 * The shared engine emits HAPTIC(arrive | approach | offRoute | finish); the pure core/haptics/CueMap turns that
 * (plus the arriving stop's side, from the controller's snapshot) into cues, CueGate rate-limits them, and each
 * cue's on/off pattern is played as timed vibrations (Sensor Service Kit vibrator, usage 'notification').
 * Every cue is logged (WATCH_CUE) and reported to the UI listener, because a device without a motor (the DevEco
 * emulator answers 14600101) must still show what the wrist would feel.
 */
import { vibrator } from '@kit.SensorServiceKit';
import { Cue, CueGate, HapticKind, HapticsPort, RelDir, TimedCue, cuesFor, schedule } from 'common';
import { Log } from '../app/Log';

export type CueListener = (cue: Cue) => void;

export class WatchHaptics implements HapticsPort {
  private readonly dirOfArrival: () => RelDir | undefined;
  private readonly gate: CueGate = new CueGate();
  private listener: CueListener | undefined = undefined;
  private timers: number[] = [];

  /** dirOfArrival: the side of the stop being arrived at (the controller's current snapshot). */
  constructor(dirOfArrival: () => RelDir | undefined) {
    this.dirOfArrival = dirOfArrival;
  }

  setListener(l: CueListener | undefined): void {
    this.listener = l;
  }

  play(kind: HapticKind): void {
    try {
      let dir: RelDir | undefined = undefined;
      if (kind === HapticKind.ARRIVE) {
        try {
          dir = this.dirOfArrival();
        } catch (e) {
          dir = undefined;
        }
      }
      const cues: Cue[] = cuesFor(kind, dir);
      if (cues.length === 0) {
        Log.i('WATCH_CUE', `kind=${kind} cues=none`);
        return;
      }
      if (!this.gate.allow(cues[0], Date.now())) {
        Log.i('WATCH_CUE', `kind=${kind} cues=${cues.join('+')} skipped=rate_limit`);
        return;
      }
      Log.i('WATCH_CUE', `kind=${kind} dir=${dir === undefined ? 'none' : dir} cues=${cues.join('+')}`);
      for (const t of schedule(cues)) {
        this.timers.push(setTimeout(() => this.playCue(t), t.atMs));
      }
    } catch (e) {
      Log.e('WATCH_CUE', `kind=${kind} ok=0 where=play ${Log.errKv(e as Object)}`);
    }
  }

  /** Cancels cues still waiting (tour end). */
  cancel(): void {
    for (const id of this.timers) {
      clearTimeout(id);
    }
    this.timers = [];
  }

  private playCue(t: TimedCue): void {
    if (this.listener !== undefined) {
      try {
        this.listener(t.cue);
      } catch (e) {
        Log.w('WATCH_CUE', `where=listener ${Log.errKv(e as Object)}`);
      }
    }
    let at: number = 0;
    for (let i = 0; i < t.pattern.length; i++) {
      if (i % 2 === 0) {
        const ms: number = t.pattern[i];
        const first: boolean = i === 0;
        this.timers.push(setTimeout(() => this.buzz(t.cue, ms, first), at));
      }
      at += t.pattern[i];
    }
  }

  private buzz(cue: Cue, ms: number, log: boolean): void {
    const attr: vibrator.VibrateAttribute = { id: 0, usage: 'notification' };
    const effect: vibrator.VibrateTime = { type: 'time', duration: ms };
    try {
      vibrator.startVibration(effect, attr).then(() => {
        if (log) {
          Log.i('WATCH_CUE', `cue=${cue} vibrate=ok`);
        }
      }).catch((e: Object) => {
        if (log) {
          Log.w('WATCH_CUE', `cue=${cue} vibrate=fail ${Log.errKv(e)}`);
        }
      });
    } catch (e) {
      // 201 / 401 / 801 / 14600101 may be thrown synchronously (vibrator API doc)
      if (log) {
        Log.w('WATCH_CUE', `cue=${cue} vibrate=fail ${Log.errKv(e as Object)}`);
      }
    }
  }
}

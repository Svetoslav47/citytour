/*
 * Watch HAP constants (docs/research/WATCH.md).
 */
export class WatchConfig {
  /** The bundled watch pack (scripts/pack/watch-pack.mjs) in rawfile/. */
  static readonly PACK_DIR: string = 'watch/royal-route';
  static readonly TOUR_ID: string = 'royal-route';
  /** Demo walk replay speed on the watch (1 | 2 | 4 | 8). */
  static readonly DEMO_DEFAULT_SPEED: number = 8;
  /** Launch parameter: `aa start ... --ps demo 1` starts the Demo walk tour right away (verification without UI). */
  static readonly LAUNCH_PARAM_DEMO: string = 'demo';
}

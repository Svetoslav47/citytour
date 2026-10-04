/*
 * State of the watch's two screens (docs/research/WATCH.md §1, task W5): the start screen (tour, Start walk,
 * Demo walk) and the next-stop glance (progress ring, arrow, distance, n/N, stop name, SIMULATED pill, one status
 * line, the cue flash). Fed by the shared TourController's snapshots and the WatchHaptics cue listener; the
 * derivations are the pure core/watch/Glance functions.
 */
import {
  Cue, EngineSnapshot, FixSource, GlanceArrow, GlanceStatus, Lang, PackLoadResult, Poi, RoundedDistance,
  SnapshotUse, Tour, TourController, TourPhase, glanceArrow, glanceSnapshotUse, glanceStatus, glanceStopId,
  localized, roundWalkDistance, stopsDone
} from 'common';
import { Log } from '../app/Log';
import { WatchConfig } from '../app/WatchConfig';
import { WatchContainer } from '../app/WatchContainer';
import { WatchHaptics } from '../services/WatchHaptics';
import { WatchPackRepository } from '../services/WatchPackRepository';

export enum WatchScreen { START = 'start', GLANCE = 'glance', FINISHED = 'finished' }

const CUE_SHOW_MS: number = 2500;

@ObservedV2
export class WatchViewModel {
  @Trace screen: WatchScreen = WatchScreen.START;
  @Trace packOk: boolean = true;
  @Trace title: string = '';
  @Trace stopCount: number = 0;
  @Trace estMinutes: number = 0;
  @Trace done: number = 0;
  @Trace total: number = 0;
  @Trace nextName: string = '';
  @Trace distValue: string = '';
  @Trace distUnit: string = '';
  @Trace arrowKnown: boolean = false;
  @Trace arrowDeg: number = 0;
  @Trace here: boolean = false;
  @Trace simulated: boolean = false;
  @Trace status: GlanceStatus = GlanceStatus.NONE;
  @Trace cue: Cue | undefined = undefined;
  private lang: Lang = Lang.EN;
  private unsubscribe: (() => void) | undefined = undefined;
  private cueTimer: number = -1;
  private lastStatus: GlanceStatus = GlanceStatus.NONE;
  /** The new tour has reached WALKING: until then a snapshot of the previous (ended) tour is ignored. */
  private live: boolean = false;

  async load(): Promise<void> {
    const pack: WatchPackRepository | undefined = WatchContainer.pack();
    if (pack === undefined) {
      this.packOk = false;
      return;
    }
    const r: PackLoadResult = await pack.load();
    this.packOk = r.ok;
    const tour: Tour | undefined = pack.tours().find((t: Tour) => t.id === WatchConfig.TOUR_ID);
    if (!r.ok || tour === undefined) {
      this.packOk = false;
      return;
    }
    this.title = localized(tour.titles, this.lang);
    this.stopCount = tour.stops.length;
    this.estMinutes = tour.estMinutes;
  }

  attach(): void {
    const ctrl: TourController | undefined = WatchContainer.tour();
    if (ctrl !== undefined && this.unsubscribe === undefined) {
      this.unsubscribe = ctrl.subscribe((s: EngineSnapshot) => this.onSnapshot(s));
    }
    const h: WatchHaptics | undefined = WatchContainer.haptics();
    if (h !== undefined) {
      h.setListener((c: Cue) => this.showCue(c));
    }
    WatchContainer.setStartHandler((kind: FixSource) => this.start(kind));
  }

  detach(): void {
    if (this.unsubscribe !== undefined) {
      this.unsubscribe();
      this.unsubscribe = undefined;
    }
    const h: WatchHaptics | undefined = WatchContainer.haptics();
    if (h !== undefined) {
      h.setListener(undefined);
    }
    WatchContainer.setStartHandler(undefined);
  }

  start(kind: FixSource): void {
    this.screen = WatchScreen.GLANCE;
    this.simulated = kind === FixSource.DEMO;
    this.status = GlanceStatus.NO_FIX;
    this.total = this.stopCount;
    this.done = 0;
    this.live = false;
    Log.i('WATCH_UI', `action=start source=${kind}`);
    WatchContainer.keepScreenOn(true);
    WatchContainer.startTour(kind);
  }

  end(): void {
    Log.i('WATCH_UI', `action=end screen=${this.screen}`);
    this.live = false;
    WatchContainer.endTour();
    WatchContainer.keepScreenOn(false);
    this.screen = WatchScreen.START;
    this.cue = undefined;
  }

  onSnapshot(s: EngineSnapshot): void {
    const use: SnapshotUse = glanceSnapshotUse(this.screen !== WatchScreen.START, this.live, s.phase);
    if (use === SnapshotUse.IGNORE) {
      return;
    }
    if (use === SnapshotUse.ABORTED) {
      if (this.screen === WatchScreen.GLANCE) {
        this.live = false;
        this.screen = WatchScreen.START;
        WatchContainer.keepScreenOn(false);
      }
      return;
    }
    this.live = true;
    const pack: WatchPackRepository | undefined = WatchContainer.pack();
    this.simulated = s.source === FixSource.DEMO;
    this.total = s.stops.length;
    this.done = stopsDone(s.stops);
    const atStop: boolean = s.phase === TourPhase.AT_STOP;
    if (pack !== undefined) {
      const poi: Poi | undefined = pack.poi(glanceStopId(s));
      this.nextName = poi !== undefined ? localized(poi.names, this.lang) : '';
    }
    if (s.next !== undefined) {
      const r: RoundedDistance = roundWalkDistance(s.next.distanceM);
      this.distValue = Number.isFinite(s.next.distanceM) ? (r.km ? r.value.toFixed(1) : `${r.value}`) : '';
      this.distUnit = r.km ? 'km' : 'm';
    }
    const a: GlanceArrow = glanceArrow(s.next, s.user);
    this.arrowKnown = a.known && !atStop;
    this.arrowDeg = a.deg;
    this.here = a.here || atStop;
    this.status = glanceStatus(s);
    if (this.status !== this.lastStatus) {
      Log.i('WATCH_UI', `status=${this.status} done=${this.done}/${this.total}`);
      this.lastStatus = this.status;
    }
    if (this.status === GlanceStatus.FINISHED && this.screen !== WatchScreen.FINISHED) {
      this.screen = WatchScreen.FINISHED;
      WatchContainer.keepScreenOn(false);
    }
  }

  private showCue(c: Cue): void {
    this.cue = c;
    if (this.cueTimer >= 0) {
      clearTimeout(this.cueTimer);
    }
    this.cueTimer = setTimeout(() => {
      this.cue = undefined;
      this.cueTimer = -1;
    }, CUE_SHOW_MS);
  }
}

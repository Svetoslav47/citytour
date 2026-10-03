/*
 * Courses screen view model (docs/SERVER.md §6 "Courses screen") and the persisted "Online studio voice" setting.
 * Rows come from the pure core/remote/CourseRules.mergeCourses over CourseRepository's installed courses, its
 * catalog (server or the last verified offline copy) and the bundled course. Each row shows title (UI language),
 * city, stops · km · minutes, languages, size, and its state: Download (size) / progress % / Downloaded ✓ / Update /
 * Delete; selecting a downloaded course makes it the active course for Home and Tour detail.
 * States: server disabled (BASE_URL '') -> "Only the built-in course"; offline -> cached catalog + "Offline" note;
 * no cached catalog and offline -> local courses only + note. Every call is bounded (withTimeout) and never throws.
 * RemoteSettings persists with PersistenceV2 under 'remoteSettings' (no change to the UserSettings contract).
 */
import { PersistenceV2 } from '@kit.ArkUI';
import { Lang } from '../contracts/Model';
import { AppContainer } from '../app/AppContainer';
import { Log } from '../app/Log';
import { LogEvents } from '../app/LogEvents';
import { CourseRow, CourseState, courseTitle, mergeCourses, progressPct, sizeLabel } from '../core/remote/CourseRules';
import { CourseSummary } from '../core/remote/ServerApi';
import { CatalogSource, CatalogState, OpResult } from '../services/remote/CourseRepository';
import { CancelToken, InstallProgress } from '../services/remote/CourseStore';
import { AppViewModel } from './AppViewModel';
import { withTimeout } from './Async';
import { localName } from './Format';
import { findTour, listedMetres } from './PackView';
import { MapCache } from './MapViewModel';

/** The active course changed: drop the cached detail map and let Home / About re-read the pack. */
function notifyCourseChanged(): void {
  MapCache.reset();
  AppViewModel.get().courseChanged();
}

export const REMOTE_SETTINGS_KEY: string = 'remoteSettings';

@ObservedV2
export class RemoteSettings {
  @Trace onlineStudioVoice: boolean = true;

  private static inst: RemoteSettings | undefined = undefined;

  static get(): RemoteSettings {
    if (RemoteSettings.inst === undefined) {
      let x: RemoteSettings | undefined = undefined;
      try {
        x = PersistenceV2.connect(RemoteSettings, REMOTE_SETTINGS_KEY, () => new RemoteSettings());
      } catch (e) {
        Log.e(LogEvents.UNCAUGHT, `where=RemoteSettings.get ${Log.errKv(e as Object)}`);
      }
      RemoteSettings.inst = x !== undefined ? x : new RemoteSettings();
    }
    return RemoteSettings.inst;
  }

  /** A course server is configured (RemoteConfig.BASE_URL non-empty). */
  static serverEnabled(): boolean {
    try {
      return AppContainer.courses().serverEnabled();
    } catch (e) {
      return false;
    }
  }

  setOnlineVoice(on: boolean): void {
    this.onlineStudioVoice = on;
    RemoteSettings.apply();
  }

  /** App start + every toggle: push the setting into RemoteVoice. */
  static apply(): void {
    try {
      AppContainer.remoteVoice().setOnlineVoice(RemoteSettings.get().onlineStudioVoice);
    } catch (e) {
      Log.e(LogEvents.UNCAUGHT, `where=RemoteSettings.apply ${Log.errKv(e as Object)}`);
    }
  }
}

export enum RowAction { NONE = 'none', DOWNLOAD = 'download', UPDATE = 'update', DOWNLOADING = 'downloading' }

@ObservedV2
export class CourseItem {
  id: string = '';
  @Trace title: string = '';
  @Trace city: string = '';
  @Trace stops: number = 0;
  @Trace km: string = '';
  @Trace minutes: number = 0;
  @Trace langs: string = '';
  @Trace size: string = '';
  @Trace state: CourseState = CourseState.AVAILABLE;
  @Trace builtin: boolean = false;
  @Trace active: boolean = false;
  @Trace canDelete: boolean = false;
  @Trace canSelect: boolean = false;
  @Trace downloading: boolean = false;
  @Trace pct: number = 0;
  @Trace failed: boolean = false;
}

export enum CatalogNote { NONE = 'none', LOADING = 'loading', DISABLED = 'disabled', OFFLINE_CACHED = 'offlineCached',
  OFFLINE_EMPTY = 'offlineEmpty', UNVERIFIED = 'unverified' }

const CATALOG_TIMEOUT_MS: number = 15000;
const SWITCH_TIMEOUT_MS: number = 15000;
const DOWNLOAD_TIMEOUT_MS: number = 30 * 60000;

function uiLangOf(lang: Lang): string {
  return lang === Lang.PL ? 'pl' : lang === Lang.ZH ? 'zh' : 'en';
}

/** One instance for the app session, so a download keeps its row progress when the page is left and reopened. */
@ObservedV2
export class CoursesViewModel {
  private static inst: CoursesViewModel | undefined = undefined;

  static get(): CoursesViewModel {
    if (CoursesViewModel.inst === undefined) {
      CoursesViewModel.inst = new CoursesViewModel();
    }
    return CoursesViewModel.inst;
  }

  @Trace items: CourseItem[] = [];
  @Trace note: CatalogNote = CatalogNote.NONE;
  @Trace enabled: boolean = false;
  @Trace switchFailed: boolean = false;
  @Trace tourRunning: boolean = false;
  @Trace busySwitch: boolean = false;
  private bundled: CourseSummary = new CourseSummary();
  private lang: Lang = Lang.EN;
  private progress: Map<string, number> = new Map<string, number>();
  private failed: Set<string> = new Set<string>();
  private cancels: Map<string, CancelToken> = new Map<string, CancelToken>();

  /** Page shown: local rows at once, then the catalog from the server. */
  async open(lang: Lang): Promise<void> {
    this.lang = lang;
    try {
      const repo = AppContainer.courses();
      this.enabled = repo.serverEnabled();
      this.tourRunning = AppContainer.tourController().isRunning();
      await withTimeout(repo.init(), CATALOG_TIMEOUT_MS, undefined, 'courses.init');
      await this.buildBundled();
      this.rebuild();
      if (!this.enabled) {
        this.note = CatalogNote.DISABLED;
        return;
      }
      this.note = CatalogNote.LOADING;
      const fallback = new CatalogState();
      fallback.error = 'timeout';
      const st = await withTimeout(repo.refreshCatalog(), CATALOG_TIMEOUT_MS, fallback, 'courses.catalog');
      this.note = this.noteFor(st);
      this.rebuild();
    } catch (e) {
      Log.e(LogEvents.UNCAUGHT, `where=CoursesViewModel.open ${Log.errKv(e as Object)}`);
      this.note = CatalogNote.OFFLINE_EMPTY;
    }
  }

  retry(): void {
    this.open(this.lang);
  }

  private noteFor(st: CatalogState): CatalogNote {
    if (st.source === CatalogSource.SERVER) {
      return CatalogNote.NONE;
    }
    if (st.error === 'bad_signature' || st.error === 'no_public_key' || st.error.startsWith('envelope_') ||
      st.error.startsWith('catalog_')) {
      return st.source === CatalogSource.CACHE ? CatalogNote.OFFLINE_CACHED : CatalogNote.UNVERIFIED;
    }
    return st.source === CatalogSource.CACHE ? CatalogNote.OFFLINE_CACHED : CatalogNote.OFFLINE_EMPTY;
  }

  /** The bundled course's catalog-shaped summary, from the bundled pack itself. */
  private async buildBundled(): Promise<void> {
    const repo = AppContainer.courses();
    const pack = repo.bundledPack();
    const s = new CourseSummary();
    s.id = repo.bundledCourseId();
    s.version = await withTimeout(repo.bundledVersion(), 5000, '', 'courses.bundledVersion');
    const tour = findTour(pack, '');
    if (tour !== undefined) {
      s.title.en = localName(tour.titles, Lang.EN);
      s.title.pl = localName(tour.titles, Lang.PL);
      s.title.zh = localName(tour.titles, Lang.ZH);
      s.stops = tour.stops.length;
      s.minutes = tour.estMinutes;
      const m = listedMetres(pack, tour.stops.map((st) => st.poiId));
      s.km = m > 0 ? Math.round(m / 100) / 10 : 0;
    }
    s.city = 'Kraków';
    s.langs = ['en', 'pl', 'zh'];
    this.bundled = s;
  }

  private rebuild(): void {
    try {
      const repo = AppContainer.courses();
      const cat = repo.catalog().courses;
      const rows: CourseRow[] = mergeCourses(this.bundled, repo.installed(), cat, repo.activeId());
      const ui = uiLangOf(this.lang);
      const out: CourseItem[] = [];
      for (const r of rows) {
        const it = new CourseItem();
        it.id = r.summary.id;
        it.title = courseTitle(r.summary, ui);
        it.city = r.summary.city;
        it.stops = r.summary.stops;
        it.km = r.summary.km > 0 ? `${r.summary.km}` : '';
        it.minutes = r.summary.minutes;
        it.langs = r.summary.langs.map((l: string) => l === 'zh' ? '中文' : l.toUpperCase()).join(' · ');
        it.size = sizeLabel(r.summary.bytes);
        it.state = r.state;
        it.builtin = r.builtin;
        it.active = r.active;
        it.canDelete = r.canDelete;
        it.canSelect = r.canSelect;
        const p = this.progress.get(it.id);
        it.downloading = p !== undefined;
        it.pct = p !== undefined ? p : 0;
        it.failed = this.failed.has(it.id);
        out.push(it);
      }
      this.items = out;
    } catch (e) {
      Log.e(LogEvents.UNCAUGHT, `where=CoursesViewModel.rebuild ${Log.errKv(e as Object)}`);
    }
  }

  private item(id: string): CourseItem | undefined {
    return this.items.find((i: CourseItem) => i.id === id);
  }

  /** Download or update; progress shows on the row. */
  async download(id: string): Promise<void> {
    if (this.progress.has(id)) {
      return;
    }
    this.failed.delete(id);
    this.progress.set(id, 0);
    const cancel = new CancelToken();
    this.cancels.set(id, cancel);
    this.rebuild();
    const onProgress = (p: InstallProgress): void => {
      const pct = progressPct(p.doneBytes, p.totalBytes, p.doneFiles, p.totalFiles);
      this.progress.set(id, pct);
      const it = this.item(id);
      if (it !== undefined) {
        it.pct = pct;
      }
    };
    const timedOut = new OpResult();
    timedOut.error = 'timeout';
    let r: OpResult;
    try {
      r = await withTimeout(AppContainer.courses().download(id, cancel, onProgress), DOWNLOAD_TIMEOUT_MS, timedOut,
        'courses.download');
    } catch (e) {
      r = new OpResult();
      r.error = 'exception';
    }
    if (r.error === 'timeout') {
      cancel.cancelled = true;
    }
    this.progress.delete(id);
    this.cancels.delete(id);
    if (!r.ok) {
      this.failed.add(id);
      Log.w(LogEvents.COURSE, `event=ui_download_fail id=${id} reason=${r.error}`);
    }
    this.rebuild();
    if (r.ok && AppContainer.courses().activeId() === id) {
      notifyCourseChanged();   // an update of the active course: Home re-reads it
    }
  }

  async remove(id: string): Promise<void> {
    if (this.tourRunning && AppContainer.courses().activeId() === id) {
      return;
    }
    const wasActive = AppContainer.courses().activeId() === id;
    const r = await withTimeout(AppContainer.courses().remove(id), SWITCH_TIMEOUT_MS, new OpResult(), 'courses.remove');
    if (!r.ok) {
      Log.w(LogEvents.COURSE, `event=ui_delete_fail id=${id} reason=${r.error}`);
    }
    this.rebuild();
    if (wasActive) {
      notifyCourseChanged();
    }
  }

  /** Make a bundled or downloaded course the active one (not during a tour). */
  async select(id: string): Promise<void> {
    this.switchFailed = false;
    this.tourRunning = AppContainer.tourController().isRunning();
    if (this.tourRunning || this.busySwitch || AppContainer.courses().activeId() === id) {
      return;
    }
    this.busySwitch = true;
    try {
      const r = await withTimeout(AppContainer.courses().activate(id), SWITCH_TIMEOUT_MS, new OpResult(),
        'courses.activate');
      this.switchFailed = !r.ok;
      if (r.ok) {
        notifyCourseChanged();
      }
    } finally {
      this.busySwitch = false;
      this.rebuild();
    }
  }
}

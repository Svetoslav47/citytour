/*
 * CourseRepository (docs/SERVER.md §6): the downloaded courses (filesDir/courses/<id>/<version>/, CourseStore). The
 * app ships NO built-in course: until the first download there is no active course and Home shows "Download your
 * first walk". It owns:
 *   - the catalog: fetched from the server (signed, verified) and kept as the last good copy for offline use;
 *   - download / update / delete of courses, with progress and cancel;
 *   - the ACTIVE course ('' = none): which pack ActivePackRepository forwards to (Home, Tour detail, the tour itself)
 *     and which clip manifest NarrationPlayer loads (listeners). The first successful download becomes active.
 * The merge/state rules are the pure core/remote/CourseRules. Nothing here blocks the UI thread: all IO is async.
 * With BASE_URL '' (RemoteConfig) the network is never used; downloaded courses (if any) still work.
 */
import { PackLoadResult } from '../../contracts/Ports';
import { Log } from '../../app/Log';
import { LogEvents } from '../../app/LogEvents';
import { activeAfterInstall, InstalledCourse, resolveActive } from '../../core/remote/CourseRules';
import { CourseSummary } from '../../core/remote/ServerApi';
import { ActivePackRepository, PackChoice } from '../pack/ActivePackRepository';
import { FilePackRepository } from '../pack/FilePackRepository';
import { CancelToken, CourseRecord, CourseStore, InstallProgress } from './CourseStore';
import { RemoteClient } from './RemoteClient';

/** What the speech side needs to know about the active course. */
export class ActiveCourse {
  /** '' = no course installed. */
  id: string = '';
  /** Absolute course root ('' = no course). */
  root: string = '';
  /** Course-relative clip manifest path ('' = none). */
  audioManifestPath: string = '';
}

export type ActiveCourseListener = (c: ActiveCourse) => void;

export enum CatalogSource { NONE = 'none', SERVER = 'server', CACHE = 'cache' }

export class CatalogState {
  source: CatalogSource = CatalogSource.NONE;
  courses: CourseSummary[] | undefined = undefined;
  /** '' = fine; else why the server could not be used (offline, bad_signature, no_public_key, disabled ...). */
  error: string = '';
  fetchedAt: number = 0;
}

export class OpResult {
  ok: boolean = false;
  error: string = '';
}

export class CourseRepository {
  private readonly client: RemoteClient;
  private readonly store: CourseStore;
  private readonly pack: ActivePackRepository;
  private records: CourseRecord[] = [];
  private catalogState: CatalogState = new CatalogState();
  private listeners: ActiveCourseListener[] = [];
  private initP: Promise<void> | undefined = undefined;
  private busy: Set<string> = new Set<string>();

  constructor(client: RemoteClient, store: CourseStore, pack: ActivePackRepository) {
    this.client = client;
    this.store = store;
    this.pack = pack;
  }

  /**
   * Start-up (AppContainer.init): reads the installed courses and the active id, hands ActivePackRepository the
   * pack to load first (none when nothing is installed), and announces the active course once it has loaded.
   * Never rejects.
   */
  start(): void {
    let saved = '';
    const chosen: Promise<PackChoice | undefined> = this.init().then(async (): Promise<PackChoice | undefined> => {
      saved = await this.store.readActive();
      const id = resolveActive(saved, this.installed());
      const rec = this.record(id);
      if (rec === undefined) {
        return undefined;
      }
      return new PackChoice(new FilePackRepository(this.store.packPath(rec)), id);
    });
    this.pack.setStartupChoice(chosen);
    chosen.then(async () => {
      await this.pack.load();
      const now = this.pack.activeId();
      if (now !== saved) {
        await this.store.writeActive(now);   // the saved course is gone: another installed one, or none
      }
      this.announce();
    }).catch((e: Object) => {
      Log.e(LogEvents.COURSE, `event=start_fail ${Log.errKv(e)}`);
      this.announce();
    });
  }

  init(): Promise<void> {
    if (this.initP === undefined) {
      this.initP = this.doInit();
    }
    return this.initP;
  }

  private async doInit(): Promise<void> {
    try {
      await this.store.cleanTemp();
      this.records = await this.store.installed();
      const cached = await this.store.readCatalog();
      if (cached !== undefined && this.client.canVerify()) {
        const r = await this.client.acceptCatalog(cached);
        if (r.ok) {
          this.catalogState.source = CatalogSource.CACHE;
          this.catalogState.courses = r.courses;
        }
      }
      Log.i(LogEvents.COURSE, `event=init installed=${this.records.length}` +
        ` ids=${this.records.map((r: CourseRecord) => `${r.id}@${r.version}`).join(',') || 'none'}` +
        ` cachedCatalog=${this.catalogState.source === CatalogSource.CACHE}`);
    } catch (e) {
      Log.e(LogEvents.COURSE, `event=init_fail ${Log.errKv(e as Object)}`);
    }
  }

  serverEnabled(): boolean {
    return this.client.enabled();
  }

  installed(): InstalledCourse[] {
    return this.records.map((r: CourseRecord) => CourseStore.toInstalled(r));
  }

  catalog(): CatalogState {
    return this.catalogState;
  }

  activeId(): string {
    return this.pack.activeId();
  }

  hasCourse(): boolean {
    return this.pack.hasCourse();
  }

  isBusy(id: string): boolean {
    return this.busy.has(id);
  }

  addListener(l: ActiveCourseListener): void {
    this.listeners.push(l);
  }

  activeCourse(): ActiveCourse {
    const c = new ActiveCourse();
    c.id = this.pack.activeId();
    const rec = this.record(c.id);
    if (rec === undefined) {
      c.id = '';
      return c;
    }
    c.root = this.store.courseDir(rec.id, rec.version);
    c.audioManifestPath = rec.audioManifestPath;
    return c;
  }

  /** GET /v1/catalog; on success the envelope becomes the offline copy. On failure the cached copy stays. */
  async refreshCatalog(): Promise<CatalogState> {
    await this.init();
    if (!this.client.enabled()) {
      this.catalogState.error = 'disabled';
      return this.catalogState;
    }
    const r = await this.client.catalog();
    if (r.ok) {
      const s = new CatalogState();
      s.source = CatalogSource.SERVER;
      s.courses = r.courses;
      s.fetchedAt = Date.now();
      this.catalogState = s;
      await this.store.writeCatalog(r.text);
    } else {
      this.catalogState.error = r.error;
      Log.w(LogEvents.COURSE, `event=catalog_fail reason=${r.error} keep=${this.catalogState.source}`);
    }
    return this.catalogState;
  }

  /** Download (or update) a course from the catalog. Never rejects. */
  async download(id: string, cancel: CancelToken, onProgress: (p: InstallProgress) => void): Promise<OpResult> {
    const out = new OpResult();
    await this.init();
    if (this.busy.has(id)) {
      out.error = 'busy';
      return out;
    }
    const courses = this.catalogState.courses;
    const summary = courses === undefined ? undefined : courses.find((c: CourseSummary) => c.id === id);
    if (summary === undefined) {
      out.error = 'not_in_catalog';
      return out;
    }
    this.busy.add(id);
    try {
      const m = await this.client.manifest(id);
      if (!m.ok || m.manifest === undefined) {
        out.error = m.error;
        Log.w(LogEvents.COURSE, `event=manifest_fail id=${id} reason=${m.error}`);
        return out;
      }
      const res = await this.store.install(this.client, m.manifest, summary, cancel, onProgress);
      if (!res.ok || res.record === undefined) {
        out.error = res.error;
        return out;
      }
      const rec: CourseRecord = res.record;
      this.records = this.records.filter((r: CourseRecord) => r.id !== id);
      this.records.push(rec);
      // An update of the active course: switch to the new version now (the old folder is gone). The first course
      // downloaded becomes the active one.
      const before = this.pack.activeId();
      if (before === id || activeAfterInstall(before, id) === id) {
        const a = await this.activate(id);
        if (!a.ok) {
          out.error = `activate_${a.error}`;
          return out;
        }
      }
      out.ok = true;
      return out;
    } catch (e) {
      out.error = `exception ${Log.errKv(e as Object)}`;
      Log.e(LogEvents.COURSE, `event=download_fail id=${id} ${out.error}`);
      return out;
    } finally {
      this.busy.delete(id);
    }
  }

  /**
   * Deletes a downloaded course. When it was the active one, another installed course becomes active (CourseRules
   * resolveActive), or none: Home goes back to "Download your first walk".
   */
  async remove(id: string): Promise<OpResult> {
    const out = new OpResult();
    await this.init();
    if (this.record(id) === undefined || this.busy.has(id)) {
      out.error = this.busy.has(id) ? 'busy' : 'not_installed';
      return out;
    }
    const wasActive = this.pack.activeId() === id;
    this.records = this.records.filter((r: CourseRecord) => r.id !== id);
    if (wasActive) {
      const next = resolveActive('', this.installed());
      const rec = this.record(next);
      let switched = false;
      if (rec !== undefined) {
        switched = (await this.pack.switchTo(new FilePackRepository(this.store.packPath(rec)), next)).ok;
      }
      if (!switched) {
        await this.pack.switchToNone();
      }
      await this.store.writeActive(this.pack.activeId());
      this.announce();
    }
    out.ok = await this.store.remove(id);
    if (!out.ok) {
      out.error = 'remove_failed';
    }
    return out;
  }

  /** Makes a downloaded course the active one. Never rejects. */
  async activate(id: string): Promise<OpResult> {
    const out = new OpResult();
    await this.init();
    const rec = this.record(id);
    if (rec === undefined) {
      out.error = 'not_installed';
      return out;
    }
    const r: PackLoadResult = await this.pack.switchTo(new FilePackRepository(this.store.packPath(rec)), id);
    if (!r.ok) {
      out.error = 'load_failed';
      return out;
    }
    await this.store.writeActive(id);
    this.announce();
    out.ok = true;
    return out;
  }

  private record(id: string): CourseRecord | undefined {
    return this.records.find((r: CourseRecord) => r.id === id);
  }

  private announce(): void {
    const c = this.activeCourse();
    Log.i(LogEvents.COURSE, `event=active_course id=${c.id || 'none'}` +
      ` clips=${c.audioManifestPath !== '' ? c.audioManifestPath : 'none'}`);
    for (const l of this.listeners) {
      try {
        l(c);
      } catch (e) {
        Log.e(LogEvents.UNCAUGHT, `where=CourseRepository.announce ${Log.errKv(e as Object)}`);
      }
    }
  }
}

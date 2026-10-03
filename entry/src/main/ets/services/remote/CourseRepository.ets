/*
 * CourseRepository (docs/SERVER.md §6): the bundled course (rawfile, always present, never deletable) merged with
 * the downloaded ones (filesDir/courses/<id>/<version>/, CourseStore). It owns:
 *   - the catalog: fetched from the server (signed, verified) and kept as the last good copy for offline use;
 *   - download / update / delete of courses, with progress;
 *   - the ACTIVE course: which pack ActivePackRepository forwards to (Home, Tour detail, the tour itself) and which
 *     clip manifest NarrationPlayer loads (listeners).
 * The merge/state rules are the pure core/remote/CourseRules. Nothing here blocks the UI thread: all IO is async.
 * With BASE_URL '' (RemoteConfig) the network is never used; downloaded courses (if any) still work.
 */
import { PackLoadResult, PackRepository } from '../../contracts/Ports';
import { Log } from '../../app/Log';
import { LogEvents } from '../../app/LogEvents';
import { InstalledCourse, resolveActive } from '../../core/remote/CourseRules';
import { bundledCourseVersion, CourseSummary } from '../../core/remote/ServerApi';
import { CLIP_MANIFEST_RAWFILE } from '../../core/speech/ClipSelection';
import { application } from '@kit.AbilityKit';
import { FileStore } from './FileStore';
import { ActivePackRepository } from '../pack/ActivePackRepository';
import { FilePackRepository } from '../pack/FilePackRepository';
import { CancelToken, CourseRecord, CourseStore, InstallProgress } from './CourseStore';
import { RemoteClient } from './RemoteClient';

/** What the speech side needs to know about the active course. */
export class ActiveCourse {
  id: string = '';
  bundled: boolean = true;
  /** Absolute course root ('' for the bundled course). */
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
  private readonly bundledId: string;
  private records: CourseRecord[] = [];
  private catalogState: CatalogState = new CatalogState();
  private listeners: ActiveCourseListener[] = [];
  private initP: Promise<void> | undefined = undefined;
  private busy: Set<string> = new Set<string>();
  private bundledVersionP: Promise<string> | undefined = undefined;

  constructor(client: RemoteClient, store: CourseStore, pack: ActivePackRepository, bundledId: string) {
    this.client = client;
    this.store = store;
    this.pack = pack;
    this.bundledId = bundledId;
  }

  /**
   * Start-up (AppContainer.init): reads the installed courses and the active id, hands ActivePackRepository the
   * pack to load first, and announces the active course once the pack has loaded. Never rejects.
   */
  start(): void {
    let startId = this.bundledId;
    let saved = '';
    const chosen: Promise<PackRepository | undefined> = this.init().then(async (): Promise<PackRepository | undefined> => {
      saved = await this.store.readActive();
      const id = resolveActive(saved, this.bundledId, this.installed());
      const rec = this.record(id);
      if (rec === undefined) {
        return undefined;
      }
      startId = id;
      return new FilePackRepository(this.store.packPath(rec));
    });
    this.pack.setStartupChoice(chosen, () => startId);
    chosen.then(async () => {
      await this.pack.load();
      const now = this.pack.activeId() === this.bundledId && this.record(this.bundledId) === undefined ? '' :
        this.pack.activeId();
      if (now !== saved) {
        await this.store.writeActive(now);   // the saved course is gone or failed to load: bundled from now on
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

  bundledCourseId(): string {
    return this.bundledId;
  }

  /**
   * The bundled course's version as the catalog writes it (SERVER.md §3.1: `<pack version>-a<sha8 of
   * audio/manifest.json>`), so an unchanged server course is not shown as an update. Async digest, never rejects.
   */
  bundledVersion(): Promise<string> {
    if (this.bundledVersionP === undefined) {
      this.bundledVersionP = this.computeBundledVersion();
    }
    return this.bundledVersionP;
  }

  private async computeBundledVersion(): Promise<string> {
    let packVersion = '';
    try {
      const r = await this.pack.bundledRepo().load();
      packVersion = r.manifest !== undefined ? r.manifest.version : '';
      const bytes = await application.getApplicationContext().resourceManager.getRawFileContent(CLIP_MANIFEST_RAWFILE);
      const sha = await FileStore.sha256Bytes(bytes);
      const v = bundledCourseVersion(packVersion, sha);
      Log.i(LogEvents.COURSE, `event=bundled_version version=${v}`);
      return v;
    } catch (e) {
      Log.w(LogEvents.COURSE, `event=bundled_version_fail ${Log.errKv(e as Object)}`);
      return packVersion;
    }
  }

  bundledPack(): PackRepository {
    return this.pack.bundledRepo();
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
    if (rec === undefined || this.pack.isBundled()) {
      c.bundled = true;
      return c;
    }
    c.bundled = false;
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
      // An update of the active course: switch to the new version now (the old folder is gone).
      if (this.pack.activeId() === id) {
        await this.activate(id);
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

  /** Deletes a downloaded course (the bundled one cannot be deleted). The active one falls back to bundled. */
  async remove(id: string): Promise<OpResult> {
    const out = new OpResult();
    await this.init();
    if (this.record(id) === undefined || this.busy.has(id)) {
      out.error = this.busy.has(id) ? 'busy' : 'not_installed';
      return out;
    }
    if (this.pack.activeId() === id) {
      const r = await this.pack.switchToBundled();
      if (!r.ok) {
        out.error = 'bundled_load_failed';
        return out;
      }
      await this.store.writeActive('');
      this.announce();
    }
    this.records = this.records.filter((r: CourseRecord) => r.id !== id);
    out.ok = await this.store.remove(id);
    if (!out.ok) {
      out.error = 'remove_failed';
    }
    return out;
  }

  /** Makes a course active (bundled id or a downloaded one). Never rejects. */
  async activate(id: string): Promise<OpResult> {
    const out = new OpResult();
    await this.init();
    let r: PackLoadResult;
    if (id === this.bundledId && (this.record(id) === undefined)) {
      r = await this.pack.switchToBundled();
    } else {
      const rec = this.record(id);
      if (rec === undefined) {
        out.error = 'not_installed';
        return out;
      }
      r = await this.pack.switchTo(new FilePackRepository(this.store.packPath(rec)), id);
    }
    if (!r.ok) {
      out.error = 'load_failed';
      return out;
    }
    await this.store.writeActive(id === this.bundledId && this.record(id) === undefined ? '' : id);
    this.announce();
    out.ok = true;
    return out;
  }

  private record(id: string): CourseRecord | undefined {
    return this.records.find((r: CourseRecord) => r.id === id);
  }

  private announce(): void {
    const c = this.activeCourse();
    Log.i(LogEvents.COURSE, `event=active_course id=${c.id} bundled=${c.bundled}` +
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

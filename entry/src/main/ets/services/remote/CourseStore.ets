/*
 * Downloaded courses on disk (docs/SERVER.md §3 "A course is installed to a temp folder, then swapped in atomically",
 * §6). Layout under the app's filesDir:
 *   courses/<id>/<version>/            one installed course (the files of its signed manifest, by their paths)
 *   courses/<id>/<version>/course.json what the app needs without the network: summary, pack folder, clip manifest
 *   courses/.tmp/<id>-<version>-<ms>/  a download in progress (deleted on failure and at start-up)
 *   courses/catalog.json               the last catalog envelope that verified (offline Courses screen)
 *   courses/active.json                {"id": "..."} the active course ('' or missing = the bundled one)
 * Install: every file is fetched by its sha256 (GET /v1/blobs/:sha), its size and SHA-256 are checked (async, off
 * the UI thread), it is written into the temp folder; only when ALL files verified is the temp folder renamed to
 * courses/<id>/<version> (one rename), and only then are older versions of that course removed. A failed, cancelled
 * or partial download never touches a working course.
 */
import { Log } from '../../app/Log';
import { LogEvents } from '../../app/LogEvents';
import { InstalledCourse } from '../../core/remote/CourseRules';
import {
  CourseFile, CourseManifest, CourseSummary, DEFAULT_AUDIO_MANIFEST, manifestBytes, packDir, safeRelPath, validId,
  validVersion
} from '../../core/remote/ServerApi';
import { FileStore } from './FileStore';
import { RemoteClient } from './RemoteClient';

const PARALLEL: number = 3;
const BLOB_RETRIES: number = 1;

/** courses/<id>/<version>/course.json */
export class CourseRecord {
  id: string = '';
  version: string = '';
  installedAt: number = 0;
  packDir: string = '';                       // '' or 'pack/' ... (ends in '/')
  audioManifestPath: string = DEFAULT_AUDIO_MANIFEST;
  summary: CourseSummary = new CourseSummary();
}

export class InstallProgress {
  doneBytes: number = 0;
  totalBytes: number = 0;
  doneFiles: number = 0;
  totalFiles: number = 0;
}

export class InstallResult {
  ok: boolean = false;
  error: string = '';
  record: CourseRecord | undefined = undefined;
}

export class CancelToken {
  cancelled: boolean = false;
}

function str(r: Record<string, Object>, k: string): string {
  const v: Object | undefined = r[k];
  return typeof v === 'string' ? v as string : '';
}

/** Rebuilds a CourseSummary from JSON written by this app (plain field copy, validated). */
function summaryFrom(v: Object | undefined): CourseSummary {
  const s = new CourseSummary();
  if (v === undefined || v === null || typeof v !== 'object') {
    return s;
  }
  const r = v as Record<string, Object>;
  s.id = str(r, 'id');
  s.version = str(r, 'version');
  s.city = str(r, 'city');
  const t: Object | undefined = r['title'];
  if (t !== undefined && t !== null && typeof t === 'object') {
    const tr = t as Record<string, Object>;
    s.title.en = str(tr, 'en');
    s.title.pl = str(tr, 'pl');
    s.title.zh = str(tr, 'zh');
  }
  s.stops = typeof r['stops'] === 'number' ? r['stops'] as number : 0;
  s.km = typeof r['km'] === 'number' ? r['km'] as number : 0;
  s.minutes = typeof r['minutes'] === 'number' ? r['minutes'] as number : 0;
  s.bytes = typeof r['bytes'] === 'number' ? r['bytes'] as number : 0;
  const langs: Object | undefined = r['langs'];
  if (Array.isArray(langs)) {
    for (const l of langs as Object[]) {
      if (typeof l === 'string') {
        s.langs.push(l as string);
      }
    }
  }
  return s;
}

export class CourseStore {
  private readonly dirOf: () => string;

  constructor(dirOf: () => string) {
    this.dirOf = dirOf;
  }

  root(): string {
    const d = this.dirOf();
    return d === '' ? '' : `${d}/courses`;
  }

  courseDir(id: string, version: string): string {
    return `${this.root()}/${id}/${version}`;
  }

  /** Removes leftovers of interrupted downloads. */
  async cleanTemp(): Promise<void> {
    if (this.root() === '') {
      return;
    }
    await FileStore.remove(`${this.root()}/.tmp`);
  }

  /** Installed courses (one version per id: the newest record wins, the others are removed). */
  async installed(): Promise<CourseRecord[]> {
    const root = this.root();
    if (root === '') {
      return [];
    }
    const out: CourseRecord[] = [];
    for (const id of await FileStore.list(root)) {
      if (!validId(id)) {
        continue;
      }
      let best: CourseRecord | undefined = undefined;
      const stale: string[] = [];
      for (const version of await FileStore.list(`${root}/${id}`)) {
        if (!validVersion(version)) {
          continue;
        }
        const rec = await this.readRecord(id, version);
        if (rec === undefined) {
          stale.push(version);   // a folder without a valid course.json is not a complete install
          continue;
        }
        if (best === undefined || rec.installedAt > best.installedAt) {
          if (best !== undefined) {
            stale.push(best.version);
          }
          best = rec;
        } else {
          stale.push(version);
        }
      }
      for (const v of stale) {
        Log.w(LogEvents.COURSE, `event=prune id=${id} version=${v}`);
        await FileStore.remove(`${root}/${id}/${v}`);
      }
      if (best !== undefined) {
        out.push(best);
      }
    }
    return out;
  }

  private async readRecord(id: string, version: string): Promise<CourseRecord | undefined> {
    const text = await FileStore.readText(`${this.courseDir(id, version)}/course.json`);
    if (text === undefined) {
      return undefined;
    }
    try {
      const r = JSON.parse(text) as Record<string, Object>;
      const rec = new CourseRecord();
      rec.id = str(r, 'id');
      rec.version = str(r, 'version');
      rec.installedAt = typeof r['installedAt'] === 'number' ? r['installedAt'] as number : 0;
      rec.packDir = str(r, 'packDir');
      rec.audioManifestPath = str(r, 'audioManifestPath');
      rec.summary = summaryFrom(r['summary']);
      if (rec.id !== id || rec.version !== version || (rec.packDir !== '' && !safeRelPath(rec.packDir + 'x')) ||
        (rec.audioManifestPath !== '' && !safeRelPath(rec.audioManifestPath))) {
        return undefined;
      }
      if (rec.summary.id === '') {
        rec.summary.id = id;
        rec.summary.version = version;
        rec.summary.title.en = id;
      }
      return rec;
    } catch (e) {
      return undefined;
    }
  }

  static toInstalled(r: CourseRecord): InstalledCourse {
    const i = new InstalledCourse();
    i.id = r.id;
    i.version = r.version;
    i.summary = r.summary;
    return i;
  }

  /** Absolute folder of the pack of an installed course. */
  packPath(r: CourseRecord): string {
    const d = this.courseDir(r.id, r.version);
    return r.packDir === '' ? d : `${d}/${r.packDir.substring(0, r.packDir.length - 1)}`;
  }

  // ---------- catalog + active course ----------

  async readCatalog(): Promise<string | undefined> {
    return this.root() === '' ? undefined : FileStore.readText(`${this.root()}/catalog.json`);
  }

  async writeCatalog(text: string): Promise<void> {
    if (this.root() !== '') {
      await FileStore.writeText(`${this.root()}/catalog.json`, text);
    }
  }

  async readActive(): Promise<string> {
    if (this.root() === '') {
      return '';
    }
    const t = await FileStore.readText(`${this.root()}/active.json`);
    if (t === undefined) {
      return '';
    }
    try {
      const id = str(JSON.parse(t) as Record<string, Object>, 'id');
      return validId(id) ? id : '';
    } catch (e) {
      return '';
    }
  }

  async writeActive(id: string): Promise<void> {
    if (this.root() !== '') {
      const o: Record<string, string> = { 'id': id };
      await FileStore.writeText(`${this.root()}/active.json`, JSON.stringify(o));
    }
  }

  // ---------- install / delete ----------

  async remove(id: string): Promise<boolean> {
    if (!validId(id) || this.root() === '') {
      return false;
    }
    const ok = await FileStore.remove(`${this.root()}/${id}`);
    Log.i(LogEvents.COURSE, `event=delete id=${id} ok=${ok}`);
    return ok;
  }

  /**
   * Downloads and verifies every file of `m` into a temp folder, then swaps it in with one rename.
   * `summary` is the catalog row (stored for the offline list). Never rejects.
   */
  async install(client: RemoteClient, m: CourseManifest, summary: CourseSummary, cancel: CancelToken,
    onProgress: (p: InstallProgress) => void): Promise<InstallResult> {
    const res = new InstallResult();
    const root = this.root();
    if (root === '') {
      res.error = 'no_context';
      return res;
    }
    const t0 = Date.now();
    const tmp = `${root}/.tmp/${m.courseId}-${m.version}-${Date.now()}`;
    if (!(await FileStore.mkdirs(tmp))) {
      res.error = 'mkdir';
      return res;
    }
    const prog = new InstallProgress();
    prog.totalBytes = manifestBytes(m);
    prog.totalFiles = m.files.length;
    onProgress(prog);
    Log.i(LogEvents.COURSE, `event=download_start id=${m.courseId} version=${m.version} files=${m.files.length}` +
      ` bytes=${prog.totalBytes}`);
    let failure = '';
    let next = 0;
    const worker = async (): Promise<void> => {
      while (failure === '' && !cancel.cancelled) {
        const i = next++;
        if (i >= m.files.length) {
          return;
        }
        const f = m.files[i];
        const err = await this.fetchVerified(client, f, `${tmp}/${f.path}`);
        if (err !== '') {
          failure = `${err} file=${f.path}`;
          return;
        }
        prog.doneBytes += f.bytes;
        prog.doneFiles++;
        try {
          onProgress(prog);
        } catch (e) {
          // progress listener errors never abort the download
        }
      }
    };
    const workers: Promise<void>[] = [];
    for (let k = 0; k < PARALLEL; k++) {
      workers.push(worker());
    }
    await Promise.all(workers);
    if (cancel.cancelled && failure === '') {
      failure = 'cancelled';
    }
    if (failure === '') {
      const rec = new CourseRecord();
      rec.id = m.courseId;
      rec.version = m.version;
      rec.installedAt = Date.now();
      rec.packDir = packDir(m);
      rec.audioManifestPath = m.files.some((f: CourseFile) => f.path === m.audioManifestPath) ? m.audioManifestPath : '';
      rec.summary = summary;
      if (!(await FileStore.writeText(`${tmp}/course.json`, JSON.stringify(rec)))) {
        failure = 'write_record';
      } else {
        const dest = this.courseDir(m.courseId, m.version);
        await FileStore.remove(dest);   // a broken earlier copy of this exact version
        if (!(await FileStore.mkdirs(`${root}/${m.courseId}`)) || !(await FileStore.rename(tmp, dest))) {
          failure = 'rename';
        } else {
          for (const v of await FileStore.list(`${root}/${m.courseId}`)) {
            if (v !== m.version) {
              await FileStore.remove(`${root}/${m.courseId}/${v}`);
            }
          }
          res.ok = true;
          res.record = rec;
        }
      }
    }
    if (!res.ok) {
      await FileStore.remove(tmp);
      res.error = failure;
      Log.e(LogEvents.COURSE, `event=download_fail id=${m.courseId} version=${m.version} reason=${failure}` +
        ` ms=${Date.now() - t0}`);
    } else {
      Log.i(LogEvents.COURSE, `event=installed id=${m.courseId} version=${m.version} files=${m.files.length}` +
        ` bytes=${prog.totalBytes} ms=${Date.now() - t0}`);
    }
    return res;
  }

  /** '' when the file is on disk with the right size and SHA-256. */
  private async fetchVerified(client: RemoteClient, f: CourseFile, dest: string): Promise<string> {
    let last = '';
    for (let attempt = 0; attempt <= BLOB_RETRIES; attempt++) {
      const h = await client.blob(f.sha256);
      if (h.status !== 200 || h.bytes === undefined) {
        last = h.status === 0 ? 'offline' : `http_${h.status}`;
        if (h.status === 404) {
          return last;
        }
        continue;
      }
      if (h.bytes.byteLength !== f.bytes) {
        last = `size expected=${f.bytes} got=${h.bytes.byteLength}`;
        continue;
      }
      const sha = await FileStore.sha256Bytes(new Uint8Array(h.bytes));
      if (sha !== f.sha256) {
        last = 'sha256_mismatch';
        continue;
      }
      if (!(await FileStore.writeBytes(dest, h.bytes))) {
        return 'write';
      }
      return '';
    }
    return last;
  }
}

/*
 * Course list rules (docs/SERVER.md §6 "CourseRepository" and "Courses screen"). Pure: no @kit imports, unit-tested
 * in entry/src/test/CourseRules.test.ets.
 *
 * - The bundled course (rawfile) is always present, always first, and can never be deleted.
 * - A downloaded course is listed even when the catalog is unavailable (offline) or no longer lists it.
 * - A catalog version different from the installed one (or, for the bundled course id, from the bundled pack) is
 *   an update. A downloaded copy of the bundled course id (an update of it) can be deleted, which returns to the
 *   bundled version.
 * - The active course falls back to the bundled course whenever its download is missing (deleted, broken).
 */
import { CourseSummary } from './ServerApi';

export enum CourseState {
  BUILTIN = 'builtin',         // the bundled course, nothing newer on the server
  AVAILABLE = 'available',     // on the server, not downloaded: "Download"
  DOWNLOADED = 'downloaded',   // installed and current (or the server is unknown): "Downloaded ✓"
  UPDATE = 'update'            // installed (or bundled) but the server has another version: "Update"
}

export class InstalledCourse {
  id: string = '';
  version: string = '';
  summary: CourseSummary = new CourseSummary();
}

export class CourseRow {
  summary: CourseSummary = new CourseSummary();   // what the row shows (catalog when known, else the local copy)
  state: CourseState = CourseState.AVAILABLE;
  builtin: boolean = false;
  installedVersion: string = '';                  // '' = not downloaded
  canDelete: boolean = false;
  canSelect: boolean = false;                     // bundled or downloaded: can be the active course
  active: boolean = false;
}

function find(list: CourseSummary[] | undefined, id: string): CourseSummary | undefined {
  if (list === undefined) {
    return undefined;
  }
  return list.find((c: CourseSummary) => c.id === id);
}

function findInstalled(list: InstalledCourse[], id: string): InstalledCourse | undefined {
  return list.find((c: InstalledCourse) => c.id === id);
}

/** The id the app should use as its active course. */
export function resolveActive(activeId: string, bundledId: string, installed: InstalledCourse[]): string {
  if (activeId === '' || activeId === bundledId) {
    return bundledId;
  }
  return findInstalled(installed, activeId) !== undefined ? activeId : bundledId;
}

/**
 * The Courses screen rows. `catalog` undefined = the server was never reached and nothing is cached (offline,
 * disabled): only local courses are listed.
 */
export function mergeCourses(bundled: CourseSummary, installed: InstalledCourse[], catalog: CourseSummary[] | undefined,
  activeId: string): CourseRow[] {
  const active = resolveActive(activeId, bundled.id, installed);
  const rows: CourseRow[] = [];

  // 1. The bundled course (always).
  const b = new CourseRow();
  b.builtin = true;
  b.canSelect = true;
  const bInst = findInstalled(installed, bundled.id);
  const bCat = find(catalog, bundled.id);
  b.summary = bCat !== undefined ? bCat : (bInst !== undefined ? bInst.summary : bundled);
  if (bInst !== undefined) {
    b.installedVersion = bInst.version;
    b.canDelete = true;   // deletes the downloaded update only
    b.state = bCat !== undefined && bCat.version !== bInst.version ? CourseState.UPDATE : CourseState.DOWNLOADED;
  } else {
    b.state = bCat !== undefined && bCat.version !== bundled.version ? CourseState.UPDATE : CourseState.BUILTIN;
  }
  b.active = active === bundled.id;
  rows.push(b);

  // 2. Downloaded courses, in catalog order first, then the ones the catalog does not list.
  const done = new Set<string>([bundled.id]);
  const ordered: string[] = [];
  if (catalog !== undefined) {
    for (const c of catalog) {
      if (!done.has(c.id)) {
        ordered.push(c.id);
        done.add(c.id);
      }
    }
  }
  for (const i of installed) {
    if (!done.has(i.id)) {
      ordered.push(i.id);
      done.add(i.id);
    }
  }
  for (const id of ordered) {
    const inst = findInstalled(installed, id);
    const cat = find(catalog, id);
    const r = new CourseRow();
    if (inst !== undefined) {
      r.summary = cat !== undefined ? cat : inst.summary;
      r.installedVersion = inst.version;
      r.canDelete = true;
      r.canSelect = true;
      r.state = cat !== undefined && cat.version !== inst.version ? CourseState.UPDATE : CourseState.DOWNLOADED;
      r.active = active === id;
    } else if (cat !== undefined) {
      r.summary = cat;
      r.state = CourseState.AVAILABLE;
    } else {
      continue;
    }
    rows.push(r);
  }
  return rows;
}

/** The installed list after a successful download (replaces an older version of the same course). */
export function afterInstall(installed: InstalledCourse[], c: InstalledCourse): InstalledCourse[] {
  const out = installed.filter((i: InstalledCourse) => i.id !== c.id);
  out.push(c);
  return out;
}

/** The installed list after a delete; the active course after it (bundled when the active one was deleted). */
export class DeleteResult {
  installed: InstalledCourse[] = [];
  activeId: string = '';
  allowed: boolean = true;
}

export function afterDelete(installed: InstalledCourse[], id: string, activeId: string, bundledId: string): DeleteResult {
  const r = new DeleteResult();
  if (findInstalled(installed, id) === undefined) {
    r.allowed = false;   // the bundled course itself (or an unknown id) is never deleted
    r.installed = installed;
    r.activeId = resolveActive(activeId, bundledId, installed);
    return r;
  }
  r.installed = installed.filter((i: InstalledCourse) => i.id !== id);
  r.activeId = resolveActive(activeId === id ? bundledId : activeId, bundledId, r.installed);
  return r;
}

/** Title in the UI language, falling back to English, then any title, then the id. */
export function courseTitle(c: CourseSummary, uiLang: string): string {
  const t = uiLang === 'pl' ? c.title.pl : uiLang === 'zh' ? c.title.zh : c.title.en;
  if (t !== '') {
    return t;
  }
  return c.title.en !== '' ? c.title.en : c.title.pl !== '' ? c.title.pl : c.title.zh !== '' ? c.title.zh : c.id;
}

/** "12.3 MB" / "850 KB" for the Download button. */
export function sizeLabel(bytes: number): string {
  if (!Number.isFinite(bytes) || bytes <= 0) {
    return '';
  }
  if (bytes >= 1024 * 1024) {
    return `${(Math.round(bytes / (1024 * 1024) * 10) / 10).toFixed(1)} MB`;
  }
  return `${Math.max(1, Math.round(bytes / 1024))} KB`;
}

/** Download progress 0..100 from bytes done / total (files count as a fallback when sizes are 0). */
export function progressPct(doneBytes: number, totalBytes: number, doneFiles: number, totalFiles: number): number {
  if (totalBytes > 0) {
    return Math.max(0, Math.min(100, Math.floor(doneBytes * 100 / totalBytes)));
  }
  if (totalFiles > 0) {
    return Math.max(0, Math.min(100, Math.floor(doneFiles * 100 / totalFiles)));
  }
  return 0;
}

// Course publishing (docs/SERVER.md §3, §4 "No free-text TTS", §5). Runs on the maintainer's machine only; it is
// the only code that touches the private key. See cli/publish-course.ts for the command line.
import { existsSync } from 'node:fs';
import { mkdir, readdir, readFile, stat } from 'node:fs/promises';
import { join, relative, sep } from 'node:path';
import { pathToFileURL } from 'node:url';
import type { KeyObject } from 'node:crypto';
import { Envelope, sha256Hex, signPayload } from './canonical.js';
import { COURSE_ID_RE, TtsIndex, writeFileAtomic } from './store.js';

export interface FileEntry {
  path: string;
  sha256: string;
  bytes: number;
}

export interface CourseManifest {
  schemaVersion: 1;
  courseId: string;
  version: string;
  publishedAt: string;
  packId: string;
  files: FileEntry[];
  audio: { manifestPath: string; clips: number };
  allowedTtsSha: string;
}

export interface CourseSummary {
  id: string;
  version: string;
  title: { en: string; pl: string; zh: string };
  city: string;
  stops: number;
  km: number;
  minutes: number;
  langs: string[];
  bytes: number;
  coverBlob?: string;     // sha256 of the pack's cover.jpg (served by /v1/blobs/:sha256), absent without a cover
  coverCredit?: string;   // "<author>, <licence>" from the pack's cover.json (shown on the photo before download)
}

export interface Catalog {
  courses: CourseSummary[];
}

export interface PublishOptions {
  courseId: string;
  packDir: string;
  audioDir: string;          // the course audio dir, data/course/<id>/audio (contains manifest.json and <lang>/... clips)
  dataDir: string;
  seedDir?: string;
  privateKey: KeyObject;
  systemLinesPath: string;   // scripts/voice/system-lines.mjs
  city: string;
  publishedAt?: string;
  log?: (s: string) => void;
}

export interface PublishResult {
  manifest: CourseManifest;
  summary: CourseSummary;
  allowedCount: number;
  allowedBreakdown: { narration: number; system: number; numeric: number };
  clipsNotAllowed: number;
  blobsWritten: number;
  shippedIndexed: number;
}

// The subset of scripts/voice/system-lines.mjs used here (plain JS module, imported at runtime).
interface SystemLinesModule {
  loadPack(packDir: string, tourId: string): unknown;
  enumerateCases(pack: unknown, opts: Record<string, unknown>): unknown[];
  numericCases(names: Record<string, string[]>, opts?: Record<string, unknown>): unknown[];
  stopNames(pack: unknown): Record<string, string[]>;
  linesFromCases(cases: unknown[]): { lang: string; text: string; textSha256: string }[];
}

interface AudioClip {
  lang: string;
  file: string;
  textSha256: string;
  chars: number;
  bytes: number;
  renderedAt?: string;
}

interface Tour {
  id: string;
  titles?: Record<string, string>;
  stops: { poiId: string }[];
  estMinutes?: number;
}

const AUDIO_FILE_RE = /^audio\/[A-Za-z0-9_.-]+(\/[A-Za-z0-9_.-]+)*$/;

async function readJson<T>(p: string): Promise<T> {
  return JSON.parse(await readFile(p, 'utf8')) as T;
}

async function walk(dir: string): Promise<string[]> {
  const out: string[] = [];
  for (const e of await readdir(dir, { withFileTypes: true })) {
    if (e.name.startsWith('.')) {
      continue;
    }
    const p = join(dir, e.name);
    if (e.isDirectory()) {
      out.push(...(await walk(p)));
    } else if (e.isFile()) {
      out.push(p);
    }
  }
  return out;
}

/** Stores a file as blobs/<sha256> and re-reads the blob to verify it. */
async function putVerified(blobsDir: string, data: Buffer, sha: string): Promise<boolean> {
  const p = join(blobsDir, sha);
  let wrote = false;
  if (!existsSync(p)) {
    await writeFileAtomic(p, data);
    wrote = true;
  }
  if (sha256Hex(await readFile(p)) !== sha) {
    throw new Error(`blob ${sha} failed verification after write`);
  }
  return wrote;
}

/**
 * Course version (docs/SERVER.md §3.1): `<pack version>-a<8 hex of sha256(audio/manifest.json)>`, plus
 * `-c<8 hex>` when the pack has a cover photo, so adding or changing the cover is an update for installed apps.
 */
export function courseVersion(packVersion: string, audioSha: string, coverTag?: string): string {
  return `${packVersion}-a${audioSha.slice(0, 8)}${coverTag ? `-c${coverTag}` : ''}`;
}

export interface CoverInfo {
  sha: string;          // sha256 of cover.jpg
  credit: string;       // "<author>, <licence>"
  versionTag: string;   // 8 hex of sha256(cover.jpg sha + cover.json sha)
}

/** The pack's cover photo, or undefined when it has none. Throws when only one of the two files is there. */
export async function readCover(packDir: string): Promise<CoverInfo | undefined> {
  const jpg = join(packDir, 'cover.jpg');
  const json = join(packDir, 'cover.json');
  if (!existsSync(jpg) && !existsSync(json)) {
    return undefined;
  }
  if (!existsSync(jpg) || !existsSync(json)) {
    throw new Error(`${packDir}: a cover needs both cover.jpg and cover.json`);
  }
  const jsonBytes = await readFile(json);
  const meta = JSON.parse(jsonBytes.toString('utf8')) as { author?: unknown; license?: unknown };
  const author = typeof meta.author === 'string' ? meta.author.trim() : '';
  const license = typeof meta.license === 'string' ? meta.license.trim() : '';
  if (author === '' || license === '') {
    throw new Error(`${packDir}/cover.json: author and license are required`);
  }
  const sha = sha256Hex(await readFile(jpg));
  return {
    sha,
    credit: `${author}, ${license}`,
    versionTag: sha256Hex(Buffer.from(`${sha}:${sha256Hex(jsonBytes)}`, 'utf8')).slice(0, 8)
  };
}

export function bucketKm(m: number): number {
  return Math.round(m / 100) / 10;
}

export async function publishCourse(o: PublishOptions): Promise<PublishResult> {
  const log = o.log ?? (() => undefined);
  if (!COURSE_ID_RE.test(o.courseId)) {
    throw new Error(`bad course id ${o.courseId}`);
  }
  const blobsDir = join(o.dataDir, 'blobs');
  await mkdir(blobsDir, { recursive: true });
  await mkdir(join(o.dataDir, 'courses', o.courseId), { recursive: true });

  // ---- pack files
  const packManifest = await readJson<{ packId: string; version: string; files?: FileEntry[] }>(
    join(o.packDir, 'manifest.json'));
  const packId = packManifest.packId;
  if (!/^[a-z0-9-]{1,64}$/.test(packId)) {
    throw new Error(`bad packId ${packId}`);
  }
  const expected = new Map((packManifest.files ?? []).map((f) => [f.path, f.sha256]));
  const files: FileEntry[] = [];
  let blobsWritten = 0;
  for (const abs of (await walk(o.packDir)).sort()) {
    const rel = relative(o.packDir, abs).split(sep).join('/');
    const data = await readFile(abs);
    const sha = sha256Hex(data);
    const want = expected.get(rel);
    if (want !== undefined && want !== sha) {
      throw new Error(`pack file ${rel}: sha256 ${sha} != pack manifest ${want}`);
    }
    if (await putVerified(blobsDir, data, sha)) {
      blobsWritten++;
    }
    files.push({ path: `packs/${packId}/${rel}`, sha256: sha, bytes: data.length });
  }
  for (const p of expected.keys()) {
    if (!files.some((f) => f.path === `packs/${packId}/${p}`)) {
      throw new Error(`pack manifest lists ${p} but the file is missing`);
    }
  }
  log(`pack ${packId} ${packManifest.version}: ${files.length} files verified`);

  // ---- audio manifest + clips (paths relative to the course root, as the clip manifest writes them)
  const audioManifestBytes = await readFile(join(o.audioDir, 'manifest.json'));
  const audioManifest = JSON.parse(audioManifestBytes.toString('utf8')) as { clips?: AudioClip[] };
  const clips = audioManifest.clips ?? [];
  const audioSha = sha256Hex(audioManifestBytes);
  if (await putVerified(blobsDir, audioManifestBytes, audioSha)) {
    blobsWritten++;
  }
  files.push({ path: 'audio/manifest.json', sha256: audioSha, bytes: audioManifestBytes.length });
  const shipped: TtsIndex = {};
  const seenClip = new Set<string>();
  for (const c of clips) {
    if (!AUDIO_FILE_RE.test(c.file) || c.file.includes('..')) {
      throw new Error(`bad clip path ${c.file}`);
    }
    const data = await readFile(join(o.audioDir, c.file.slice('audio/'.length)));
    if (data.length !== c.bytes) {
      throw new Error(`clip ${c.file}: ${data.length} bytes != manifest ${c.bytes}`);
    }
    const sha = sha256Hex(data);
    if (await putVerified(blobsDir, data, sha)) {
      blobsWritten++;
    }
    if (!seenClip.has(c.file)) {
      seenClip.add(c.file);
      files.push({ path: c.file, sha256: sha, bytes: data.length });
    }
    shipped[c.textSha256] = {
      blob: sha, chars: c.chars, lang: c.lang, source: 'shipped', renderedAt: c.renderedAt ?? ''
    };
  }
  files.sort((a, b) => (a.path < b.path ? -1 : a.path > b.path ? 1 : 0));
  log(`audio: manifest + ${seenClip.size} clips verified`);

  // ---- allowed-lines set
  const narration = new Set<string>();
  const narrDir = join(o.packDir, 'narrations');
  for (const f of existsSync(narrDir) ? (await readdir(narrDir)).filter((x) => x.endsWith('.json')).sort() : []) {
    const list = await readJson<{ sentences?: string[] }[]>(join(narrDir, f));
    for (const n of list) {
      for (const s of n.sentences ?? []) {
        if (s.length > 0) {
          narration.add(sha256Hex(Buffer.from(s, 'utf8')));
        }
      }
    }
  }
  const sl = (await import(pathToFileURL(o.systemLinesPath).href)) as SystemLinesModule;
  const toursRaw = await readJson<Tour[] | { tours: Tour[] }>(join(o.packDir, 'tours.json'));
  const tours = Array.isArray(toursRaw) ? toursRaw : toursRaw.tours;
  if (!tours || tours.length === 0) {
    throw new Error('no tours in tours.json');
  }
  const system = new Set<string>();
  const numeric = new Set<string>();
  for (const t of tours) {
    const pack = sl.loadPack(o.packDir, t.id);
    for (const l of sl.linesFromCases(sl.enumerateCases(pack, { navLegs: 'all' }))) {
      system.add(l.textSha256);
    }
    for (const l of sl.linesFromCases(sl.numericCases(sl.stopNames(pack)))) {
      numeric.add(l.textSha256);
    }
  }
  const allowedList = [...new Set([...narration, ...system, ...numeric])].sort();
  const allowedSet = new Set(allowedList);
  const clipsNotAllowed = Object.keys(shipped).filter((s) => !allowedSet.has(s)).length;
  const allowedBytes = Buffer.from(JSON.stringify(allowedList), 'utf8');
  log(`allowed lines: ${allowedList.length} (narration ${narration.size}, system ${system.size}, numeric ${numeric.size})`);

  // ---- cover photo (scripts/pack/lib/cover.mjs: packs/<id>/cover.jpg + cover.json, already signed into `files`)
  const cover = await readCover(o.packDir);
  if (cover) {
    log(`cover ${cover.sha.slice(0, 12)} (${cover.credit})`);
  }

  // ---- manifest
  const version = courseVersion(packManifest.version, audioSha, cover?.versionTag);
  const manifest: CourseManifest = {
    schemaVersion: 1,
    courseId: o.courseId,
    version,
    publishedAt: o.publishedAt ?? new Date().toISOString(),
    packId,
    files,
    audio: { manifestPath: 'audio/manifest.json', clips: seenClip.size },
    allowedTtsSha: sha256Hex(allowedBytes)
  };
  const manifestEnv = signPayload(manifest, o.privateKey);

  // ---- catalog summary (the first tour of the pack is the course's tour)
  const tour = tours[0] as Tour;
  const routes = existsSync(join(o.packDir, 'routes.json')) ?
    await readJson<{ legs?: { fromPoiId: string; toPoiId: string; distanceM: number }[] }>(join(o.packDir, 'routes.json')) :
    { legs: [] };
  let meters = 0;
  for (let i = 0; i + 1 < tour.stops.length; i++) {
    const a = tour.stops[i]?.poiId;
    const b = tour.stops[i + 1]?.poiId;
    const leg = (routes.legs ?? []).find((l) => l.fromPoiId === a && l.toPoiId === b);
    meters += leg ? leg.distanceM : 0;
  }
  const langs = existsSync(narrDir) ?
    (await readdir(narrDir)).filter((x) => /^[a-z]{2}\.json$/.test(x)).map((x) => x.slice(0, 2)).sort() : [];
  const titles = tour.titles ?? {};
  const summary: CourseSummary = {
    id: o.courseId,
    version,
    title: { en: titles.en ?? tour.id, pl: titles.pl ?? titles.en ?? tour.id, zh: titles.zh ?? titles.en ?? tour.id },
    city: o.city,
    stops: tour.stops.length,
    km: bucketKm(meters),
    minutes: tour.estMinutes ?? Math.round(meters / 1.3 / 60),
    langs,
    bytes: files.reduce((n, f) => n + f.bytes, 0)
  };
  if (cover) {
    summary.coverBlob = cover.sha;
    summary.coverCredit = cover.credit;
  }

  // ---- write the data dir: allowed, manifest, catalog, tts-index (shipped clips pre-seeded: never cost credits)
  const writeCourse = async (root: string, catalogFrom: string): Promise<void> => {
    await mkdir(join(root, 'courses', o.courseId), { recursive: true });
    await writeFileAtomic(join(root, 'courses', o.courseId, 'allowed.json'), allowedBytes);
    await writeFileAtomic(join(root, 'courses', o.courseId, 'manifest.json'), JSON.stringify(manifestEnv));
    let courses: CourseSummary[] = [];
    const catPath = join(catalogFrom, 'catalog.json');
    if (existsSync(catPath)) {
      courses = (await readJson<Envelope<Catalog>>(catPath)).payload.courses.filter((c) => c.id !== o.courseId);
    }
    courses.push(summary);
    courses.sort((a, b) => (a.id < b.id ? -1 : a.id > b.id ? 1 : 0));
    await writeFileAtomic(join(root, 'catalog.json'), JSON.stringify(signPayload<Catalog>({ courses }, o.privateKey)));
    const idxPath = join(root, 'tts-index.json');
    const idx: TtsIndex = existsSync(idxPath) ? await readJson<TtsIndex>(idxPath) : {};
    for (const [k, e] of Object.entries(shipped)) {
      if (!(idx[k] && idx[k].source === 'runtime')) {
        idx[k] = e;
      }
    }
    await writeFileAtomic(idxPath, JSON.stringify(idx));
  };
  await writeCourse(o.dataDir, o.dataDir);
  if (o.seedDir) {
    await mkdir(o.seedDir, { recursive: true });
    await writeCourse(o.seedDir, o.seedDir);
    log(`seed metadata written to ${o.seedDir}`);
  }
  const st = await stat(join(o.dataDir, 'courses', o.courseId, 'manifest.json'));
  log(`course ${o.courseId} ${version}: ${files.length} files, ${summary.bytes} bytes, manifest ${st.size} bytes`);
  return {
    manifest, summary, allowedCount: allowedList.length,
    allowedBreakdown: { narration: narration.size, system: system.size, numeric: numeric.size },
    clipsNotAllowed, blobsWritten, shippedIndexed: Object.keys(shipped).length
  };
}

// Watch pack (docs/research/WATCH.md, task W3): a small offline pack for the watch HAP, cut from the downloaded
// Kraków course pack. Same schema as the phone pack (PackParser reads it unchanged), but only one tour, its stops'
// POIs, its route legs and the personas. No narrations and no audio clips (the watch has no TTS and the first
// watch slice plays no audio). Deterministic: the same input gives the same bytes.
// Usage: node scripts/pack/watch-pack.mjs            (writes wearable/src/main/resources/rawfile/watch/<tour>/)
//        node scripts/pack/watch-pack.mjs --check    (exit 1 if the committed watch pack is not current)
import { createHash } from 'node:crypto';
import { mkdirSync, readFileSync, writeFileSync, existsSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

export const REPO_ROOT = join(dirname(fileURLToPath(import.meta.url)), '..', '..');
export const SRC_DIR = join(REPO_ROOT, 'data/course/krakow/packs/krakow');
export const TOUR_ID = 'royal-route';
export const OUT_DIR = join(REPO_ROOT, 'wearable/src/main/resources/rawfile/watch', TOUR_ID);
export const FILES = ['tours.json', 'pois.json', 'routes.json', 'personas.json'];
// The SIMULATED Demo walk track is the phone's (scripts/demo/make-demo-walk.mjs); the watch gets a byte copy.
export const DEMO_SRC = join(REPO_ROOT, 'entry/src/main/resources/rawfile/demo/royal-route-walk.json');
export const DEMO_OUT = join(REPO_ROOT, 'wearable/src/main/resources/rawfile/demo/royal-route-walk.json');

const readJson = (dir, f) => JSON.parse(readFileSync(join(dir, f), 'utf8'));
const sha256 = (s) => createHash('sha256').update(s, 'utf8').digest('hex');

/** Returns { [file]: string } for the watch pack, including manifest.json. Throws on inconsistent input. */
export function buildWatchPack(srcDir = SRC_DIR, tourId = TOUR_ID) {
  const srcManifest = readJson(srcDir, 'manifest.json');
  const tour = readJson(srcDir, 'tours.json').find((t) => t.id === tourId);
  if (!tour) throw new Error(`tour ${tourId} not in ${srcDir}/tours.json`);
  const stopIds = tour.stops.map((s) => s.poiId);
  const poiById = new Map(readJson(srcDir, 'pois.json').map((p) => [p.id, p]));
  const pois = stopIds.map((id) => {
    const p = poiById.get(id);
    if (!p) throw new Error(`stop ${id} has no POI`);
    return p;
  });
  const routes = readJson(srcDir, 'routes.json');
  const nodes = new Set(routes.nodeIds);
  for (const id of stopIds) if (!nodes.has(id)) throw new Error(`stop ${id} missing from routes.nodeIds`);
  const personas = readJson(srcDir, 'personas.json');

  const out = {
    'tours.json': JSON.stringify([tour]),
    'pois.json': JSON.stringify(pois),
    'routes.json': JSON.stringify(routes),
    'personas.json': JSON.stringify(personas),
  };
  const manifest = {
    schemaVersion: srcManifest.schemaVersion,
    packId: `watch-${tourId}`,
    version: srcManifest.version,
    builtAt: srcManifest.builtAt,
    origin: srcManifest.origin,
    bbox: srcManifest.bbox,
    files: FILES.slice().sort().map((f) => ({ path: f, bytes: Buffer.byteLength(out[f], 'utf8'), sha256: sha256(out[f]) })),
    counts: { pois: pois.length, legs: routes.legs.length, narrations_en: 0, narrations_pl: 0, narrations_zh: 0 },
    licenses: srcManifest.licenses,
  };
  out['manifest.json'] = JSON.stringify(manifest);
  return out;
}

function main() {
  const pack = buildWatchPack();
  if (process.argv.includes('--check')) {
    const stale = Object.keys(pack).filter((f) => !existsSync(join(OUT_DIR, f)) || readFileSync(join(OUT_DIR, f), 'utf8') !== pack[f]);
    if (!existsSync(DEMO_OUT) || !readFileSync(DEMO_OUT).equals(readFileSync(DEMO_SRC))) stale.push('demo track');
    if (stale.length) { console.error(`watch pack stale: ${stale.join(', ')} (run node scripts/pack/watch-pack.mjs)`); process.exit(1); }
    console.log('watch pack current');
    return;
  }
  mkdirSync(OUT_DIR, { recursive: true });
  for (const [f, s] of Object.entries(pack)) writeFileSync(join(OUT_DIR, f), s);
  mkdirSync(dirname(DEMO_OUT), { recursive: true });
  writeFileSync(DEMO_OUT, readFileSync(DEMO_SRC));
  const bytes = Object.values(pack).reduce((n, s) => n + Buffer.byteLength(s, 'utf8'), 0);
  console.log(`watch pack ${TOUR_ID}: ${Object.keys(pack).length} files, ${bytes} bytes -> ${OUT_DIR}`);
}

if (process.argv[1] === fileURLToPath(import.meta.url)) main();

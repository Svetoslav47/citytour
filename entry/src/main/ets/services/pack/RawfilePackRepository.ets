/*
 * The offline Kraków pack from rawfile/packs/krakow/ (task B3; pack built by scripts/pack/build-pack.sh, B2).
 * - load() runs once and is shared (the UI and the TourController both call it).
 * - Integrity: every file listed in manifest.json is checked for byte size and SHA-256 when it is read;
 *   a mismatch, invalid JSON or another schema major is blocking (PACK_ERR, ARCHITECTURE §9 row 17).
 * - Records are re-validated by core/content/PackParser; invalid ones are dropped (PACK_DROP).
 * - Narrations load lazily per language (NarrationRepository), the map lazily per level.
 * Remote courses (docs/SERVER.md §6): the same parsing and integrity checks also serve a downloaded course; only the
 * byte source differs (PackSource: rawfile here, files under filesDir/courses/<id>/<version>/ in FilePackRepository).
 * APIs (all <= API 20): application.getApplicationContext (14+, doc js-apis-app-ability-application),
 * ResourceManager.getRawFileContent / getRawFileContentSync (9+/10+, js-apis-resource-manager),
 * util.TextDecoder.create + decodeToString (12+, js-apis-util), cryptoFramework.createMd SHA256 +
 * updateSync/digestSync (12+, js-apis-cryptoframework).
 */
import { application } from '@kit.AbilityKit';
import { cryptoFramework } from '@kit.CryptoArchitectureKit';
import { resourceManager } from '@kit.LocalizationKit';
import { util } from '@kit.ArkTS';
import { AppIssue, IssueCode, IssueSeverity } from '../../contracts/EngineTypes';
import {
  Lang, LatLng, MapData, Narration, NarrationLength, PackFile, PackManifest, Persona, Poi, RouteData, SourceRef, Tour
} from '../../contracts/Model';
import { PackLoadResult, PackRepository } from '../../contracts/Ports';
import { Log } from '../../app/Log';
import { LogEvents } from '../../app/LogEvents';
import {
  emptyRoutes, parseManifest, parseMap, parsePersonas, parsePois, parseRoutes, parseSources, parseTours,
  pruneTourStops
} from '../../core/content/PackParser';
import { NarrationRepository } from './NarrationRepository';

export const PACK_DIR: string = 'packs/krakow/';
export const PACK_ID: string = 'krakow';

function hex(bytes: Uint8Array): string {
  let s = '';
  for (let i = 0; i < bytes.length; i++) {
    s += (bytes[i] < 16 ? '0' : '') + bytes[i].toString(16);
  }
  return s;
}

/** Where a pack's files come from (pack-relative paths such as 'pois.json', 'narrations/en.json'). Both throw on error. */
export interface PackSource {
  label(): string;
  read(file: string): Promise<Uint8Array>;
  readSync(file: string): Uint8Array;
}

/** The bundled pack in rawfile/packs/krakow/. */
export class RawfilePackSource implements PackSource {
  private rm: resourceManager.ResourceManager | undefined = undefined;

  label(): string {
    return 'rawfile';
  }

  read(file: string): Promise<Uint8Array> {
    return this.resources().getRawFileContent(`${PACK_DIR}${file}`);
  }

  readSync(file: string): Uint8Array {
    return this.resources().getRawFileContentSync(`${PACK_DIR}${file}`);
  }

  private resources(): resourceManager.ResourceManager {
    if (this.rm === undefined) {
      this.rm = application.getApplicationContext().resourceManager;
    }
    return this.rm;
  }
}

export class RawfilePackRepository implements PackRepository {
  private loading: Promise<PackLoadResult> | undefined = undefined;
  private readonly src: PackSource;
  private manifestData: PackManifest | undefined = undefined;
  private fileIndex: Map<string, PackFile> = new Map<string, PackFile>();
  private poiList: Poi[] = [];
  private poiById: Map<string, Poi> = new Map<string, Poi>();
  private tourList: Tour[] = [];
  private personaList: Persona[] = [];
  private sourceById: Map<string, SourceRef> = new Map<string, SourceRef>();
  private routeData: RouteData = emptyRoutes();
  private maps: Map<string, MapData> = new Map<string, MapData>();
  private narr: NarrationRepository;

  constructor(src?: PackSource) {
    this.src = src !== undefined ? src : new RawfilePackSource();
    this.narr = new NarrationRepository((lang: Lang) => this.readTextSync(`narrations/${lang}.json`),
      (id: string) => this.poiById.get(id), (id: string) => this.sourceById.has(id));
  }

  /** True when the bundled pack is present (manifest readable). Used by PackFactory. */
  static available(): boolean {
    try {
      const bytes = application.getApplicationContext().resourceManager.getRawFileContentSync(`${PACK_DIR}manifest.json`);
      return bytes.length > 0;
    } catch (e) {
      return false;
    }
  }

  load(): Promise<PackLoadResult> {
    if (this.loading === undefined) {
      this.loading = this.doLoad();
    }
    return this.loading;
  }

  pois(): Poi[] {
    return this.poiList;
  }

  poi(id: string): Poi | undefined {
    return this.poiById.get(id);
  }

  tours(): Tour[] {
    return this.tourList;
  }

  personas(): Persona[] {
    return this.personaList;
  }

  routes(): RouteData {
    return this.routeData;
  }

  map(level: string): MapData {
    const hit = this.maps.get(level);
    if (hit !== undefined) {
      return hit;
    }
    const file = `map-${level}.json`;
    const text = this.readTextSync(file);
    let data: MapData | undefined = undefined;
    if (text !== undefined) {
      const r = parseMap(text);
      if (r.error !== '') {
        Log.e(LogEvents.PACK_ERR, `file=${file} reason=${r.error} blocking=false`);
      } else {
        data = r.map;
        if (r.dropped > 0) {
          Log.w(LogEvents.PACK_DROP, `file=${file} n=${r.dropped}`);
        }
      }
    }
    if (data === undefined) {
      const fallbackOrigin: LatLng = { lat: 50.06143, lng: 19.93658 };
      const origin = this.manifestData !== undefined ? this.manifestData.origin : fallbackOrigin;
      data = { level: level, origin: origin, bounds: [0, 0, 0, 0], layers: [] };
    }
    this.maps.set(level, data);
    return data;
  }

  narration(poiId: string, personaId: string, lang: Lang, len: NarrationLength): Narration | undefined {
    try {
      return this.narr.get(poiId, personaId, lang, len);
    } catch (e) {
      Log.e(LogEvents.UNCAUGHT, `where=RawfilePackRepository.narration ${Log.errKv(e as Object)}`);
      return undefined;
    }
  }

  source(id: string): SourceRef | undefined {
    return this.sourceById.get(id);
  }

  // ---------- loading ----------

  private async doLoad(): Promise<PackLoadResult> {
    const t0 = Date.now();
    const issues: AppIssue[] = [];
    try {
      const mtext = await this.readText('manifest.json', false);
      if (mtext === undefined) {
        return this.fail(issues, 'manifest.json', 'missing');
      }
      const mr = parseManifest(mtext);
      if (mr.manifest === undefined) {
        return this.fail(issues, 'manifest.json', mr.error);
      }
      this.manifestData = mr.manifest;
      for (const f of mr.manifest.files) {
        this.fileIndex.set(f.path, f);
      }

      const ptext = await this.readText('pois.json', true);
      if (ptext === undefined) {
        return this.fail(issues, 'pois.json', 'missing_or_integrity');
      }
      const pois = parsePois(ptext);
      if (pois.error !== '') {
        return this.fail(issues, 'pois.json', pois.error);
      }
      NarrationRepository.logDrops(pois.drops.length, pois.drops.length > 0 ? pois.drops[0].reason : '', 'pois.json');
      this.poiList = pois.items;
      this.poiById = new Map<string, Poi>();
      for (const p of pois.items) {
        this.poiById.set(p.id, p);
      }

      const ttext = await this.readText('tours.json', true);
      const tours = ttext === undefined ? undefined : parseTours(ttext);
      if (tours === undefined || tours.error !== '' || tours.items.length === 0) {
        return this.fail(issues, 'tours.json', tours === undefined ? 'missing_or_integrity' : tours.error || 'empty');
      }
      const pruned = pruneTourStops(tours.items, (id: string) => this.poiById.has(id));
      NarrationRepository.logDrops(tours.drops.length + pruned.length,
        pruned.length > 0 ? pruned[0].reason : (tours.drops.length > 0 ? tours.drops[0].reason : ''), 'tours.json');
      this.tourList = tours.items.filter((t: Tour) => t.stops.length > 0);

      const petext = await this.readText('personas.json', true);
      const personas = petext === undefined ? undefined : parsePersonas(petext);
      this.personaList = personas === undefined ? [] : personas.items;
      this.narr.setPersonas(this.personaList);

      const stext = await this.readText('sources.json', true);
      const sources = stext === undefined ? undefined : parseSources(stext);
      this.sourceById = new Map<string, SourceRef>();
      if (sources !== undefined) {
        for (const s of sources.items) {
          this.sourceById.set(s.id, s);
        }
        NarrationRepository.logDrops(sources.drops.length, sources.drops.length > 0 ? sources.drops[0].reason : '',
          'sources.json');
      }

      const rtext = await this.readText('routes.json', true);
      const routes = rtext === undefined ? undefined : parseRoutes(rtext);
      if (routes === undefined || routes.error !== '') {
        // Not blocking: the planner falls back to straight-line estimates (§9 rows 19-20).
        Log.w(LogEvents.ROUTE_FALLBACK, `file=routes.json reason=${routes === undefined ? 'missing' : routes.error}`);
        issues.push({ code: IssueCode.ROUTE_FALLBACK, severity: IssueSeverity.WARN, detail: 'routes.json' });
        this.routeData = emptyRoutes();
      } else {
        this.routeData = routes.routes;
        NarrationRepository.logDrops(routes.drops.length, routes.drops.length > 0 ? routes.drops[0].reason : '',
          'routes.json');
      }

      const narrEn = this.narr.ensure(Lang.EN);
      Log.i(LogEvents.PACK_LOAD, `where=repo src=${this.src.label()} ms=${Date.now() - t0} pack=${mr.manifest.packId} ` +
        `version=${mr.manifest.version} pois=${this.poiList.length} tours=${this.tourList.length} ` +
        `narr=${narrEn} legs=${this.routeData.legs.length} sources=${this.sourceById.size}`);
      const ok: PackLoadResult = { ok: true, manifest: mr.manifest, issues: issues };
      return ok;
    } catch (e) {
      return this.fail(issues, 'pack', `exception ${Log.errKv(e as Object)}`);
    }
  }

  private fail(issues: AppIssue[], file: string, reason: string): PackLoadResult {
    Log.e(LogEvents.PACK_ERR, `file=${file} reason=${reason} blocking=true`);
    issues.push({ code: IssueCode.PACK_ERR, severity: IssueSeverity.BLOCKING, detail: `${file}: ${reason}` });
    const r: PackLoadResult = { ok: false, issues: issues };
    return r;
  }

  /** Reads a pack file; when `verify`, checks it against the manifest (bytes + SHA-256). */
  private async readText(file: string, verify: boolean): Promise<string | undefined> {
    try {
      const bytes = await this.src.read(file);
      return this.decodeChecked(file, bytes, verify);
    } catch (e) {
      Log.e(LogEvents.PACK_ERR, `file=${file} reason=read ${Log.errKv(e as Object)}`);
      return undefined;
    }
  }

  private readTextSync(file: string): string | undefined {
    try {
      const bytes = this.src.readSync(file);
      return this.decodeChecked(file, bytes, true);
    } catch (e) {
      Log.w(LogEvents.PACK_ERR, `file=${file} reason=read ${Log.errKv(e as Object)} blocking=false`);
      return undefined;
    }
  }

  private decodeChecked(file: string, bytes: Uint8Array, verify: boolean): string | undefined {
    if (verify) {
      const entry = this.fileIndex.get(file);
      if (entry === undefined) {
        Log.w(LogEvents.PACK_ERR, `file=${file} reason=not_in_manifest blocking=false`);
      } else {
        if (entry.bytes !== bytes.length) {
          Log.e(LogEvents.PACK_ERR, `file=${file} reason=size expected=${entry.bytes} got=${bytes.length}`);
          return undefined;
        }
        const sha = this.sha256(bytes);
        if (sha !== '' && entry.sha256 !== '' && sha !== entry.sha256.toLowerCase()) {
          Log.e(LogEvents.PACK_ERR, `file=${file} reason=sha256_mismatch`);
          return undefined;
        }
      }
    }
    const decoder = util.TextDecoder.create('utf-8', { ignoreBOM: true });
    return decoder.decodeToString(bytes);
  }

  /** Hex SHA-256, or '' if the crypto service is unavailable (then only the size check applies). */
  private sha256(bytes: Uint8Array): string {
    try {
      const md = cryptoFramework.createMd('SHA256');
      md.updateSync({ data: bytes });
      return hex(md.digestSync().data);
    } catch (e) {
      Log.w(LogEvents.PACK_ERR, `reason=sha256_unavailable ${Log.errKv(e as Object)} blocking=false`);
      return '';
    }
  }
}

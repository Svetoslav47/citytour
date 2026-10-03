/*
 * The watch's PackRepository: the small pack bundled in rawfile/watch/<tour>/ (scripts/pack/watch-pack.mjs, task W3).
 * Same schema as the phone pack, parsed and re-validated by the shared core/content/PackParser; invalid records are
 * dropped (PACK_DROP), a missing or unparsable file is blocking (PACK_ERR, ARCHITECTURE §9 row 17).
 * The watch pack has no narrations, maps or sources: narration() returns undefined, so the engine shows only the
 * stop name and direction (it never speaks: the watch has no TTS, docs/research/WATCH.md §2).
 * Rawfile read: resourceManager.getRawFileContent + util.TextDecoder (same as the phone's DemoWalkSource).
 */
import { common } from '@kit.AbilityKit';
import { util } from '@kit.ArkTS';
import {
  AppIssue, Drop, IssueCode, IssueSeverity, Lang, LogEvents, ManifestResult, MapData, Narration, NarrationLength,
  PackLoadResult, PackManifest, PackRepository, Parsed, Persona, Poi, RouteData, RoutesResult, SourceRef, Tour,
  emptyRoutes, parseManifest, parsePersonas, parsePois, parseRoutes, parseTours, pruneTourStops
} from 'common';
import { Log } from '../app/Log';

export class WatchPackRepository implements PackRepository {
  private readonly ctx: common.Context;
  private readonly dir: string;
  private poiList: Poi[] = [];
  private readonly poiById: Map<string, Poi> = new Map<string, Poi>();
  private tourList: Tour[] = [];
  private personaList: Persona[] = [];
  private routeData: RouteData = emptyRoutes();
  private loaded: PackLoadResult | undefined = undefined;

  constructor(ctx: common.Context, dir: string) {
    this.ctx = ctx;
    this.dir = dir;
  }

  async load(): Promise<PackLoadResult> {
    if (this.loaded !== undefined && this.loaded.ok) {
      return this.loaded;
    }
    const t0: number = Date.now();
    const issues: AppIssue[] = [];
    try {
      const mr: ManifestResult = parseManifest(await this.text('manifest.json'));
      if (mr.manifest === undefined) {
        return this.fail(`manifest.json ${mr.error}`);
      }
      const manifest: PackManifest = mr.manifest;
      const pois: Parsed<Poi> = parsePois(await this.text('pois.json'));
      const tours: Parsed<Tour> = parseTours(await this.text('tours.json'));
      const personas: Parsed<Persona> = parsePersonas(await this.text('personas.json'));
      const routes: RoutesResult = parseRoutes(await this.text('routes.json'));
      for (const p of [pois.error, tours.error, personas.error, routes.error]) {
        if (p !== '') {
          return this.fail(p);
        }
      }
      this.poiList = pois.items;
      this.poiById.clear();
      for (const p of this.poiList) {
        this.poiById.set(p.id, p);
      }
      this.tourList = tours.items;
      this.personaList = personas.items;
      this.routeData = routes.routes;
      const drops: Drop[] = pois.drops.concat(tours.drops, personas.drops, routes.drops,
        pruneTourStops(this.tourList, (id: string) => this.poiById.has(id)));
      for (const d of drops) {
        Log.w(LogEvents.PACK_DROP, `file=${d.file} id=${d.id} reason=${d.reason}`);
      }
      Log.i(LogEvents.PACK_LOAD, `where=watch src=rawfile ms=${Date.now() - t0} pack=${manifest.packId} ` +
        `version=${manifest.version} pois=${this.poiList.length} tours=${this.tourList.length} narr=none ` +
        `legs=${this.routeData.legs.length} drops=${drops.length}`);
      const ok: PackLoadResult = { ok: true, manifest: manifest, issues: issues };
      this.loaded = ok;
      return ok;
    } catch (e) {
      return this.fail(`read ${Log.errKv(e as Object)}`);
    }
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
    const m: MapData = { level: level, origin: { lat: 0, lng: 0 }, bounds: [], layers: [] };
    return m;
  }

  narration(poiId: string, personaId: string, lang: Lang, len: NarrationLength): Narration | undefined {
    return undefined;
  }

  source(id: string): SourceRef | undefined {
    return undefined;
  }

  private async text(file: string): Promise<string> {
    const bytes: Uint8Array = await this.ctx.resourceManager.getRawFileContent(`${this.dir}/${file}`);
    return new util.TextDecoder('utf-8').decodeToString(bytes);
  }

  private fail(reason: string): PackLoadResult {
    Log.e(LogEvents.PACK_ERR, `where=watch reason=${reason} blocking=true`);
    const issue: AppIssue = { code: IssueCode.PACK_ERR, severity: IssueSeverity.BLOCKING, detail: reason };
    const r: PackLoadResult = { ok: false, issues: [issue] };
    return r;
  }
}

/*
 * The PackRepository the whole app holds (AppContainer.packRepository()): it forwards to the ACTIVE course's pack,
 * the bundled Kraków pack (always available) or a downloaded course (FilePackRepository) chosen on the Courses
 * screen (docs/SERVER.md §6). Nothing else in the app needs to know which one it is.
 *
 * - load(): waits (bounded) for the start-up choice of the active course, then loads it. A downloaded course that
 *   fails to load falls back to the bundled pack (COURSE event=fallback), so a broken download never blocks the app.
 * - switchTo(): loads the new pack first and swaps only when it loaded; the old pack stays active otherwise.
 * With no server and no downloads this is a transparent wrapper around RawfilePackRepository.
 */
import { Lang, MapData, Narration, NarrationLength, Persona, Poi, RouteData, SourceRef, Tour } from '../../contracts/Model';
import { PackLoadResult, PackRepository } from '../../contracts/Ports';
import { Log } from '../../app/Log';
import { LogEvents } from '../../app/LogEvents';

const STARTUP_CHOICE_TIMEOUT_MS: number = 3000;

export class ActivePackRepository implements PackRepository {
  private readonly bundled: PackRepository;
  private current: PackRepository;
  private currentId: string;
  private readonly bundledId: string;
  private startup: Promise<void> = Promise.resolve();
  private loading: Promise<PackLoadResult> | undefined = undefined;
  private chosen: boolean = false;   // the start-up choice was applied (or timed out); later choices are ignored

  constructor(bundled: PackRepository, bundledId: string) {
    this.bundled = bundled;
    this.current = bundled;
    this.bundledId = bundledId;
    this.currentId = bundledId;
  }

  bundledRepo(): PackRepository {
    return this.bundled;
  }

  activeId(): string {
    return this.currentId;
  }

  isBundled(): boolean {
    return this.current === this.bundled;
  }

  /**
   * Start-up: `choose` resolves the downloaded course to use (or undefined for the bundled pack) before the first
   * load(). Called once by CourseRepository.init().
   */
  setStartupChoice(choose: Promise<PackRepository | undefined>, idOf: () => string): void {
    this.startup = choose.then((repo: PackRepository | undefined) => {
      if (repo !== undefined && !this.chosen) {
        const id = idOf();
        this.current = repo;
        this.currentId = id;
        Log.i(LogEvents.COURSE, `event=active_restore id=${id}`);
      }
    }).catch((e: Object) => {
      Log.e(LogEvents.COURSE, `event=active_restore_fail ${Log.errKv(e)}`);
    });
  }

  load(): Promise<PackLoadResult> {
    if (this.loading === undefined) {
      this.loading = this.doLoad();
    }
    return this.loading;
  }

  /** Loads `repo`, then makes it active. Resolves the load result; on failure the previous pack stays active. */
  async switchTo(repo: PackRepository, id: string): Promise<PackLoadResult> {
    let r: PackLoadResult;
    try {
      r = await repo.load();
    } catch (e) {
      Log.e(LogEvents.COURSE, `event=switch_fail id=${id} ${Log.errKv(e as Object)}`);
      const bad: PackLoadResult = { ok: false, issues: [] };
      return bad;
    }
    if (!r.ok) {
      Log.e(LogEvents.COURSE, `event=switch_fail id=${id} issues=${r.issues.length} keep=${this.currentId}`);
      return r;
    }
    this.chosen = true;
    this.current = repo;
    this.currentId = id;
    this.loading = Promise.resolve(r);
    Log.i(LogEvents.COURSE, `event=active id=${id} pack=${r.manifest !== undefined ? r.manifest.packId : ''}` +
      ` version=${r.manifest !== undefined ? r.manifest.version : ''}`);
    return r;
  }

  /** Back to the bundled pack. */
  switchToBundled(): Promise<PackLoadResult> {
    return this.switchTo(this.bundled, this.bundledId);
  }

  private async doLoad(): Promise<PackLoadResult> {
    await Promise.race([this.startup, new Promise<void>((resolve) => setTimeout(resolve, STARTUP_CHOICE_TIMEOUT_MS))]);
    this.chosen = true;
    const repo = this.current;
    let r: PackLoadResult;
    try {
      r = await repo.load();
    } catch (e) {
      const bad: PackLoadResult = { ok: false, issues: [] };
      r = bad;
    }
    if (!r.ok && repo !== this.bundled) {
      Log.w(LogEvents.COURSE, `event=fallback from=${this.currentId} to=${this.bundledId} reason=load_failed`);
      this.current = this.bundled;
      this.currentId = this.bundledId;
      return this.bundled.load();
    }
    return r;
  }

  pois(): Poi[] {
    return this.current.pois();
  }

  poi(id: string): Poi | undefined {
    return this.current.poi(id);
  }

  tours(): Tour[] {
    return this.current.tours();
  }

  personas(): Persona[] {
    return this.current.personas();
  }

  routes(): RouteData {
    return this.current.routes();
  }

  map(level: string): MapData {
    return this.current.map(level);
  }

  narration(poiId: string, personaId: string, lang: Lang, len: NarrationLength): Narration | undefined {
    return this.current.narration(poiId, personaId, lang, len);
  }

  source(id: string): SourceRef | undefined {
    return this.current.source(id);
  }
}

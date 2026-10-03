/*
 * Place detail view model (B8, DESIGN §3.8): the narration to read (FULL, else TEASER; the active text
 * language, else English with "Shown in English"), its tier and provenance for the trust labels, the numbered
 * sources with licences, and the reviewed "where to look" hint for tour stops. Content comes validated from
 * PackRepository.narration() (validator + fallback chain of B3); this class never shows unvalidated text.
 */
import { ContentTier, Lang, LookDir, MapData, Narration, NarrationLength, Poi, PoiKind, ProvenanceKind, SourceRef, Tour,
  TourStop } from '../contracts/Model';
import { TourPhase } from '../contracts/EngineTypes';
import { AppContainer } from '../app/AppContainer';
import { Log } from '../app/Log';
import { LogEvents } from '../app/LogEvents';
import { MapOverlay } from '../views/map/MapRenderer';
import { localName } from './Format';
import { MapCache, placeBounds, placeOverlay } from './MapViewModel';
import { safePoi } from './PackView';

export class SourceRow {
  n: number;
  id: string;
  title: string;
  publisher: string;
  license: string;
  url: string;

  constructor(n: number, s: SourceRef) {
    this.n = n;
    this.id = s.id;
    this.title = s.title;
    this.publisher = s.publisher;
    this.license = s.license;
    this.url = s.url;
  }
}

const HISTORIAN: string = 'historian';

/** Strips TTS pause markup ([p400]) from a sentence for reading. */
export function readable(sentence: string): string {
  return sentence.replace(/\s*\[p\d+\]\s*/g, ' ').trim();
}

@ObservedV2
export class PlaceViewModel {
  @Trace found: boolean = false;
  @Trace poiId: string = '';
  @Trace name: string = '';
  @Trace localNamePl: string = '';
  @Trace kind: PoiKind = PoiKind.OTHER;
  @Trace stopNumber: number = 0;
  @Trace paragraphs: string[] = [];
  @Trace tier: ContentTier = ContentTier.NAME_ONLY;
  @Trace machineTranslated: boolean = false;
  @Trace shownInEnglish: boolean = false;
  @Trace reviewedAt: string = '';
  @Trace sources: SourceRow[] = [];
  @Trace look: LookDir | undefined = undefined;
  @Trace lookFeature: string = '';
  @Trace fromWikipedia: boolean = false;
  @Trace currentStop: boolean = false;
  @Trace map: MapData | undefined = undefined;
  @Trace scene: MapOverlay = new MapOverlay();
  @Trace sceneBounds: number[] = [];

  load(poiId: string, lang: Lang): void {
    const pack = AppContainer.packRepository();
    const poi: Poi | undefined = safePoi(pack, poiId);
    this.poiId = poiId;
    if (poi === undefined) {
      this.found = false;
      Log.w(LogEvents.PACK_ERR, `where=PlaceViewModel poi=${poiId} reason=not_found`);
      return;
    }
    this.name = localName(poi.names, lang);
    this.localNamePl = lang !== Lang.PL && poi.names.pl !== undefined && poi.names.pl !== this.name ? poi.names.pl : '';
    this.kind = poi.kind;
    this.stopNumber = this.findStopNumber(poiId);
    this.map = MapCache.detailMap();
    this.scene = placeOverlay(poi.x, poi.y, this.stopNumber);
    this.sceneBounds = placeBounds(poi.x, poi.y);
    if (poi.view !== undefined) {
      this.look = poi.view.look;
      this.lookFeature = localName(poi.view.feature, lang);
    }

    let n = this.narration(poiId, lang);
    this.shownInEnglish = false;
    if (n === undefined && lang !== Lang.EN) {
      n = this.narration(poiId, Lang.EN);
      this.shownInEnglish = n !== undefined;
    }
    if (n !== undefined) {
      this.paragraphs = n.sentences.map((s: string) => readable(s)).filter((s: string) => s.length > 0);
      this.tier = n.tier;
      this.machineTranslated = n.generatedBy.kind === ProvenanceKind.MACHINE_TRANSLATION;
      this.reviewedAt = n.reviewedBy !== undefined ? n.reviewedBy.at : '';
    } else {
      this.paragraphs = [];
      this.tier = ContentTier.NAME_ONLY;
    }
    this.sources = this.collectSources(poi, n);
    this.fromWikipedia = this.sources.some((s: SourceRow) => s.publisher.toLowerCase().indexOf('wikipedia') >= 0);
    try {
      const snap = AppContainer.tourControl().current();
      const idx = snap.currentStopIdx;
      this.currentStop = snap.phase === TourPhase.AT_STOP && idx >= 0 && idx < snap.stops.length &&
        snap.stops[idx].poiId === poiId;
    } catch (e) {
      this.currentStop = false;
    }
    this.found = true;
    Log.i(LogEvents.NARR_SOURCE, `where=placeDetail poi=${poiId} tier=${this.tier} lang=${lang} ` +
      `sources=${this.sources.length} mt=${this.machineTranslated}`);
  }

  /** "Tell me more" at the stop being visited: the engine queues the deep layer (TourControl.more). */
  tellMore(): void {
    try {
      AppContainer.tourControl().more();
      Log.i('USER_MORE', `src=placeDetail poi=${this.poiId}`);
    } catch (e) {
      Log.e(LogEvents.UNCAUGHT, `where=PlaceViewModel.tellMore ${Log.errKv(e as Object)}`);
    }
  }

  private narration(poiId: string, lang: Lang): Narration | undefined {
    const pack = AppContainer.packRepository();
    try {
      const full = pack.narration(poiId, HISTORIAN, lang, NarrationLength.FULL);
      return full !== undefined ? full : pack.narration(poiId, HISTORIAN, lang, NarrationLength.TEASER);
    } catch (e) {
      return undefined;
    }
  }

  private findStopNumber(poiId: string): number {
    try {
      for (const t of AppContainer.packRepository().tours()) {
        const tour: Tour = t;
        const i = tour.stops.findIndex((s: TourStop) => s.poiId === poiId);
        if (i >= 0) {
          return i + 1;
        }
      }
    } catch (e) {
      return 0;
    }
    return 0;
  }

  private collectSources(poi: Poi, n: Narration | undefined): SourceRow[] {
    const pack = AppContainer.packRepository();
    const ids: string[] = [];
    const add = (id: string): void => {
      if (id !== '' && ids.indexOf(id) < 0) {
        ids.push(id);
      }
    };
    if (n !== undefined) {
      n.sources.forEach((s: string) => add(s));
      n.claims.forEach((c) => add(c.sourceId));
    }
    poi.sourceIds.forEach((s: string) => add(s));
    const rows: SourceRow[] = [];
    for (const id of ids) {
      const ref = pack.source(id);
      if (ref !== undefined) {
        rows.push(new SourceRow(rows.length + 1, ref));
      }
    }
    return rows;
  }
}

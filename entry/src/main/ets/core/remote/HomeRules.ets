/*
 * Home = the walks of the current city (docs/SERVER.md §6 "Home"). Pure: no @kit imports, unit-tested in
 * entry/src/test/HomeRules.test.ets.
 *
 * - Header: "You're in {city}" when the latest location fix lies inside that city's bbox ([minLat, minLng, maxLat,
 *   maxLng], city.json); otherwise (no fix, outside, bbox unknown) "Walks in {city}".
 * - City: the active course's city when it has walks, else the first city in catalog order that has walks.
 * - One card per walk with its actions ON the card: Start (one tap: stream if needed, start, Now Walking), Demo walk
 *   (SIMULATED), a small download button (download / progress / downloaded) and "Remove download".
 */

export enum HomeHeader { IN_CITY = 'inCity', WALKS_IN = 'walksIn' }

/** "You're in {city}" only with a real fix inside the city's bbox. lat/lng NaN = no fix. */
export function homeHeader(lat: number, lng: number, bbox: number[]): HomeHeader {
  if (!Number.isFinite(lat) || !Number.isFinite(lng) || bbox.length < 4 || !bbox.every((v: number) => Number.isFinite(v))) {
    return HomeHeader.WALKS_IN;
  }
  const inside = lat >= bbox[0] && lat <= bbox[2] && lng >= bbox[1] && lng <= bbox[3];
  return inside ? HomeHeader.IN_CITY : HomeHeader.WALKS_IN;
}

/** The city Home lists: the active course's city when it has walks, else the first city (catalog order) with walks. */
export function homeCity(activeCityId: string, walkCityIds: string[]): string {
  if (activeCityId !== '' && walkCityIds.indexOf(activeCityId) >= 0) {
    return activeCityId;
  }
  return walkCityIds.length > 0 ? walkCityIds[0] : '';
}

/** The card's main button. */
export enum CardPrimary {
  START = 'start',           // one tap: (stream,) start, Now Walking
  CONTINUE = 'continue',     // this walk is running: open Now Walking
  PREPARING = 'preparing',   // fetching / activating / starting: "Preparing…", disabled
  UNAVAILABLE = 'unavailable' // not on the device and no server to fetch it from: disabled
}

export enum CardDownload { HIDDEN = 'hidden', DOWNLOAD = 'download', PROGRESS = 'progress', DONE = 'done' }

export class CardInput {
  /** Fully downloaded (offline). */
  downloaded: boolean = false;
  /** A newer version is on the server (downloaded only). */
  updateAvailable: boolean = false;
  /** Streamed copy on the device. */
  streamed: boolean = false;
  /** Download running. */
  downloading: boolean = false;
  /** Start / Demo walk is preparing this walk. */
  preparing: boolean = false;
  /** The last Start / Download of this walk failed. */
  failed: boolean = false;
  /** This walk is the running tour. */
  running: boolean = false;
  /** Another walk's tour is running (Start asks to end it first). */
  otherRunning: boolean = false;
  /** A course server is configured (fetch / download possible). */
  serverEnabled: boolean = false;
  /** This walk is the active course. */
  active: boolean = false;
  /** The active course's pack ships a demo track (meaningful only when `active`). */
  activeHasDemo: boolean = false;
}

export class CardActions {
  primary: CardPrimary = CardPrimary.START;
  /** "Demo walk" shown on the card. */
  demo: boolean = false;
  /** Buttons usable (false while preparing / downloading another way). */
  enabled: boolean = true;
  /** Start must first confirm ending the running tour. */
  confirmEnd: boolean = false;
  download: CardDownload = CardDownload.HIDDEN;
  /** "Remove download" offered (long-press / ⋯). */
  canRemove: boolean = false;
  /** Show the inline failure line. */
  showFailed: boolean = false;
}

export function cardActions(i: CardInput): CardActions {
  const a = new CardActions();
  const onDevice = i.downloaded || i.streamed;
  if (i.running) {
    a.primary = CardPrimary.CONTINUE;
  } else if (i.preparing) {
    a.primary = CardPrimary.PREPARING;
    a.enabled = false;
  } else if (!onDevice && !i.serverEnabled) {
    a.primary = CardPrimary.UNAVAILABLE;
    a.enabled = false;
  } else {
    a.primary = CardPrimary.START;
    a.confirmEnd = i.otherRunning;
  }
  // The demo track is known only once the walk's pack is loaded (active); a walk not yet active is offered the demo
  // when it can be made active (Start then reports a walk without a track).
  a.demo = !i.running && (i.active ? i.activeHasDemo : (onDevice || i.serverEnabled));
  if (i.downloading) {
    a.download = CardDownload.PROGRESS;
  } else if (i.downloaded && !i.updateAvailable) {
    a.download = CardDownload.DONE;
  } else if (i.serverEnabled) {
    a.download = CardDownload.DOWNLOAD;
  } else {
    a.download = i.downloaded ? CardDownload.DONE : CardDownload.HIDDEN;
  }
  a.canRemove = onDevice && !i.running && !i.downloading && !i.preparing;
  a.showFailed = i.failed && !i.preparing && !i.downloading;
  return a;
}

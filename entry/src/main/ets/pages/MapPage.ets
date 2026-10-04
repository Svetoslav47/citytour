/*
 * Full map (B6 P1, DESIGN §3.7, tour mode): the whole native map, interactive (pan, pinch, double-tap zoom,
 * recenter), north-up. Opened from Now Walking (menu "Full map": live walk overlay) or from Tour detail (tap the
 * map: the planned route). The SIMULATED pill shows while the Demo walk drives the dot.
 * B13 explore mode (Home "All places in {city}"): every place of the course's city as dots (PoiLayer), fitted to the
 * course map (the city's default bounds from its city.json without one); the layers button toggles the same dots on the tour maps. Tapping a dot opens the place card sheet
 * (bindSheet, map stays interactive, doc ts-universal-attributes-sheet-transition) -> Details -> Place detail.
 * Explore "you are here": the WALK-mode position marker, live. Source (core/map/ExploreMe): a running tour's
 * snapshots (incl. the Demo walk, SIMULATED pill as in WALK mode), else Location Kit while the page is open (only
 * when already permitted; the locate button asks via requestPermissionsFromUser). Logs MAP_ME per state change.
 */
import { EngineSnapshot } from 'common';
import { MapData } from 'common';
import { FixSource } from 'common';
import { Fix } from 'common';
import { PermissionState } from 'common';
import { centreOnFirstFix, chooseMeSource, MeChoice, MeSource } from 'common';
import { Projection } from 'common';
import { worldBox } from 'common';
import { mapOpenBounds } from 'common';
import { AppContainer } from '../app/AppContainer';
import { Log } from '../app/Log';
import { LogEvents } from 'common';
import { AppViewModel } from '../viewmodel/AppViewModel';
import { MapCache, overlayBounds, userMark, walkOverlay } from '../viewmodel/MapViewModel';
import { RealLocationSource } from '../services/location/RealLocationSource';
import { SafeArea } from '../viewmodel/SafeArea';
import { FloatingIconButton } from '../views/common/FloatingIconButton';
import { SimulatedBadge } from '../views/common/SimulatedBadge';
import { Size, Space } from '../views/common/Tokens';
import { MapCanvas } from '../views/map/MapCanvas';
import { MapOverlay } from '../views/map/MapRenderer';
import { PlaceCardSheet } from '../views/map/PlaceCardSheet';
import { PoiLayer } from '../views/map/PoiLayer';

export class MapMode {
  static readonly WALK: string = 'walk';
  static readonly TOUR: string = 'tour';
  static readonly EXPLORE: string = 'explore';
}

/** Explore mode opens on the course map's bounds; without a map, on the city's default bounds (city.json). */
function cityDefaultBounds(): number[] {
  const c = AppContainer.activeCity();
  return c === undefined ? [] : worldBox(c.defaultBounds, Projection.fromOrigin(c.origin));
}

/** The city's projection (the frame of its map and places); undefined without an active city. */
function cityProjection(): Projection | undefined {
  const c = AppContainer.activeCity();
  return c === undefined ? undefined : Projection.fromOrigin(c.origin);
}

function permOk(p: PermissionState): boolean {
  return p === PermissionState.GRANTED || p === PermissionState.APPROX_ONLY;
}

@ComponentV2
export struct MapPage {
  @Param mode: string = MapMode.TOUR;
  @Local app: AppViewModel = AppViewModel.get();
  /** Window avoid areas (edge-to-edge window, issue #63). */
  @Local sa: SafeArea = SafeArea.get();
  @Local map: MapData | undefined = undefined;
  @Local scene: MapOverlay = new MapOverlay();
  @Local bounds: number[] = [];
  @Local demo: boolean = false;
  @Local h: number = 0;
  @Local places: PoiLayer | undefined = undefined;
  @Local showPlaces: boolean = false;
  @Local placesRev: number = 0;
  @Local cardPoi: string = '';
  @Local showCard: boolean = false;
  private unsubscribe: (() => void) | undefined = undefined;
  /** Explore "you are here" (EXPLORE mode only). */
  @Local meSrc: string = MeSource.NONE;
  @Local focusRev: number = 0;
  @Local focusX: number = 0;
  @Local focusY: number = 0;
  @Local focusZoom: boolean = false;
  private meX: number = Number.NaN;
  private meY: number = Number.NaN;
  private meFirstHandled: boolean = false;
  private meLoc: RealLocationSource | undefined = undefined;
  private meProj: Projection | undefined = undefined;
  private meGone: boolean = false;

  aboutToAppear(): void {
    this.map = MapCache.detailMap();
    this.showPlaces = this.mode === MapMode.EXPLORE;
    if (this.showPlaces) {
      this.loadPlaces();
    }
    if (this.mode === MapMode.EXPLORE) {
      this.bounds = mapOpenBounds(this.map?.bounds, cityDefaultBounds());
      this.startMe();
    } else if (this.mode === MapMode.WALK) {
      try {
        this.unsubscribe = AppContainer.tourControl().subscribe((s: EngineSnapshot) => {
          this.scene = walkOverlay(s, this.app.textLang);
          this.demo = s.source === FixSource.DEMO;
          if (this.bounds.length === 0) {
            this.bounds = overlayBounds(this.scene) ?? [];
          }
        });
      } catch (e) {
        Log.e(LogEvents.UNCAUGHT, `where=MapPage.subscribe ${Log.errKv(e as Object)}`);
      }
    } else {
      const plan = this.app.tourPlan;
      this.scene = plan.orderScene.stops.length > 0 ? plan.orderScene : plan.scene;
      this.bounds = overlayBounds(this.scene) ?? [];
    }
  }

  private setMe(src: MeSource, reason: string): void {
    if (this.meSrc !== src) {
      Log.i('MAP_ME', `src=${src} reason=${reason}`);
    }
    this.meSrc = src;
  }

  /** Picks the position source without ever opening a system dialog (that is the locate button's job). */
  private async startMe(): Promise<void> {
    try {
      const tourRunning = AppContainer.tourController().isRunning();
      let granted = false;
      let switchOn = false;
      if (!tourRunning) {
        const perms = AppContainer.permissions();
        granted = permOk(await perms.locationState());
        switchOn = granted && perms.isLocationSwitchOn();
      }
      if (this.meGone) {
        return;
      }
      const c: MeChoice = chooseMeSource(tourRunning, granted, switchOn);
      if (c.src === MeSource.TOUR) {
        this.unsubscribe = AppContainer.tourControl().subscribe((s: EngineSnapshot) => {
          this.demo = s.source === FixSource.DEMO;
          if (s.user !== undefined) {
            this.onMe(s.user.x, s.user.y, s.user.accuracyM, s.user.speedMps, s.user.courseDeg, this.demo);
          }
        });
        this.setMe(MeSource.TOUR, c.reason);
      } else if (c.src === MeSource.LOCATION) {
        this.startLocation(c.reason);
      } else {
        this.setMe(MeSource.NONE, c.reason);
      }
    } catch (e) {
      this.setMe(MeSource.NONE, 'error');
      Log.e(LogEvents.UNCAUGHT, `where=MapPage.startMe ${Log.errKv(e as Object)}`);
    }
  }

  /** Location Kit directly (own RealLocationSource: the tour's shared one keeps its listener). start() asks for the
   * permission / switch only when they are missing, i.e. only from the locate button. */
  private startLocation(reason: string): void {
    this.meProj = cityProjection();
    if (this.meProj === undefined) {
      this.setMe(MeSource.NONE, 'no_city');
      return;
    }
    if (this.meLoc === undefined) {
      this.meLoc = new RealLocationSource(AppContainer.permissions());
    }
    const src = this.meLoc;
    src.start((f: Fix) => {
      const p = this.meProj;
      if (!this.meGone && p !== undefined) {
        this.setMe(MeSource.LOCATION, reason);
        this.onMe(p.x(f.lng), p.y(f.lat), f.accuracyM, f.speedMps, f.courseDeg, false);
      }
    }, (code: number, msg: string) => {
      if (!src.isRunning()) {
        this.setMe(MeSource.NONE, `location_error code=${code}`);
      }
    }).then(() => {
      if (this.meGone) {
        src.stop();
      } else if (src.isRunning()) {
        this.setMe(MeSource.LOCATION, reason);
      }
    });
  }

  private onMe(x: number, y: number, acc: number, speed: number, course: number, simulated: boolean): void {
    const u = userMark(x, y, acc, speed, course, simulated);
    if (u === undefined) {
      return;
    }
    const ov = new MapOverlay();
    ov.user = u;
    this.scene = ov;
    this.meX = x;
    this.meY = y;
    if (!this.meFirstHandled) {
      const centre = centreOnFirstFix(false, this.bounds, x, y);
      this.meFirstHandled = true;
      Log.i('MAP_ME', `first_fix src=${this.meSrc} centred=${centre} reason=${centre ? 'inside_bounds' : 'outside_bounds'}`);
      if (centre) {
        this.focus(false);
      }
    }
  }

  private focus(zoom: boolean): void {
    this.focusX = this.meX;
    this.focusY = this.meY;
    this.focusZoom = zoom;
    this.focusRev++;
  }

  /** Locate: centre on the position; without one and without a source, ask for the permission (and switch). */
  private locate(): void {
    if (Number.isFinite(this.meX) && Number.isFinite(this.meY)) {
      Log.i('MAP_ME', `locate src=${this.meSrc} action=centre`);
      this.focus(true);
      return;
    }
    if (this.meSrc !== MeSource.NONE) {
      Log.i('MAP_ME', `locate src=${this.meSrc} action=wait_fix`);
      return;
    }
    Log.i('MAP_ME', 'locate src=none action=request_permission');
    this.startLocation('locate_button');
  }

  private loadPlaces(): void {
    if (this.places !== undefined) {
      return;
    }
    const t0 = Date.now();
    try {
      this.places = PoiLayer.of(AppContainer.packRepository().pois());
      Log.i('MAP_PLACES', `on=true pois=${this.places.size()} mode=${this.mode} ms=${Date.now() - t0}`);
    } catch (e) {
      this.places = undefined;
      this.showPlaces = false;
      Log.e(LogEvents.PACK_ERR, `where=MapPage.places ${Log.errKv(e as Object)} blocking=false`);
    }
  }

  private togglePlaces(): void {
    this.showPlaces = !this.showPlaces;
    if (this.showPlaces) {
      this.loadPlaces();
    } else {
      this.closeCard();
      Log.i('MAP_PLACES', `on=false mode=${this.mode}`);
    }
  }

  private selectPlace(poiId: string): void {
    if (poiId === '') {
      return;   // a tap on the map, not on a dot: keep the card as it is
    }
    if (this.places !== undefined) {
      this.places.selectedId = poiId;
    }
    this.placesRev++;
    this.cardPoi = poiId;
    this.showCard = true;
  }

  private closeCard(): void {
    this.showCard = false;
    if (this.places !== undefined && this.places.selectedId !== '') {
      this.places.selectedId = '';
      this.placesRev++;
    }
  }

  @Builder
  placeCard() {
    PlaceCardSheet({
      poiId: this.cardPoi,
      lang: this.app.textLang,
      onDetails: (poiId: string) => {
        // Close first: a page pushed from an open sheet would open under it (doc faqs-arkui-464).
        this.closeCard();
        this.app.openPlace(poiId);
      }
    })
  }

  aboutToDisappear(): void {
    this.meGone = true;
    if (this.meLoc !== undefined) {
      this.meLoc.stop();
      this.meLoc = undefined;
    }
    if (this.unsubscribe !== undefined) {
      this.unsubscribe();
      this.unsubscribe = undefined;
    }
  }

  build() {
    NavDestination() {
      Stack({ alignContent: Alignment.TopStart }) {
        if (this.h > 0) {
          MapCanvas({
            map: this.map,
            scene: this.scene,
            bounds: this.bounds,
            interactive: true,
            boxHeight: this.h,
            topInset: 56 + this.sa.top,
            bottomInset: this.sa.bottom,
            mapId: 'mapFull',
            places: this.showPlaces ? this.places : undefined,
            placesRev: this.placesRev,
            focusRev: this.focusRev,
            focusX: this.focusX,
            focusY: this.focusY,
            focusZoom: this.focusZoom,
            onTapPlace: (poiId: string) => this.selectPlace(poiId)
          })
        }
        Row() {
          FloatingIconButton({
            symbol: $r('sys.symbol.chevron_backward'),
            label: $r('app.string.a11y_back'),
            buttonId: 'btnBackMap',
            onTap: () => this.app.back()
          })
          Blank()
          SimulatedBadge({ visible: this.demo })
          FloatingIconButton({
            symbol: this.showPlaces ? $r('sys.symbol.layer_fill') : $r('sys.symbol.layer'),
            label: this.showPlaces ? $r('app.string.map_places_hide') : $r('app.string.map_places_show'),
            buttonId: 'btnPlaces',
            onTap: () => this.togglePlaces()
          })
        }
        .width('100%')
        // The map is full-bleed under both system bars; the floating controls sit below the status bar.
        .padding({ left: Space.S2 + this.sa.left, right: Space.S2 + this.sa.right, top: Space.S2 + this.sa.top })
        .height(Size.TOUCH + Space.S2 + this.sa.top)
        if (this.mode === MapMode.EXPLORE) {
          Row() {
            Blank()
            FloatingIconButton({
              symbol: this.meSrc === MeSource.NONE ? $r('sys.symbol.location_up') : $r('sys.symbol.location_up_fill'),
              label: $r('app.string.map_locate_me'),
              buttonId: 'btnLocateMe',
              onTap: () => this.locate()
            })
          }
          .width('100%')
          .padding({ right: Space.S2 + this.sa.right })
          .margin({ top: Size.TOUCH + Space.S2 + this.sa.top })
        }
      }
      .width('100%')
      .height('100%')
      .onAreaChange((o: Area, n: Area) => {
        this.h = n.height as number;
      })
      .bindSheet(this.showCard, this.placeCard(), {
        height: SheetSize.FIT_CONTENT,
        dragBar: true,
        showClose: true,
        preferType: SheetType.BOTTOM,
        enableOutsideInteractive: true,
        onDisappear: () => {
          this.closeCard();
        }
      })
    }
    .id('pageMap')
    .hideTitleBar(true)
    .backgroundColor($r('app.color.map_land'))
    .onShown(() => {
      Log.i(LogEvents.APP_PAGE, `page=FullMap shown mode=${this.mode}`);
    })
  }
}

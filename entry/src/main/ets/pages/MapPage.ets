/*
 * Full map (B6 P1, DESIGN §3.7, tour mode): the whole native map, interactive (pan, pinch, double-tap zoom,
 * recenter), north-up. Opened from Now Walking (menu "Full map": live walk overlay) or from Tour detail (tap the
 * map: the planned route). The SIMULATED pill shows while the Demo walk drives the dot.
 * B13 explore mode (Home "All places in {city}"): every place of the course's city as dots (PoiLayer), fitted to the
 * course map (the city's default bounds from its city.json without one); the layers button toggles the same dots on the tour maps. Tapping a dot opens the place card sheet
 * (bindSheet, map stays interactive, doc ts-universal-attributes-sheet-transition) -> Details -> Place detail.
 */
import { EngineSnapshot } from 'common';
import { MapData } from 'common';
import { FixSource } from 'common';
import { Projection } from 'common';
import { worldBox } from 'common';
import { mapOpenBounds } from 'common';
import { AppContainer } from '../app/AppContainer';
import { Log } from '../app/Log';
import { LogEvents } from 'common';
import { AppViewModel } from '../viewmodel/AppViewModel';
import { MapCache, overlayBounds, walkOverlay } from '../viewmodel/MapViewModel';
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

  aboutToAppear(): void {
    this.map = MapCache.detailMap();
    this.showPlaces = this.mode === MapMode.EXPLORE;
    if (this.showPlaces) {
      this.loadPlaces();
    }
    if (this.mode === MapMode.EXPLORE) {
      this.bounds = mapOpenBounds(this.map?.bounds, cityDefaultBounds());
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

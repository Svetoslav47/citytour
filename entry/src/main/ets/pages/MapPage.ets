/*
 * Full map (B6 P1, DESIGN §3.7, tour mode): the whole native map, interactive (pan, pinch, double-tap zoom,
 * recenter), north-up. Opened from Now Walking (menu "Full map": live walk overlay) or from Tour detail (tap the
 * map: the planned route). The SIMULATED pill shows while the Demo walk drives the dot.
 */
import { EngineSnapshot } from '../contracts/EngineTypes';
import { MapData } from '../contracts/Model';
import { FixSource } from '../contracts/Ports';
import { AppContainer } from '../app/AppContainer';
import { Log } from '../app/Log';
import { LogEvents } from '../app/LogEvents';
import { AppViewModel } from '../viewmodel/AppViewModel';
import { MapCache, overlayBounds, walkOverlay } from '../viewmodel/MapViewModel';
import { FloatingIconButton } from '../views/common/FloatingIconButton';
import { SimulatedBadge } from '../views/common/SimulatedBadge';
import { Size, Space } from '../views/common/Tokens';
import { MapCanvas } from '../views/map/MapCanvas';
import { MapOverlay } from '../views/map/MapRenderer';

export class MapMode {
  static readonly WALK: string = 'walk';
  static readonly TOUR: string = 'tour';
}

@ComponentV2
export struct MapPage {
  @Param mode: string = MapMode.TOUR;
  @Local app: AppViewModel = AppViewModel.get();
  @Local map: MapData | undefined = undefined;
  @Local scene: MapOverlay = new MapOverlay();
  @Local bounds: number[] = [];
  @Local demo: boolean = false;
  @Local h: number = 0;
  private unsubscribe: (() => void) | undefined = undefined;

  aboutToAppear(): void {
    this.map = MapCache.detailMap();
    if (this.mode === MapMode.WALK) {
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
            topInset: 56,
            mapId: 'mapFull'
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
        }
        .width('100%')
        .padding({ left: Space.S2, right: Space.S3, top: Space.S2 })
        .height(Size.TOUCH + Space.S2)
      }
      .width('100%')
      .height('100%')
      .onAreaChange((o: Area, n: Area) => {
        this.h = n.height as number;
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

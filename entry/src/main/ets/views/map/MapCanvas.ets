/*
 * Native offline map (B6, ARCHITECTURE §3, DESIGN §4.7-4.8): an ArkUI Canvas drawn by MapRenderer, no Map Kit,
 * no web view. Base map: the vector layers of the map-detail.json of the active course's pack (its own map, or its
 * city's map); without one only the route and places are drawn (no city-specific image is bundled in the app). Modes: static fit-to-route (previews), follow the user (Now Walking mini map), interactive
 * (full map: pan, pinch, double-tap zoom, recenter). "© OpenStreetMap contributors" is always shown when the
 * base map is drawn (ODbL). Logs MAP_FRAME ms= (sampled) so the perf gate G8 can be read from the log.
 */
import { common, ConfigurationConstant } from '@kit.AbilityKit';
import { MapData } from 'common';
import { Log } from '../../app/Log';
import { Camera, fitBounds, pan, zoomAt } from 'common';
import { DARK, LIGHT, MapPalette } from './MapStyle';
import { MapOverlay, MapRenderer } from './MapRenderer';
import { PoiLayer } from './PoiLayer';

const MAP_FRAME: string = 'MAP_FRAME';

const FIT_PAD: number = 28;

@ComponentV2
export struct MapCanvas {
  @Param map: MapData | undefined = undefined;
  @Param scene: MapOverlay = new MapOverlay();
  /** World box to fit when not following the user (e.g. the route). */
  @Param bounds: number[] = [];
  /** Centre on the overlay's user dot at `followScale` (Now Walking). */
  @Param follow: boolean = false;
  @Param followScale: number = 2.2;
  @Param interactive: boolean = false;
  @Param topInset: number = 0;
  @Param bottomInset: number = 0;
  @Param boxHeight: number = 260;
  @Param mapId: string = 'map';
  /** Multiplies the layers' minimum scale (1 = normal LOD). A static preview fitted to a long route passes < 1 so
   * the streets and buildings still show at its small scale. */
  @Param lodScale: number = 1;
  /** B13: all places as dots (full map), tappable when `interactive`. */
  @Param places: PoiLayer | undefined = undefined;
  /** Bumped by the page when the layer's selection changes, to redraw. */
  @Param placesRev: number = 0;
  /** Tap on a place dot: its id ('' = the tap hit no dot). */
  @Event onTapPlace: (poiId: string) => void = (poiId: string) => {};
  @Local w: number = 0;
  @Local userMoved: boolean = false;
  private settings: RenderingContextSettings = new RenderingContextSettings(true);
  private ctx: CanvasRenderingContext2D = new CanvasRenderingContext2D(this.settings);
  private renderer: MapRenderer = new MapRenderer();
  private cam: Camera = new Camera(0, 0, 1);
  private ready: boolean = false;
  private gesturing: boolean = false;
  private pinchStart: Camera = new Camera(0, 0, 1);
  private panLastX: number = 0;
  private panLastY: number = 0;
  private frames: number = 0;

  @Monitor('map', 'scene', 'bounds', 'follow', 'w', 'boxHeight', 'places', 'placesRev')
  onInputs(): void {
    this.placeCamera();
    this.draw(false);
  }

  private palette(): MapPalette {
    try {
      const ctx = this.getUIContext().getHostContext() as common.UIAbilityContext;
      if (ctx !== undefined && ctx.config.colorMode === ConfigurationConstant.ColorMode.COLOR_MODE_DARK) {
        return DARK;
      }
    } catch (e) {
      // default to light
    }
    return LIGHT;
  }

  /** Static / follow cameras are recomputed from the inputs; a user-panned full map keeps its camera. */
  private placeCamera(): void {
    if (this.w <= 0 || (this.interactive && this.userMoved)) {
      return;
    }
    const u = this.scene.user;
    if (this.follow && u !== undefined) {
      const s = this.followScale;
      // Keep the dot in the visible band between the insets.
      const band = (this.topInset - this.bottomInset) / 2;
      this.cam = new Camera(u.x, u.y + band / s, s);
      return;
    }
    if (this.bounds.length === 4) {
      this.cam = fitBounds(this.bounds, this.w, this.boxHeight, FIT_PAD, this.topInset, this.bottomInset);
    }
  }

  /** A map layer finished building (incremental, off the critical frame): redraw with it. */
  private onPathsReady = (): void => {
    this.draw(false);
  };

  aboutToDisappear(): void {
    this.renderer.release();
  }

  private draw(fast: boolean): void {
    if (!this.ready || this.w <= 0) {
      return;
    }
    try {
      this.renderer.setMap(this.map, this.onPathsReady);
      const ms = this.renderer.draw(this.ctx, this.w, this.boxHeight, this.cam, this.scene, this.palette(), fast,
        false, this.places, this.lodScale);
      this.frames++;
      if (this.frames % 30 === 1 || ms > 33) {
        Log.i(MAP_FRAME, `id=${this.mapId} ms=${ms} s=${this.cam.s.toFixed(2)} layers=${this.renderer.layerCount()} ` +
          `base=${this.renderer.hasBase() ? 'vector' : 'none'} fast=${fast} n=${this.frames}` +
          (this.places !== undefined ? ` dots=${this.places.shown()}/${this.places.size()}` : ''));
      }
    } catch (e) {
      Log.e(MAP_FRAME, `id=${this.mapId} error ${Log.errKv(e as Object)}`);
    }
  }

  private recenter(): void {
    this.userMoved = false;
    this.placeCamera();
    this.draw(false);
  }

  build() {
    Stack({ alignContent: Alignment.BottomStart }) {
      Canvas(this.ctx)
        .width('100%')
        .height(this.boxHeight)
        .onReady(() => {
          this.ready = true;
          this.placeCamera();
          this.draw(false);
        })
        .gesture(GestureGroup(GestureMode.Parallel,
          PanGesture({ fingers: 1, distance: 4 })
            .onActionStart((e: GestureEvent) => {
              if (!this.interactive) {
                return;
              }
              this.gesturing = true;
              this.userMoved = true;
              this.panLastX = e.offsetX;
              this.panLastY = e.offsetY;
            })
            .onActionUpdate((e: GestureEvent) => {
              if (!this.interactive) {
                return;
              }
              this.cam = pan(this.cam, e.offsetX - this.panLastX, e.offsetY - this.panLastY);
              this.panLastX = e.offsetX;
              this.panLastY = e.offsetY;
              this.draw(true);
            })
            .onActionEnd(() => {
              this.gesturing = false;
              this.draw(false);
            }),
          PinchGesture({ fingers: 2 })
            .onActionStart(() => {
              if (!this.interactive) {
                return;
              }
              this.gesturing = true;
              this.userMoved = true;
              this.pinchStart = this.cam.copy();
            })
            .onActionUpdate((e: GestureEvent) => {
              if (!this.interactive) {
                return;
              }
              this.cam = zoomAt(this.pinchStart, e.scale, e.pinchCenterX, e.pinchCenterY, this.w, this.boxHeight);
              this.draw(true);
            })
            .onActionEnd(() => {
              this.gesturing = false;
              this.draw(false);
            })))
        // Double tap zooms, a single tap picks a place dot; exclusive, double first (doc faqs-arkui-306), so a
        // double tap never also selects. Tap point: fingerList[0].localX/Y (doc faqs-arkui-4).
        .gesture(GestureGroup(GestureMode.Exclusive,
          TapGesture({ count: 2 }).onAction((e: GestureEvent) => {
            if (!this.interactive) {
              return;
            }
            this.userMoved = true;
            this.cam = zoomAt(this.cam, 2, this.w / 2, this.boxHeight / 2, this.w, this.boxHeight);
            this.draw(false);
          }),
          TapGesture({ count: 1 }).onAction((e: GestureEvent) => {
            if (!this.interactive || this.places === undefined || e.fingerList.length === 0) {
              return;
            }
            this.onTapPlace(this.places.hit(e.fingerList[0].localX, e.fingerList[0].localY));
          })))

      if (this.map !== undefined) {
        Text($r('app.string.map_attribution'))
          .fontSize(10)
          .fontColor($r('app.color.text_secondary'))
          .padding({ left: 6, right: 6, top: 2, bottom: 2 })
          .borderRadius(6)
          .backgroundColor($r('app.color.bg_scrim'))
          .margin({ left: 8, bottom: 6 + this.bottomInset })
          .accessibilityText($r('app.string.map_attribution'))
      }

      if (this.interactive && this.userMoved) {
        Row() {
          Blank()
          Button({ type: ButtonType.Circle, buttonStyle: ButtonStyleMode.NORMAL }) {
            SymbolGlyph($r('sys.symbol.location_up_fill'))
              .fontSize(20)
              .fontColor([$r('app.color.accent')])
          }
          .id('btnRecenter')
          .width(44)
          .height(44)
          .backgroundColor($r('app.color.bg_surface'))
          .shadow(ShadowStyle.OUTER_DEFAULT_XS)
          .accessibilityText($r('app.string.map_recenter'))
          .onClick(() => this.recenter())
        }
        .width('100%')
        .padding({ right: 12, bottom: 12 + this.bottomInset })
      }
    }
    .id(this.mapId)
    .width('100%')
    .height(this.boxHeight)
    .clip(true)
    .backgroundColor($r('app.color.map_land'))
    .onAreaChange((oldArea: Area, newArea: Area) => {
      this.w = newArea.width as number;
    })
  }
}

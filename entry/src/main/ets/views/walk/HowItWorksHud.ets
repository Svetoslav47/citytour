/*
 * "How it works" HUD (task B12, docs/DESIGN.md §3.6 HUD block, docs/OPPORTUNITIES.md §3.2): a translucent card over
 * the Now Walking map that shows every platform capability live, one row each: location source (Location Kit or the
 * SIMULATED Demo walk), course/speed, next stop + bearing, trigger radii, route (off-route / turn cue), voice,
 * AVSession, continuous task. Rows come from the pure, unit-tested core/hud/HudRows; every value is read from the
 * EngineSnapshot (or "n/a"). Toggled from the Now Walking ⋯ menu; the on/off state lives for the app session
 * (AppStorageV2 key 'hud'). Ids: hudHowItWorks, hudRow_<key>.
 * Docs: AppStorageV2 (开发指南/.../状态管理_V2/管理应用拥有的状态/AppStorageV2_应用全局UI状态存储/arkts-new-appstoragev2,
 * API 12); backgroundBlurStyle COMPONENT_THICK as on the header capsule (API 10+).
 */
import { AppStorageV2 } from '@kit.ArkUI';
import { EngineSnapshot } from 'common';
import { Poi, Tour, TourStop } from 'common';
import { AppContainer } from '../../app/AppContainer';
import { Log } from '../../app/Log';
import { LogEvents } from 'common';
import { HudInput, HudRow, HudTone, hudRows, TriggerRadii, triggerRadii } from 'common';
import { TourConfig } from 'common';
import { findTour, safePoi } from '../../viewmodel/PackView';
import { Radius, Space, TABULAR, Type } from '../common/Tokens';

const HUD_KEY: string = 'hud';
const LABEL_W: number = 78;

/** HUD visibility for the app session (DESIGN: "remembers its state per session"). */
@ObservedV2
export class HudPrefs {
  @Trace visible: boolean = false;

  private static fallback: HudPrefs | undefined = undefined;

  static get(): HudPrefs {
    try {
      const p = AppStorageV2.connect(HudPrefs, HUD_KEY, () => new HudPrefs());
      if (p !== undefined) {
        return p;
      }
    } catch (e) {
      Log.e(LogEvents.UNCAUGHT, `where=HudPrefs.get ${Log.errKv(e as Object)}`);
    }
    if (HudPrefs.fallback === undefined) {
      HudPrefs.fallback = new HudPrefs();
    }
    return HudPrefs.fallback;
  }
}

/** The next stop's trigger radii as the engine builds them (pack + the tour options' TourConfig); undefined if unknown. */
function nextTrigger(snap: EngineSnapshot | undefined): TriggerRadii | undefined {
  if (snap === undefined || snap.next === undefined) {
    return undefined;
  }
  try {
    const pack = AppContainer.packRepository();
    const poiId: string = snap.next.poiId;
    const poi: Poi | undefined = safePoi(pack, poiId);
    const tour: Tour | undefined = findTour(pack, snap.tourId);
    const stop: TourStop | undefined = tour === undefined ? undefined :
      tour.stops.find((s: TourStop) => s.poiId === poiId);
    const cfg: TourConfig | undefined = AppContainer.tourController().options().config;
    return triggerRadii(stop, poi, cfg !== undefined ? cfg : new TourConfig());
  } catch (e) {
    Log.e(LogEvents.UNCAUGHT, `where=HowItWorksHud.nextTrigger ${Log.errKv(e as Object)}`);
    return undefined;
  }
}

/** Builds the HUD rows for one snapshot; never throws (all rows "n/a" on error). */
export function hudRowsFor(snap: EngineSnapshot | undefined, nextName: string, demoSpeed: number): HudRow[] {
  let server: string | undefined = undefined;
  try {
    server = AppContainer.remoteVoice().hudText();
  } catch (e) {
    server = undefined;
  }
  const input: HudInput = {
    snap: snap, nextName: nextName, demoSpeed: demoSpeed, trigger: nextTrigger(snap), server: server
  };
  try {
    return hudRows(input);
  } catch (e) {
    Log.e(LogEvents.UNCAUGHT, `where=HowItWorksHud.rows ${Log.errKv(e as Object)}`);
    const none: HudInput = { snap: undefined, nextName: '', demoSpeed: Number.NaN, trigger: undefined };
    return hudRows(none);
  }
}

function toneColor(t: HudTone): Resource {
  switch (t) {
    case HudTone.OK:
      return $r('app.color.accent');
    case HudTone.WARN:
    case HudTone.SIM:
      return $r('app.color.signal_simulated_fg');
    case HudTone.OFF:
      return $r('app.color.signal_error');
    default:
      return $r('app.color.text_tertiary');
  }
}

@ComponentV2
export struct HowItWorksHud {
  @Param rows: HudRow[] = [];

  build() {
    Column({ space: Space.S1 }) {
      Row({ space: Space.S2 }) {
        SymbolGlyph($r('sys.symbol.info_circle'))
          .fontSize(14)
          .fontColor([$r('app.color.text_secondary')])
        Text($r('app.string.hud_title'))
          .fontSize(Type.CAPTION)
          .lineHeight(Type.CAPTION_LH)
          .fontWeight(FontWeight.Medium)
          .letterSpacing(Type.OVERLINE_SPACING)
          .fontColor($r('app.color.text_secondary'))
          .layoutWeight(1)
        Text($r('app.string.hud_live'))
          .fontSize(Type.CAPTION)
          .lineHeight(Type.CAPTION_LH)
          .fontColor($r('app.color.text_tertiary'))
      }
      .width('100%')
      .margin({ bottom: 2 })

      ForEach(this.rows, (r: HudRow) => {
        Row({ space: Space.S2 }) {
          Circle()
            .width(6)
            .height(6)
            .fill(toneColor(r.tone))
            .margin({ top: 5 })
          Text(r.label)
            .width(LABEL_W)
            .fontSize(Type.CAPTION)
            .lineHeight(Type.CAPTION_LH)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.text_secondary'))
            .maxLines(1)
          Text(r.value)
            .layoutWeight(1)
            .fontSize(Type.CAPTION)
            .lineHeight(Type.CAPTION_LH)
            .fontFeature(TABULAR)
            .fontColor($r('app.color.text_primary'))
            .maxLines(2)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
        .id(`hudRow_${r.key}`)
        .width('100%')
        .alignItems(VerticalAlign.Top)
        .accessibilityGroup(true)
        .accessibilityText(`${r.label}: ${r.value}`)
      }, (r: HudRow) => `${r.key}|${r.tone}|${r.value}`)
    }
    .id('hudHowItWorks')
    .width('100%')
    .constraintSize({ maxWidth: 480 })
    .padding({ left: Space.S3, right: Space.S3, top: Space.S2, bottom: Space.S3 })
    .borderRadius(Radius.MD)
    .backgroundColor($r('app.color.bg_scrim'))
    .backgroundBlurStyle(BlurStyle.COMPONENT_THICK)
    .shadow(ShadowStyle.OUTER_DEFAULT_XS)
  }
}

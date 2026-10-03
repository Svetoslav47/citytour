/*
 * Place detail (B8, DESIGN §3.8): "why should I trust this?" answered on screen. A 4:3 offline map snippet
 * centred on the place (the pack has no photos), overline (stop number + kind),
 * name (+ Polish name), the provenance chips (TierLabel), the reviewed "where to look" box for tour stops, the
 * transcript (selectable), numbered sources with licences, and the AI / extract note. Missing narration never
 * gives an empty screen: the fallback tier label and a plain note show instead. "Tell me more" only at the stop
 * being visited (TourControl.more).
 */
import { ContentTier, PoiKind } from '../contracts/Model';
import { Log } from '../app/Log';
import { LogEvents } from '../app/LogEvents';
import { AppViewModel } from '../viewmodel/AppViewModel';
import { PlaceViewModel } from '../viewmodel/PlaceViewModel';
import { SafeArea } from '../viewmodel/SafeArea';
import { FloatingIconButton } from '../views/common/FloatingIconButton';
import { MapCanvas } from '../views/map/MapCanvas';
import { Radius, Size, Space, Type } from '../views/common/Tokens';
import { LookBox } from '../views/place/LookBox';
import { SourcesList } from '../views/place/SourcesList';
import { TierLabel } from '../views/place/TierLabel';

export function kindLabel(kind: PoiKind): Resource {
  switch (kind) {
    case PoiKind.MONUMENT:
      return $r('app.string.kind_monument');
    case PoiKind.CHURCH:
      return $r('app.string.kind_church');
    case PoiKind.CASTLE:
      return $r('app.string.kind_castle');
    case PoiKind.SQUARE:
      return $r('app.string.kind_square');
    case PoiKind.GATE:
      return $r('app.string.kind_gate');
    case PoiKind.MUSEUM:
      return $r('app.string.kind_museum');
    case PoiKind.BUILDING:
      return $r('app.string.kind_building');
    case PoiKind.PLAQUE:
      return $r('app.string.kind_plaque');
    case PoiKind.VIEWPOINT:
      return $r('app.string.kind_viewpoint');
    case PoiKind.SYNAGOGUE:
      return $r('app.string.kind_synagogue');
    default:
      return $r('app.string.kind_other');
  }
}

@ComponentV2
export struct PlaceDetailPage {
  @Param poiId: string = '';
  @Local app: AppViewModel = AppViewModel.get();
  @Local vm: PlaceViewModel = new PlaceViewModel();
  @Local pageW: number = 0;
  /** Window avoid areas (edge-to-edge window, issue #63): the map snippet runs under the status bar, the back
   * button sits below it and the text ends clear of the navigation indicator. */
  @Local sa: SafeArea = SafeArea.get();

  aboutToAppear(): void {
    this.vm.load(this.poiId, this.app.textLang);
  }

  @Builder
  sectionHeader(label: Resource) {
    Text(label)
      .fontSize(Type.CAPTION)
      .lineHeight(Type.CAPTION_LH)
      .fontWeight(FontWeight.Medium)
      .letterSpacing(Type.OVERLINE_SPACING)
      .textCase(TextCase.UpperCase)
      .fontColor($r('app.color.text_secondary'))
      .margin({ left: Space.S1 })
  }

  @Builder
  note() {
    Row({ space: Space.S2 }) {
      SymbolGlyph($r('sys.symbol.info_circle'))
        .fontSize(14)
        .fontColor([$r('app.color.text_secondary')])
      if (this.vm.tier === ContentTier.REVIEWED_HISTORIAN || this.vm.tier === ContentTier.GROUNDED_AI) {
        Text(this.vm.reviewedAt !== '' ? $r('app.string.place_ai_note', this.vm.reviewedAt) :
          $r('app.string.about_ai_model'))
          .fontSize(Type.FOOTNOTE)
          .lineHeight(Type.FOOTNOTE_LH)
          .fontColor($r('app.color.text_secondary'))
          .layoutWeight(1)
      } else if (this.vm.tier === ContentTier.SOURCE_EXTRACT) {
        Text($r('app.string.place_extract_note'))
          .fontSize(Type.FOOTNOTE)
          .lineHeight(Type.FOOTNOTE_LH)
          .fontColor($r('app.color.text_secondary'))
          .layoutWeight(1)
      } else {
        Text($r('app.string.place_basic_note'))
          .fontSize(Type.FOOTNOTE)
          .lineHeight(Type.FOOTNOTE_LH)
          .fontColor($r('app.color.text_secondary'))
          .layoutWeight(1)
      }
    }
    .alignItems(VerticalAlign.Top)
    .width('100%')
    .padding({ left: Space.S1, right: Space.S1 })
  }

  @Builder
  content() {
    Column({ space: 20 }) {
      Column({ space: 2 }) {
        Text() {
          if (this.vm.stopNumber > 0) {
            Span($r('app.string.place_stop_overline', this.vm.stopNumber))
            Span(' · ')
          }
          Span(kindLabel(this.vm.kind))
        }
        .fontSize(Type.CAPTION)
        .lineHeight(Type.CAPTION_LH)
        .fontWeight(FontWeight.Medium)
        .letterSpacing(Type.OVERLINE_SPACING)
        .textCase(TextCase.UpperCase)
        .fontColor($r('app.color.text_secondary'))
        Text(this.vm.name)
          .id('placeName')
          .fontSize(Type.TITLE1)
          .lineHeight(Type.TITLE1_LH)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.text_primary'))
          .margin({ top: 6 })
        if (this.vm.localNamePl !== '') {
          Text(this.vm.localNamePl)
            .fontSize(Type.CALLOUT)
            .lineHeight(Type.CALLOUT_LH)
            .fontColor($r('app.color.text_secondary'))
        }
      }
      .alignItems(HorizontalAlign.Start)
      .width('100%')

      TierLabel({
        tier: this.vm.tier,
        sources: this.vm.sources.length,
        fromWikipedia: this.vm.fromWikipedia,
        machineTranslated: this.vm.machineTranslated,
        shownInEnglish: this.vm.shownInEnglish
      })

      if (this.vm.currentStop) {
        Button($r('app.string.cta_tell_more'), { type: ButtonType.Capsule, buttonStyle: ButtonStyleMode.NORMAL })
          .id('btnTellMore')
          .height(Size.BUTTON_H)
          .fontColor($r('app.color.text_primary'))
          .onClick(() => this.vm.tellMore())
      }

      if (this.vm.look !== undefined) {
        LookBox({ look: this.vm.look, feature: this.vm.lookFeature })
      }

      if (this.vm.paragraphs.length > 0) {
        Column({ space: Space.S3 }) {
          this.sectionHeader($r('app.string.place_transcript'))
          ForEach(this.vm.paragraphs, (p: string) => {
            Text(p)
              .fontSize(Type.TRANSCRIPT)
              .lineHeight(Type.TRANSCRIPT_LH)
              .fontColor($r('app.color.text_primary'))
              .copyOption(CopyOptions.LocalDevice)
              .width('100%')
          }, (p: string, i: number) => `${i}:${p.length}`)
        }
        .id('placeTranscript')
        .alignItems(HorizontalAlign.Start)
        .width('100%')
      }

      if (this.vm.sources.length > 0) {
        Column({ space: Space.S2 }) {
          this.sectionHeader($r('app.string.place_sources'))
          SourcesList({ rows: this.vm.sources })
        }
        .alignItems(HorizontalAlign.Start)
        .width('100%')
      }

      this.note()

      Text($r('app.string.place_see_sources'))
        .id('btnAboutSources')
        .fontSize(Type.CALLOUT)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.accent'))
        .padding({ left: Space.S1, top: Space.S2, bottom: Space.S2 })
        .onClick(() => this.app.openAbout())

      Column().height(Space.S6)
    }
    .alignItems(HorizontalAlign.Start)
    .width('100%')
    .constraintSize({ maxWidth: Size.PAGE_MAX_W })
    .padding({ left: Space.S4, right: Space.S4, top: Space.S5 })
  }

  build() {
    NavDestination() {
      Scroll() {
        Column() {
          // No photos in the pack: the 4:3 map snippet centred on the place stands in (DESIGN §3.8), with the
          // back button floating over it as on Tour detail.
          Stack({ alignContent: Alignment.TopStart }) {
            if (this.vm.found && this.pageW > 0) {
              MapCanvas({ map: this.vm.map, scene: this.vm.scene, bounds: this.vm.sceneBounds,
                boxHeight: Math.round(this.pageW * 3 / 4) + this.sa.top, topInset: this.sa.top, mapId: 'mapPlace' })
                .accessibilityText($r('app.string.place_map_a11y', this.vm.name))
            }
            FloatingIconButton({
              symbol: $r('sys.symbol.chevron_backward'),
              label: $r('app.string.a11y_back'),
              buttonId: 'btnBackPlace',
              onTap: () => this.app.back()
            })
              .margin({ left: Space.S2 + this.sa.left, top: Space.S2 + this.sa.top })
          }
          .width('100%')

          if (this.vm.found) {
            this.content()
          } else {
            Text($r('app.string.place_not_found'))
              .fontSize(Type.BODY)
              .fontColor($r('app.color.text_secondary'))
              .padding(Space.S4)
          }
        }
        .width('100%')
        .padding({ bottom: this.sa.bottom })
      }
      .scrollBar(BarState.Off)
      .align(Alignment.Top)
      .width('100%')
      .height('100%')
      .onAreaChange((oldArea: Area, newArea: Area) => {
        this.pageW = Math.min(newArea.width as number, Size.PAGE_MAX_W);
      })
    }
    .id('pagePlace')
    .hideTitleBar(true)
    .backgroundColor($r('app.color.bg_canvas'))
    .onShown(() => {
      Log.i(LogEvents.APP_PAGE, `page=PlaceDetail shown poi=${this.poiId} tier=${this.vm.tier}`);
    })
  }
}

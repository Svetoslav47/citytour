/*
 * Place card (B13, DESIGN §3.7): the sheet content shown when a place dot is tapped on the full map. Kind,
 * name, distance from you (only when the tour knows where you are), a 2-line teaser, the provenance label, and
 * Details -> Place detail. Text comes from PlaceViewModel (validated pack narration, fallback chain of B3), so a
 * name-only place shows its plain description and the "Basic info" label rather than an empty card.
 */
import { Lang } from '../../contracts/Model';
import { AppContainer } from '../../app/AppContainer';
import { Log } from '../../app/Log';
import { distanceRes } from '../../viewmodel/Format';
import { PlaceViewModel } from '../../viewmodel/PlaceViewModel';
import { kindLabel } from '../../pages/PlaceDetailPage';
import { Size, Space, Type } from '../common/Tokens';
import { TierLabel } from '../place/TierLabel';

const MAP_PLACE: string = 'MAP_PLACE';

@ComponentV2
export struct PlaceCardSheet {
  @Param poiId: string = '';
  @Param lang: Lang = Lang.EN;
  @Event onDetails: (poiId: string) => void = (poiId: string) => {};
  @Local vm: PlaceViewModel = new PlaceViewModel();
  @Local distM: number = Number.NaN;

  aboutToAppear(): void {
    this.load();
  }

  @Monitor('poiId', 'lang')
  onPlace(): void {
    this.load();
  }

  private load(): void {
    if (this.poiId === '') {
      return;
    }
    const vm = new PlaceViewModel();
    vm.load(this.poiId, this.lang);
    this.vm = vm;
    this.distM = Number.NaN;
    try {
      const u = AppContainer.tourControl().current().user;
      const p = AppContainer.packRepository().poi(this.poiId);
      if (u !== undefined && p !== undefined && Number.isFinite(u.x) && Number.isFinite(u.y)) {
        this.distM = Math.hypot(p.x - u.x, p.y - u.y);
      }
    } catch (e) {
      this.distM = Number.NaN;
    }
    Log.i(MAP_PLACE, `poi=${this.poiId} found=${vm.found} tier=${vm.tier} ` +
      `distM=${Number.isFinite(this.distM) ? Math.round(this.distM) : 'none'}`);
  }

  build() {
    Column({ space: Space.S2 }) {
      if (!this.vm.found) {
        Text($r('app.string.place_not_found'))
          .fontSize(Type.BODY)
          .fontColor($r('app.color.text_secondary'))
      } else {
        Row({ space: Space.S2 }) {
          Text(kindLabel(this.vm.kind))
            .fontSize(Type.CALLOUT)
            .fontColor($r('app.color.text_secondary'))
          if (Number.isFinite(this.distM)) {
            Text('·')
              .fontSize(Type.CALLOUT)
              .fontColor($r('app.color.text_tertiary'))
            Text(distanceRes(this.distM))
              .fontSize(Type.CALLOUT)
              .fontColor($r('app.color.text_secondary'))
          }
        }

        Text(this.vm.name)
          .id('placeCardName')
          .fontSize(Type.TITLE3)
          .lineHeight(Type.TITLE3_LH)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.text_primary'))
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })

        if (this.vm.paragraphs.length > 0) {
          Text(this.vm.paragraphs[0])
            .fontSize(Type.CALLOUT)
            .lineHeight(Type.CALLOUT_LH)
            .fontColor($r('app.color.text_secondary'))
            .maxLines(2)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }

        TierLabel({
          tier: this.vm.tier,
          sources: this.vm.sources.length,
          fromWikipedia: this.vm.fromWikipedia,
          machineTranslated: this.vm.machineTranslated,
          shownInEnglish: this.vm.shownInEnglish
        })

        Button($r('app.string.place_card_details'), { type: ButtonType.Capsule, buttonStyle: ButtonStyleMode.EMPHASIZED })
          .id('btnPlaceDetails')
          .height(Size.BUTTON_H)
          .width('100%')
          .margin({ top: Space.S2 })
          .fontSize(Type.BODY)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.on_accent'))
          .backgroundColor($r('app.color.accent'))
          .onClick(() => this.onDetails(this.poiId))
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .padding({ left: Space.S4, right: Space.S4, top: Space.S2, bottom: Space.S4 })
  }
}

/*
 * Provenance label for a story (ARCHITECTURE §7.4 tier labels, DESIGN §3.8): what the visitor reads and how it
 * was made. Shown at the top of Place detail; "Machine-translated" and "Shown in English" are extra chips.
 */
import { ContentTier } from '../../contracts/Model';
import { Radius, Type } from '../common/Tokens';

export function tierLabel(tier: ContentTier, sources: number, fromWikipedia: boolean): Resource {
  switch (tier) {
    case ContentTier.REVIEWED_HISTORIAN:
      return $r('app.string.place_tier_reviewed', sources);
    case ContentTier.GROUNDED_AI:
      return $r('app.string.place_tier_grounded');
    case ContentTier.SOURCE_EXTRACT:
      return fromWikipedia ? $r('app.string.place_tier_wikipedia') : $r('app.string.place_tier_register');
    default:
      return $r('app.string.place_tier_basic');
  }
}

@ComponentV2
export struct TierLabel {
  @Param tier: ContentTier = ContentTier.NAME_ONLY;
  @Param sources: number = 0;
  @Param fromWikipedia: boolean = false;
  @Param machineTranslated: boolean = false;
  @Param shownInEnglish: boolean = false;

  @Builder
  chip(label: Resource, strong: boolean, id: string) {
    Row({ space: 4 }) {
      if (strong) {
        SymbolGlyph($r('sys.symbol.checkmark_circle_fill'))
          .fontSize(14)
          .fontColor([$r('app.color.accent')])
      }
      Text(label)
        .fontSize(Type.CAPTION)
        .fontWeight(FontWeight.Medium)
        .fontColor(strong ? $r('app.color.accent') : $r('app.color.text_secondary'))
    }
    .id(id)
    .height(28)
    .padding({ left: 10, right: 10 })
    .borderRadius(Radius.SM)
    .backgroundColor(strong ? $r('app.color.accent_subtle') : Color.Transparent)
    .border({ width: strong ? 0 : 1, color: $r('app.color.divider') })
  }

  build() {
    Flex({ wrap: FlexWrap.Wrap }) {
      this.chip(tierLabel(this.tier, this.sources, this.fromWikipedia),
        this.tier === ContentTier.REVIEWED_HISTORIAN, 'chipTier')
      if (this.machineTranslated) {
        Column() {
          this.chip($r('app.string.place_mt_label'), false, 'chipMt')
        }
        .margin({ left: 8 })
      }
      if (this.shownInEnglish) {
        Column() {
          this.chip($r('app.string.place_shown_in_en'), false, 'chipShownEn')
        }
        .margin({ left: 8 })
      }
    }
    .width('100%')
  }
}

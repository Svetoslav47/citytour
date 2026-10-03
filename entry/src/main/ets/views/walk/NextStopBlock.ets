/*
 * "Where next, how far, which way" (DESIGN §3.6): overline, stop name (title2, 2 lines), the hero distance
 * (display 34 fp, tabular, max font scale 1.6) or the look phrase at a stop, the ETA, and the Look cue.
 */
import { Type } from '../common/Tokens';
import { LookCue } from './LookCue';

@ComponentV2
export struct NextStopBlock {
  @Param overline: ResourceStr = '';
  @Param title: ResourceStr = '';
  /** Hero text: a distance ("180 m"), "—" with no GPS, or '' to hide. */
  @Param hero: ResourceStr = '';
  /** True when the hero is the look phrase (title3 instead of display). */
  @Param heroIsPhrase: boolean = false;
  @Param approx: boolean = false;
  @Param sub: ResourceStr = '';
  @Param dim: boolean = false;
  @Param showCue: boolean = true;
  @Param angleDeg: number = Number.NaN;
  @Param relDir: string = 'here';
  @Param lookUp: boolean = false;
  @Param landmark: string = '';
  @Param emphasised: boolean = false;

  build() {
    Column({ space: 2 }) {
      Text(this.overline)
        .id('walkOverline')
        .fontSize(Type.CAPTION)
        .lineHeight(Type.CAPTION_LH)
        .fontWeight(FontWeight.Medium)
        .letterSpacing(Type.OVERLINE_SPACING)
        .textCase(TextCase.UpperCase)
        .fontColor($r('app.color.text_secondary'))
      Text(this.title)
        .id('walkTitle')
        .fontSize(Type.TITLE2)
        .lineHeight(Type.TITLE2_LH)
        .fontWeight(FontWeight.Bold)
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .fontColor($r('app.color.text_primary'))

      Row({ space: 12 }) {
        Column({ space: 2 }) {
          if (this.hero !== '') {
            Text() {
              if (this.approx) {
                Span('~')
              }
              Span(this.hero)
            }
            .id('walkHero')
            .fontSize(this.heroIsPhrase ? Type.TITLE3 : Type.DISPLAY)
            .lineHeight(this.heroIsPhrase ? Type.TITLE3_LH : Type.DISPLAY_LH)
            .fontWeight(this.heroIsPhrase ? FontWeight.Medium : FontWeight.Bold)
            .fontFeature('"tnum" 1')
            .maxFontScale(1.6)
            .fontColor(this.dim ? $r('app.color.text_secondary') : $r('app.color.text_primary'))
          }
          if (this.sub !== '') {
            Text(this.sub)
              .fontSize(Type.CALLOUT)
              .lineHeight(Type.CALLOUT_LH)
              .fontColor($r('app.color.text_secondary'))
          }
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)

        if (this.showCue) {
          LookCue({
            angleDeg: this.angleDeg,
            relDir: this.relDir,
            lookUp: this.lookUp,
            landmark: this.landmark,
            emphasised: this.emphasised,
            dim: this.dim
          })
        }
      }
      .alignItems(VerticalAlign.Bottom)
      .width('100%')
      .margin({ top: 6 })
    }
    .alignItems(HorizontalAlign.Start)
    .width('100%')
    .accessibilityGroup(true)
  }
}

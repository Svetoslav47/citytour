/*
 * "Where to look" box for tour stops (DESIGN §3.8): the reviewed view hint (look up / ahead / down + the
 * feature). Directions relative to the visitor ("on your left") are never stored: they come from the walking
 * course at runtime, so this box only says what to look for.
 */
import { LookDir } from '../../contracts/Model';
import { Radius, Space, Type } from '../common/Tokens';

@ComponentV2
export struct LookBox {
  @Param look: LookDir = LookDir.LEVEL;
  @Param feature: string = '';

  private lookText(): Resource {
    if (this.look === LookDir.UP) {
      return $r('app.string.place_look_up');
    }
    if (this.look === LookDir.DOWN) {
      return $r('app.string.place_look_down');
    }
    return $r('app.string.place_look_level');
  }

  build() {
    Column({ space: 6 }) {
      Row({ space: 6 }) {
        SymbolGlyph($r('sys.symbol.eye'))
          .fontSize(14)
          .fontColor([$r('app.color.accent')])
        Text($r('app.string.place_look'))
          .fontSize(Type.CAPTION)
          .fontWeight(FontWeight.Medium)
          .letterSpacing(Type.OVERLINE_SPACING)
          .textCase(TextCase.UpperCase)
          .fontColor($r('app.color.accent'))
        Blank()
        if (this.look === LookDir.UP) {
          SymbolGlyph($r('sys.symbol.arrow_up'))
            .fontSize(18)
            .fontColor([$r('app.color.accent')])
        }
      }
      .width('100%')
      Text() {
        Span(this.lookText())
        if (this.feature !== '') {
          Span(': ')
          Span(this.feature)
        }
        Span('.')
      }
      .fontSize(17)
      .lineHeight(25)
      .fontColor($r('app.color.text_primary'))
    }
    .id('boxLook')
    .alignItems(HorizontalAlign.Start)
    .width('100%')
    .padding(Space.S4)
    .borderRadius(Radius.LG)
    .backgroundColor($r('app.color.accent_subtle'))
    .accessibilityGroup(true)
  }
}

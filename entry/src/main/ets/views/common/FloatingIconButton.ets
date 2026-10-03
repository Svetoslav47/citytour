/*
 * 40 vp circular icon button that floats over the map (back, expand, attribution), with a 48 vp hit area and
 * the scrim material (DESIGN §4.5: blur only on the floating functional layer).
 */
import { Size } from './Tokens';

@ComponentV2
export struct FloatingIconButton {
  @Param symbol: Resource = $r('sys.symbol.chevron_backward');
  @Param label: Resource = $r('app.string.a11y_back');
  @Param buttonId: string = '';
  @Param diameter: number = Size.ICON_BUTTON;
  @Event onTap: () => void = () => {};

  build() {
    Stack() {
      Stack() {
        SymbolGlyph(this.symbol)
          .fontSize(this.diameter >= 40 ? 20 : 16)
          .fontColor([$r('app.color.text_primary')])
      }
      .width(this.diameter)
      .height(this.diameter)
      .borderRadius(this.diameter / 2)
      .backgroundColor($r('app.color.bg_scrim'))
      .backgroundBlurStyle(BlurStyle.COMPONENT_THICK)
      .shadow(ShadowStyle.OUTER_DEFAULT_XS)
    }
    .id(this.buttonId)
    .width(Size.TOUCH)
    .height(Size.TOUCH)
    .accessibilityText(this.label)
    .onClick(() => this.onTap())
  }
}

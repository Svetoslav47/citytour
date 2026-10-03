/*
 * The amber SIMULATED pill (DESIGN §3.6, §4.1 signal.simulated). Shown on every surface while the Demo walk
 * (or any other simulated input) is active. Amber means simulated or warning, never brand.
 */
import { Type } from './Tokens';

@ComponentV2
export struct SimulatedBadge {
  /** When false nothing is rendered, so callers can bind it straight to `snapshot.source === DEMO`. */
  @Param visible: boolean = true;
  /** Optional: tapping opens the Demo controls sheet (B5). */
  @Param tappable: boolean = false;
  @Event onTap: () => void = () => {};

  build() {
    if (this.visible) {
      Row({ space: 4 }) {
        SymbolGlyph($r('sys.symbol.figure_walk'))
          .fontSize(14)
          .fontColor([$r('app.color.signal_simulated_fg')])
        Text($r('app.string.label_simulated'))
          .fontSize(Type.CAPTION)
          .lineHeight(Type.CAPTION_LH)
          .fontWeight(FontWeight.Medium)
          .letterSpacing(Type.OVERLINE_SPACING)
          .fontColor($r('app.color.signal_simulated_fg'))
      }
      .id('badgeSimulated')
      .height(28)
      .padding({ left: 10, right: 12 })
      .borderRadius(14)
      .backgroundColor($r('app.color.signal_simulated_bg'))
      .accessibilityGroup(true)
      .accessibilityText(this.tappable ? $r('app.string.label_demo_walk_a11y') : $r('app.string.label_simulated_a11y'))
      .onClick(() => {
        if (this.tappable) {
          this.onTap();
        }
      })
    }
  }
}

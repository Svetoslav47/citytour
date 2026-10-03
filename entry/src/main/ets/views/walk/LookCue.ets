/*
 * The Look cue (DESIGN §3.6.1): a 72 vp top half-arc relative to the walking direction with one accent dot at
 * the target's relative bearing (-90 left, 0 ahead, +90 right; behind -> bottom + chevron), an "up" arrow when
 * the script says to look up, and the caption in the same words as the voice. No angle -> landmark mode
 * ("Face St Mary's Basilica"). Geometry: core/map/WalkDisplay.dialDot (unit-tested).
 */
import { DialDot, dialDot } from '../../core/map/WalkDisplay';
import { Type } from '../common/Tokens';

const SIZE: number = 72;
const CX: number = 36;
const CY: number = 38;
const R: number = 30;
const DOT: number = 12;

/** Caption resource for the engine's direction bucket (same words as the voice). */
export function relDirCaption(relDir: string): Resource {
  switch (relDir) {
    case 'ahead':
      return $r('app.string.dir_ahead');
    case 'aheadRight':
      return $r('app.string.dir_ahead_right');
    case 'right':
      return $r('app.string.dir_right');
    case 'behindRight':
      return $r('app.string.dir_behind_right');
    case 'behind':
      return $r('app.string.dir_behind');
    case 'behindLeft':
      return $r('app.string.dir_behind_left');
    case 'left':
      return $r('app.string.dir_left');
    case 'aheadLeft':
      return $r('app.string.dir_ahead_left');
    default:
      return $r('app.string.dir_here');
  }
}

@ComponentV2
export struct LookCue {
  /** Relative bearing in degrees; NaN = landmark mode. */
  @Param angleDeg: number = Number.NaN;
  @Param relDir: string = 'here';
  @Param lookUp: boolean = false;
  @Param landmark: string = '';
  /** Approaching: the dot gets a ring. */
  @Param emphasised: boolean = false;
  /** Paused / weak GPS: dimmed. */
  @Param dim: boolean = false;

  private dot(): DialDot {
    return dialDot(this.angleDeg, CX, CY, R, 22);
  }

  build() {
    Column({ space: 2 }) {
      if (this.dot().valid) {
        Stack({ alignContent: Alignment.TopStart }) {
          // Top half of a circle = the arc.
          Column() {
            Circle({ width: 2 * R + 3, height: 2 * R + 3 })
              .fill(Color.Transparent)
              .stroke($r('app.color.divider'))
              .strokeWidth(3)
          }
          .width(2 * R + 3)
          .height(R + 2)
          .clip(true)
          .position({ x: CX - R - 1.5, y: CY - R - 1.5 })

          // "You" notch at the bottom centre.
          Column()
            .width(3)
            .height(8)
            .borderRadius(1.5)
            .backgroundColor($r('app.color.text_tertiary'))
            .position({ x: CX - 1.5, y: CY - 2 })

          if (this.dot().behind) {
            SymbolGlyph($r('sys.symbol.chevron_down'))
              .fontSize(12)
              .fontColor([$r('app.color.accent')])
              .position({ x: CX - 6, y: this.dot().y + 6 })
          }
          if (this.lookUp) {
            SymbolGlyph($r('sys.symbol.arrow_up'))
              .fontSize(10)
              .fontColor([$r('app.color.accent')])
              .position({ x: this.dot().x - 5, y: this.dot().y - 18 })
          }
          Column()
            .width(DOT)
            .height(DOT)
            .borderRadius(DOT / 2)
            .backgroundColor($r('app.color.accent'))
            .border({ width: this.emphasised ? 3 : 0, color: $r('app.color.accent_subtle') })
            .position({ x: this.dot().x - DOT / 2, y: this.dot().y - DOT / 2 })
            .animation({ duration: 200, curve: Curve.Friction })
        }
        .width(SIZE)
        .height(SIZE - 4)
        .opacity(this.dim ? 0.5 : 1)

        Text() {
          Span(relDirCaption(this.relDir))
          if (this.lookUp) {
            Span($r('app.string.walk_look_up'))   // carries its own separator: ", look up" / "，抬头看"
          }
        }
        .fontSize(Type.CAPTION)
        .lineHeight(Type.CAPTION_LH)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.text_secondary'))
        .textAlign(TextAlign.Center)
        .maxLines(2)
      } else if (this.landmark !== '') {
        Row({ space: 6 }) {
          SymbolGlyph($r('sys.symbol.figure_walk'))
            .fontSize(16)
            .fontColor([$r('app.color.accent')])
          Text($r('app.string.walk_face', this.landmark))
            .fontSize(Type.CAPTION)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.text_secondary'))
            .maxLines(2)
        }
      }
    }
    .id('lookCue')
    .constraintSize({ minWidth: SIZE, maxWidth: 140 })
    .accessibilityGroup(true)
  }
}

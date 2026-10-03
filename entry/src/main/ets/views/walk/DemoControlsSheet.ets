/*
 * Demo controls sheet content (DESIGN Flow G, §3.6 SIMULATED pill): replay speed 1/2/4/8 and "Jump to next
 * stop", labelled "Demo assist". Only reachable while the Demo walk (SIMULATED source) is active.
 * Ids: segSpeed1/2/4/8, btnJumpNext.
 */
import { Radius, Size, Space, Type } from '../common/Tokens';

const SPEEDS: number[] = [1, 2, 4, 8];

@ComponentV2
export struct DemoControlsSheet {
  @Param speed: number = 4;
  @Event onSpeed: (mult: number) => void = (mult: number) => {};
  @Event onJump: () => void = () => {};

  build() {
    Column({ space: Space.S3 }) {
      Row({ space: Space.S2 }) {
        SymbolGlyph($r('sys.symbol.figure_walk'))
          .fontSize(16)
          .fontColor([$r('app.color.signal_simulated_fg')])
        Text($r('app.string.label_demo_assist'))
          .fontSize(Type.CAPTION)
          .fontWeight(FontWeight.Medium)
          .letterSpacing(Type.OVERLINE_SPACING)
          .textCase(TextCase.UpperCase)
          .fontColor($r('app.color.signal_simulated_fg'))
      }
      .height(28)
      .padding({ left: 10, right: 12 })
      .borderRadius(14)
      .backgroundColor($r('app.color.signal_simulated_bg'))

      Text($r('app.string.demo_speed'))
        .fontSize(Type.CAPTION)
        .fontWeight(FontWeight.Medium)
        .letterSpacing(Type.OVERLINE_SPACING)
        .textCase(TextCase.UpperCase)
        .fontColor($r('app.color.text_secondary'))
        .margin({ top: Space.S2 })

      Row() {
        ForEach(SPEEDS, (x: number) => {
          Text(`${x}×`)
            .id(`segSpeed${x}`)
            .fontSize(Type.CALLOUT)
            .fontWeight(FontWeight.Medium)
            .fontFeature('"tnum" 1')
            .fontColor(x === this.speed ? $r('app.color.on_accent') : $r('app.color.text_secondary'))
            .textAlign(TextAlign.Center)
            .height(40)
            .layoutWeight(1)
            .borderRadius(20)
            .backgroundColor(x === this.speed ? $r('app.color.accent') : Color.Transparent)
            .animation({ duration: 150, curve: Curve.Sharp })
            .onClick(() => this.onSpeed(x))
        }, (x: number) => `${x}`)
      }
      .width('100%')
      .height(Size.TOUCH)
      .padding({ left: 4, right: 4 })
      .borderRadius(24)
      .backgroundColor($r('app.color.bg_surface_sunken'))

      Button({ type: ButtonType.Capsule, buttonStyle: ButtonStyleMode.NORMAL }) {
        Row({ space: Space.S2 }) {
          SymbolGlyph($r('sys.symbol.forward_end_fill'))
            .fontSize(18)
            .fontColor([$r('app.color.accent')])
          Text($r('app.string.demo_jump_next'))
            .fontSize(Type.BODY)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.accent'))
        }
      }
      .id('btnJumpNext')
      .width('100%')
      .height(Size.BUTTON_H)
      .backgroundColor($r('app.color.accent_subtle'))
      .margin({ top: Space.S2 })
      .onClick(() => this.onJump())

      Text($r('app.string.demo_assist_note'))
        .fontSize(Type.FOOTNOTE)
        .lineHeight(Type.FOOTNOTE_LH)
        .fontColor($r('app.color.text_secondary'))
    }
    .alignItems(HorizontalAlign.Start)
    .width('100%')
    .padding({ left: Space.S4, right: Space.S4, top: Space.S2, bottom: Space.S6 })
    .borderRadius(Radius.LG)
  }
}

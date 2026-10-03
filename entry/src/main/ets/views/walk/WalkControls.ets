/*
 * Replay 56 vp · Play/Pause 72 vp (accent) · Skip 56 vp (DESIGN §3.6 controls). No haptic on tap.
 * Ids: btnReplay, btnPlayPause, btnSkip.
 */
@ComponentV2
export struct WalkControls {
  @Param paused: boolean = false;
  @Param active: boolean = true;
  @Event onReplay: () => void = () => {};
  @Event onToggle: () => void = () => {};
  @Event onSkip: () => void = () => {};

  @Builder
  side(symbol: Resource, label: Resource, id: string, action: () => void) {
    Button({ type: ButtonType.Circle, buttonStyle: ButtonStyleMode.NORMAL }) {
      SymbolGlyph(symbol)
        .fontSize(24)
        .fontColor([$r('app.color.text_primary')])
    }
    .id(id)
    .width(56)
    .height(56)
    .backgroundColor($r('app.color.bg_surface_sunken'))
    .enabled(this.active)
    .accessibilityText(label)
    .onClick(() => action())
  }

  build() {
    Row({ space: 28 }) {
      this.side($r('sys.symbol.arrow_counterclockwise'), $r('app.string.walk_replay'), 'btnReplay',
        () => this.onReplay())
      Button({ type: ButtonType.Circle, buttonStyle: ButtonStyleMode.EMPHASIZED }) {
        SymbolGlyph(this.paused ? $r('sys.symbol.play_fill') : $r('sys.symbol.pause_fill'))
          .fontSize(32)
          .fontColor([$r('app.color.on_accent')])
      }
      .id('btnPlayPause')
      .width(72)
      .height(72)
      .backgroundColor($r('app.color.accent'))
      .enabled(this.active)
      .accessibilityText(this.paused ? $r('app.string.walk_play') : $r('app.string.walk_pause'))
      .onClick(() => this.onToggle())
      this.side($r('sys.symbol.forward_end_fill'), $r('app.string.walk_skip'), 'btnSkip', () => this.onSkip())
    }
    .justifyContent(FlexAlign.Center)
    .width('100%')
  }
}

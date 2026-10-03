/*
 * Numbered stop marker ("plaque"), inspired by Kraków's numbered street plaques (DESIGN §4.7).
 * Visual sizes per state; callers give the 48 vp hit area.
 */
export enum PlaqueState { UPCOMING = 'upcoming', NEXT = 'next', CURRENT = 'current', VISITED = 'visited',
  SKIPPED = 'skipped', NEUTRAL = 'neutral' }

@ComponentV2
export struct Plaque {
  @Param n: number = 1;
  @Param state: PlaqueState = PlaqueState.UPCOMING;

  private diameter(): number {
    if (this.state === PlaqueState.NEXT || this.state === PlaqueState.CURRENT) {
      return 34;
    }
    if (this.state === PlaqueState.VISITED || this.state === PlaqueState.SKIPPED) {
      return 24;
    }
    return 28;
  }

  private filled(): boolean {
    return this.state === PlaqueState.NEXT || this.state === PlaqueState.CURRENT;
  }

  build() {
    Stack() {
      if (this.state === PlaqueState.VISITED) {
        SymbolGlyph($r('sys.symbol.checkmark'))
          .fontSize(14)
          .fontColor([$r('app.color.bg_surface')])
      } else {
        Text(`${this.n}`)
          .fontSize(this.filled() ? 13 : 12)
          .fontWeight(FontWeight.Bold)
          .fontFeature('"tnum" 1')
          .fontColor(this.filled() ? $r('app.color.on_accent') :
            this.state === PlaqueState.UPCOMING ? $r('app.color.accent') :
              this.state === PlaqueState.NEUTRAL ? $r('app.color.text_primary') : $r('app.color.text_tertiary'))
      }
    }
    .width(this.diameter())
    .height(this.diameter())
    .borderRadius(this.diameter() / 2)
    .backgroundColor(this.filled() ? $r('app.color.accent') :
      this.state === PlaqueState.VISITED ? $r('app.color.text_tertiary') : $r('app.color.bg_surface'))
    .border({
      width: this.filled() ? 3 : this.state === PlaqueState.VISITED ? 0 : this.state === PlaqueState.UPCOMING ? 2 : 1.5,
      color: this.filled() ? $r('app.color.bg_surface') :
        this.state === PlaqueState.UPCOMING ? $r('app.color.accent') : $r('app.color.text_tertiary'),
      style: this.state === PlaqueState.SKIPPED ? BorderStyle.Dashed : BorderStyle.Solid
    })
  }
}

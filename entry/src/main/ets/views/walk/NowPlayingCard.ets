/*
 * "What am I hearing" (DESIGN §3.6): waveform glyph + story title, the current sentence (transcript 18 fp,
 * 3 lines), a thin progress bar through the sentences, and the teaser chip when walking past a stop.
 * Reading mode (Polish text-only) shows the full transcript at 20 fp instead.
 */
import { Radius, Space, Type } from '../common/Tokens';

@ComponentV2
export struct NowPlayingCard {
  @Param title: string = '';
  @Param caption: string = '';
  @Param sentenceIndex: number = 0;
  @Param sentenceCount: number = 0;
  @Param playing: boolean = true;
  @Param teaser: boolean = false;
  @Param reading: boolean = false;

  build() {
    Column({ space: Space.S2 }) {
      Row({ space: Space.S2 }) {
        SymbolGlyph($r('sys.symbol.waveform'))
          .fontSize(18)
          .fontColor([this.playing ? $r('app.color.accent') : $r('app.color.text_tertiary')])
        Text(this.title !== '' ? this.title : $r('app.string.walk_now_playing'))
          .fontSize(Type.BODY)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.text_primary'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .layoutWeight(1)
      }
      .width('100%')

      Text(this.caption)
        .id('walkCaption')
        .fontSize(this.reading ? 20 : Type.TRANSCRIPT)
        .lineHeight(this.reading ? 30 : Type.TRANSCRIPT_LH)
        .maxLines(this.reading ? 40 : 3)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .fontColor($r('app.color.text_primary'))
        .copyOption(CopyOptions.LocalDevice)
        .width('100%')

      if (this.sentenceCount > 1) {
        Progress({ value: Math.min(this.sentenceCount, this.sentenceIndex + 1), total: this.sentenceCount,
          type: ProgressType.Linear })
          .color($r('app.color.accent'))
          .backgroundColor($r('app.color.divider'))
          .style({ strokeWidth: 3 })
          .width('100%')
      }
      if (this.teaser) {
        Text($r('app.string.walk_short_version'))
          .fontSize(Type.CAPTION)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.accent'))
          .padding({ left: 10, right: 10, top: 4, bottom: 4 })
          .borderRadius(Radius.SM)
          .backgroundColor($r('app.color.accent_subtle'))
      }
    }
    .id('cardNowPlaying')
    .alignItems(HorizontalAlign.Start)
    .width('100%')
    .padding(Space.S4)
    .borderRadius(Radius.LG)
    .backgroundColor($r('app.color.bg_surface_sunken'))
    .accessibilityGroup(true)
  }
}

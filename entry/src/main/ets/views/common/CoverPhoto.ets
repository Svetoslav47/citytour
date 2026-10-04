/*
 * A tour cover photo (core/remote/CoverRules.ets): full-bleed Image (objectFit Cover, decoded off the UI thread),
 * and, with a title, a dark gradient at the bottom with the title on the photo. The photo credit (CC BY-SA:
 * author, licence, source) lives in Settings -> About, not on the photo. While the file loads, or when it
 * cannot be decoded, a neutral placeholder fills the same box, so the layout never jumps.
 * The gradient is black in both themes: the photo is the same picture in light and dark mode, and white text on it
 * needs the same contrast either way.
 * Doc: Image + sandbox file (FAQ faqs-arkui-154: pass fileUri.getUriFromPath, not the raw sandbox path).
 */
import { fileUri } from '@kit.CoreFileKit';
import { Log } from '../../app/Log';
import { LogEvents } from 'common';
import { Space, Type } from './Tokens';

function uriOf(path: string): string {
  if (path === '') {
    return '';
  }
  try {
    return fileUri.getUriFromPath(path);
  } catch (e) {
    Log.w(LogEvents.COURSE, `event=cover_uri_fail ${Log.errKv(e as Object)}`);
    return '';
  }
}

@ComponentV2
export struct CoverPhoto {
  /** Absolute path of the JPEG; '' = placeholder only (still loading). */
  @Param path: string = '';
  /** Alt text: what the photo shows. */
  @Param alt: Resource = $r('app.string.about_cover_title');
  /** Optional title drawn on the photo (Tour detail hero). */
  @Param title: string = '';
  /** Fixed height in vp; 0 = follow `ratio` (width / height). */
  @Param boxHeight: number = 0;
  @Param ratio: number = 16 / 10;
  /** Left/right (and, with a title, bottom) padding of the text on the photo. */
  @Param textPadding: number = Space.S4;
  @Param photoId: string = '';
  @Local failed: boolean = false;
  @Local boxWidth: number = 0;

  @Monitor('path')
  onPathChanged(): void {
    this.failed = false;
  }

  private heightVp(): number {
    if (this.boxHeight > 0) {
      return this.boxHeight;
    }
    return this.boxWidth > 0 && this.ratio > 0 ? this.boxWidth / this.ratio : 0;
  }

  build() {
    Stack({ alignContent: Alignment.BottomStart }) {
      // Placeholder (loading or undecodable): the sunken surface colour, same box.
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor($r('app.color.bg_surface_sunken'))
      if (this.path !== '' && !this.failed) {
        Image(uriOf(this.path))
          .width('100%')
          .height('100%')
          .objectFit(ImageFit.Cover)
          .syncLoad(false)
          .draggable(false)
          .accessibilityText(this.alt)
          .onError((e: ImageError) => {
            this.failed = true;
            Log.w(LogEvents.COURSE, `event=cover_decode_fail w=${e.componentWidth} msg=${e.message} fallback=placeholder`);
          })
      }
      if (this.path !== '' && !this.failed && this.title !== '') {
        Column() {
          Text(this.title)
            .fontSize(Type.TITLE1)
            .lineHeight(Type.TITLE1_LH)
            .fontWeight(FontWeight.Bold)
            .fontColor(Color.White)
            .maxLines(2)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .textShadow({ radius: 6, color: '#66000000', offsetX: 0, offsetY: 1 })
        }
        .alignItems(HorizontalAlign.Start)
        .width('100%')
        .padding({
          left: this.textPadding,
          right: this.textPadding,
          top: 48,
          bottom: this.textPadding
        })
        .linearGradient({
          direction: GradientDirection.Top,
          colors: [['#B3000000', 0.0], ['#59000000', 0.55], ['#00000000', 1.0]]
        })
      }
    }
    .id(this.photoId)
    .width('100%')
    .height(this.heightVp())
    .clip(true)
    .onAreaChange((oldArea: Area, newArea: Area) => {
      this.boxWidth = newArea.width as number;
    })
    .accessibilityGroup(true)
  }
}

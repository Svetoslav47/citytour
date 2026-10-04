/*
 * Onboarding, 3 steps (task A12, DESIGN §3.1, Flow A §2.3; mockups docs/design/mockups/Onboarding{1,2,3}.dc.html).
 * 1 "Your guide fits in your pocket": the Royal Route from the active course with plaques 1, 5, 11 and headphones
 *   (just the headphones on first run: the app ships no built-in course).
 * 2 "How should the guide speak?": English / 中文 / Polski with the real voice status, Download for Laura, Play a sample.
 * 3 "Two permissions, and why": Location (+ location switch) and Notifications, each Allow opens the system UI.
 * A Swiper with disableSwipe(true) and custom dots (button driven, so no accidental swipe during a system dialog).
 * First-run root content of the Navigation (Index); also a NavDestination (Routes.ONBOARDING) for Settings later.
 * Swiper: doc API参考/ArkUI_方舟UI框架/ArkTS组件/容器组件/Swiper/ts-container-swiper (index, disableSwipe, indicator).
 * Radio: ts-basic-components-radio. SymbolGlyph names verified in the SDK sysResource.js.
 */
import { Lang } from 'common';
import { EnVoiceRow, LocRow, NotifRow, ONB_STEP_PERMS, ONB_STEPS } from 'common';
import { AppViewModel, PackState } from '../viewmodel/AppViewModel';
import { OnboardingViewModel } from '../viewmodel/OnboardingViewModel';
import { SafeArea } from '../viewmodel/SafeArea';
import { Plaque, PlaqueState } from '../views/common/Plaque';
import { PreviewPoint } from '../views/common/RoutePreview';
import { Radius, Size, Space, TABULAR, Type } from '../views/common/Tokens';

const VISUAL_W: number = 200;
const VISUAL_H: number = 240;
const VISUAL_PAD: number = 30;
const RADIO_GROUP: string = 'onbNarrationLang';

class VisualPoint {
  x: number = 0;
  y: number = 0;
  n: number = 0;
}

@ComponentV2
export struct OnboardingPage {
  /** true when opened from Settings as a NavDestination; false as the first-run root. */
  @Param asRoute: boolean = false;
  @Local vm: OnboardingViewModel = new OnboardingViewModel();
  @Local app: AppViewModel = AppViewModel.get();
  /** Window avoid areas (edge-to-edge window, issue #63): Skip below the status bar, Continue above the indicator. */
  @Local sa: SafeArea = SafeArea.get();
  private voiceScroller: Scroller = new Scroller();

  aboutToAppear(): void {
    this.vm.start(this.asRoute);
    this.vm.refreshPreview();
  }

  aboutToDisappear(): void {
    this.vm.stop();
  }

  @Monitor('app.packState')
  onPackChanged(): void {
    if (this.app.packState === PackState.READY) {
      this.vm.refreshPreview();
    }
  }

  /** The sample caption sits below Play a sample: bring it into view (it is the only output for Polish). */
  @Monitor('vm.sampleText')
  onSampleText(): void {
    if (this.vm.sampleText !== '') {
      setTimeout(() => {
        try {
          this.voiceScroller.scrollEdge(Edge.Bottom);
        } catch (e) {
          // scrolling is cosmetic
        }
      }, 50);
    }
  }

  // ---------- step 1 visual ----------

  private fitPoints(points: PreviewPoint[]): VisualPoint[] {
    const out: VisualPoint[] = [];
    if (points.length === 0) {
      return out;
    }
    let minX = Number.POSITIVE_INFINITY;
    let maxX = Number.NEGATIVE_INFINITY;
    let minY = Number.POSITIVE_INFINITY;
    let maxY = Number.NEGATIVE_INFINITY;
    for (const p of points) {
      minX = Math.min(minX, p.x);
      maxX = Math.max(maxX, p.x);
      minY = Math.min(minY, p.y);
      maxY = Math.max(maxY, p.y);
    }
    const spanX = Math.max(1, maxX - minX);
    const spanY = Math.max(1, maxY - minY);
    const scale = Math.min((VISUAL_W - 2 * VISUAL_PAD) / spanX, (VISUAL_H - 2 * VISUAL_PAD) / spanY);
    const offX = (VISUAL_W - spanX * scale) / 2;
    const offY = (VISUAL_H - spanY * scale) / 2;
    for (const p of points) {
      const v = new VisualPoint();
      v.x = offX + (p.x - minX) * scale;
      v.y = offY + (maxY - p.y) * scale;   // north up
      v.n = p.n;
      out.push(v);
    }
    return out;
  }

  /** Plaques 1, 5 and the last stop, as in the mockup. */
  private shownPlaques(pts: VisualPoint[]): VisualPoint[] {
    if (pts.length === 0) {
      return [];
    }
    const out: VisualPoint[] = [pts[0]];
    if (pts.length > 5) {
      out.push(pts[4]);
    }
    if (pts.length > 1) {
      out.push(pts[pts.length - 1]);
    }
    return out;
  }

  @Builder
  routeVisual() {
    Stack({ alignContent: Alignment.TopStart }) {
      if (this.vm.preview.length > 1) {
        Polyline()
          .points(this.fitPoints(this.vm.preview).map((p: VisualPoint) => [p.x, p.y]))
          .width(VISUAL_W)
          .height(VISUAL_H)
          .fillOpacity(0)
          .stroke($r('app.color.bg_surface'))
          .strokeWidth(9)
          .strokeLineJoin(LineJoinStyle.Round)
          .strokeLineCap(LineCapStyle.Round)
        Polyline()
          .points(this.fitPoints(this.vm.preview).map((p: VisualPoint) => [p.x, p.y]))
          .width(VISUAL_W)
          .height(VISUAL_H)
          .fillOpacity(0)
          .stroke($r('app.color.accent'))
          .strokeWidth(5)
          .strokeLineJoin(LineJoinStyle.Round)
          .strokeLineCap(LineCapStyle.Round)
        ForEach(this.shownPlaques(this.fitPoints(this.vm.preview)), (p: VisualPoint, idx: number) => {
          Plaque({ n: p.n, state: idx === 0 ? PlaqueState.NEXT : PlaqueState.UPCOMING })
            .position({ x: p.x - (idx === 0 ? 17 : 14), y: p.y - (idx === 0 ? 17 : 14) })
        }, (p: VisualPoint) => `${p.n}`)
        this.headphones(this.fitPoints(this.vm.preview)[0])
      } else {
        Stack() {
          SymbolGlyph($r('sys.symbol.headphones'))
            .fontSize(32)
            .fontColor([$r('app.color.text_primary')])
        }
        .width(Size.TOUCH)
        .height(Size.TOUCH)
        .borderRadius(Size.TOUCH / 2)
        .backgroundColor($r('app.color.bg_surface'))
        .position({ x: (VISUAL_W - Size.TOUCH) / 2, y: (VISUAL_H - Size.TOUCH) / 2 })
      }
    }
    .width(VISUAL_W)
    .height(VISUAL_H)
    .borderRadius(Radius.LG)
    .clip(true)
    .backgroundColor($r('app.color.map_land'))
    .accessibilityGroup(true)
    .accessibilityText($r('app.string.onb_visual_a11y'))
  }

  @Builder
  headphones(start: VisualPoint) {
    Stack() {
      SymbolGlyph($r('sys.symbol.headphones'))
        .fontSize(32)
        .fontColor([$r('app.color.text_primary')])
    }
    .width(Size.TOUCH)
    .height(Size.TOUCH)
    .borderRadius(Size.TOUCH / 2)
    .backgroundColor($r('app.color.bg_surface'))
    .shadow({ radius: 14, color: '#1A000000', offsetY: 4 })
    .position({
      x: Math.min(VISUAL_W - Size.TOUCH - 4, Math.max(4, start.x - 66)),
      y: Math.min(VISUAL_H - Size.TOUCH - 4, Math.max(4, start.y - 14))
    })
  }

  // ---------- shared pieces ----------

  @Builder
  title(res: Resource, center: boolean) {
    Text(res)
      .fontSize(Type.TITLE1)
      .lineHeight(Type.TITLE1_LH)
      .fontWeight(FontWeight.Bold)
      .fontColor($r('app.color.text_primary'))
      .textAlign(center ? TextAlign.Center : TextAlign.Start)
      .width('100%')
      .accessibilityLevel('yes')
  }

  @Builder
  body(res: Resource, center: boolean) {
    Text(res)
      .fontSize(Type.BODY)
      .lineHeight(Type.BODY_LH)
      .fontColor($r('app.color.text_secondary'))
      .textAlign(center ? TextAlign.Center : TextAlign.Start)
      .width('100%')
  }

  @Builder
  chip(res: Resource) {
    Text(res)
      .fontSize(Type.CAPTION)
      .lineHeight(Type.CAPTION_LH)
      .fontWeight(FontWeight.Medium)
      .fontColor($r('app.color.accent'))
      .backgroundColor($r('app.color.accent_subtle'))
      .borderRadius(Radius.SM)
      .padding({ left: Space.S2, right: Space.S2, top: 3, bottom: 3 })
  }

  @Builder
  divider(indent: number) {
    Divider()
      .strokeWidth(1)
      .color($r('app.color.divider'))
      .margin({ left: indent })
  }

  @Builder
  radio(lang: Lang, label: Resource) {
    Radio({ value: lang as string, group: RADIO_GROUP })
      .checked(this.vm.selected === lang)
      .radioStyle({
        checkedBackgroundColor: $r('app.color.accent'),
        uncheckedBorderColor: $r('app.color.text_tertiary'),
        indicatorColor: $r('app.color.on_accent')
      })
      .width(20)
      .height(20)
      .margin({ top: 2 })
      .responseRegion({ x: -14, y: -14, width: Size.TOUCH, height: Size.TOUCH })
      .accessibilityText(label)
      .onChange((isChecked: boolean) => {
        if (isChecked) {
          this.vm.select(lang);
        }
      })
  }

  // ---------- step 1 ----------

  @Builder
  stepIntro() {
    Scroll() {
      Column() {
        this.routeVisual()
        Column({ space: Space.S3 }) {
          this.title($r('app.string.onb1_title'), true)
          this.body($r('app.string.onb1_body'), true)
        }
        .padding({ left: 28, right: 28, top: 40 })
      }
      .width('100%')
      .padding({ top: 20, bottom: Space.S4 })
    }
    .scrollBar(BarState.Off)
    .align(Alignment.Top)
    .width('100%')
    .height('100%')
  }

  // ---------- step 2 ----------

  @Builder
  enSubtitle() {
    if (this.vm.enRow() === EnVoiceRow.CHECKING) {
      Row({ space: Space.S2 }) {
        LoadingProgress()
          .width(16)
          .height(16)
          .color($r('app.color.text_secondary'))
        Text($r('app.string.onb_checking_voice'))
          .fontSize(Type.CALLOUT)
          .lineHeight(Type.CALLOUT_LH)
          .fontColor($r('app.color.text_secondary'))
      }
    } else if (this.vm.enRow() === EnVoiceRow.DOWNLOADING) {
      Row({ space: Space.S2 }) {
        this.spoken()
        this.chip($r('app.string.onb_downloading'))
      }
    } else if (this.vm.enRow() === EnVoiceRow.TEXT_ONLY && !this.vm.studio(Lang.EN)) {
      Text($r('app.string.voice_text_only_platform'))
        .fontSize(Type.CALLOUT)
        .lineHeight(Type.CALLOUT_LH)
        .fontColor($r('app.color.text_secondary'))
    } else {
      // Which voice speaks (installed, pre-recorded or the Chinese voice) is not labelled here; see Settings > About.
      this.spoken()
    }
  }

  @Builder
  spoken() {
    Text($r('app.string.onb_spoken'))
      .fontSize(Type.CALLOUT)
      .lineHeight(Type.CALLOUT_LH)
      .fontColor($r('app.color.text_secondary'))
  }

  @Builder
  enDetail() {
    if (this.vm.enRow() === EnVoiceRow.DOWNLOADING) {
      Row({ space: 10 }) {
        Progress({ value: this.vm.downloadPct, total: 100, type: ProgressType.Linear })
          .color($r('app.color.accent'))
          .backgroundColor($r('app.color.divider'))
          .style({ strokeWidth: 4 })
          .layoutWeight(1)
          .accessibilityText($r('app.string.voice_downloading', `${this.vm.downloadPct}%`))
        Text(`${this.vm.downloadPct}%`)
          .fontSize(Type.CAPTION)
          .fontWeight(FontWeight.Medium)
          .fontFeature(TABULAR)
          .fontColor($r('app.color.text_secondary'))
      }
      .width('100%')
      .margin({ top: 10 })
    } else if (this.vm.enRow() === EnVoiceRow.DOWNLOAD_FAILED) {
      Text($r('app.string.voice_download_failed'))
        .id('txtOnbDownloadFailed')
        .fontSize(Type.FOOTNOTE)
        .lineHeight(Type.FOOTNOTE_LH)
        .fontColor($r('app.color.text_secondary'))
        .margin({ top: Space.S1 })
    }
    if (this.vm.canDownload()) {
      Button({ type: ButtonType.Capsule, buttonStyle: ButtonStyleMode.TEXTUAL }) {
        Row({ space: 6 }) {
          SymbolGlyph(this.vm.downloadFailed ? $r('sys.symbol.arrow_clockwise') : $r('sys.symbol.arrow_down_circle'))
            .fontSize(16)
            .fontColor([$r('app.color.accent')])
          Text(this.vm.downloadFailed ? $r('app.string.err_try_again') : $r('app.string.voice_download'))
            .fontSize(Type.CALLOUT)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.accent'))
        }
        .height(32)
        .padding({ left: Space.S3, right: Space.S4 })
        .borderRadius(16)
        .backgroundColor($r('app.color.bg_overlay_button'))
      }
      .id('btnOnbDownloadVoice')
      .height(Size.TOUCH)
      .padding(0)
      .margin({ top: Space.S1 })
      .onClick(() => {
        this.vm.download();
      })
    }
  }

  @Builder
  langRows() {
    Column() {
      // English: real voice status from VoiceManager (listVoices + strategy)
      Row({ space: Space.S3 }) {
        Column() {
          Text($r('app.string.lang_english'))
            .fontSize(Type.BODY)
            .lineHeight(Type.BODY_LH)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.text_primary'))
          Column() {
            this.enSubtitle()
          }
          .alignItems(HorizontalAlign.Start)
          .margin({ top: 2 })
          this.enDetail()
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)

        this.radio(Lang.EN, $r('app.string.lang_en_spoken'))
      }
      .id('rowOnbLangEn')
      .alignItems(VerticalAlign.Top)
      .width('100%')
      .constraintSize({ minHeight: Size.TOUCH })
      .padding({ left: Space.S4, right: Space.S4, top: 14, bottom: Space.S4 })
      .onClick(() => this.vm.select(Lang.EN))

      this.divider(Space.S4)

      // 中文: built-in zh-CN voice (聆小珊)
      Row({ space: Space.S3 }) {
        Column() {
          Text($r('app.string.lang_chinese'))
            .fontSize(Type.BODY)
            .lineHeight(Type.BODY_LH)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.text_primary'))
          Text(this.vm.studio(Lang.ZH) || this.vm.zhSpoken() ? $r('app.string.onb_spoken') :
            $r('app.string.voice_text_only_platform'))
            .fontSize(Type.CALLOUT)
            .lineHeight(Type.CALLOUT_LH)
            .fontColor($r('app.color.text_secondary'))
            .margin({ top: 2 })
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)

        this.radio(Lang.ZH, $r('app.string.lang_zh_spoken'))
      }
      .id('rowOnbLangZh')
      .alignItems(VerticalAlign.Top)
      .width('100%')
      .constraintSize({ minHeight: Size.TOUCH })
      .padding({ left: Space.S4, right: Space.S4, top: 14, bottom: 14 })
      .onClick(() => this.vm.select(Lang.ZH))

      this.divider(Space.S4)

      // Polski: spoken when the A13 clips ship, else text only (no Polish voice in Core Speech Kit)
      Row({ space: Space.S3 }) {
        Column() {
          Text($r('app.string.lang_polish'))
            .fontSize(Type.BODY)
            .lineHeight(Type.BODY_LH)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.text_primary'))
          if (this.vm.studio(Lang.PL)) {
            Text($r('app.string.onb_spoken'))
              .fontSize(Type.CALLOUT)
              .lineHeight(Type.CALLOUT_LH)
              .fontColor($r('app.color.text_secondary'))
              .margin({ top: 2 })
          } else {
            Row({ space: 6 }) {
              Text($r('app.string.voice_text_only'))
                .fontSize(Type.CALLOUT)
                .lineHeight(Type.CALLOUT_LH)
                .fontColor($r('app.color.text_secondary'))
              SymbolGlyph($r('sys.symbol.info_circle'))
                .fontSize(16)
                .fontColor([$r('app.color.text_secondary')])
                .accessibilityLevel('no')
            }
            .margin({ top: 2 })
          }
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)

        this.radio(Lang.PL, this.vm.studio(Lang.PL) ? $r('app.string.lang_pl_spoken') : $r('app.string.lang_pl_text'))
      }
      .id('rowOnbLangPl')
      .alignItems(VerticalAlign.Top)
      .width('100%')
      .constraintSize({ minHeight: Size.TOUCH })
      .padding({ left: Space.S4, right: Space.S4, top: 14, bottom: 14 })
      .onClick(() => this.vm.select(Lang.PL))
    }
    .width('100%')
    .borderRadius(Radius.LG)
    .clip(true)
    .backgroundColor($r('app.color.bg_surface'))
    .accessibilityText($r('app.string.onb_lang_group'))
  }

  @Builder
  stepVoice() {
    Scroll(this.voiceScroller) {
      Column() {
        Column({ space: Space.S2 }) {
          this.title($r('app.string.onb2_title'), false)
          this.body($r('app.string.onb2_body'), false)
        }
        .padding({ left: Space.S4, right: Space.S4, top: Space.S4 })

        Column() {
          this.langRows()
        }
        .padding({ left: Space.S4, right: Space.S4 })
        .margin({ top: Space.S5 })

        if (!this.vm.studio(Lang.PL)) {
          Row({ space: Space.S2 }) {
            SymbolGlyph($r('sys.symbol.info_circle'))
              .fontSize(16)
              .fontColor([$r('app.color.text_secondary')])
              .margin({ top: 1 })
              .accessibilityLevel('no')
            Text($r('app.string.lang_pl_footnote'))
              .fontSize(Type.FOOTNOTE)
              .lineHeight(Type.FOOTNOTE_LH)
              .fontColor($r('app.color.text_secondary'))
              .layoutWeight(1)
          }
          .alignItems(VerticalAlign.Top)
          .width('100%')
          .padding({ left: 20, right: 20 })
          .margin({ top: Space.S3 })
        }

        Column({ space: Space.S2 }) {
          Button({ type: ButtonType.Capsule, buttonStyle: ButtonStyleMode.NORMAL }) {
            Row({ space: Space.S2 }) {
              SymbolGlyph(this.vm.samplePlaying ? $r('sys.symbol.waveform') : $r('sys.symbol.speaker_wave_2'))
                .fontSize(20)
                .fontColor([$r('app.color.accent')])
              Text($r('app.string.onb_play_sample'))
                .fontSize(Type.BODY)
                .fontWeight(FontWeight.Medium)
                .fontColor($r('app.color.accent'))
            }
            .padding({ left: Space.S4, right: 20 })
          }
          .id('btnOnbSample')
          .height(Size.BUTTON_H)
          .backgroundColor($r('app.color.bg_overlay_button'))
          .enabled(this.vm.sampleAllowed())
          .onClick(() => {
            this.vm.playSample();
          })

          if (this.vm.sampleText !== '') {
            Text(`“${this.vm.sampleText}”`)
              .id('txtOnbSample')
              .fontSize(Type.CALLOUT)
              .lineHeight(Type.CALLOUT_LH)
              .fontStyle(FontStyle.Italic)
              .fontColor(this.vm.samplePlaying ? $r('app.color.text_primary') : $r('app.color.text_secondary'))
              .padding({ left: Space.S1, right: Space.S1 })
          }
        }
        .alignItems(HorizontalAlign.Start)
        .width('100%')
        .padding({ left: Space.S4, right: Space.S4, top: Space.S4 })
      }
      .alignItems(HorizontalAlign.Start)
      .width('100%')
      .padding({ bottom: Space.S4 })
    }
    .scrollBar(BarState.Off)
    .align(Alignment.Top)
    .width('100%')
    .height('100%')
  }

  // ---------- step 3 ----------

  @Builder
  smallAction(label: Resource, id: string, busy: boolean, action: () => void) {
    if (busy) {
      LoadingProgress()
        .width(24)
        .height(24)
        .margin({ top: 2 })
        .color($r('app.color.accent'))
    } else {
      Button({ type: ButtonType.Capsule, buttonStyle: ButtonStyleMode.TEXTUAL }) {
        Text(label)
          .fontSize(Type.CALLOUT)
          .lineHeight(Type.CALLOUT_LH)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.accent'))
          .height(32)
          .padding({ left: Space.S4, right: Space.S4 })
          .borderRadius(16)
          .backgroundColor($r('app.color.bg_overlay_button'))
      }
      .id(id)
      .height(Size.TOUCH)
      .padding({ left: Space.S2, right: 0 })
      .margin({ top: -8 })
      .onClick(action)
    }
  }

  @Builder
  allowed() {
    Row({ space: 6 }) {
      SymbolGlyph($r('sys.symbol.checkmark_circle_fill'))
        .fontSize(20)
        .fontColor([$r('app.color.accent')])
      Text($r('app.string.onb_allowed'))
        .fontSize(Type.CALLOUT)
        .lineHeight(Type.CALLOUT_LH)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.accent'))
    }
    .height(28)
  }

  @Builder
  note(res: Resource, id: string) {
    Text(res)
      .id(id)
      .fontSize(Type.FOOTNOTE)
      .lineHeight(Type.FOOTNOTE_LH)
      .fontColor($r('app.color.text_primary'))
      .margin({ top: Space.S1 })
  }

  @Builder
  locationRow() {
    Row({ space: 14 }) {
      SymbolGlyph($r('sys.symbol.local'))
        .fontSize(32)
        .fontColor([$r('app.color.accent')])
        .margin({ top: 2 })
      Column({ space: 2 }) {
        Text($r('app.string.onb_loc_title'))
          .fontSize(Type.BODY)
          .lineHeight(Type.BODY_LH)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.text_primary'))
        Text($r('app.string.onb_loc_body'))
          .fontSize(Type.CALLOUT)
          .lineHeight(Type.CALLOUT_LH)
          .fontColor($r('app.color.text_secondary'))
        if (this.vm.loc === LocRow.SWITCH_OFF) {
          this.note($r('app.string.err_loc_switch_off'), 'txtOnbLocNote')
        } else if (this.vm.loc === LocRow.APPROX) {
          this.note($r('app.string.err_perm_approx'), 'txtOnbLocNote')
        } else if (this.vm.loc === LocRow.DENIED) {
          this.note($r('app.string.err_perm_denied'), 'txtOnbLocNote')
        }
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)

      if (this.vm.loc === LocRow.ALLOWED) {
        this.allowed()
      } else {
        this.smallAction(this.vm.loc === LocRow.SWITCH_OFF || this.vm.loc === LocRow.APPROX ?
          $r('app.string.err_perm_turn_on') : $r('app.string.onb_allow'), 'btnOnbAllowLocation', this.vm.locBusy,
          () => {
            this.vm.allowLocation();
          })
      }
    }
    .id('rowOnbLocation')
    .alignItems(VerticalAlign.Top)
    .width('100%')
    .padding(Space.S4)
  }

  @Builder
  notificationRow() {
    Row({ space: 14 }) {
      SymbolGlyph($r('sys.symbol.bell'))
        .fontSize(32)
        .fontColor([$r('app.color.accent')])
        .margin({ top: 2 })
      Column({ space: 2 }) {
        Text($r('app.string.onb_notif_title'))
          .fontSize(Type.BODY)
          .lineHeight(Type.BODY_LH)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.text_primary'))
        Text($r('app.string.onb_notif_body'))
          .fontSize(Type.CALLOUT)
          .lineHeight(Type.CALLOUT_LH)
          .fontColor($r('app.color.text_secondary'))
        if (this.vm.notif === NotifRow.DENIED) {
          this.note($r('app.string.err_notif_denied'), 'txtOnbNotifNote')
        }
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)

      if (this.vm.notif === NotifRow.ALLOWED) {
        this.allowed()
      } else if (this.vm.notif === NotifRow.ASK) {
        this.smallAction($r('app.string.onb_allow'), 'btnOnbAllowNotif', this.vm.notifBusy, () => {
          this.vm.allowNotifications();
        })
      }
    }
    .id('rowOnbNotifications')
    .alignItems(VerticalAlign.Top)
    .width('100%')
    .padding(Space.S4)
  }

  @Builder
  stepPermissions() {
    Scroll() {
      Column() {
        Column() {
          this.title($r('app.string.onb3_title'), false)
        }
        .padding({ top: Space.S4 })

        Column() {
          this.locationRow()
          this.divider(62)
          this.notificationRow()
        }
        .width('100%')
        .borderRadius(Radius.LG)
        .clip(true)
        .backgroundColor($r('app.color.bg_surface'))
        .margin({ top: 28 })
        .padding(0)
        .constraintSize({ maxWidth: Size.PAGE_MAX_W })

        Text($r('app.string.onb_footer'))
          .fontSize(Type.FOOTNOTE)
          .lineHeight(Type.FOOTNOTE_LH)
          .fontColor($r('app.color.text_secondary'))
          .width('100%')
          .padding({ left: Space.S1, right: Space.S1 })
          .margin({ top: Space.S3 })
      }
      .alignItems(HorizontalAlign.Start)
      .width('100%')
      .padding({ left: Space.S4, right: Space.S4, bottom: Space.S4 })
    }
    .scrollBar(BarState.Off)
    .align(Alignment.Top)
    .width('100%')
    .height('100%')
  }

  // ---------- frame ----------

  @Builder
  dots() {
    Row({ space: 6 }) {
      ForEach([0, 1, 2], (i: number) => {
        Column()
          .width(i === this.vm.step ? 18 : 6)
          .height(6)
          .borderRadius(3)
          .backgroundColor(i === this.vm.step ? $r('app.color.accent') : $r('app.color.text_tertiary'))
          .opacity(i === this.vm.step ? 1 : 0.38)
      }, (i: number) => `${i}-${i === this.vm.step}`)
    }
    .id('onbDots')
    .justifyContent(FlexAlign.Center)
    .height(16)
    .width('100%')
    .accessibilityGroup(true)
    .accessibilityText($r('app.string.onb_step_a11y', this.vm.step + 1, ONB_STEPS))
  }

  build() {
    Column() {
      Row() {
        Button($r('app.string.onb_skip'), { type: ButtonType.Capsule, buttonStyle: ButtonStyleMode.TEXTUAL })
          .id('btnOnbSkip')
          .height(Size.TOUCH)
          .fontSize(Type.BODY)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.text_secondary'))
          .padding({ left: Space.S4, right: Space.S4 })
          .accessibilityText($r('app.string.onb_skip_a11y'))
          .onClick(() => this.vm.finish('skip'))
      }
      .justifyContent(FlexAlign.End)
      .width('100%')
      .height(Size.TOUCH)
      .padding({ right: Space.S1 })

      Swiper() {
        this.stepIntro()
        this.stepVoice()
        this.stepPermissions()
      }
      .id('onbSwiper')
      .index(this.vm.step)
      .disableSwipe(true)
      .indicator(false)
      .loop(false)
      .layoutWeight(1)
      .width('100%')
      .onChange((i: number) => {
        if (i !== this.vm.step) {
          this.vm.goTo(i);
        }
      })

      Column({ space: this.vm.step === ONB_STEP_PERMS ? Space.S2 : Space.S5 }) {
        this.dots()
        if (this.vm.step === ONB_STEP_PERMS) {
          Blank().height(Space.S4)
        }
        Button(this.vm.step === ONB_STEP_PERMS ? $r('app.string.onb_done') : $r('app.string.cta_continue'),
          { type: ButtonType.Capsule, buttonStyle: ButtonStyleMode.EMPHASIZED })
          .id('btnOnbNext')
          .width('100%')
          .height(Size.BUTTON_H)
          .fontSize(Type.BODY)
          .fontWeight(FontWeight.Medium)
          .backgroundColor($r('app.color.accent'))
          .fontColor($r('app.color.on_accent'))
          .onClick(() => this.vm.next())
        if (this.vm.step === ONB_STEP_PERMS) {
          Button($r('app.string.onb_later'), { type: ButtonType.Capsule, buttonStyle: ButtonStyleMode.TEXTUAL })
            .id('btnOnbLater')
            .width('100%')
            .height(Size.TOUCH)
            .fontSize(Type.BODY)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.accent'))
            .onClick(() => this.vm.finish('later'))
        }
      }
      .width('100%')
      .constraintSize({ maxWidth: Size.PAGE_MAX_W })
      .padding({ left: Space.S4, right: Space.S4, top: Space.S3, bottom: Space.S5 })
    }
    .id('pageOnboarding')
    .width('100%')
    .height('100%')
    .padding({ top: this.sa.top, bottom: this.sa.bottom, left: this.sa.left, right: this.sa.right })
    .backgroundColor($r('app.color.bg_canvas'))
  }
}

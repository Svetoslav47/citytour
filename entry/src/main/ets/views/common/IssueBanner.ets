/*
 * Inline banner for an AppIssue (DESIGN §3.6.2 banners, ARCHITECTURE §9). One banner at a time, in the guide's
 * voice, with at most two actions. Codes go to hilog, never to the UI.
 */
import { AppIssue, IssueCode } from 'common';
import { Radius, Space, Type } from './Tokens';
import { AppViewModel } from '../../viewmodel/AppViewModel';

/** User-facing message for each §9 error-matrix code. */
export function issueMessage(code: IssueCode, city: string = ''): Resource {
  switch (code) {
    case IssueCode.PERM_DENIED:
      return $r('app.string.err_perm_denied');
    case IssueCode.PERM_APPROX_ONLY:
      return $r('app.string.err_perm_approx');
    case IssueCode.LOC_SWITCH_OFF:
      return $r('app.string.err_loc_switch_off');
    case IssueCode.LOC_NOFIX:
      return $r('app.string.err_loc_nofix');
    case IssueCode.LOC_LOST:
      return $r('app.string.err_loc_lost');
    case IssueCode.LOC_POOR:
      return $r('app.string.err_loc_poor');
    case IssueCode.LOC_UNAVAILABLE:
      return $r('app.string.err_loc_unavailable');
    case IssueCode.LOC_OUT_OF_AREA:
      return city !== '' ? $r('app.string.err_loc_out_of_area', city) : $r('app.string.err_loc_out_of_area_any');
    case IssueCode.TTS_INIT_FAIL:
      return $r('app.string.err_tts_init');
    case IssueCode.VOICE_UNAVAILABLE:
      return $r('app.string.err_voice_unavailable');
    case IssueCode.TTS_ERR:
      return $r('app.string.err_tts_err');
    case IssueCode.AUDIO_INTERRUPT:
      return $r('app.string.err_audio_interrupt');
    case IssueCode.AUDIO_ROUTE_LOST:
      return $r('app.string.err_audio_route_lost');
    case IssueCode.BG_FAIL:
      return $r('app.string.err_bg_fail');
    case IssueCode.AVS_FAIL:
      return $r('app.string.err_avs_fail');
    case IssueCode.NOTIF_DENIED:
      return $r('app.string.err_notif_denied');
    case IssueCode.PACK_ERR:
      return $r('app.string.err_pack');
    case IssueCode.NARR_FALLBACK:
      return $r('app.string.err_narr_fallback');
    case IssueCode.ROUTE_FALLBACK:
      return $r('app.string.err_route_fallback');
    default:
      return $r('app.string.err_uncaught');
  }
}

/** The most important issue to show (DESIGN: permission > GPS > other). */
export function topIssue(issues: AppIssue[]): AppIssue | undefined {
  const rank = (c: IssueCode): number => {
    if (c === IssueCode.PERM_DENIED || c === IssueCode.PERM_APPROX_ONLY || c === IssueCode.LOC_SWITCH_OFF) {
      return 0;
    }
    if (c === IssueCode.LOC_NOFIX || c === IssueCode.LOC_LOST || c === IssueCode.LOC_POOR ||
      c === IssueCode.LOC_UNAVAILABLE || c === IssueCode.LOC_OUT_OF_AREA) {
      return 1;
    }
    return 2;
  };
  let best: AppIssue | undefined = undefined;
  for (const i of issues) {
    if (best === undefined || rank(i.code) < rank(best.code)) {
      best = i;
    }
  }
  return best;
}

@ComponentV2
export struct IssueBanner {
  /** Explicit message; when empty the message comes from `code`. */
  @Param message: ResourceStr = '';
  @Param code: IssueCode = IssueCode.UNCAUGHT;
  @Param actionLabel: ResourceStr = '';
  @Param actionId: string = '';
  @Param secondaryLabel: ResourceStr = '';
  @Param secondaryId: string = '';
  @Event onAction: () => void = () => {};
  @Event onSecondary: () => void = () => {};

  build() {
    Column({ space: Space.S2 }) {
      Row({ space: Space.S3 }) {
        SymbolGlyph($r('sys.symbol.exclamationmark_triangle_fill'))
          .fontSize(20)
          .fontColor([$r('app.color.signal_simulated_fg')])
        Text(this.message !== '' ? this.message : issueMessage(this.code, AppViewModel.get().cityName))
          .fontSize(Type.CALLOUT)
          .lineHeight(Type.CALLOUT_LH)
          .fontColor($r('app.color.text_primary'))
          .layoutWeight(1)
      }
      .alignItems(VerticalAlign.Top)
      .width('100%')

      if (this.actionLabel !== '' || this.secondaryLabel !== '') {
        Flex({ wrap: FlexWrap.Wrap, alignItems: ItemAlign.Center }) {
          if (this.actionLabel !== '') {
            Button(this.actionLabel, { type: ButtonType.Capsule, buttonStyle: ButtonStyleMode.NORMAL })
              .id(this.actionId)
              .height(40)
              .fontSize(Type.CALLOUT)
              .fontColor($r('app.color.accent'))
              .margin({ right: Space.S2, top: Space.S1 })
              .onClick(() => this.onAction())
          }
          if (this.secondaryLabel !== '') {
            Button(this.secondaryLabel, { type: ButtonType.Capsule, buttonStyle: ButtonStyleMode.TEXTUAL })
              .id(this.secondaryId)
              .height(40)
              .fontSize(Type.CALLOUT)
              .fontColor($r('app.color.accent'))
              .margin({ top: Space.S1 })
              .onClick(() => this.onSecondary())
          }
        }
        .padding({ left: 28 })
        .width('100%')
      }
    }
    .width('100%')
    .padding(Space.S3)
    .borderRadius(Radius.LG)
    .backgroundColor($r('app.color.signal_warning_bg'))
  }
}

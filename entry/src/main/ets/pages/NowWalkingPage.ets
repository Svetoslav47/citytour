/*
 * Now Walking: minimal live mirror of the TourControl snapshot so the B4 flow has a real destination.
 * Task B5 replaces this with the full screen (DESIGN §3.6: map slot, Look cue, now-playing card, controls).
 * Already honest: SIMULATED when the source is the Demo walk, "Fallback voice" when English is read by the
 * zh-CN voice. Back (chevron down) returns Home; the tour keeps running.
 */
import { EngineSnapshot, TourPhase } from '../contracts/EngineTypes';
import { FixSource } from '../contracts/Ports';
import { VoiceLabel } from '../contracts/Settings';
import { AppContainer } from '../app/AppContainer';
import { Log } from '../app/Log';
import { LogEvents } from '../app/LogEvents';
import { AppViewModel } from '../viewmodel/AppViewModel';
import { distanceRes } from '../viewmodel/Format';
import { poiName } from '../viewmodel/PackView';
import { FloatingIconButton } from '../views/common/FloatingIconButton';
import { SimulatedBadge } from '../views/common/SimulatedBadge';
import { Radius, Space, TABULAR, Type } from '../views/common/Tokens';

@ComponentV2
export struct NowWalkingPage {
  @Local app: AppViewModel = AppViewModel.get();
  @Local snap: EngineSnapshot | undefined = undefined;
  @Local stopName: string = '';
  private unsubscribe: (() => void) | undefined = undefined;

  aboutToAppear(): void {
    try {
      this.unsubscribe = AppContainer.tourControl().subscribe((s: EngineSnapshot) => {
        this.snap = s;
        const id = s.next !== undefined ? s.next.poiId : '';
        this.stopName = id === '' ? '' : poiName(AppContainer.packRepository(), id, this.app.textLang);
      });
    } catch (e) {
      Log.e(LogEvents.UNCAUGHT, `where=NowWalkingPage.subscribe ${Log.errKv(e as Object)}`);
    }
  }

  aboutToDisappear(): void {
    if (this.unsubscribe !== undefined) {
      this.unsubscribe();
      this.unsubscribe = undefined;
    }
  }

  private overline(): Resource {
    const s = this.snap;
    const n = s === undefined ? 1 : s.currentStopIdx + 1;
    if (s === undefined) {
      return $r('app.string.walk_next_stop', n);
    }
    if (s.phase === TourPhase.FINISHED) {
      return $r('app.string.walk_tour_complete');
    }
    if (s.phase === TourPhase.ABORTED) {
      return $r('app.string.walk_tour_ended');
    }
    if (s.paused) {
      return $r('app.string.walk_paused');
    }
    if (s.phase === TourPhase.AT_STOP) {
      return $r('app.string.walk_here_stop', n);
    }
    if (s.phase === TourPhase.APPROACHING && s.next !== undefined) {
      return $r('app.string.walk_in_m', Math.round(s.next.distanceM));
    }
    return $r('app.string.walk_next_stop', n);
  }

  build() {
    NavDestination() {
      Column() {
        Row() {
          FloatingIconButton({
            symbol: $r('sys.symbol.chevron_down'),
            label: $r('app.string.walk_minimise'),
            buttonId: 'btnMinimise',
            onTap: () => this.app.back()
          })
          Blank()
          SimulatedBadge({ visible: this.snap !== undefined && this.snap.source === FixSource.DEMO })
        }
        .width('100%')
        .padding({ right: Space.S3 })

        Column({ space: Space.S2 }) {
          Text(this.overline())
            .fontSize(Type.CAPTION)
            .fontWeight(FontWeight.Medium)
            .letterSpacing(Type.OVERLINE_SPACING)
            .textCase(TextCase.UpperCase)
            .fontColor($r('app.color.text_secondary'))
          if (this.stopName !== '') {
            Text(this.stopName)
              .fontSize(Type.TITLE2)
              .lineHeight(Type.TITLE2_LH)
              .fontWeight(FontWeight.Bold)
              .fontColor($r('app.color.text_primary'))
          }
          if (this.snap !== undefined && this.snap.next !== undefined && this.snap.phase !== TourPhase.AT_STOP) {
            Text(distanceRes(this.snap.next.distanceM))
              .fontSize(Type.DISPLAY)
              .lineHeight(Type.DISPLAY_LH)
              .fontWeight(FontWeight.Bold)
              .fontFeature(TABULAR)
              .maxFontScale(1.6)
              .fontColor($r('app.color.text_primary'))
          }
          if (this.snap !== undefined && this.snap.nowPlaying !== undefined) {
            Text(this.snap.nowPlaying.caption)
              .fontSize(Type.TRANSCRIPT)
              .lineHeight(Type.TRANSCRIPT_LH)
              .fontColor($r('app.color.text_primary'))
              .padding(Space.S4)
              .width('100%')
              .borderRadius(Radius.LG)
              .backgroundColor($r('app.color.bg_surface_sunken'))
          }
          if (this.snap !== undefined && this.snap.voiceLabel === VoiceLabel.FALLBACK_ZH_READS_EN) {
            Text($r('app.string.voice_fallback_badge'))
              .id('chipFallbackVoice')
              .fontSize(Type.CAPTION)
              .fontWeight(FontWeight.Medium)
              .fontColor($r('app.color.text_secondary'))
              .height(28)
              .padding({ left: 10, right: 10 })
              .borderRadius(Radius.SM)
              .border({ width: 1, color: $r('app.color.divider') })
              .accessibilityText($r('app.string.voice_fallback_tooltip'))
          }
        }
        .alignItems(HorizontalAlign.Start)
        .width('100%')
        .padding(Space.S4)
      }
      .width('100%')
      .height('100%')
    }
    .id('pageNowWalking')
    .hideTitleBar(true)
    .backgroundColor($r('app.color.bg_canvas'))
    .onShown(() => {
      Log.i(LogEvents.APP_PAGE, 'page=NowWalking shown');
    })
  }
}

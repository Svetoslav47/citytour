/*
 * Home-screen "Next stop" card, 2×2 (B14, DESIGN §3.13). Shows what the app pushes with formProvider.updateForm
 * (services/form/WidgetBridge, texts already localised): overline ("NEXT · 5/11"), stop name, distance, footnote, and the
 * amber SIMULATED pill during the Demo walk. Idle: the tour name and "Tap to start". Tapping the card opens the app
 * (postCardAction router -> EntryAbility; doc arkts-ui-widget-event-router).
 * State management V1 (@Entry(LocalStorage) + @LocalStorageProp): ArkTS cards support V2 only from API 23
 * (doc arkts-v1-v2-migration-card), and the app's minimum is API 20. scripts/test.sh exempts this folder.
 */
const cardStorage: LocalStorage = new LocalStorage();

@Entry(cardStorage)
@Component
struct NextStopCard {
  @LocalStorageProp('overline') overline: string = 'CityTour';
  @LocalStorageProp('title') title: string = '';
  @LocalStorageProp('big') big: string = '';
  @LocalStorageProp('foot') foot: string = '';
  @LocalStorageProp('demo') demo: string = '0';
  @LocalStorageProp('mode') mode: string = 'idle';

  build() {
    Column() {
      Row() {
        Text(this.overline)
          .fontSize(12)
          .fontWeight(FontWeight.Medium)
          .letterSpacing(0.6)
          .fontColor($r('app.color.text_secondary'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .layoutWeight(1)
        if (this.demo === '1') {
          Text($r('app.string.label_simulated'))
            .fontSize(9)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.signal_simulated_fg'))
            .backgroundColor($r('app.color.signal_simulated_bg'))
            .borderRadius(8)
            .padding({ left: 6, right: 6, top: 2, bottom: 2 })
        }
      }
      .width('100%')

      Text(this.title !== '' ? this.title : 'CityTour')
        .fontSize(18)
        .fontWeight(FontWeight.Bold)
        .lineHeight(22)
        .fontColor($r('app.color.text_primary'))
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .margin({ top: 6 })
        .width('100%')

      Blank()

      if (this.big !== '') {
        Text(this.big)
          .fontSize(28)
          .fontWeight(FontWeight.Bold)
          .fontFeature('"tnum" 1')
          .fontColor($r('app.color.text_primary'))
          .maxLines(1)
      }
      Text(this.foot)
        .fontSize(12)
        .fontColor(this.mode === 'idle' ? $r('app.color.accent') : $r('app.color.text_secondary'))
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .width('100%')
    }
    .id('cardNextStop')
    .alignItems(HorizontalAlign.Start)
    .width('100%')
    .height('100%')
    .padding(14)
    .backgroundColor($r('app.color.bg_surface'))
    .onClick(() => {
      postCardAction(this, { action: 'router', abilityName: 'EntryAbility', params: { from: 'widget' } });
    })
  }
}

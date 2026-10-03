/*
 * Developer-only page (A-owned). Opened with:
 *   hdc shell aa start -a EntryAbility -b com.hackyeah.citytour --ps page dev
 * Later tasks add buttons for TTS (A4), location sources (A5) and background/AVSession (A6).
 */
@Entry
@ComponentV2
struct DevPanel {
  build() {
    Column() {
      Text('CityTour DevPanel')
        .id('devPanelTitle')
        .fontSize(24)
        .fontWeight(FontWeight.Bold)
        .margin({ top: 48 })
    }
    .width('100%')
    .height('100%')
  }
}

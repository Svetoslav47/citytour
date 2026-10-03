/*
 * Placeholder watch page (task W2: module skeleton). The next-stop glance screen replaces it in task W5.
 */
@Entry
@ComponentV2
struct WatchHome {
  build() {
    Column() {
      Text('CityTour')
        .fontSize(24)
        .fontWeight(FontWeight.Medium)
        .fontColor(Color.White)
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .backgroundColor(Color.Black)
  }
}

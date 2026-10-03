/*
 * Navigation host (DESIGN §2.1-2.2): one Navigation bound to AppViewModel.stack, Home as the root content, the
 * other screens as NavDestinations from the navDestination builder (doc: ts-basic-components-navigation).
 * No tab bar in the MVP. Each screen draws its own header, so the system title bar is hidden.
 */
import { AppViewModel, Routes } from '../viewmodel/AppViewModel';
import { HomePage } from './HomePage';
import { NowWalkingPage } from './NowWalkingPage';
import { RouteReadyPage } from './RouteReadyPage';
import { TourDetailPage } from './TourDetailPage';

@Entry
@ComponentV2
struct Index {
  @Local app: AppViewModel = AppViewModel.get();

  aboutToAppear(): void {
    this.app.applySupportedUiLanguage();
    this.app.loadPack();
  }

  @Builder
  pageMap(name: string, param: Object) {
    if (name === Routes.TOUR_DETAIL) {
      TourDetailPage({ tourId: param as string })
    } else if (name === Routes.ROUTE_READY) {
      RouteReadyPage()
    } else if (name === Routes.NOW_WALKING) {
      NowWalkingPage()
    }
  }

  build() {
    Navigation(this.app.stack) {
      HomePage()
    }
    .navDestination(this.pageMap)
    .mode(NavigationMode.Stack)
    .hideTitleBar(true)
    .hideToolBar(true)
    .backgroundColor($r('app.color.bg_canvas'))
    .width('100%')
    .height('100%')
  }
}

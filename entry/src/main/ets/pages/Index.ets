/*
 * Navigation host (DESIGN §2.1-2.2): one Navigation bound to AppViewModel.stack, Home as the root content, the
 * other screens as NavDestinations from the navDestination builder (doc: ts-basic-components-navigation).
 * No tab bar in the MVP. Each screen draws its own header, so the system title bar is hidden.
 */
import { UserSettings } from '../contracts/Settings';
import { AppViewModel, Routes } from '../viewmodel/AppViewModel';
import { OnboardingViewModel } from '../viewmodel/OnboardingViewModel';
import { AboutSourcesPage } from './AboutSourcesPage';
import { HomePage } from './HomePage';
import { PlaceDetailPage } from './PlaceDetailPage';
import { NowWalkingPage } from './NowWalkingPage';
import { OnboardingPage } from './OnboardingPage';
import { RouteReadyPage } from './RouteReadyPage';
import { TourDetailPage } from './TourDetailPage';

@Entry
@ComponentV2
struct Index {
  @Local app: AppViewModel = AppViewModel.get();
  /** A12: persisted UserSettings (PersistenceV2); onboarding shows until onboardingDone. */
  @Local settings: UserSettings = OnboardingViewModel.settings();

  aboutToAppear(): void {
    this.app.applySupportedUiLanguage();
    OnboardingViewModel.restoreNarration(this.app);
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
    } else if (name === Routes.PLACE_DETAIL) {
      PlaceDetailPage({ poiId: param as string })
    } else if (name === Routes.ABOUT_SOURCES) {
      AboutSourcesPage()
    } else if (name === Routes.ONBOARDING) {
      NavDestination() {
        OnboardingPage({ asRoute: true })
      }
      .hideTitleBar(true)
    }
  }

  build() {
    Navigation(this.app.stack) {
      if (this.settings.onboardingDone) {
        HomePage()
      } else {
        OnboardingPage({ asRoute: false })
      }
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

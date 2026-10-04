/*
 * Navigation host (DESIGN §2.1-2.2): one Navigation bound to AppViewModel.stack, Home as the root content, the
 * other screens as NavDestinations from the navDestination builder (doc: ts-basic-components-navigation).
 * No tab bar in the MVP. Each screen draws its own header, so the system title bar is hidden.
 */
import { UserSettings } from 'common';
import { AppViewModel, Routes } from '../viewmodel/AppViewModel';
import { OnboardingViewModel } from '../viewmodel/OnboardingViewModel';
import { AboutSourcesPage } from './AboutSourcesPage';
import { CoursesPage } from './CoursesPage';
import { RemoteSettings } from '../viewmodel/CoursesViewModel';
import { HomePage } from './HomePage';
import { MapPage } from './MapPage';
import { PlaceDetailPage } from './PlaceDetailPage';
import { NowWalkingPage } from './NowWalkingPage';
import { OnboardingPage } from './OnboardingPage';
import { RouteReadyPage } from './RouteReadyPage';
import { SettingsPage } from './SettingsPage';
import { SummaryPage } from './SummaryPage';
import { TourDetailPage } from './TourDetailPage';
import { SettingsViewModel } from '../viewmodel/SettingsViewModel';
import { SummaryViewModel } from '../viewmodel/SummaryViewModel';
import { WidgetBridge } from '../viewmodel/WidgetBridge';
import { AppLanguagePage } from '../views/settings/AppLanguagePage';
import { StoryLanguagePage } from '../views/settings/StoryLanguagePage';
import { VoicePage } from '../views/settings/VoicePage';

@Entry
@ComponentV2
struct Index {
  @Local app: AppViewModel = AppViewModel.get();
  /** A12: persisted UserSettings (PersistenceV2); onboarding shows until onboardingDone. */
  @Local settings: UserSettings = OnboardingViewModel.settings();

  aboutToAppear(): void {
    this.app.applySupportedUiLanguage();
    SettingsViewModel.applyAll(this.app);   // B9: narration (A12 restore), voice strategy, UI language, tour, source
    RemoteSettings.apply();                  // SERVER.md §2: Online studio voice on/off
    this.app.loadPack();
    SummaryViewModel.startRecording();   // B11: times every tour for its summary
    WidgetBridge.start(() => this.app.textLang);   // B14: home-screen Next stop card
  }

  @Builder
  pageMap(name: string, param: Object) {
    if (name === Routes.TOUR_DETAIL) {
      TourDetailPage({ tourId: param as string })
    } else if (name === Routes.ROUTE_READY) {
      RouteReadyPage()
    } else if (name === Routes.NOW_WALKING) {
      NowWalkingPage()
    } else if (name === Routes.FULL_MAP) {
      MapPage({ mode: param as string })
    } else if (name === Routes.PLACE_DETAIL) {
      PlaceDetailPage({ poiId: param as string })
    } else if (name === Routes.ABOUT_SOURCES) {
      AboutSourcesPage()
    } else if (name === Routes.ONBOARDING) {
      NavDestination() {
        OnboardingPage({ asRoute: true })
      }
      .hideTitleBar(true)
    } else if (name === Routes.SETTINGS) {
      SettingsPage()
    } else if (name === Routes.SETTINGS_STORY_LANG) {
      StoryLanguagePage()
    } else if (name === Routes.SETTINGS_APP_LANG) {
      AppLanguagePage()
    } else if (name === Routes.SETTINGS_VOICE) {
      VoicePage()
    } else if (name === Routes.SUMMARY) {
      SummaryPage()
    } else if (name === Routes.COURSES) {
      CoursesPage()
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

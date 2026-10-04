// Suite: HomeRules.test - module under test: core/remote/HomeRules (Home = the city's walks, actions on the card).
// Cases: header from fix/bbox (inside, outside, no fix, bad bbox); which city Home lists; card actions for a walk
// not on the device / streaming / downloaded / running / preparing / failed / another tour running / no server;
// the Explore row's step (no walk yet, streamed walk, places on device, busy, no server) and which walk it activates.
import { describe, it, expect } from '@ohos/hypium';
import {
  CardActions, CardDownload, CardInput, cardActions, CardPrimary, ExploreInput, ExploreStep, exploreStep, ExploreWalk,
  exploreWalk, homeCity, HomeHeader, homeHeader
} from 'common';

const KRAKOW: number[] = [49.97, 19.79, 50.13, 20.22];

function input(): CardInput {
  const i = new CardInput();
  i.serverEnabled = true;
  return i;
}

export default function homeRulesTest() {
  describe('HomeRules', () => {
    it('header_in_city_when_fix_inside_bbox', 0, () => {
      expect(homeHeader(50.0614, 19.9366, KRAKOW)).assertEqual(HomeHeader.IN_CITY);
    });
    it('header_walks_in_when_outside', 0, () => {
      expect(homeHeader(39.9, 116.4, KRAKOW)).assertEqual(HomeHeader.WALKS_IN);   // the emulator's Beijing fix
    });
    it('header_walks_in_without_fix', 0, () => {
      expect(homeHeader(Number.NaN, Number.NaN, KRAKOW)).assertEqual(HomeHeader.WALKS_IN);
    });
    it('header_walks_in_with_unknown_bbox', 0, () => {
      expect(homeHeader(50.06, 19.93, [])).assertEqual(HomeHeader.WALKS_IN);
      expect(homeHeader(50.06, 19.93, [1, Number.NaN, 2, 3])).assertEqual(HomeHeader.WALKS_IN);
    });
    it('header_bbox_edge_is_inside', 0, () => {
      expect(homeHeader(49.97, 19.79, KRAKOW)).assertEqual(HomeHeader.IN_CITY);
    });
    it('city_active_first_else_catalog_order', 0, () => {
      expect(homeCity('krakow', ['warsaw', 'krakow'])).assertEqual('krakow');
      expect(homeCity('', ['warsaw', 'krakow'])).assertEqual('warsaw');
      expect(homeCity('gdansk', ['krakow'])).assertEqual('krakow');
      expect(homeCity('', [])).assertEqual('');
    });
    it('card_not_installed_starts_by_streaming', 0, () => {
      const a: CardActions = cardActions(input());
      expect(a.primary).assertEqual(CardPrimary.START);
      expect(a.enabled).assertTrue();
      expect(a.demo).assertTrue();
      expect(a.download).assertEqual(CardDownload.DOWNLOAD);
      expect(a.canRemove).assertFalse();
      expect(a.confirmEnd).assertFalse();
    });
    it('card_streaming_offers_download_and_remove', 0, () => {
      const i = input();
      i.streamed = true;
      const a = cardActions(i);
      expect(a.primary).assertEqual(CardPrimary.START);
      expect(a.download).assertEqual(CardDownload.DOWNLOAD);
      expect(a.canRemove).assertTrue();
    });
    it('card_downloaded_shows_done', 0, () => {
      const i = input();
      i.downloaded = true;
      const a = cardActions(i);
      expect(a.download).assertEqual(CardDownload.DONE);
      expect(a.canRemove).assertTrue();
      i.updateAvailable = true;
      expect(cardActions(i).download).assertEqual(CardDownload.DOWNLOAD);
    });
    it('card_downloaded_offline_still_starts', 0, () => {
      const i = new CardInput();
      i.downloaded = true;
      const a = cardActions(i);
      expect(a.primary).assertEqual(CardPrimary.START);
      expect(a.download).assertEqual(CardDownload.DONE);
    });
    it('card_not_on_device_without_server_unavailable', 0, () => {
      const a = cardActions(new CardInput());
      expect(a.primary).assertEqual(CardPrimary.UNAVAILABLE);
      expect(a.enabled).assertFalse();
      expect(a.demo).assertFalse();
      expect(a.download).assertEqual(CardDownload.HIDDEN);
    });
    it('card_running_continues', 0, () => {
      const i = input();
      i.streamed = true;
      i.active = true;
      i.activeHasDemo = true;
      i.running = true;
      const a = cardActions(i);
      expect(a.primary).assertEqual(CardPrimary.CONTINUE);
      expect(a.demo).assertFalse();
      expect(a.canRemove).assertFalse();
    });
    it('card_other_running_confirms_end', 0, () => {
      const i = input();
      i.otherRunning = true;
      const a = cardActions(i);
      expect(a.primary).assertEqual(CardPrimary.START);
      expect(a.confirmEnd).assertTrue();
    });
    it('card_preparing_disabled', 0, () => {
      const i = input();
      i.preparing = true;
      i.failed = true;
      const a = cardActions(i);
      expect(a.primary).assertEqual(CardPrimary.PREPARING);
      expect(a.enabled).assertFalse();
      expect(a.showFailed).assertFalse();
      expect(a.canRemove).assertFalse();
    });
    it('card_failed_shows_line', 0, () => {
      const i = input();
      i.failed = true;
      const a = cardActions(i);
      expect(a.showFailed).assertTrue();
      expect(a.primary).assertEqual(CardPrimary.START);
    });
    it('card_downloading_shows_progress', 0, () => {
      const i = input();
      i.streamed = true;
      i.downloading = true;
      const a = cardActions(i);
      expect(a.download).assertEqual(CardDownload.PROGRESS);
      expect(a.canRemove).assertFalse();
    });
    it('card_active_demo_follows_track', 0, () => {
      const i = input();
      i.downloaded = true;
      i.active = true;
      expect(cardActions(i).demo).assertFalse();
      i.activeHasDemo = true;
      expect(cardActions(i).demo).assertTrue();
    });
    it('explore_offered_before_any_walk_is_loaded', 0, () => {
      const i = new ExploreInput();
      i.homeCityId = 'krakow';
      i.serverEnabled = true;
      expect(exploreStep(i)).assertEqual(ExploreStep.PREPARE);   // fresh install: was hidden (the bug)
    });
    it('explore_hidden_without_city_or_walk', 0, () => {
      const i = new ExploreInput();
      i.serverEnabled = true;
      expect(exploreStep(i)).assertEqual(ExploreStep.HIDDEN);
      i.homeCityId = 'krakow';
      i.serverEnabled = false;
      expect(exploreStep(i)).assertEqual(ExploreStep.HIDDEN);   // nothing loaded and nothing to fetch it from
    });
    it('explore_streamed_walk_fetches_the_places', 0, () => {
      const i = new ExploreInput();
      i.homeCityId = 'krakow';
      i.activeLoaded = true;
      i.activeCityId = 'krakow';
      i.serverEnabled = true;
      expect(exploreStep(i)).assertEqual(ExploreStep.GET_PLACES);
      i.placesOnDevice = true;
      expect(exploreStep(i)).assertEqual(ExploreStep.OPEN);
    });
    it('explore_opens_offline_on_what_is_on_device', 0, () => {
      const i = new ExploreInput();
      i.homeCityId = 'krakow';
      i.activeLoaded = true;
      i.activeCityId = 'krakow';
      expect(exploreStep(i)).assertEqual(ExploreStep.OPEN);
    });
    it('explore_self_contained_course_opens', 0, () => {
      const i = new ExploreInput();
      i.activeLoaded = true;
      i.placesOnDevice = true;
      expect(exploreStep(i)).assertEqual(ExploreStep.OPEN);
    });
    it('explore_busy_shows_progress', 0, () => {
      const i = new ExploreInput();
      i.homeCityId = 'krakow';
      i.serverEnabled = true;
      i.busy = true;
      expect(exploreStep(i)).assertEqual(ExploreStep.BUSY);
    });
    it('explore_other_city_loaded_prepares_home_city', 0, () => {
      const i = new ExploreInput();
      i.homeCityId = 'krakow';
      i.activeLoaded = true;
      i.activeCityId = 'warsaw';
      i.placesOnDevice = true;
      i.serverEnabled = true;
      expect(exploreStep(i)).assertEqual(ExploreStep.PREPARE);
    });
    it('explore_walk_prefers_downloaded_then_streamed', 0, () => {
      const a = new ExploreWalk('royal', 'krakow', false, false);
      const b = new ExploreWalk('kazimierz', 'krakow', false, true);
      const c = new ExploreWalk('scholars', 'krakow', true, false);
      const w = new ExploreWalk('old', 'warsaw', true, false);
      expect(exploreWalk([w, a, b, c], 'krakow')).assertEqual('scholars');
      expect(exploreWalk([w, a, b], 'krakow')).assertEqual('kazimierz');
      expect(exploreWalk([w, a], 'krakow')).assertEqual('royal');
      expect(exploreWalk([w], 'krakow')).assertEqual('');
      expect(exploreWalk([], '')).assertEqual('');
    });
  });
}

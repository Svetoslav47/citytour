// Suite: HomeRules.test - module under test: core/remote/HomeRules (Home = the city's walks, actions on the card).
// Cases: header from fix/bbox (inside, outside, no fix, bad bbox); which city Home lists; card actions for a walk
// not on the device / streaming / downloaded / running / preparing / failed / another tour running / no server.
import { describe, it, expect } from '@ohos/hypium';
import {
  CardActions, CardDownload, CardInput, cardActions, CardPrimary, homeCity, HomeHeader, homeHeader
} from '../main/ets/core/remote/HomeRules';

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
  });
}

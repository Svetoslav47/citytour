// Suite: PackParser.test - module under test: core/content/PackParser (task B3, Person B).
// Runtime re-validation of the offline pack: bad records are dropped with a reason, bad files are blocking.
import { describe, it, expect } from '@ohos/hypium';
import { Lang, Maneuver, Poi } from 'common';
import {
  parseManifest, parseMap, parseNarrations, parsePois, parseRoutes, parseTours, pruneTourStops
} from 'common';
import {
  MANIFEST_OK, MANIFEST_V2, MAP_JSON, NARR_EN_JSON, POI_BARBICAN, POIS_JSON, ROUTES_JSON, TOURS_JSON
} from './fixtures/PackJson';

export default function packParserTest() {
  describe('PackParser', () => {
    it('manifest_ok', 0, () => {
      const r = parseManifest(MANIFEST_OK);
      expect(r.error).assertEqual('');
      expect(r.manifest !== undefined && r.manifest.packId === 'krakow').assertTrue();
    });
    it('malformed_json_is_blocking', 0, () => {
      expect(parseManifest('{ not json').error.length > 0).assertTrue();
      expect(parsePois('[{"id": ').error.length > 0).assertTrue();
      expect(parseRoutes('nope').error.length > 0).assertTrue();
    });
    it('other_schema_major_is_blocking', 0, () => {
      expect(parseManifest(MANIFEST_V2).error.indexOf('schemaVersion') >= 0).assertTrue();
    });
    it('unknown_enum_and_bad_coords_are_dropped_with_reason', 0, () => {
      const r = parsePois(POIS_JSON);
      expect(r.error).assertEqual('');
      expect(r.items.length).assertEqual(2);
      expect(r.drops.length).assertEqual(2);
      expect(r.drops[0].reason).assertEqual('enum_kind');
      expect(r.drops[0].id).assertEqual('poi_wd_Q1');
      expect(r.drops[1].reason).assertEqual('latlng');
    });
    it('valid_poi_fields_survive', 0, () => {
      const p = parsePois(POIS_JSON).items[0];
      expect(p.id).assertEqual(POI_BARBICAN);
      expect(p.view !== undefined && p.view.look === 'up').assertTrue();
      expect(p.heritage !== undefined && p.heritage.unesco).assertTrue();
    });
    it('tour_stops_with_unknown_poi_are_pruned', 0, () => {
      const pois = parsePois(POIS_JSON).items;
      const tours = parseTours(TOURS_JSON).items;
      expect(tours.length).assertEqual(1);
      const drops = pruneTourStops(tours, (id: string) => pois.some((p: Poi) => p.id === id));
      expect(tours[0].stops.length).assertEqual(2);
      expect(drops.length).assertEqual(1);
      expect(drops[0].reason).assertEqual('unknown_poi');
    });
    it('routes_matrix_and_legs', 0, () => {
      const r = parseRoutes(ROUTES_JSON);
      expect(r.error).assertEqual('');
      expect(r.routes.nodeIds.length).assertEqual(2);
      expect(r.routes.legs.length).assertEqual(1);          // odd geometry leg dropped
      expect(r.drops[0].reason).assertEqual('geometry');
      expect(r.routes.legs[0].steps[0].maneuver).assertEqual(Maneuver.OTHER); // unknown maneuver kept as other
    });
    it('narrations_in_the_wrong_file_are_dropped', 0, () => {
      const r = parseNarrations('narrations/en.json', NARR_EN_JSON, Lang.EN);
      expect(r.items.length).assertEqual(1);
      expect(r.drops[0].reason).assertEqual('wrong_file_lang');
    });
    it('map_drops_bad_features_and_layers', 0, () => {
      const r = parseMap(MAP_JSON);
      expect(r.error).assertEqual('');
      expect(r.map !== undefined && r.map.layers.length === 1).assertTrue();
      expect(r.map !== undefined && r.map.layers[0].features.length === 1).assertTrue();
      expect(r.dropped).assertEqual(2);
    });
  });
}

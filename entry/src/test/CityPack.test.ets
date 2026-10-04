// Suite: CityPack.test - module under test: core/content/CityPack (city places packs, SERVER.md §3 R7).
// Cases: city.json parsing (valid, missing origin/id/names, bad boxes, proper nouns incl. the city's own name); the
// city's display name per UI language with fallbacks (no inflection: the nominative goes into the string slot);
// lat/lng box -> world box in the pack projection; layering course records over city records (course wins, order
// kept, course-only records appended); the layered manifest (origin mismatch refused, city bbox, place count,
// licences without duplicates, files of both); the media session album line.
import { describe, it, expect } from '@ohos/hypium';
import { PackFile, PackManifest, Poi } from 'common';
import {
  albumLine, cityDisplayName, CityInfo, latLngBox, layerManifests, layerPois, parseCityJson, worldBox
} from 'common';
import { Projection } from 'common';

const CITY_JSON: string = '{"schemaVersion":1,"cityId":"krakow","names":{"en":"Kraków","pl":"Kraków","zh":"克拉科夫"},' +
  '"origin":{"lat":50.06143,"lng":19.93658},"bbox":[49.978575,19.796944,50.1278,20.202296],' +
  '"defaultBounds":[50.0525,19.929,50.0675,19.947],"properNouns":["Vistula","Wawel"," ",""]}';

function poi(id: string, name: string): Poi {
  const p: Poi = {
    id: id, kind: 'other', lat: 50, lng: 19, x: 0, y: 0, names: { en: name }, importance: 0, tier: 'name-only',
    triggerRadiusM: 30, sourceIds: []
  } as Poi;
  return p;
}

function manifest(packId: string, lat: number, lng: number, files: string[], licenses: string[]): PackManifest {
  const m: PackManifest = {
    schemaVersion: 1, packId: packId, version: `${packId}-v`, builtAt: '2026-10-03T00:00:00Z', origin: { lat: lat, lng: lng },
    bbox: [1, 2, 3, 4], files: files.map((f: string) => {
      const pf: PackFile = { path: f, bytes: 10, sha256: '' };
      return pf;
    }),
    counts: { pois: 0, narrations_en: 5, narrations_pl: 6, narrations_zh: 7, legs: 8 }, licenses: licenses
  };
  return m;
}

export default function cityPackTest() {
  describe('CityPack', () => {
    it('parsesCityJson', 0, () => {
      const c = parseCityJson(CITY_JSON) as CityInfo;
      expect(c !== undefined).assertTrue();
      expect(c.id).assertEqual('krakow');
      expect(c.names.zh).assertEqual('克拉科夫');
      expect(c.origin.lat).assertEqual(50.06143);
      expect(c.bbox.length).assertEqual(4);
      expect(c.defaultBounds[1]).assertEqual(19.929);
      // blank nouns dropped; the city's own name is always grounded (once)
      expect(c.properNouns.join('|')).assertEqual('Vistula|Wawel|Kraków');
    });

    it('rejectsUnusableCityJson', 0, () => {
      expect(parseCityJson('not json') === undefined).assertTrue();
      expect(parseCityJson('[]') === undefined).assertTrue();
      expect(parseCityJson('{"cityId":"x","names":{"en":"X"}}') === undefined).assertTrue();                 // no origin
      expect(parseCityJson('{"cityId":"x","names":{"en":"X"},"origin":{"lat":91,"lng":0}}') === undefined).assertTrue();
      expect(parseCityJson('{"cityId":"","names":{"en":"X"},"origin":{"lat":1,"lng":2}}') === undefined).assertTrue();
      expect(parseCityJson('{"cityId":"x","names":{},"origin":{"lat":1,"lng":2}}') === undefined).assertTrue();
      // optional parts missing or malformed: still a city, with empty boxes
      const c = parseCityJson('{"cityId":"gdansk","names":{"pl":"Gdańsk"},"origin":{"lat":54.35,"lng":18.65},' +
        '"bbox":[1,2],"defaultBounds":[5,5,4,6]}') as CityInfo;
      expect(c.id).assertEqual('gdansk');
      expect(c.bbox.length).assertEqual(0);
      expect(c.defaultBounds.length).assertEqual(0);
    });

    it('latLngBoxValidation', 0, () => {
      expect(latLngBox([1, 2, 3, 4]).length).assertEqual(4);
      expect(latLngBox([3, 2, 1, 4]).length).assertEqual(0);     // min >= max
      expect(latLngBox([1, 2, 3]).length).assertEqual(0);
      expect(latLngBox([1, 200, 3, 201]).length).assertEqual(0);
      expect(latLngBox(undefined).length).assertEqual(0);
    });

    it('cityNamePerUiLanguage', 0, () => {
      const c = parseCityJson(CITY_JSON) as CityInfo;
      expect(cityDisplayName(c, 'en', '')).assertEqual('Kraków');
      expect(cityDisplayName(c, 'pl', '')).assertEqual('Kraków');   // nominative: "Wszystkie miejsca: Kraków"
      expect(cityDisplayName(c, 'zh', '')).assertEqual('克拉科夫');
      const g = parseCityJson('{"cityId":"gdansk","names":{"pl":"Gdańsk"},"origin":{"lat":54.35,"lng":18.65}}');
      expect(cityDisplayName(g, 'en', 'x')).assertEqual('Gdańsk');  // any name before the fallback
      expect(cityDisplayName(undefined, 'en', 'Kraków')).assertEqual('Kraków');   // older course: catalog `city`
      expect(cityDisplayName(undefined, 'zh', '')).assertEqual('');
    });

    it('worldBoxInPackProjection', 0, () => {
      const p = new Projection(50.06143, 19.93658);
      const b = worldBox([50.0525, 19.929, 50.0675, 19.947], p);
      expect(b.length).assertEqual(4);
      expect(Math.abs(b[0] - p.x(19.929)) < 1e-9).assertTrue();
      expect(Math.abs(b[1] - p.y(50.0525)) < 1e-9).assertTrue();
      expect(b[2] > b[0] && b[3] > b[1]).assertTrue();
      expect(worldBox([], p).length).assertEqual(0);
      // another city, another origin: its own frame (the box is around 0,0 of its origin)
      const g = new Projection(54.35, 18.65);
      const gb = worldBox([54.34, 18.64, 54.36, 18.66], g);
      expect(gb[0] < 0 && gb[2] > 0 && gb[1] < 0 && gb[3] > 0).assertTrue();
    });

    it('layersCourseOverCity', 0, () => {
      const city = [poi('a', 'A city'), poi('b', 'B city'), poi('c', 'C city')];
      const course = [poi('b', 'B curated'), poi('z', 'Z course only')];
      const out = layerPois(city, course);
      expect(out.map((p: Poi) => `${p.id}:${p.names.en}`).join(',')).assertEqual('a:A city,b:B curated,c:C city,z:Z course only');
      expect(layerPois([], course).length).assertEqual(2);
      expect(layerPois(city, []).length).assertEqual(3);
    });

    it('layeredManifest', 0, () => {
      const city = manifest('krakow', 50.06143, 19.93658, ['pois.json', 'city.json'], ['OSM', 'Wikipedia']);
      city.bbox = [49.9, 19.7, 50.2, 20.3];
      const course = manifest('krakow-scholars', 50.06143, 19.93658, ['tours.json'], ['OSRM', 'OSM']);
      const r = layerManifests(city, course, 4291);
      expect(r.error).assertEqual('');
      const m = r.manifest as PackManifest;
      expect(m.packId).assertEqual('krakow-scholars');
      expect(m.version).assertEqual('krakow-scholars-v');
      expect(m.bbox[0]).assertEqual(49.9);                        // the out-of-area check uses the city bbox
      expect(m.counts.pois).assertEqual(4291);
      expect(m.counts.legs).assertEqual(8);
      expect(m.licenses.join('|')).assertEqual('OSRM|OSM|Wikipedia');
      expect(m.files.map((f: PackFile) => f.path).join(',')).assertEqual('tours.json,city/pois.json,city/city.json');
      const bad = layerManifests(city, manifest('x', 54.35, 18.65, [], []), 1);
      expect(bad.error).assertEqual('origin_mismatch');
      expect(bad.manifest === undefined).assertTrue();
    });

    it('albumLine', 0, () => {
      expect(albumLine('Kraków', 'The Royal Route')).assertEqual('Kraków · The Royal Route');
      expect(albumLine('', 'The Royal Route')).assertEqual('The Royal Route');
      expect(albumLine('Gdańsk', ' ')).assertEqual('Gdańsk');
      expect(albumLine('', '')).assertEqual('CityTour');
    });
  });
}

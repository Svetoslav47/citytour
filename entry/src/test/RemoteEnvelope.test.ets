// Suite: RemoteEnvelope.test - modules under test: core/remote/CanonicalJson and core/remote/ServerApi (SERVER.md §3).
// Cases: canonical JSON equals Node's (sorted keys at every depth, no whitespace, escapes, unicode, numbers) and its
// sha256 matches Node; base64 (standard, url-safe, malformed); the {payload, sig} envelope (missing parts, bad
// signature encoding); catalog rows (validation, dropped rows, unsafe ids); course manifest (path safety, id match,
// pack layout R3); install token expiry (R2); the /v1/tts body limits.
import { describe, it, expect } from '@ohos/hypium';
import { base64Decode, canonicalJson } from '../main/ets/core/remote/CanonicalJson';
import {
  cityName, CourseManifest, packDir, packManifestPath, parseCatalog, parseCityManifest, parseCourseManifest, parseEnvelope, parseExpiresAt,
  parseInstall, safeRelPath, tokenUsable, ttsBodyJson, validVersion, courseVersion
} from '../main/ets/core/remote/ServerApi';
import { sha256Hex, utf8Bytes } from '../main/ets/core/speech/Sha256';

// Computed with Node 22 (scratch script vec.mjs): the same text, the canonical form, its sha256 and an Ed25519 sig.
const SIG: string = 'rYe6vCKK9uvXkP4geDHKtZkC25Tpvn/oUXbQA5RHnNC6VxXUL/PFjS4jDzQnI5Gg98RT4cQthyzxQvYcD9QGAg==';
const ENVELOPE: string = '{ "payload": { "courses": [ { "version": "2026.10.03", "id": "krakow", "title": {"zh":"皇家之路","pl":"Droga Królewska","en":"Royal Route"}, "km": 1.5, "stops": 6, "minutes": 45, "langs": ["en","pl","zh"], "bytes": 12345678, "city": "Kraków", "note": "a\\"b\\\\c\\n\\u0001 😀" } ], "Zeta": null, "alpha": [true, false, 0.1, -2, 1e21, 100] }, "sig": "' + SIG + '" }';
const CANONICAL: string = '{"Zeta":null,"alpha":[true,false,0.1,-2,1e+21,100],"courses":[{"bytes":12345678,"city":"Kraków","id":"krakow","km":1.5,"langs":["en","pl","zh"],"minutes":45,"note":"a\\"b\\\\c\\n\\u0001 😀","stops":6,"title":{"en":"Royal Route","pl":"Droga Królewska","zh":"皇家之路"},"version":"2026.10.03"}]}';
const CANONICAL_SHA: string = '76fadf7ebe2f244070e2da4e8dd7e1cd76d8436cfc9c39e8ed12903aa7a6c806';
// The committed server/seed/catalog.json of origin/feat/server (PR #79), signed with the production key in
// RemoteConfig. Node: crypto.verify(null, utf8(canonical(payload)), spkiKey, base64(sig)) === true for this file and
// for server/seed/courses/krakow/manifest.json (canonical sha 6c915617...); here we check the app builds the same
// canonical bytes (so the on-device Ed25519 verify sees exactly what was signed).
const SEED_CATALOG: string = '{"payload":{"courses":[{"id":"krakow","version":"2026.10.03-41e1482c-a572a94e2","title":{"en":"The Royal Route","pl":"Droga Królewska","zh":"皇家之路"},"city":"Kraków","stops":11,"km":2,"minutes":55,"langs":["en","pl","zh"],"bytes":40307550}]},"sig":"rbXn3169LJC36iAm7iGjGJBEzaQL/hW6Vgb6MXq32enKT+rUoMijfuBZkQriQqXqy9AkuUNIZrubhLtwCO+xCQ=="}';
const SEED_CATALOG_CANONICAL_SHA: string = '10af69091bf6875c2be7da0a005ea6e5265faa45a1df7b1f36ae5c50a9d81f84';
const SHA_A: string = 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
const SHA_B: string = 'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';

function manifestJson(files: string, extra: string = ''): string {
  return `{"schemaVersion":1,"courseId":"gdansk","version":"3","publishedAt":"2026-10-03T20:00:00Z",` +
    `"packId":"gdansk","files":${files},"audio":{"manifestPath":"audio/manifest.json","clips":2},` +
    `"allowedTtsSha":"${SHA_A}"${extra}}`;
}

function ascii(b: number[]): string {
  let s = '';
  for (const c of b) {
    s += String.fromCharCode(c);
  }
  return s;
}

function parseObj(text: string): Object {
  return JSON.parse(text) as Object;
}

export default function remoteEnvelopeTest() {
  describe('RemoteEnvelope', () => {
    it('canonicalJsonMatchesNode', 0, () => {
      const env = parseEnvelope(ENVELOPE);
      expect(env.error).assertEqual('');
      expect(env.canonical).assertEqual(CANONICAL);
      expect(sha256Hex(env.canonical)).assertEqual(CANONICAL_SHA);
      expect(env.sig.length).assertEqual(64);
    });

    it('seedCatalogFromServer', 0, () => {
      const env = parseEnvelope(SEED_CATALOG);
      expect(env.error).assertEqual('');
      expect(sha256Hex(env.canonical)).assertEqual(SEED_CATALOG_CANONICAL_SHA);
      const cat = parseCatalog(env.payload);
      expect(cat.courses.length).assertEqual(1);
      expect(cat.courses[0].version).assertEqual('2026.10.03-41e1482c-a572a94e2');
      expect(cat.courses[0].bytes).assertEqual(40307550);
      // R6: the Kraków pack 2026.10.03-41e1482c + sha256(audio/manifest.json) 572a94e2... = the same version
      expect(courseVersion('2026.10.03-41e1482c', '572a94e2' + 'f'.repeat(56)))
        .assertEqual('2026.10.03-41e1482c-a572a94e2');
      expect(courseVersion('1.0', 'nothex')).assertEqual('1.0');
    });

    it('canonicalJsonScalarsAndNesting', 0, () => {
      expect(canonicalJson(parseObj('{"b":{"d":1,"c":[{"z":0,"y":"x"}]},"a":""}')))
        .assertEqual('{"a":"","b":{"c":[{"y":"x","z":0}],"d":1}}');
      expect(canonicalJson(parseObj('[ ]'))).assertEqual('[]');
      expect(canonicalJson(parseObj('{ }'))).assertEqual('{}');
      expect(canonicalJson(null)).assertEqual('null');
      // key order is by UTF-16 code unit: upper case before lower case
      expect(canonicalJson(parseObj('{"b":1,"B":2,"a":3}'))).assertEqual('{"B":2,"a":3,"b":1}');
    });

    it('base64Decode', 0, () => {
      const hello = base64Decode('aGVsbG8gd29ybGQhPw==');
      expect(hello !== undefined).assertTrue();
      expect((hello as number[]).length).assertEqual(13);
      expect(ascii(hello as number[])).assertEqual('hello world!?');
      const url = base64Decode('AAEC-vv8_f7_') as number[];
      expect(url.join(',')).assertEqual('0,1,2,250,251,252,253,254,255');
      expect(base64Decode('a') === undefined).assertTrue();
      expect(base64Decode('ab$c') === undefined).assertTrue();
      expect((base64Decode('') as number[]).length).assertEqual(0);
    });

    it('envelopeRejectsMalformed', 0, () => {
      expect(parseEnvelope('not json').error).assertEqual('json');
      expect(parseEnvelope('[1]').error).assertEqual('not_object');
      expect(parseEnvelope('{"sig":"' + SIG + '"}').error).assertEqual('no_payload');
      expect(parseEnvelope('{"payload":[],"sig":"' + SIG + '"}').error).assertEqual('no_payload');
      expect(parseEnvelope('{"payload":{}}').error).assertEqual('no_sig');
      expect(parseEnvelope('{"payload":{},"sig":"AAAA"}').error).assertEqual('bad_sig_encoding');
      expect(parseEnvelope('{"payload":{},"sig":"!!"}').error).assertEqual('bad_sig_encoding');
    });

    it('catalogValidatesRows', 0, () => {
      const env = parseEnvelope(ENVELOPE);
      const cat = parseCatalog(env.payload);
      expect(cat.error).assertEqual('');
      expect(cat.courses.length).assertEqual(1);
      const c = cat.courses[0];
      expect(c.id).assertEqual('krakow');
      expect(c.title.pl).assertEqual('Droga Królewska');
      expect(c.stops).assertEqual(6);
      expect(c.km).assertEqual(1.5);
      expect(c.langs.join(',')).assertEqual('en,pl,zh');
      expect(c.bytes).assertEqual(12345678);
      const bad = parseCatalog(parseObj('{"courses":[{"id":"../etc","version":"1"},{"id":"ok","version":"a/b"},' +
        '{"id":"ok","version":"1","stops":-3,"km":"x"},{"id":"ok","version":"2"},7]}'));
      expect(bad.courses.length).assertEqual(1);
      expect(bad.dropped).assertEqual(4);
      expect(bad.courses[0].stops).assertEqual(0);
      expect(bad.courses[0].title.en).assertEqual('ok');
      expect(parseCatalog(parseObj('{"x":1}')).error).assertEqual('no_courses');
      expect(parseCatalog(undefined).error).assertEqual('not_object');
    });

    it('manifestParsesAndLocatesPack', 0, () => {
      const m = parseCourseManifest(parseObj(manifestJson(
        `[{"path":"manifest.json","sha256":"${SHA_A}","bytes":10},{"path":"audio/en/x.mp3","sha256":"${SHA_B}","bytes":5}]`)),
        'gdansk');
      expect(m.error).assertEqual('');
      const man = m.manifest as CourseManifest;
      expect(man.files.length).assertEqual(2);
      expect(man.audioManifestPath).assertEqual('audio/manifest.json');
      expect(man.audioClips).assertEqual(2);
      expect(packManifestPath(man)).assertEqual('manifest.json');
      expect(packDir(man)).assertEqual('');
      const nested = parseCourseManifest(parseObj(manifestJson(
        `[{"path":"packs/gdansk/manifest.json","sha256":"${SHA_A}","bytes":10}]`)), 'gdansk');
      expect(packDir(nested.manifest as CourseManifest)).assertEqual('packs/gdansk/');
    });

    it('manifestRejectsUnsafe', 0, () => {
      const f = (p: string): string => `[{"path":"manifest.json","sha256":"${SHA_A}","bytes":1},` +
        `{"path":"${p}","sha256":"${SHA_B}","bytes":1}]`;
      expect(parseCourseManifest(parseObj(manifestJson(f('../x'))), 'gdansk').error.startsWith('file_entry'))
        .assertTrue();
      expect(parseCourseManifest(parseObj(manifestJson(f('/abs'))), 'gdansk').error.startsWith('file_entry'))
        .assertTrue();
      expect(parseCourseManifest(parseObj(manifestJson(f('manifest.json'))), 'gdansk').error.startsWith('file_entry'))
        .assertTrue();   // duplicate path
      expect(parseCourseManifest(parseObj(manifestJson(`[{"path":"manifest.json","sha256":"XYZ","bytes":1}]`)),
        'gdansk').error.startsWith('file_entry')).assertTrue();
      expect(parseCourseManifest(parseObj(manifestJson(`[{"path":"pois.json","sha256":"${SHA_A}","bytes":1}]`)),
        'gdansk').error).assertEqual('no_pack_manifest');
      expect(parseCourseManifest(parseObj(manifestJson(`[]`)), 'gdansk').error).assertEqual('files');
      expect(parseCourseManifest(parseObj(manifestJson(`[{"path":"manifest.json","sha256":"${SHA_A}","bytes":1}]`)),
        'krakow').error).assertEqual('course_id');
      expect(parseCourseManifest(parseObj('{"schemaVersion":2}'), 'gdansk').error).assertEqual('schema_2');
      expect(safeRelPath('audio/en/a_b-1.mp3')).assertTrue();
      expect(safeRelPath('a//b')).assertFalse();
      expect(safeRelPath('a/')).assertFalse();
      expect(validVersion('2026.10.03')).assertTrue();
      expect(validVersion('..')).assertFalse();
    });

    it('catalogCitiesAndCourseCity', 0, () => {
      const cat = parseCatalog(parseObj('{"courses":[{"id":"krakow-scholars","version":"1","cityId":"krakow",' +
        '"city":"Kraków"},{"id":"old","version":"1"},{"id":"bad","version":"1","cityId":"../x"}],' +
        '"cities":[{"id":"krakow","version":"2026.10.03-67db603d","names":{"en":"Kraków","pl":"Kraków","zh":"克拉科夫"},' +
        '"places":4290,"bytes":8200000},{"id":"../x","version":"1"},{"id":"krakow","version":"2"},' +
        '{"id":"gdansk","version":"1","places":-1}]}'));
      expect(cat.error).assertEqual('');
      expect(cat.courses.length).assertEqual(3);
      expect(cat.courses[0].cityId).assertEqual('krakow');
      expect(cat.courses[1].cityId).assertEqual('');             // an older self-contained course
      expect(cat.courses[2].cityId).assertEqual('');             // unsafe city id ignored
      expect(cat.cities.length).assertEqual(2);
      expect(cat.cities[0].id).assertEqual('krakow');
      expect(cat.cities[0].places).assertEqual(4290);
      expect(cat.cities[0].bytes).assertEqual(8200000);
      expect(cat.cities[1].places).assertEqual(0);
      expect(cat.dropped).assertEqual(2);                        // bad id + duplicate city
      expect(cityName(cat.cities[0].names, 'krakow', 'zh')).assertEqual('克拉科夫');
      expect(cityName(cat.cities[1].names, 'gdansk', 'pl')).assertEqual('gdansk');
      // an older catalog has no cities at all
      expect(parseCatalog(parseObj('{"courses":[]}')).cities.length).assertEqual(0);
    });

    it('cityManifestAndTourLayout', 0, () => {
      const city = parseCityManifest(parseObj('{"schemaVersion":1,"cityId":"krakow","version":"2026.10.03-67db603d",' +
        `"publishedAt":"x","packId":"krakow","files":[{"path":"manifest.json","sha256":"${SHA_A}","bytes":3},` +
        `{"path":"narrations/en.json","sha256":"${SHA_B}","bytes":4}]}`), 'krakow');
      expect(city.error).assertEqual('');
      const cm = city.manifest as CourseManifest;
      expect(cm.courseId).assertEqual('krakow');
      expect(cm.cityId).assertEqual('krakow');
      expect(cm.audioManifestPath).assertEqual('');
      expect(packDir(cm)).assertEqual('');
      expect(parseCityManifest(parseObj(`{"schemaVersion":1,"cityId":"krakow","version":"1","files":` +
        `[{"path":"manifest.json","sha256":"${SHA_A}","bytes":3}]}`), 'gdansk').error).assertEqual('city_id');
      expect(parseCityManifest(parseObj(`{"schemaVersion":1,"cityId":"krakow","version":"1","files":` +
        `[{"path":"../manifest.json","sha256":"${SHA_A}","bytes":3}]}`), 'krakow').error.startsWith('file_entry'))
        .assertTrue();
      expect(parseCityManifest(parseObj('{"schemaVersion":2}'), 'krakow').error).assertEqual('schema_2');
      // a course of a city: its own pack under tour/, plus cityId
      const course = parseCourseManifest(parseObj(manifestJson(
        `[{"path":"tour/manifest.json","sha256":"${SHA_A}","bytes":10},{"path":"tour/demo-walk.json","sha256":"${SHA_B}","bytes":5}]`,
        ',"cityId":"gdansk-city"')), 'gdansk');
      expect(course.error).assertEqual('');
      const m = course.manifest as CourseManifest;
      expect(m.cityId).assertEqual('gdansk-city');
      expect(packDir(m)).assertEqual('tour/');
      expect(parseCourseManifest(parseObj(manifestJson(`[{"path":"tour/manifest.json","sha256":"${SHA_A}","bytes":1}]`,
        ',"cityId":"Bad City"')), 'gdansk').error).assertEqual('city_id');
    });

    it('installTokenExpiry', 0, () => {
      expect(parseExpiresAt(1790000000)).assertEqual(1790000000000);
      expect(parseExpiresAt(1790000000000)).assertEqual(1790000000000);
      expect(parseExpiresAt('2026-11-02T00:00:00Z')).assertEqual(Date.UTC(2026, 10, 2));
      expect(Number.isNaN(parseExpiresAt('soon'))).assertTrue();
      const t = parseInstall('{"token":"abc.def","expiresAt":"2026-11-02T00:00:00Z"}');
      expect(t !== undefined).assertTrue();
      expect(tokenUsable(t, Date.UTC(2026, 9, 3))).assertTrue();
      expect(tokenUsable(t, Date.UTC(2026, 10, 1, 12))).assertFalse();   // inside the refresh margin
      expect(parseInstall('{"token":"","expiresAt":1}') === undefined).assertTrue();
      expect(parseInstall('{"token":"x"}') === undefined).assertTrue();
      expect(tokenUsable(undefined, 0)).assertFalse();
    });

    it('ttsBodyLimits', 0, () => {
      const len = (s: string): number => utf8Bytes(s).length;
      expect(ttsBodyJson('krakow', 'pl', 'To jest Barbakan.', len))
        .assertEqual('{"courseId":"krakow","lang":"pl","text":"To jest Barbakan."}');
      expect(ttsBodyJson('krakow', 'de', 'Hallo', len)).assertEqual('');
      expect(ttsBodyJson('krakow', 'en', '', len)).assertEqual('');
      expect(ttsBodyJson('krakow', 'en', 'x'.repeat(401), len)).assertEqual('');
      expect(ttsBodyJson('krakow', 'zh', '长'.repeat(400), len).length > 0).assertTrue();   // 1200 bytes <= 2 KB
      expect(ttsBodyJson('../x', 'en', 'Hi', len)).assertEqual('');
    });
  });
}

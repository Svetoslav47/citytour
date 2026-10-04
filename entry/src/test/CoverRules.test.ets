// Suite: CoverRules.test - module under test: core/remote/CoverRules (tour cover photos, SERVER.md §3 coverBlob).
// Cases: cover.json parsing (complete credit, missing author/licence, junk); the credit line "<author>, <licence>"
// (long authors shortened, control characters removed); the catalog credit; alt text per language with English
// fallback; cache file names; the source order installed > catalog cache > none (never a photo without a credit);
// the Home / Tour detail slot (placeholder while loading, photo, map fallback); which Courses rows get a banner;
// the course version with a cover tag and the catalog's coverCredit.
import { describe, it, expect } from '@ohos/hypium';
import {
  catalogCredit, chooseCover, coverCacheName, CoverCredit, CoverSource, coverSubject, creditText, CoverView,
  coverView, parseCoverJson, rowHasCover
} from 'common';
import { courseVersion, parseCatalog } from 'common';

const SHA: string = 'ab'.repeat(32);

const COVER_JSON: string = '{"schemaVersion":1,"file":"cover.jpg","width":1280,"height":800,' +
  '"subject":{"en":"Wawel Royal Castle","pl":"Zamek na Wawelu","zh":""},"author":"Jakub Hałun",' +
  '"license":"CC BY-SA 4.0","licenseUrl":"https://creativecommons.org/licenses/by-sa/4.0",' +
  '"sourceTitle":"File:Wawel.jpg","sourceUrl":"https://commons.wikimedia.org/wiki/File:Wawel.jpg",' +
  '"publisher":"Wikimedia Commons","changes":"Cropped","retrievedAt":"2026-10-03T22:01:58Z"}';

function credit(author: string, license: string): CoverCredit {
  const c = new CoverCredit();
  c.author = author;
  c.license = license;
  return c;
}

export default function coverRulesTest() {
  describe('CoverRules', () => {
    it('parsesCoverJson', 0, () => {
      const c = parseCoverJson(COVER_JSON) as CoverCredit;
      expect(c !== undefined).assertTrue();
      expect(c.author).assertEqual('Jakub Hałun');
      expect(c.license).assertEqual('CC BY-SA 4.0');
      expect(c.licenseUrl).assertEqual('https://creativecommons.org/licenses/by-sa/4.0');
      expect(c.sourceUrl).assertEqual('https://commons.wikimedia.org/wiki/File:Wawel.jpg');
      expect(c.subject.pl).assertEqual('Zamek na Wawelu');
    });

    it('rejectsCoverJsonWithoutCredit', 0, () => {
      expect(parseCoverJson('{"license":"CC BY-SA 4.0"}') === undefined).assertTrue();
      expect(parseCoverJson('{"author":"A"}') === undefined).assertTrue();
      expect(parseCoverJson('not json') === undefined).assertTrue();
      expect(parseCoverJson('[1,2]') === undefined).assertTrue();
      // a non-http licence URL is dropped, the credit stays
      const c = parseCoverJson('{"author":"A","license":"CC0 1.0","licenseUrl":"javascript:x"}') as CoverCredit;
      expect(c.licenseUrl).assertEqual('');
    });

    it('formatsCreditLine', 0, () => {
      expect(creditText('Jakub Hałun', 'CC BY-SA 4.0')).assertEqual('Jakub Hałun, CC BY-SA 4.0');
      expect(creditText('  Chris \n Olszewski ', 'CC BY-SA 4.0')).assertEqual('Chris Olszewski, CC BY-SA 4.0');
      const long = creditText('A'.repeat(60), 'CC BY 4.0');
      expect(long).assertEqual(`${'A'.repeat(39)}…, CC BY 4.0`);
      expect(creditText('', 'CC BY 4.0')).assertEqual('');
      expect(creditText('A', '')).assertEqual('');
    });

    it('cleansCatalogCredit', 0, () => {
      expect(catalogCredit('Marco Almbauer, CC BY-SA 4.0')).assertEqual('Marco Almbauer, CC BY-SA 4.0');
      expect(catalogCredit('Smith, J., CC BY 4.0')).assertEqual('Smith, J., CC BY 4.0');
      expect(catalogCredit('no licence')).assertEqual('');
      expect(catalogCredit('')).assertEqual('');
      expect(catalogCredit('Author,')).assertEqual('');
    });

    it('altTextPerLanguage', 0, () => {
      const c = parseCoverJson(COVER_JSON) as CoverCredit;
      expect(coverSubject(c, 'pl')).assertEqual('Zamek na Wawelu');
      expect(coverSubject(c, 'en')).assertEqual('Wawel Royal Castle');
      expect(coverSubject(c, 'zh')).assertEqual('Wawel Royal Castle');   // missing zh falls back to English
      expect(coverSubject(undefined, 'en')).assertEqual('');
    });

    it('cacheNameOnlyForValidSha', 0, () => {
      expect(coverCacheName(SHA)).assertEqual(`${SHA}.jpg`);
      expect(coverCacheName('../etc/passwd')).assertEqual('');
      expect(coverCacheName('AB'.repeat(32))).assertEqual('');
    });

    it('choosesInstalledThenCatalogThenNone', 0, () => {
      const inst = chooseCover('/c/pack/cover.jpg', credit('A', 'CC BY 4.0'), '/c/covers/x.jpg', 'B, CC0 1.0');
      expect(inst.source).assertEqual(CoverSource.INSTALLED);
      expect(inst.path).assertEqual('/c/pack/cover.jpg');
      expect(inst.credit).assertEqual('A, CC BY 4.0');
      const cat = chooseCover('', undefined, '/c/covers/x.jpg', 'B, CC0 1.0');
      expect(cat.source).assertEqual(CoverSource.CATALOG);
      expect(cat.credit).assertEqual('B, CC0 1.0');
      const none = chooseCover('', undefined, '', 'B, CC0 1.0');
      expect(none.source).assertEqual(CoverSource.NONE);
      expect(none.path).assertEqual('');
    });

    it('neverAPhotoWithoutCredit', 0, () => {
      // installed photo whose cover.json has no usable credit: falls through to the catalog, then to none
      expect(chooseCover('/p/cover.jpg', credit('', ''), '/c/x.jpg', 'B, CC0 1.0').source)
        .assertEqual(CoverSource.CATALOG);
      expect(chooseCover('/p/cover.jpg', undefined, '/c/x.jpg', '').source).assertEqual(CoverSource.NONE);
    });

    it('slotPlaceholderPhotoOrMap', 0, () => {
      expect(coverView(true, '')).assertEqual(CoverView.LOADING);
      expect(coverView(false, '')).assertEqual(CoverView.FALLBACK);
      expect(coverView(true, '/p.jpg')).assertEqual(CoverView.PHOTO);
      expect(coverView(false, '/p.jpg')).assertEqual(CoverView.PHOTO);
    });

    it('rowBanner', 0, () => {
      expect(rowHasCover(SHA, '')).assertTrue();
      expect(rowHasCover('', '/p/cover.jpg')).assertTrue();
      expect(rowHasCover('', '')).assertFalse();
      expect(rowHasCover('nothex', '')).assertFalse();
    });

    it('versionWithCoverTag', 0, () => {
      const audio = '572a94e2' + 'f'.repeat(56);
      expect(courseVersion('2026.10.03-41e1482c', audio, '0123abcd')).assertEqual('2026.10.03-41e1482c-a572a94e2-c0123abcd');
      expect(courseVersion('2026.10.03-41e1482c', audio, 'bad')).assertEqual('2026.10.03-41e1482c-a572a94e2');
    });

    it('catalogCoverFields', 0, () => {
      const payload = JSON.parse(`{"courses":[{"id":"krakow","version":"v1-c0123abcd","title":{"en":"The Royal Route"},` +
        `"coverBlob":"${SHA}","coverCredit":"Jakub Hałun, CC BY-SA 4.0"},` +
        `{"id":"krakow-scholars","version":"v1","coverCredit":"orphan credit, CC0 1.0"}]}`) as Object;
      const cat = parseCatalog(payload);
      expect(cat.courses.length).assertEqual(2);
      expect(cat.courses[0].coverBlob).assertEqual(SHA);
      expect(cat.courses[0].coverCredit).assertEqual('Jakub Hałun, CC BY-SA 4.0');
      // a credit without a cover is ignored
      expect(cat.courses[1].coverBlob).assertEqual('');
      expect(cat.courses[1].coverCredit).assertEqual('');
    });
  });
}

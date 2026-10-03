// Suite: CourseRules.test - module under test: core/remote/CourseRules (SERVER.md §6 CourseRepository + Courses screen).
// Cases: the bundled course is always present and first (no server, offline, catalog without it), never deletable;
// catalog-only = Download; installed + same version = Downloaded; another version = Update (also for the bundled id);
// installed courses stay listed offline; delete (active falls back to bundled, bundled refused); install replaces an
// older version; the active id resolves to bundled when its download is missing; titles, sizes and progress.
import { describe, it, expect } from '@ohos/hypium';
import {
  afterDelete, afterInstall, CourseRow, CourseState, courseTitle, InstalledCourse, mergeCourses, progressPct,
  resolveActive, sizeLabel
} from '../main/ets/core/remote/CourseRules';
import { CourseSummary } from '../main/ets/core/remote/ServerApi';

function course(id: string, version: string): CourseSummary {
  const c = new CourseSummary();
  c.id = id;
  c.version = version;
  c.title.en = `${id} en`;
  c.title.pl = `${id} pl`;
  return c;
}

function installed(id: string, version: string): InstalledCourse {
  const i = new InstalledCourse();
  i.id = id;
  i.version = version;
  i.summary = course(id, version);
  return i;
}

const BUNDLED: CourseSummary = course('krakow', '1.0.0');

function ids(rows: CourseRow[]): string {
  return rows.map((r: CourseRow) => `${r.summary.id}:${r.state}`).join(',');
}

export default function courseRulesTest() {
  describe('CourseRules', () => {
    it('bundledAlwaysPresentWithoutServer', 0, () => {
      const rows = mergeCourses(BUNDLED, [], undefined, '');
      expect(ids(rows)).assertEqual('krakow:builtin');
      expect(rows[0].builtin).assertTrue();
      expect(rows[0].canDelete).assertFalse();
      expect(rows[0].active).assertTrue();
      const r2 = mergeCourses(BUNDLED, [], [course('gdansk', '1')], '');
      expect(ids(r2)).assertEqual('krakow:builtin,gdansk:available');
    });

    it('catalogStates', 0, () => {
      const cat = [course('krakow', '1.0.0'), course('gdansk', '2'), course('warsaw', '1')];
      const rows = mergeCourses(BUNDLED, [installed('gdansk', '2'), installed('warsaw', '0')], cat, 'gdansk');
      expect(ids(rows)).assertEqual('krakow:builtin,gdansk:downloaded,warsaw:update');
      expect(rows[1].active).assertTrue();
      expect(rows[0].active).assertFalse();
      expect(rows[1].canDelete).assertTrue();
      expect(rows[2].installedVersion).assertEqual('0');
      expect(rows[2].summary.version).assertEqual('1');   // the row shows the catalog version
    });

    it('bundledIdUpdate', 0, () => {
      const newer = [course('krakow', '1.1.0')];
      expect(ids(mergeCourses(BUNDLED, [], newer, ''))).assertEqual('krakow:update');
      const rows = mergeCourses(BUNDLED, [installed('krakow', '1.1.0')], newer, '');
      expect(ids(rows)).assertEqual('krakow:downloaded');
      expect(rows[0].canDelete).assertTrue();     // deletes the downloaded update, the bundled copy stays
      expect(rows[0].builtin).assertTrue();
    });

    it('offlineKeepsInstalled', 0, () => {
      const rows = mergeCourses(BUNDLED, [installed('gdansk', '2')], undefined, 'gdansk');
      expect(ids(rows)).assertEqual('krakow:builtin,gdansk:downloaded');
      expect(rows[1].active).assertTrue();
      // a course the server no longer lists stays usable
      expect(ids(mergeCourses(BUNDLED, [installed('gdansk', '2')], [course('warsaw', '1')], '')))
        .assertEqual('krakow:builtin,warsaw:available,gdansk:downloaded');
    });

    it('activeFallsBackToBundled', 0, () => {
      expect(resolveActive('gdansk', 'krakow', [])).assertEqual('krakow');
      expect(resolveActive('', 'krakow', [installed('gdansk', '2')])).assertEqual('krakow');
      expect(resolveActive('gdansk', 'krakow', [installed('gdansk', '2')])).assertEqual('gdansk');
      const rows = mergeCourses(BUNDLED, [], [course('gdansk', '2')], 'gdansk');
      expect(rows[0].active).assertTrue();
      expect(rows[1].active).assertFalse();
    });

    it('deleteRules', 0, () => {
      const list = [installed('gdansk', '2'), installed('warsaw', '1')];
      const d = afterDelete(list, 'gdansk', 'gdansk', 'krakow');
      expect(d.allowed).assertTrue();
      expect(d.installed.length).assertEqual(1);
      expect(d.activeId).assertEqual('krakow');
      const d2 = afterDelete(list, 'warsaw', 'gdansk', 'krakow');
      expect(d2.activeId).assertEqual('gdansk');
      const d3 = afterDelete(list, 'krakow', 'krakow', 'krakow');
      expect(d3.allowed).assertFalse();
      expect(d3.installed.length).assertEqual(2);
    });

    it('installReplacesOlderVersion', 0, () => {
      const list = afterInstall([installed('gdansk', '1'), installed('warsaw', '1')], installed('gdansk', '2'));
      expect(list.length).assertEqual(2);
      expect(list.filter((i: InstalledCourse) => i.id === 'gdansk')[0].version).assertEqual('2');
    });

    it('titlesSizesProgress', 0, () => {
      const c = course('gdansk', '1');
      expect(courseTitle(c, 'pl')).assertEqual('gdansk pl');
      expect(courseTitle(c, 'zh')).assertEqual('gdansk en');   // no zh title: English
      c.title.en = '';
      c.title.pl = '';
      expect(courseTitle(c, 'en')).assertEqual('gdansk');
      expect(sizeLabel(12345678)).assertEqual('11.8 MB');
      expect(sizeLabel(2048)).assertEqual('2 KB');
      expect(sizeLabel(0)).assertEqual('');
      expect(progressPct(50, 200, 0, 0)).assertEqual(25);
      expect(progressPct(0, 0, 3, 4)).assertEqual(75);
      expect(progressPct(500, 200, 0, 0)).assertEqual(100);
      expect(progressPct(0, 0, 0, 0)).assertEqual(0);
    });
  });
}

// Suite: CourseRules.test - module under test: core/remote/CourseRules (SERVER.md §6 CourseRepository + Courses screen).
// The app ships NO built-in course. Cases: first run lists only the catalog (nothing installed, no active course);
// catalog-only = Download; installed + same version = Downloaded; another version = Update; installed courses stay
// listed offline; the active id resolves to '' with nothing installed, to the saved one, or to the first installed;
// the first download becomes active, a later one does not; delete (active -> another installed course or none);
// install replaces an older version; Home's mode (loading / empty state / ready / error); the Demo walk for any active
// course whose pack ships a demo track (no course id is special); two courses of one city side by side; the city
// places pack: download when missing/outdated, removal with the last course of the city; titles, sizes and progress.
import { describe, it, expect } from '@ohos/hypium';
import {
  activeAfterInstall, afterDelete, afterInstall, cityNeedsDownload, CourseRow, CourseState, courseTitle,
  demoWalkOffered, orphanCities, HomeMode, homeMode, InstalledCourse, mergeCourses, progressPct, resolveActive, sizeLabel
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

function ids(rows: CourseRow[]): string {
  return rows.map((r: CourseRow) => `${r.summary.id}:${r.state}`).join(',');
}

export default function courseRulesTest() {
  describe('CourseRules', () => {
    it('firstRunNoBuiltInCourse', 0, () => {
      // No server reached and nothing installed: no rows at all (the UI shows the offline/empty note).
      expect(mergeCourses([], undefined, '').length).assertEqual(0);
      const rows = mergeCourses([], [course('krakow', '1')], '');
      expect(ids(rows)).assertEqual('krakow:available');
      expect(rows[0].active).assertFalse();
      expect(rows[0].canDelete).assertFalse();
      expect(rows[0].canSelect).assertFalse();
      expect(resolveActive('', [])).assertEqual('');
    });

    it('catalogStates', 0, () => {
      const cat = [course('krakow', '1.0.0'), course('gdansk', '2'), course('warsaw', '1')];
      const rows = mergeCourses([installed('gdansk', '2'), installed('warsaw', '0')], cat, 'gdansk');
      expect(ids(rows)).assertEqual('krakow:available,gdansk:downloaded,warsaw:update');
      expect(rows[1].active).assertTrue();
      expect(rows[0].active).assertFalse();
      expect(rows[1].canDelete).assertTrue();
      expect(rows[1].canSelect).assertTrue();
      expect(rows[2].installedVersion).assertEqual('0');
      expect(rows[2].summary.version).assertEqual('1');   // the row shows the catalog version
    });

    it('offlineKeepsInstalled', 0, () => {
      const rows = mergeCourses([installed('krakow', '2')], undefined, 'krakow');
      expect(ids(rows)).assertEqual('krakow:downloaded');
      expect(rows[0].active).assertTrue();
      // a course the server no longer lists stays usable
      expect(ids(mergeCourses([installed('gdansk', '2')], [course('warsaw', '1')], '')))
        .assertEqual('warsaw:available,gdansk:downloaded');
    });

    it('activeResolution', 0, () => {
      expect(resolveActive('gdansk', [])).assertEqual('');                                     // saved one gone
      expect(resolveActive('', [installed('gdansk', '2')])).assertEqual('gdansk');              // first installed
      expect(resolveActive('gdansk', [installed('krakow', '1'), installed('gdansk', '2')])).assertEqual('gdansk');
      expect(resolveActive('warsaw', [installed('krakow', '1'), installed('gdansk', '2')])).assertEqual('krakow');
      // the merged rows mark the resolved active course
      const rows = mergeCourses([installed('krakow', '1')], [course('krakow', '1')], 'gone');
      expect(rows[0].active).assertTrue();
    });

    it('firstDownloadBecomesActive', 0, () => {
      expect(activeAfterInstall('', 'krakow')).assertEqual('krakow');
      expect(activeAfterInstall('krakow', 'gdansk')).assertEqual('krakow');   // later downloads do not switch
      expect(activeAfterInstall('krakow', 'krakow')).assertEqual('krakow');   // an update of the active course
    });

    it('deleteRules', 0, () => {
      const list = [installed('gdansk', '2'), installed('warsaw', '1')];
      const d = afterDelete(list, 'gdansk', 'gdansk');
      expect(d.allowed).assertTrue();
      expect(d.installed.length).assertEqual(1);
      expect(d.activeId).assertEqual('warsaw');   // the active one was deleted: another installed course
      const d2 = afterDelete(list, 'warsaw', 'gdansk');
      expect(d2.activeId).assertEqual('gdansk');
      const d3 = afterDelete(list, 'krakow', 'gdansk');
      expect(d3.allowed).assertFalse();
      expect(d3.installed.length).assertEqual(2);
      // deleting the last (active) course: no course, Home goes back to the empty state
      const d4 = afterDelete([installed('krakow', '1')], 'krakow', 'krakow');
      expect(d4.allowed).assertTrue();
      expect(d4.installed.length).assertEqual(0);
      expect(d4.activeId).assertEqual('');
    });

    it('installReplacesOlderVersion', 0, () => {
      const list = afterInstall([installed('gdansk', '1'), installed('warsaw', '1')], installed('gdansk', '2'));
      expect(list.length).assertEqual(2);
      expect(list.filter((i: InstalledCourse) => i.id === 'gdansk')[0].version).assertEqual('2');
    });

    it('homeModeEmptyState', 0, () => {
      expect(homeMode(true, false, false)).assertEqual(HomeMode.LOADING);
      expect(homeMode(false, false, false)).assertEqual(HomeMode.NO_COURSE);   // first run: "Download your first walk"
      expect(homeMode(false, false, true)).assertEqual(HomeMode.NO_COURSE);
      expect(homeMode(false, true, true)).assertEqual(HomeMode.READY);
      expect(homeMode(false, true, false)).assertEqual(HomeMode.ERROR);       // installed but unreadable
    });

    it('demoWalkWhereverThePackHasATrack', 0, () => {
      expect(demoWalkOffered('krakow', true)).assertTrue();
      expect(demoWalkOffered('gdansk', true)).assertTrue();          // any city, any course id
      expect(demoWalkOffered('krakow-scholars', false)).assertFalse();   // its pack ships no demo-walk.json
      expect(demoWalkOffered('', true)).assertFalse();               // no active course
      expect(demoWalkOffered('', false)).assertFalse();
    });

    it('cityPackDownloadAndCleanup', 0, () => {
      expect(cityNeedsDownload('', '')).assertTrue();                // first course of the city, catalog unknown
      expect(cityNeedsDownload('', 'c1')).assertTrue();
      expect(cityNeedsDownload('c1', 'c1')).assertFalse();           // second course of the city: shared, no download
      expect(cityNeedsDownload('c1', 'c2')).assertTrue();            // the catalog has a newer city pack
      expect(cityNeedsDownload('c1', '')).assertFalse();             // offline / older catalog: keep the installed one
      // removal: only cities no remaining course uses
      expect(orphanCities(['krakow', 'gdansk'], ['krakow', 'krakow']).join(',')).assertEqual('gdansk');
      expect(orphanCities(['krakow'], ['krakow', '']).length).assertEqual(0);
      expect(orphanCities(['krakow'], ['']).join(',')).assertEqual('krakow');   // only a self-contained course left
      expect(orphanCities([], []).length).assertEqual(0);
    });

    it('twoKrakowCourses', 0, () => {
      // catalog order; the Royal Route installed and active, Scholars and Saints only on the server
      const cat = [course('krakow', '1'), course('krakow-scholars', '1')];
      expect(ids(mergeCourses([installed('krakow', '1')], cat, 'krakow'))).assertEqual('krakow:downloaded,krakow-scholars:available');
      // download it: the active course stays the Royal Route until the user selects the new one
      const both = afterInstall([installed('krakow', '1')], installed('krakow-scholars', '1'));
      expect(activeAfterInstall('krakow', 'krakow-scholars')).assertEqual('krakow');
      const rows = mergeCourses(both, cat, 'krakow-scholars');   // the user selected it
      expect(ids(rows)).assertEqual('krakow:downloaded,krakow-scholars:downloaded');
      expect(rows[1].active).assertTrue();
      expect(rows[0].active).assertFalse();
      // deleting the active Scholars course makes the Royal Route active again
      expect(afterDelete(both, 'krakow-scholars', 'krakow-scholars').activeId).assertEqual('krakow');
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

// Suite: StreamRules.test - module under test: core/remote/StreamRules (SERVER.md §6 "Streaming a course").
// Cases: which course/city files a stream fetches up front (no clips, no city places/stories); downloaded wins over
// streamed; streamed courses can be active after the downloaded ones; when Play now must (re)prepare; "All places"
// only with the city downloaded; Download reuses the stream's files; the row's Play now / Download buttons; the clip
// chain (on device -> play, unknown or offline back-off -> fallback, else fetch); prefetch of the next sentences.
import { describe, it, expect } from '@ohos/hypium';
import {
  activeCandidates, allPlacesAvailable, clipStep, ClipStep, CourseSource, courseSource, isClipFile, prefetchAfter,
  reusableForDownload, StreamClip, streamCityFiles, streamClipFiles, streamCourseFiles, streamNeedsPrepare,
  streamRowActions
} from '../main/ets/core/remote/StreamRules';
import { InstalledCourse } from '../main/ets/core/remote/CourseRules';
import { CourseFile } from '../main/ets/core/remote/ServerApi';
import { ClipEntry, ClipIndex, ClipReason } from '../main/ets/core/speech/ClipSelection';

function file(path: string): CourseFile {
  const f = new CourseFile();
  f.path = path;
  f.sha256 = 'a'.repeat(64);
  f.bytes = 10;
  return f;
}

function paths(fs: CourseFile[]): string {
  return fs.map((f: CourseFile) => f.path).join(',');
}

function inst(id: string): InstalledCourse {
  const i = new InstalledCourse();
  i.id = id;
  i.version = 'v1';
  return i;
}

function clip(poiId: string, n: number, lang: string = 'en', length: string = 'full'): StreamClip {
  const c = new StreamClip();
  c.lang = lang;
  c.poiId = poiId;
  c.personaId = 'guide';
  c.length = length;
  c.n = n;
  c.file = `/s/audio/${lang}/${poiId}/${length}_${n}.mp3`;
  return c;
}

export default function streamRulesTest() {
  describe('StreamRules', () => {
    it('courseFilesWithoutClips', 0, () => {
      const fs = [file('tour/manifest.json'), file('tour/pois.json'), file('tour/narrations/en.json'),
        file('audio/manifest.json'), file('audio/en/poi_a/full_0.mp3'), file('audio/pl/sys/x.mp3')];
      expect(paths(streamCourseFiles(fs, 'audio/manifest.json')))
        .assertEqual('tour/manifest.json,tour/pois.json,tour/narrations/en.json,audio/manifest.json');
      expect(paths(streamClipFiles(fs, 'audio/manifest.json'))).assertEqual('audio/en/poi_a/full_0.mp3,audio/pl/sys/x.mp3');
      expect(isClipFile('audio/manifest.json', 'audio/manifest.json')).assertFalse();
      expect(isClipFile('tour/audio.json', 'audio/manifest.json')).assertFalse();
    });

    it('cityFilesOnlyManifestCityJsonMap', 0, () => {
      const fs = [file('city.json'), file('manifest.json'), file('map-detail.json'), file('pois.json'),
        file('narrations/en.json'), file('sources.json')];
      expect(paths(streamCityFiles(fs))).assertEqual('city.json,manifest.json,map-detail.json');
    });

    it('downloadedWinsOverStreamed', 0, () => {
      expect(courseSource('a', ['a'], ['a'])).assertEqual(CourseSource.DOWNLOADED);
      expect(courseSource('b', ['a'], ['b'])).assertEqual(CourseSource.STREAMED);
      expect(courseSource('c', ['a'], ['b'])).assertEqual(CourseSource.NONE);
      expect(courseSource('', ['a'], [''])).assertEqual(CourseSource.NONE);
    });

    it('activeCandidatesDownloadedFirst', 0, () => {
      const c = activeCandidates([inst('a')], [inst('a'), inst('b')]);
      expect(c.map((i: InstalledCourse) => i.id).join(',')).assertEqual('a,b');
      expect(activeCandidates([], [inst('s')]).length).assertEqual(1);
    });

    it('prepareWhenMissingOrNewer', 0, () => {
      expect(streamNeedsPrepare('', 'v1')).assertTrue();
      expect(streamNeedsPrepare('v1', 'v1')).assertFalse();
      expect(streamNeedsPrepare('v1', 'v2')).assertTrue();
      expect(streamNeedsPrepare('v1', '')).assertFalse();   // offline: keep the streamed copy
    });

    it('allPlacesNeedsTheCity', 0, () => {
      expect(allPlacesAvailable('krakow', false)).assertFalse();
      expect(allPlacesAvailable('krakow', true)).assertTrue();
      expect(allPlacesAvailable('', false)).assertTrue();
    });

    it('downloadReusesStreamedFiles', 0, () => {
      const fs = [file('tour/pois.json'), file('audio/manifest.json'), file('audio/en/p/full_0.mp3'),
        file('audio/en/p/full_1.mp3')];
      expect(paths(reusableForDownload(fs, ['tour/pois.json', 'audio/en/p/full_1.mp3', 'other.json'])))
        .assertEqual('tour/pois.json,audio/en/p/full_1.mp3');
      expect(reusableForDownload(fs, []).length).assertEqual(0);
    });

    it('rowActions', 0, () => {
      const avail = streamRowActions(CourseSource.NONE, false, true);
      expect(avail.playNow).assertTrue();
      expect(avail.download).assertTrue();
      expect(avail.streaming).assertFalse();
      const playing = streamRowActions(CourseSource.STREAMED, true, true);
      expect(playing.playNow).assertFalse();   // already the active walk
      expect(playing.download).assertTrue();   // upgrade to offline
      expect(playing.streaming).assertTrue();
      const other = streamRowActions(CourseSource.STREAMED, false, true);
      expect(other.playNow).assertTrue();
      const offline = streamRowActions(CourseSource.STREAMED, false, false);
      expect(offline.playNow).assertTrue();    // a streamed copy can be used without the server
      expect(offline.download).assertFalse();
      expect(streamRowActions(CourseSource.NONE, false, false).playNow).assertFalse();
      const dl = streamRowActions(CourseSource.DOWNLOADED, false, true);
      expect(dl.playNow || dl.download || dl.streaming).assertFalse();
    });

    it('clipChain', 0, () => {
      expect(clipStep(true, true, 1000, 5000)).assertEqual(ClipStep.PLAY);     // cached plays even offline
      expect(clipStep(false, true, 1000, 0)).assertEqual(ClipStep.FETCH);
      expect(clipStep(false, true, 1000, 5000)).assertEqual(ClipStep.FALLBACK); // offline back-off: no 3 s wait
      expect(clipStep(false, false, 1000, 0)).assertEqual(ClipStep.FALLBACK);   // not in the signed manifest
    });

    it('prefetchNextSentencesOfTheStory', 0, () => {
      const all = [clip('a', 0), clip('a', 3), clip('a', 1), clip('a', 2), clip('a', 4), clip('b', 1),
        clip('a', 1, 'pl'), clip('a', 1, 'en', 'short')];
      const got = prefetchAfter(all, clip('a', 0), 3);
      expect(got.join(',')).assertEqual('/s/audio/en/a/full_1.mp3,/s/audio/en/a/full_2.mp3,/s/audio/en/a/full_3.mp3');
      expect(prefetchAfter(all, clip('a', 4)).length).assertEqual(0);
      expect(prefetchAfter(all, clip('', 0)).length).assertEqual(0);   // system lines: on demand only
    });

    it('lateClipPlaysAgain', 0, () => {
      // A streamed clip that missed its 3 s budget is marked unavailable (the sentence falls back), then plays again
      // once it arrives.
      const e: ClipEntry = {
        lang: 'en', poiId: 'a', personaId: 'guide', length: 'full', n: 0, file: '/s/a.mp3', textSha256: 'f'.repeat(64),
        durationMs: 0
      };
      const idx = new ClipIndex([e]);
      idx.markFailed('/s/a.mp3');
      expect(idx.find('f'.repeat(64), 'en', 'guide').reason).assertEqual(ClipReason.CLIP_FAILED);
      idx.clearFailed('/s/a.mp3');
      expect(idx.find('f'.repeat(64), 'en', 'guide').reason).assertEqual(ClipReason.HASH_MATCH);
    });
  });
}

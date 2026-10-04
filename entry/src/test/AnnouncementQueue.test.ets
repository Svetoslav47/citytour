// Suite: AnnouncementQueue.test - module under test: core/tour/AnnouncementQueue (task A3).
// Cases from docs/ARCHITECTURE.md §11.1: P1 arriving mid-P2 plays after the current sentence, then P2 resumes
// at its cursor; expiry drops a stale P1; dedupe; skip-after-current; text-only timer pacing.
// Plus: one sentence in flight, a started item beats a fresh one of the same priority, pause restarts the
// sentence with a new id (a late DONE of the cut one is ignored), empty items refused, stale cue removal.
import { describe, it, expect } from '@ohos/hypium';
import {
  AnnouncementQueue, QueueAdvance, expiryFor, readingTimeMs, readingWords, stripMarkup
} from 'common';
import { TourConfig, defaultTourConfig } from 'common';
import { Announcement, AnnouncementKind, Priority } from 'common';
import { Utterance } from 'common';
import { Lang } from 'common';

function item(id: string, priority: Priority, n: number, nowMs: number, cfg: TourConfig): Announcement {
  const us: Utterance[] = [];
  for (let i = 0; i < n; i++) {
    const u: Utterance = { id: `${id}.${i}`, itemId: id, text: `${id} sentence ${i}.`, lang: Lang.EN, personaId: 'historian' };
    us.push(u);
  }
  const a: Announcement = {
    id: id, priority: priority, kind: AnnouncementKind.STOP_STORY, utterances: us, cursor: 0,
    expiresAtMs: expiryFor(priority, nowMs, cfg), dedupeKey: `key:${id}`
  };
  return a;
}

/** Hands out the next sentence and returns its text ('' when nothing is handed out). */
function nextText(q: AnnouncementQueue): string {
  const u: Utterance | undefined = q.next();
  return u === undefined ? '' : u.text;
}

/** Finishes the in-flight sentence. */
function done(q: AnnouncementQueue): QueueAdvance {
  const u: Utterance | undefined = q.inFlight();
  return q.onDone(u === undefined ? 'none' : u.id);
}

export default function announcementQueueTest() {
  describe('AnnouncementQueue', () => {
    it('one_sentence_in_flight_until_done', 0, () => {
      const cfg: TourConfig = defaultTourConfig();
      const q: AnnouncementQueue = new AnnouncementQueue();
      expect(q.enqueue(item('a', Priority.P2_STORY, 3, 0, cfg))).assertTrue();
      expect(nextText(q)).assertEqual('a sentence 0.');
      expect(q.isBusy()).assertTrue();
      expect(q.next() === undefined).assertTrue();                 // busy: nothing new
      expect(q.onDone('someone-else').matched).assertFalse();      // stray DONE ignored
      expect(q.isBusy()).assertTrue();
      const r: QueueAdvance = done(q);
      expect(r.matched).assertTrue();
      expect(r.finished).assertFalse();
      expect(nextText(q)).assertEqual('a sentence 1.');
      done(q);
      expect(nextText(q)).assertEqual('a sentence 2.');
      const last: QueueAdvance = done(q);
      expect(last.finished).assertTrue();
      expect(q.size()).assertEqual(0);
      expect(q.next() === undefined).assertTrue();
    });

    it('p1_mid_p2_plays_after_current_sentence_then_p2_resumes_at_cursor', 0, () => {
      const cfg: TourConfig = defaultTourConfig();
      const q: AnnouncementQueue = new AnnouncementQueue();
      q.enqueue(item('story', Priority.P2_STORY, 3, 0, cfg));
      expect(nextText(q)).assertEqual('story sentence 0.');
      q.enqueue(item('nav', Priority.P1_NAV, 2, 1000, cfg));       // arrives mid-sentence
      expect(q.next() === undefined).assertTrue();                 // the sentence is never cut
      done(q);
      expect(nextText(q)).assertEqual('nav sentence 0.');
      done(q);
      expect(nextText(q)).assertEqual('nav sentence 1.');
      expect(done(q).finished).assertTrue();
      expect(nextText(q)).assertEqual('story sentence 1.');        // resumes at its cursor
      done(q);
      expect(nextText(q)).assertEqual('story sentence 2.');
      expect(done(q).finished).assertTrue();
    });

    it('started_item_beats_fresh_item_of_same_priority', 0, () => {
      const cfg: TourConfig = defaultTourConfig();
      const q: AnnouncementQueue = new AnnouncementQueue();
      q.enqueue(item('a', Priority.P2_STORY, 2, 0, cfg));
      nextText(q);
      q.enqueue(item('p0', Priority.P0_SYSTEM, 1, 0, cfg));
      q.enqueue(item('b', Priority.P2_STORY, 1, 0, cfg));
      done(q);
      expect(nextText(q)).assertEqual('p0 sentence 0.');
      done(q);
      expect(nextText(q)).assertEqual('a sentence 1.');
      done(q);
      expect(nextText(q)).assertEqual('b sentence 0.');
    });

    it('expiry_drops_stale_p1_but_never_the_in_flight_item', 0, () => {
      const cfg: TourConfig = defaultTourConfig();
      expect(expiryFor(Priority.P0_SYSTEM, 1000, cfg)).assertEqual(31000);
      expect(expiryFor(Priority.P1_NAV, 1000, cfg)).assertEqual(21000);
      expect(expiryFor(Priority.P2_STORY, 1000, cfg)).assertEqual(Number.POSITIVE_INFINITY);
      expect(expiryFor(Priority.P3_APPROACH, 1000, cfg)).assertEqual(31000);
      expect(expiryFor(Priority.P4_AMBIENT, 1000, cfg)).assertEqual(61000);

      const q: AnnouncementQueue = new AnnouncementQueue();
      q.enqueue(item('story', Priority.P2_STORY, 2, 0, cfg));
      nextText(q);
      q.enqueue(item('turn', Priority.P1_NAV, 1, 0, cfg));
      expect(q.expire(20000).length).assertEqual(0);              // exactly at the deadline: kept
      const dropped: Announcement[] = q.expire(25000);
      expect(dropped.length).assertEqual(1);
      expect(dropped[0].id).assertEqual('turn');
      done(q);
      expect(nextText(q)).assertEqual('story sentence 1.');       // P2 never expires

      const r: AnnouncementQueue = new AnnouncementQueue();
      r.enqueue(item('cue', Priority.P1_NAV, 2, 0, cfg));
      nextText(r);
      expect(r.expire(60000).length).assertEqual(0);              // in flight: kept
    });

    it('dedupe_key_accepted_once', 0, () => {
      const cfg: TourConfig = defaultTourConfig();
      const q: AnnouncementQueue = new AnnouncementQueue();
      const a: Announcement = item('a', Priority.P3_APPROACH, 1, 0, cfg);
      expect(q.enqueue(a)).assertTrue();
      const again: Announcement = item('a2', Priority.P3_APPROACH, 1, 0, cfg);
      again.dedupeKey = a.dedupeKey;
      expect(q.enqueue(again)).assertFalse();
      expect(q.size()).assertEqual(1);
      nextText(q);
      done(q);
      expect(q.enqueue(again)).assertFalse();                     // also after the first one played
      expect(q.wasEnqueued('key:a')).assertTrue();
      const empty: Announcement = item('e', Priority.P2_STORY, 0, 0, cfg);
      expect(q.enqueue(empty)).assertFalse();                     // nothing to say
    });

    it('skip_drops_rest_of_item_after_current_sentence', 0, () => {
      const cfg: TourConfig = defaultTourConfig();
      const q: AnnouncementQueue = new AnnouncementQueue();
      q.enqueue(item('story', Priority.P2_STORY, 3, 0, cfg));
      q.enqueue(item('next', Priority.P2_STORY, 1, 0, cfg));
      nextText(q);
      const skipped: Announcement | undefined = q.skipCurrent();
      expect(skipped !== undefined && skipped.id === 'story').assertTrue();
      expect(q.isBusy()).assertTrue();                            // the current sentence still finishes
      expect(q.next() === undefined).assertTrue();
      const r: QueueAdvance = done(q);
      expect(r.matched).assertTrue();
      expect(r.item === undefined).assertTrue();
      expect(nextText(q)).assertEqual('next sentence 0.');
    });

    it('pause_restarts_the_sentence_with_a_new_id', 0, () => {
      const cfg: TourConfig = defaultTourConfig();
      const q: AnnouncementQueue = new AnnouncementQueue();
      q.enqueue(item('story', Priority.P2_STORY, 2, 0, cfg));
      const first: Utterance | undefined = q.next();
      const cut: Utterance | undefined = q.interrupt();
      expect(first !== undefined && cut !== undefined && first.id === cut.id).assertTrue();
      expect(q.isBusy()).assertFalse();
      expect(q.onDone(first === undefined ? '' : first.id).matched).assertFalse(); // late DONE of the cut one
      const again: Utterance | undefined = q.next();
      expect(again !== undefined && again.text === 'story sentence 0.').assertTrue();
      expect(again !== undefined && first !== undefined && again.id !== first.id).assertTrue();
    });

    it('remove_waiting_cue_and_clear', 0, () => {
      const cfg: TourConfig = defaultTourConfig();
      const q: AnnouncementQueue = new AnnouncementQueue();
      q.enqueue(item('story', Priority.P2_STORY, 2, 0, cfg));
      q.enqueue(item('approach', Priority.P3_APPROACH, 1, 0, cfg));
      nextText(q);
      expect(q.removeWaiting('key:story') === undefined).assertTrue();   // in flight: not removable
      expect(q.removeWaiting('key:approach') !== undefined).assertTrue();
      expect(q.size()).assertEqual(1);
      q.clear();
      expect(q.size()).assertEqual(0);
      expect(q.isBusy()).assertFalse();
    });

    it('text_only_reading_timer', 0, () => {
      const cfg: TourConfig = defaultTourConfig();
      expect(readingTimeMs('Short one.', cfg)).assertEqual(2500);                  // floor 2.5 s
      // 13 words / 2.6 words per second = 5 s
      expect(readingTimeMs('One two three four five six seven eight nine ten eleven twelve thirteen.', cfg))
        .assertEqual(5000);
      expect(stripMarkup('[p300] Look up. [n1]')).assertEqual('Look up.');
      expect(readingWords('[p600] Look left, and up at the taller tower.')).assertEqual(8);
      // 20 CJK characters count as 10 words => 3846 ms
      expect(readingTimeMs('圣玛丽大教堂在您左侧请抬头看较高的塔楼好', cfg)).assertEqual(Math.round(10 / 2.6 * 1000));
    });
  });
}

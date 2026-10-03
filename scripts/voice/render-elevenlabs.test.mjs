// Tests for render-elevenlabs.mjs (task A13). No network, no key: only the pure helpers and the dry run.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { join } from 'node:path';
import {
  FIXTURE_NARRATIONS_DIR, buildManifest, clipKey, clipRelPath, collectClips, main, manifestEntry, parseArgs,
  parseOutputFormat, planRender, sha256Hex, stripPauseMarkup, summarize, toElevenLabsText
} from './render-elevenlabs.mjs';

// Shared with entry/src/test/ClipSelection.test.ets: the ArkTS SHA-256 must give the same hex for these.
export const HASH_VECTORS = [
  ['', 'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855'],
  ['abc', 'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad'],
  ['This is Barbican.', sha256Hex('This is Barbican.')],
];

test('sha256Hex: standard vectors (utf-8, lowercase hex)', () => {
  assert.equal(sha256Hex(''), HASH_VECTORS[0][1]);
  assert.equal(sha256Hex('abc'), HASH_VECTORS[1][1]);
  // Multi-byte text hashes its UTF-8 bytes.
  assert.equal(sha256Hex('Zażółć'), sha256Hex(Buffer.from('Zażółć', 'utf8').toString('utf8')));
  assert.notEqual(sha256Hex('This is Barbican.'), sha256Hex('This is Barbican. '));
});

test('toElevenLabsText: pauses become break tags, other markup dropped', () => {
  assert.equal(toElevenLabsText('Look up.[p300] The tower [n1]is tall.'),
    'Look up. <break time="0.3s" /> The tower is tall.');
  assert.equal(stripPauseMarkup('A [p500] B'), 'A B');
});

test('parseOutputFormat', () => {
  assert.deepEqual(parseOutputFormat('mp3_44100_64'), { codec: 'mp3', sampleRate: 44100, kbps: 64 });
  assert.throws(() => parseOutputFormat('pcm_16000'));
});

test('clipRelPath is rawfile-relative and sanitised', () => {
  assert.equal(clipRelPath('en', 'poi_wd_Q807309', 'full', 2), 'audio/en/poi_wd_Q807309/full_2.mp3');
  assert.equal(clipRelPath('en', '../x', 'full', 0), 'audio/en/.._x/full_0.mp3');
});

const NARR = {
  en: [
    { poiId: 'p1', personaId: 'historian', lang: 'en', length: 'teaser', sentences: ['One.', 'Two [p300] two.'] },
    { poiId: 'p1', personaId: 'historian', lang: 'en', length: 'full', sentences: ['Full one.', '   ', 'Full three.'] },
    { poiId: 'p2', personaId: 'kids', lang: 'en', length: 'teaser', sentences: ['Kids.'] },
    { poiId: 'p9', personaId: 'historian', lang: 'en', length: 'teaser', sentences: ['Not on the tour.'] },
  ],
  zh: [{ poiId: 'p1', personaId: 'historian', lang: 'zh', length: 'teaser', sentences: ['你好。'] }],
};

test('collectClips: one clip per non-empty sentence, filtered by persona, length, tour', () => {
  const clips = collectClips(NARR, {
    langs: ['en', 'zh', 'pl'], lengths: ['teaser', 'full'], persona: 'historian', poiIds: new Set(['p1', 'p2'])
  });
  assert.deepEqual(clips.map((c) => c.file), [
    'audio/en/p1/teaser_0.mp3', 'audio/en/p1/teaser_1.mp3', 'audio/en/p1/full_0.mp3', 'audio/en/p1/full_2.mp3',
    'audio/zh/p1/teaser_0.mp3'
  ]);
  const two = clips[1];
  assert.equal(two.textSha256, sha256Hex('Two [p300] two.'));   // hash of the exact app text, markup included
  assert.equal(two.ttsText, 'Two <break time="0.3s" /> two.');
  assert.equal(two.previousText, 'One.');
  assert.equal(two.nextText, '');
  const teaserOnly = collectClips(NARR, { langs: ['en'], lengths: ['teaser'], persona: 'historian', poiIds: null });
  assert.equal(teaserOnly.length, 3);
});

test('summarize: credits = characters, per language', () => {
  const clips = collectClips(NARR, { langs: ['en', 'zh'], lengths: ['teaser'], persona: 'historian', poiIds: null });
  const s = summarize(clips, 64);
  const en = s.rows.find((r) => r.lang === 'en');
  assert.equal(en.clips, 3);
  assert.equal(en.chars, clips.filter((c) => c.lang === 'en').reduce((n, c) => n + c.chars, 0));
  assert.equal(s.total.credits, s.total.chars);
});

test('planRender: idempotent on unchanged hash/voice/model/format, re-renders changed text, lists stale', () => {
  const cfg = { voiceId: 'v1', model: 'm', outputFormat: 'mp3_44100_64', kbps: 64 };
  const clips = collectClips(NARR, { langs: ['en'], lengths: ['teaser'], persona: 'historian', poiIds: null });
  const entries = clips.map((c) => manifestEntry(c, cfg, 8000, '2026-10-03T00:00:00Z'));
  entries.push({ ...entries[0], poiId: 'gone', file: 'audio/en/gone/teaser_0.mp3' });
  entries[1] = { ...entries[1], textSha256: 'old' };
  const m = buildManifest(entries, cfg);
  const p = planRender(clips, m, cfg, () => true);
  assert.equal(p.reuse.length, clips.length - 1);
  assert.deepEqual(p.toRender.map(clipKey), [clipKey(clips[1])]);
  assert.deepEqual(p.stale, ['audio/en/gone/teaser_0.mp3']);
  assert.equal(planRender(clips, m, { ...cfg, voiceId: 'v2' }, () => true).toRender.length, clips.length);
  assert.equal(planRender(clips, m, cfg, () => false).toRender.length, clips.length);
  assert.equal(planRender(clips, m, cfg, () => true, true).toRender.length, clips.length);
});

test('manifestEntry: CBR duration, no secret fields', () => {
  const [c] = collectClips(NARR, { langs: ['zh'], lengths: ['teaser'], persona: 'historian', poiIds: null });
  const e = manifestEntry(c, { voiceId: 'v', model: 'm', outputFormat: 'mp3_44100_64', kbps: 64 }, 16000, 't');
  assert.equal(e.durationMs, 2000);
  assert.ok(!JSON.stringify(e).toLowerCase().includes('key'));
});

test('parseArgs rejects unknown options and lengths', () => {
  assert.throws(() => parseArgs(['--bogus']));
  assert.throws(() => parseArgs(['--lengths', 'long']));
  assert.equal(parseArgs(['--limit', '3']).limit, 3);
});

test('fixture mirrors the stub pack sentences (on-device test clips hash-match)', () => {
  const en = JSON.parse(readFileSync(join(FIXTURE_NARRATIONS_DIR, 'en.json'), 'utf8'));
  const barbFull = en.find((n) => n.poiId === 'poi_stub_barbican' && n.length === 'full');
  assert.deepEqual(barbFull.sentences, ['This is Barbican.', 'The real Historian script arrives with the city pack.',
    'Until then, this placeholder lets the tour engine and the voice run end to end.']);
});

test('dry run on the fixture needs no key and exits 0', async () => {
  const saved = process.env.ELEVENLABS_API_KEY;
  delete process.env.ELEVENLABS_API_KEY;
  const log = console.log;
  const out = [];
  console.log = (...a) => out.push(a.join(' '));
  try {
    assert.equal(await main(['--dry-run', '--fixture', '--out', '/nonexistent-citytour-out']), 0);
  } finally {
    console.log = log;
    if (saved !== undefined) {
      process.env.ELEVENLABS_API_KEY = saved;
    }
  }
  assert.ok(out.some((l) => l.startsWith('DRY RUN')));
  assert.ok(out.some((l) => /^\s+en\s+3\s+15\s/.test(l)));
});

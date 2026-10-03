// Tests for watch-pack.mjs (task W3): the committed watch pack is current and self-consistent.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { createHash } from 'node:crypto';
import { readFileSync } from 'node:fs';
import { join } from 'node:path';
import { DEMO_OUT, DEMO_SRC, OUT_DIR, buildWatchPack } from './watch-pack.mjs';

const pack = buildWatchPack();

test('the committed watch pack is current (run: node scripts/pack/watch-pack.mjs)', () => {
  for (const [f, s] of Object.entries(pack)) {
    assert.equal(readFileSync(join(OUT_DIR, f), 'utf8'), s, f);
  }
});

test('one tour, one POI per stop in stop order, every stop is a route node', () => {
  const tours = JSON.parse(pack['tours.json']);
  assert.equal(tours.length, 1);
  const stopIds = tours[0].stops.map((s) => s.poiId);
  assert.deepEqual(JSON.parse(pack['pois.json']).map((p) => p.id), stopIds);
  const nodes = new Set(JSON.parse(pack['routes.json']).nodeIds);
  for (const id of stopIds) assert.ok(nodes.has(id), id);
});

test('manifest lists every data file with its size and SHA-256, and no narrations or audio', () => {
  const m = JSON.parse(pack['manifest.json']);
  assert.deepEqual(m.files.map((f) => f.path), ['personas.json', 'pois.json', 'routes.json', 'tours.json']);
  for (const f of m.files) {
    assert.equal(f.bytes, Buffer.byteLength(pack[f.path], 'utf8'), f.path);
    assert.equal(f.sha256, createHash('sha256').update(pack[f.path], 'utf8').digest('hex'), f.path);
  }
  assert.equal(m.counts.narrations_en, 0);
  assert.ok(!Object.keys(pack).some((f) => f.startsWith('narrations') || f.endsWith('.mp3')));
});

test('the watch pack stays small (< 300 KB in total)', () => {
  const bytes = Object.values(pack).reduce((n, s) => n + Buffer.byteLength(s, 'utf8'), 0);
  assert.ok(bytes < 300 * 1024, `bytes=${bytes}`);
});

test('the watch Demo walk track is a byte copy of the phone track (SIMULATED, same route)', () => {
  assert.ok(readFileSync(DEMO_OUT).equals(readFileSync(DEMO_SRC)));
});

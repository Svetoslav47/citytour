// Tests for 20-fetch-osm-tiles.mjs: the tiling must reproduce the lead's committed tiles exactly.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { parseBounds, sameBbox, osmStats, tileUrl, tiles } from './20-fetch-osm-tiles.mjs';

test('tiles(): 3x3 grid, row-major from the south-west, existing file names', () => {
  const t = tiles();
  assert.equal(t.length, 9);
  assert.deepEqual(t[0], { n: 1, rel: 'osm/oldtown-tile1.osm.gz', bbox: [19.929, 50.0525, 19.935, 50.0575] });
  assert.deepEqual(t[2].bbox, [19.941, 50.0525, 19.947, 50.0575]);
  assert.deepEqual(t[3].bbox, [19.929, 50.0575, 19.935, 50.0625]);
  assert.deepEqual(t[8], { n: 9, rel: 'osm/oldtown-tile9.osm.gz', bbox: [19.941, 50.0625, 19.947, 50.0675] });
});

test('tileUrl uses the OSM API map call with lon,lat,lon,lat at 4 decimals', () => {
  assert.equal(tileUrl([19.929, 50.0525, 19.935, 50.0575]), 'https://api.openstreetmap.org/api/0.6/map?bbox=19.9290,50.0525,19.9350,50.0575');
});

test('parseBounds / sameBbox / osmStats', () => {
  const xml = '<osm><bounds minlat="50.0525000" minlon="19.9290000" maxlat="50.0575000" maxlon="19.9350000"/>' +
    '<node id="1" timestamp="2026-01-01T00:00:00Z"/><node id="2" timestamp="2026-10-02T21:09:38Z"/><way id="3"/></osm>';
  const b = parseBounds(xml);
  assert.deepEqual(b, [19.929, 50.0525, 19.935, 50.0575]);
  assert.ok(sameBbox(b, tiles()[0].bbox));
  assert.ok(!sameBbox(b, tiles()[1].bbox));
  assert.equal(parseBounds('<osm/>'), null);
  assert.deepEqual(osmStats(xml), { nodes: 2, ways: 1, relations: 0, newestEdit: '2026-10-02T21:09:38Z' });
});

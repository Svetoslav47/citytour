#!/usr/bin/env node
// B7 self-check for the Historian review files scripts/pack/review/<poiId>.<lang>.md (format:
// scripts/pack/prompts/historian-v1.md §9). Node 22+ ESM, stdlib only.
//
// Usage: node scripts/pack/review/check-drafts.mjs [file.md ...]
//   no arguments: every <poiId>.<lang>.md in this directory, plus coverage (every tour stop has an en
//   file, >= 3 en files have a deep section). Prints a per-file PASS/FAIL table; exit 1 on any failure.
//
// Each teaser/full/deep section is checked with validator spec v1 (docs/ARCHITECTURE.md §7.4, the same
// rules as scripts/pack/80-validate.mjs and the app's NarrationValidator), using the file's claims:
//   length          teaser 15-60, full 120-420, deep 0-900 (en/pl words; zh: 40-150 / 300-1000 / 0-2200 CJK chars)
//   sentence_length every sentence <= 45 words (zh <= 110 chars)
//   total_chars     raw text < 10000 chars
//   lang            after removing the stop's names: en = ASCII letters >= 95 % and en stopwords > pl stopwords
//   numbers         every /\d+/ token of the text equals a /\d+/ token of some claim quote
//   proper_nouns    (en, pl) >= 85 % of capitalised non-sentence-initial tokens are a substring of a claim
//                   quote, a stop name or an allowlist entry
//   forbidden       URLs, # * _ ` { }, '[' other than [pNNN], TODO, "As an AI", "I cannot", hedges, absolute
//                   directions
// plus review-file checks:
//   one_sentence    each line of a section is one sentence ending in . ! or ? (the build splits on lines)
//   claims_quote    every quote is an exact substring of the cited source text (data/raw/wiki/stops-text-<lang>.json
//                   or summaries-<lang>.json, matched by title + revision id) and has >= 2 words
//   meta / format   front matter, required sections, review state (empty reviewed => status draft; filled
//                   reviewed "<initials> <YYYY-MM-DD>" => status approved|edited), view hint

import { readFileSync, readdirSync } from 'node:fs';
import { basename, dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const HERE = dirname(fileURLToPath(import.meta.url));
export const REPO = resolve(HERE, '../../..');
export const REVIEW_DIR = HERE;

// ---------------------------------------------------------------------------------------------
// Validator spec v1 constants (identical to scripts/pack/80-validate.mjs)

export const LENGTH_LIMITS = Object.freeze({
  teaser: { words: [15, 60], zh: [40, 150] },
  full: { words: [120, 420], zh: [300, 1000] },
  deep: { words: [0, 900], zh: [0, 2200] },
});
export const MAX_SENTENCE = Object.freeze({ words: 45, zh: 110 });
export const MAX_TOTAL_CHARS = 10000;
export const EN_MIN_ASCII_RATIO = 0.95;
export const ZH_MIN_CJK_RATIO = 0.6;
export const PROPER_NOUN_MIN_RATIO = 0.85;
export const EN_STOPWORDS = Object.freeze([
  'the', 'and', 'of', 'is', 'was', 'in', 'for', 'with', 'on', 'as', 'by', 'from', 'this', 'that', 'which', 'were', 'are', 'it',
]);
export const PL_STOPWORDS = Object.freeze([
  'się', 'nie', 'jest', 'w', 'z', 'na', 'oraz', 'który', 'która', 'było', 'był', 'była', 'do', 'że', 'jak', 'przez', 'od',
  'po', 'ze',
]);
export const PROPER_NOUN_ALLOWLIST = Object.freeze([
  'Kraków', 'Krakow', 'Poland', 'Polish', 'Vistula', 'Wawel', 'Rynek', 'Old Town', 'Main Square', 'UNESCO', 'Royal Route',
  'Gothic', 'Renaissance', 'Baroque', 'Romanesque', 'Catholic', 'Jagiellonian',
]);
export const FORBIDDEN_WORDS = Object.freeze([
  'TODO', 'As an AI', 'I cannot',
  'reportedly', 'it is said', 'allegedly', 'legend has it',
  'on your left', 'on your right', 'to your left', 'to your right', 'behind you', 'po lewej', 'po prawej', 'za tobą',
  '左边', '右边', '左侧', '右侧',
]);

export const SECTIONS = Object.freeze(['teaser', 'full', 'deep']);
export const LANGS = Object.freeze(['en', 'pl', 'zh']);
export const STATUSES_REVIEWED = Object.freeze(['approved', 'edited']);
export const LOOKS = Object.freeze(['up', 'level', 'down']);
export const MIN_DEEP_FILES = 3;

const EN_SET = new Set(EN_STOPWORDS);
const PL_SET = new Set(PL_STOPWORDS);
const PAUSE_RE = /\[p\d+\]/g;
const CJK_RE = /[一-鿿]/g;
const LETTER_RE = /\p{L}/gu;
const ASCII_LETTER_RE = /[A-Za-z]/g;
const PL_DIACRITIC_RE = /[ąćęłńóśźżĄĆĘŁŃÓŚŹŻ]/;
const SOURCE_ID_RE = /^wp:(en|pl|zh):(.+)@(\d+)$/;
const FILE_RE = /^([A-Za-z0-9_]+)\.(en|pl|zh)\.md$/;
const FORBIDDEN_RES = FORBIDDEN_WORDS.map((w) =>
  /^[\x20-\x7e]+$/.test(w)
    ? { word: w, test: (raw) => new RegExp(`\\b${w.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')}\\b`, 'i').test(raw) }
    : { word: w, test: (raw) => raw.toLowerCase().includes(w.toLowerCase()) },
);

// ---------------------------------------------------------------------------------------------
// Measures (same definitions as 80-validate.mjs)

export const stripPauses = (s) => s.replace(PAUSE_RE, ' ');
export const wordCount = (s) => s.split(/\s+/).filter((t) => t.length > 0).length;
export const cjkCount = (s) => (s.match(CJK_RE) || []).length;
export const sizeOf = (s, lang) => (lang === 'zh' ? cjkCount(s) : wordCount(s));

export function removeNames(text, names) {
  const sorted = [...new Set((names ?? []).filter((s) => typeof s === 'string' && s.length > 0))].sort(
    (a, b) => b.length - a.length || (a < b ? -1 : a > b ? 1 : 0),
  );
  let out = text;
  for (const name of sorted) out = out.split(name).join(' ');
  return out;
}

export function stopwordCounts(text) {
  let en = 0;
  let pl = 0;
  for (const w of text.toLowerCase().split(/[^\p{L}]+/u)) {
    if (EN_SET.has(w)) en++;
    if (PL_SET.has(w)) pl++;
  }
  return { en, pl };
}

export function langMatches(text, lang) {
  const letters = (text.match(LETTER_RE) || []).length;
  if (letters === 0) return false;
  if (lang === 'zh') return cjkCount(text) / letters >= ZH_MIN_CJK_RATIO;
  const { en, pl } = stopwordCounts(text);
  if (lang === 'en') return (text.match(ASCII_LETTER_RE) || []).length / letters >= EN_MIN_ASCII_RATIO && en > pl;
  if (lang === 'pl') return pl > en || PL_DIACRITIC_RE.test(text);
  return false;
}

export function properNounCandidates(sentence) {
  const tokens = stripPauses(sentence)
    .split(/\s+/)
    .map((t) => t.replace(/^[^\p{L}\p{N}]+|[^\p{L}\p{N}]+$/gu, '').replace(/['’]s$/u, ''))
    .filter((t) => t.length > 0);
  return tokens.filter((t, i) => i > 0 && /^\p{Lu}/u.test(t));
}

// ---------------------------------------------------------------------------------------------
// Parsing

function sectionKey(heading) {
  return heading.replace(/\(.*\)\s*$/, '').trim().toLowerCase();
}

/**
 * Parses a review file. Returns { meta, sections: {teaser, full, deep}: string[] (sentences, one per line),
 * paragraphs: {teaser, full, deep}: string[][], claims: [{text, source, quote, line}], view: {look, feature},
 * notes: {drafting, reviewer}, errors: string[] }.
 */
export function parseReviewFile(src) {
  const lines = src.replace(/\r\n?/g, '\n').split('\n');
  const errors = [];
  const meta = {};
  const out = { meta, sections: {}, paragraphs: {}, claims: [], view: {}, notes: {}, errors };
  if (lines[0] !== '---') {
    errors.push('front matter must start with a "---" line');
    return out;
  }
  const end = lines.indexOf('---', 1);
  if (end < 0) {
    errors.push('front matter is not closed with a "---" line');
    return out;
  }
  for (let i = 1; i < end; i++) {
    const line = lines[i];
    if (line.trim() === '' || line.trim().startsWith('#')) continue;
    const m = /^([A-Za-z][A-Za-z0-9_]*):(.*)$/.exec(line);
    if (!m) {
      errors.push(`front matter line ${i + 1} is not "key: value"`);
      continue;
    }
    let v = m[2];
    const hash = v.search(/(^|\s)#/);
    if (hash >= 0) v = v.slice(0, hash);
    meta[m[1]] = v.trim();
  }

  const bodies = new Map();
  let current = null;
  for (let i = end + 1; i < lines.length; i++) {
    const h = /^##\s+(.+?)\s*$/.exec(lines[i]);
    if (h) {
      current = sectionKey(h[1]);
      if (bodies.has(current)) errors.push(`section "## ${current}" appears twice`);
      bodies.set(current, []);
      continue;
    }
    if (current === null) {
      if (lines[i].trim() !== '') errors.push(`line ${i + 1} is outside any "## section"`);
      continue;
    }
    bodies.get(current).push({ text: lines[i], line: i + 1 });
  }

  for (const s of SECTIONS) {
    if (!bodies.has(s)) continue;
    const paras = [];
    let para = [];
    for (const { text } of bodies.get(s)) {
      const t = text.trim();
      if (t === '') {
        if (para.length) paras.push(para);
        para = [];
      } else para.push(t);
    }
    if (para.length) paras.push(para);
    out.paragraphs[s] = paras;
    out.sections[s] = paras.flat();
  }

  if (bodies.has('claims')) {
    let claim = null;
    for (const { text, line } of bodies.get('claims')) {
      if (text.trim() === '') continue;
      const m = /^(\s*-\s+|\s+)(text|source|quote):\s?(.*)$/.exec(text);
      if (!m) {
        errors.push(`claims line ${line} is not "- text:", "  source:" or "  quote:"`);
        continue;
      }
      const [, lead, key, rawValue] = m;
      if (lead.trim() === '-') {
        claim = { line };
        out.claims.push(claim);
      } else if (claim === null) {
        errors.push(`claims line ${line}: "${key}" before the first "- text:"`);
        continue;
      }
      if (key in claim) errors.push(`claims line ${line}: duplicate "${key}"`);
      let value = rawValue.trim();
      if (key === 'quote') {
        if (value.length < 2 || !value.startsWith('"') || !value.endsWith('"')) {
          errors.push(`claims line ${line}: quote must be wrapped in double quotes`);
          continue;
        }
        value = rawValue.trim().slice(1, -1);
      }
      claim[key] = value;
    }
  }

  if (bodies.has('view hint')) {
    for (const { text, line } of bodies.get('view hint')) {
      if (text.trim() === '') continue;
      const m = /^(look|feature):\s*(.*)$/.exec(text.trim());
      if (!m) errors.push(`view hint line ${line} is not "look:" or "feature:"`);
      else out.view[m[1]] = m[2].trim();
    }
  }
  for (const [key, name] of [['drafting notes', 'drafting'], ['reviewer notes', 'reviewer']]) {
    if (bodies.has(key)) out.notes[name] = bodies.get(key).map((l) => l.text).join('\n').trim();
  }
  return out;
}

// ---------------------------------------------------------------------------------------------
// Context: sources and tour

/** Map sourceId -> string[] (stop text and/or summary extract with that title + revision). */
export function loadSources(repo = REPO) {
  const map = new Map();
  const add = (id, text) => {
    if (typeof text !== 'string') return;
    if (!map.has(id)) map.set(id, []);
    map.get(id).push(text);
  };
  for (const lang of LANGS) {
    const stops = JSON.parse(readFileSync(join(repo, `data/raw/wiki/stops-text-${lang}.json`), 'utf8'));
    for (const p of Object.values(stops.pages)) add(`wp:${lang}:${p.title}@${p.revid}`, p.text);
    const sums = JSON.parse(readFileSync(join(repo, `data/raw/wiki/summaries-${lang}.json`), 'utf8'));
    for (const p of Object.values(sums.pages)) add(`wp:${lang}:${p.title}@${p.revision}`, p.extract);
  }
  return map;
}

/** Map poiId -> tour stop (from data/tours/royal-route.json), in tour order. */
export function loadStops(repo = REPO) {
  const tour = JSON.parse(readFileSync(join(repo, 'data/tours/royal-route.json'), 'utf8'));
  return new Map(tour.stops.map((s) => [s.poiId, s]));
}

// ---------------------------------------------------------------------------------------------
// Checks

/** Spec v1 checks of one section. Returns [{check, detail}]. */
export function checkSection(length, sentences, lang, claims, names) {
  const fails = [];
  const fail = (check, detail) => fails.push({ check, detail });
  const raw = sentences.join(' ');
  const text = stripPauses(raw);
  const unit = lang === 'zh' ? 'zh' : 'words';

  const [lo, hi] = LENGTH_LIMITS[length][unit];
  const size = sizeOf(text, lang);
  if (sentences.length === 0) fail('length', 'section is empty');
  else if (size < lo || size > hi) fail('length', `${size} ${unit === 'zh' ? 'chars' : 'words'}, allowed ${lo}-${hi}`);

  const maxS = MAX_SENTENCE[unit];
  sentences.forEach((s, i) => {
    const n = sizeOf(stripPauses(s), lang);
    if (n > maxS) fail('sentence_length', `sentence ${i + 1} has ${n} (max ${maxS})`);
  });

  if (raw.length >= MAX_TOTAL_CHARS) fail('total_chars', `${raw.length} chars`);

  // One sentence per line, ending with . ! or ? (optionally followed by a closing quote).
  sentences.forEach((s, i) => {
    const t = stripPauses(s).trim();
    if (lang !== 'zh') {
      if (!/[.!?]["'’”]?$/.test(t)) fail('one_sentence', `line ${i + 1} does not end with . ! or ?`);
      if (/[.!?]["'’”)]?\s+["'“‘(]?\p{Lu}/u.test(t)) fail('one_sentence', `line ${i + 1} holds more than one sentence`);
    } else if (!/[。！？]["'’”」]?$/.test(t)) fail('one_sentence', `line ${i + 1} does not end with 。！？`);
  });

  const stripped = removeNames(text, names);
  if (!langMatches(stripped, lang)) {
    const letters = (stripped.match(LETTER_RE) || []).length;
    const ascii = (stripped.match(ASCII_LETTER_RE) || []).length;
    const sw = stopwordCounts(stripped);
    fail('lang', `not ${lang}: ascii ${letters ? Math.round((100 * ascii) / letters) : 0} %, stopwords en ${sw.en} / pl ${sw.pl}`);
  }

  const allowed = new Set();
  for (const c of claims) for (const m of (c.quote ?? '').match(/\d+/g) || []) allowed.add(m);
  const missing = [...new Set((text.match(/\d+/g) || []).filter((m) => !allowed.has(m)))];
  if (missing.length) fail('numbers', `not in any claim quote: ${missing.join(', ')}`);

  if (lang === 'en' || lang === 'pl') {
    const candidates = sentences.flatMap(properNounCandidates);
    if (candidates.length) {
      const hay = [...claims.map((c) => c.quote ?? ''), ...names, ...PROPER_NOUN_ALLOWLIST];
      const unknown = candidates.filter((t) => !hay.some((h) => h.includes(t)));
      const ratio = (candidates.length - unknown.length) / candidates.length;
      if (ratio < PROPER_NOUN_MIN_RATIO) {
        fail('proper_nouns', `${Math.round(ratio * 100)} % grounded (min 85 %); ungrounded: ${[...new Set(unknown)].join(', ')}`);
      }
    }
  }

  const hits = [];
  if (/https?:\/\//i.test(raw)) hits.push('URL');
  for (const ch of raw.match(/[#*_`{}]/g) || []) hits.push(`"${ch}"`);
  if (raw.replace(PAUSE_RE, '').includes('[')) hits.push('"[" (only [pNNN] allowed)');
  for (const r of FORBIDDEN_RES) if (r.test(raw)) hits.push(`"${r.word}"`);
  if (hits.length) fail('forbidden', [...new Set(hits)].join(', '));
  return fails;
}

/**
 * Checks one parsed review file. ctx = { fileName, stops: Map, sources: Map }.
 * Returns { failures: [{where, check, detail}], words: {teaser, full, deep}, claims }.
 */
export function checkReview(parsed, ctx) {
  const failures = [];
  const fail = (where, check, detail) => failures.push({ where, check, detail });
  for (const e of parsed.errors) fail('file', 'format', e);
  const { meta } = parsed;

  // Front matter.
  const fm = FILE_RE.exec(ctx.fileName ?? '');
  if (!fm) fail('file', 'meta', `file name must be <poiId>.<en|pl|zh>.md, got ${ctx.fileName}`);
  const stop = ctx.stops.get(meta.poiId);
  if (!stop) fail('meta', 'meta', `poiId ${meta.poiId || '(empty)'} is not a stop of data/tours/royal-route.json`);
  if (fm && meta.poiId !== fm[1]) fail('meta', 'meta', `poiId ${meta.poiId} does not match the file name`);
  if (!LANGS.includes(meta.lang)) fail('meta', 'meta', `lang must be en|pl|zh, got ${meta.lang || '(empty)'}`);
  else if (fm && meta.lang !== fm[2]) fail('meta', 'meta', `lang ${meta.lang} does not match the file name`);
  if (meta.persona !== 'historian') fail('meta', 'meta', `persona must be historian, got ${meta.persona || '(empty)'}`);
  if (!meta.promptId) fail('meta', 'meta', 'promptId is empty');
  if (!meta.model) fail('meta', 'meta', 'model is empty');
  if (!/^\d{4}-\d{2}-\d{2}$/.test(meta.drafted ?? '')) fail('meta', 'meta', 'drafted must be YYYY-MM-DD');
  if (!('reviewed' in meta)) fail('meta', 'meta', 'reviewed line is missing (leave it empty until a human reviews)');
  else if (meta.reviewed === '') {
    if (meta.status !== 'draft') fail('meta', 'review', `reviewed is empty, so status must be draft (got ${meta.status || '(empty)'})`);
  } else {
    if (!/^\S+ \d{4}-\d{2}-\d{2}$/.test(meta.reviewed)) fail('meta', 'review', 'reviewed must be "<initials> <YYYY-MM-DD>"');
    if (!STATUSES_REVIEWED.includes(meta.status)) fail('meta', 'review', `a reviewed file needs status approved|edited (got ${meta.status || '(empty)'})`);
  }

  // Claims.
  if (parsed.claims.length === 0) fail('claims', 'claims_quote', 'no claims');
  parsed.claims.forEach((c, i) => {
    const where = `claim ${i + 1}`;
    for (const k of ['text', 'source', 'quote']) if (!c[k]) fail(where, 'claims_quote', `"${k}" is missing or empty`);
    if (!c.source || !c.quote) return;
    if (!SOURCE_ID_RE.test(c.source)) {
      fail(where, 'claims_quote', `source must be wp:<lang>:<title>@<revid>, got ${c.source}`);
      return;
    }
    const texts = ctx.sources.get(c.source);
    if (!texts) fail(where, 'claims_quote', `unknown source ${c.source} (title or revision id not in data/raw/wiki)`);
    else if (!texts.some((t) => t.includes(c.quote))) fail(where, 'claims_quote', `quote is not an exact substring of ${c.source}: "${c.quote.slice(0, 60)}"`);
    if (wordCount(c.quote) < 2) fail(where, 'claims_quote', `quote "${c.quote}" is shorter than 2 words`);
  });

  // Sections.
  const names = stop ? Object.values(stop.names ?? {}).filter((n) => typeof n === 'string') : [];
  const words = {};
  for (const s of SECTIONS) {
    const sentences = parsed.sections[s];
    const present = Array.isArray(sentences) && sentences.length > 0;
    if (!present) {
      if (s !== 'deep') fail(s, 'format', `section "## ${s}" is missing or empty`);
      continue;
    }
    words[s] = sizeOf(stripPauses(sentences.join(' ')), meta.lang);
    if (!LANGS.includes(meta.lang)) continue;
    for (const f of checkSection(s, sentences, meta.lang, parsed.claims, names)) fail(s, f.check, f.detail);
  }

  // View hint.
  if (!LOOKS.includes(parsed.view.look)) fail('view hint', 'view', `look must be up|level|down, got ${parsed.view.look ?? '(missing)'}`);
  if (!parsed.view.feature) fail('view hint', 'view', 'feature is missing or empty');
  else {
    const raw = parsed.view.feature;
    if (/[#*_`{}[]/.test(raw) || FORBIDDEN_RES.some((r) => r.test(raw))) fail('view hint', 'view', 'feature contains a forbidden pattern');
  }
  return { failures, words, claims: parsed.claims.length };
}

/** Repository-level coverage for one language: every tour stop has a file; >= 3 files have deep. */
export function checkCoverage(results, stops, lang = 'en') {
  const failures = [];
  const ofLang = results.filter((r) => r.lang === lang);
  for (const poiId of stops.keys()) {
    if (!ofLang.some((r) => r.poiId === poiId)) failures.push(`missing ${poiId}.${lang}.md`);
  }
  const deep = ofLang.filter((r) => r.words.deep !== undefined).length;
  if (deep < MIN_DEEP_FILES) failures.push(`only ${deep} ${lang} file(s) have a deep section (min ${MIN_DEEP_FILES})`);
  return failures;
}

export function reviewFiles(dir = REVIEW_DIR) {
  return readdirSync(dir)
    .filter((f) => FILE_RE.test(f))
    .sort()
    .map((f) => join(dir, f));
}

export function checkFile(path, ctx) {
  const fileName = basename(path);
  const parsed = parseReviewFile(readFileSync(path, 'utf8'));
  const r = checkReview(parsed, { ...ctx, fileName });
  return { file: fileName, poiId: parsed.meta.poiId, lang: parsed.meta.lang, status: parsed.meta.status, ...r };
}

// ---------------------------------------------------------------------------------------------
// CLI

function pad(s, n) {
  s = String(s);
  return s.length >= n ? s : s + ' '.repeat(n - s.length);
}

export function main(argv = process.argv.slice(2), repo = REPO) {
  const ctx = { stops: loadStops(repo), sources: loadSources(repo) };
  const all = argv.length === 0;
  const files = all ? reviewFiles() : argv.map((a) => resolve(a));
  const results = files.map((f) => checkFile(f, ctx));
  const order = [...ctx.stops.keys()];
  results.sort((a, b) => order.indexOf(a.poiId) - order.indexOf(b.poiId) || (a.file < b.file ? -1 : 1));

  const lines = [];
  lines.push(`${pad('file', 26)}${pad('stop', 28)}${pad('result', 8)}${pad('status', 9)}${pad('teaser', 8)}${pad('full', 6)}${pad('deep', 6)}claims`);
  for (const r of results) {
    const stop = ctx.stops.get(r.poiId);
    lines.push(
      `${pad(r.file, 26)}${pad(stop?.names?.en ?? '?', 28)}${pad(r.failures.length ? 'FAIL' : 'PASS', 8)}${pad(r.status ?? '?', 9)}` +
        `${pad(r.words.teaser ?? '-', 8)}${pad(r.words.full ?? '-', 6)}${pad(r.words.deep ?? '-', 6)}${r.claims}`,
    );
  }
  for (const r of results) for (const f of r.failures) lines.push(`  ${r.file}  [${f.where}] ${f.check}: ${f.detail}`);
  const notes = results.filter((r) => (r.words.full ?? 0) > 200).map((r) => `${r.file} full=${r.words.full}`);
  if (notes.length) lines.push(`note: full above the ~200-word demo target (REVIEW rec. 4, not a failure): ${notes.join(', ')}`);
  const coverage = all ? checkCoverage(results, ctx.stops, 'en') : [];
  for (const c of coverage) lines.push(`  coverage: ${c}`);
  const failed = results.filter((r) => r.failures.length).length;
  const reviewed = results.filter((r) => STATUSES_REVIEWED.includes(r.status)).length;
  lines.push(
    `${failed === 0 && coverage.length === 0 ? 'PASS' : 'FAIL'}: ${results.length - failed}/${results.length} files pass` +
      `, ${reviewed} reviewed, ${results.length - reviewed} draft${coverage.length ? `, ${coverage.length} coverage problem(s)` : ''}`,
  );
  return { ok: failed === 0 && coverage.length === 0, output: lines.join('\n'), results, coverage };
}

if (process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  const { ok, output } = main();
  console.log(output);
  process.exitCode = ok ? 0 : 1;
}

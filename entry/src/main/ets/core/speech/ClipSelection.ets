/*
 * Pure clip selection for pre-rendered stop stories (task A13). No @kit imports: unit-tested in
 * entry/src/test/ClipSelection.test.ets.
 *
 * rawfile/audio/manifest.json is written by scripts/voice/render-elevenlabs.mjs: one entry per sentence
 * {lang, poiId, personaId, length, n, file, textSha256, durationMs, voiceId, model, ...}.
 * For every utterance NarrationPlayer asks selectAudio():
 *   prerendered  when the manifest has an entry with textSha256 == sha256(utf8(Utterance.text)) for the same
 *                language and persona, and that clip has not failed before;
 *   tts / text   otherwise, as the VoicePlan says (the native TTS path, or text-only).
 * Matching on the hash of the exact sentence (not on poi/sentence index) is deliberate: a stop item is the arrival
 * lines plus the story sentences (TourEngine.enqueue), so indexes shift; a sentence whose text changed after
 * rendering simply has no match and falls back to TTS; dynamic lines (directions, welcome, GPS lost) never match.
 * The user's explicit "text only" choice (VoiceLabel.TEXT_ONLY_USER) is respected: no clip then either.
 * A text-only plan for lack of a platform voice (Polish) does use a clip: that is the point of pre-rendering.
 */
import { VoiceLabel } from '../../contracts/Settings';
import { sha256Hex } from './Sha256';

export const AUDIO_SRC_PRERENDERED: string = 'prerendered';
export const AUDIO_SRC_TTS: string = 'tts';
export const AUDIO_SRC_TEXT: string = 'text';

export const CLIP_MANIFEST_RAWFILE: string = 'audio/manifest.json';

/** Reasons in the NARR_AUDIO log line. */
export class ClipReason {
  static readonly HASH_MATCH: string = 'hash_match';
  static readonly NO_MANIFEST: string = 'no_manifest';
  static readonly NO_CLIP: string = 'no_clip';                 // no entry with this text hash (or text changed)
  static readonly LANG_MISMATCH: string = 'lang_mismatch';     // the text hash exists, for another language
  static readonly PERSONA_MISMATCH: string = 'persona_mismatch';
  static readonly CLIP_FAILED: string = 'clip_failed';         // the clip failed to open/play earlier (e.g. deleted)
  static readonly USER_TEXT_ONLY: string = 'user_text_only';
}

export interface ClipEntry {
  lang: string;
  poiId: string;
  personaId: string;
  length: string;
  n: number;
  file: string;          // rawfile-relative, e.g. 'audio/en/poi_wd_Q807309/full_0.mp3'
  textSha256: string;
  durationMs: number;    // 0 when unknown
}

export class ClipManifestParse {
  entries: ClipEntry[] = [];
  dropped: number = 0;   // malformed entries skipped
  error: string = '';    // '' when the file parsed (even with 0 entries)
  voiceId: string = '';
  model: string = '';
}

interface RawClipEntry {
  lang?: string;
  poiId?: string;
  personaId?: string;
  length?: string;
  n?: number;
  file?: string;
  textSha256?: string;
  durationMs?: number;
}

interface RawClipManifest {
  schemaVersion?: number;
  voiceId?: string;
  model?: string;
  clips?: RawClipEntry[];
}

function isStr(v: string | null | undefined): boolean {
  return typeof v === 'string' && (v as string).length > 0;
}

const SHA_RE: RegExp = new RegExp('^[0-9a-f]{64}$');
const FILE_RE: RegExp = new RegExp('^audio/[A-Za-z0-9_./-]+\\.(mp3|m4a|aac)$');

/** Parses and validates manifest.json. Never throws; malformed entries are dropped and counted. */
export function parseClipManifest(json: string): ClipManifestParse {
  const out = new ClipManifestParse();
  let raw: RawClipManifest;
  try {
    raw = JSON.parse(json) as RawClipManifest;
  } catch (e) {
    out.error = 'json';
    return out;
  }
  if (raw === null || raw === undefined || typeof raw !== 'object') {
    out.error = 'not_object';
    return out;
  }
  out.voiceId = typeof raw.voiceId === 'string' ? raw.voiceId as string : '';
  out.model = typeof raw.model === 'string' ? raw.model as string : '';
  const clips = raw.clips;
  if (clips === undefined || clips === null || !Array.isArray(clips)) {
    out.error = 'no_clips';
    return out;
  }
  for (let i = 0; i < clips.length; i++) {
    const r = clips[i];
    if (r === null || r === undefined || typeof r !== 'object' || !isStr(r.lang) || !isStr(r.personaId) ||
      !isStr(r.file) || !isStr(r.textSha256)) {
      out.dropped++;
      continue;
    }
    const sha = (r.textSha256 as string).toLowerCase();
    const file = r.file as string;
    if (!SHA_RE.test(sha) || !FILE_RE.test(file) || file.indexOf('..') >= 0) {
      out.dropped++;
      continue;
    }
    const e: ClipEntry = {
      lang: r.lang as string,
      poiId: isStr(r.poiId) ? r.poiId as string : '',
      personaId: r.personaId as string,
      length: isStr(r.length) ? r.length as string : '',
      n: typeof r.n === 'number' && Number.isFinite(r.n as number) ? r.n as number : -1,
      file: file,
      textSha256: sha,
      durationMs: typeof r.durationMs === 'number' && Number.isFinite(r.durationMs as number) && (r.durationMs as number) > 0 ?
        r.durationMs as number : 0
    };
    out.entries.push(e);
  }
  return out;
}

export class ClipLookup {
  entry?: ClipEntry;
  reason: string = ClipReason.NO_CLIP;
}

/** Hash -> entries index, plus the set of clips that failed at runtime (missing file, decoder error). */
export class ClipIndex {
  private byHash: Map<string, ClipEntry[]> = new Map<string, ClipEntry[]>();
  private failed: Set<string> = new Set<string>();
  private count: number = 0;

  constructor(entries: ClipEntry[]) {
    for (const e of entries) {
      const list = this.byHash.get(e.textSha256);
      if (list === undefined) {
        this.byHash.set(e.textSha256, [e]);
      } else {
        list.push(e);
      }
      this.count++;
    }
  }

  size(): number {
    return this.count;
  }

  /** Langs that have at least one clip (e.g. for "Polish is spoken" decisions later). */
  hasLang(lang: string): boolean {
    let found = false;
    this.byHash.forEach((list: ClipEntry[]) => {
      if (!found && list.some((e: ClipEntry) => e.lang === lang)) {
        found = true;
      }
    });
    return found;
  }

  markFailed(file: string): void {
    this.failed.add(file);
  }

  isFailed(file: string): boolean {
    return this.failed.has(file);
  }

  /** Exact text hash + language + persona; skips clips that already failed. */
  find(sha: string, lang: string, personaId: string): ClipLookup {
    const out = new ClipLookup();
    const list = this.byHash.get(sha);
    if (list === undefined || list.length === 0) {
      out.reason = ClipReason.NO_CLIP;
      return out;
    }
    const sameLang = list.filter((e: ClipEntry) => e.lang === lang);
    if (sameLang.length === 0) {
      out.reason = ClipReason.LANG_MISMATCH;
      return out;
    }
    const samePersona = sameLang.filter((e: ClipEntry) => e.personaId === personaId);
    if (samePersona.length === 0) {
      out.reason = ClipReason.PERSONA_MISMATCH;
      return out;
    }
    for (const e of samePersona) {
      if (!this.failed.has(e.file)) {
        out.entry = e;
        out.reason = ClipReason.HASH_MATCH;
        return out;
      }
    }
    out.reason = ClipReason.CLIP_FAILED;
    return out;
  }
}

/** What NarrationPlayer needs to know about one utterance (subset of contracts Utterance + VoicePlan). */
export interface ClipQuery {
  text: string;
  lang: string;
  personaId: string;
  planSpeechMode: string;   // VoicePlan.speechMode: 'voice' | 'text'
  planLabel: VoiceLabel;
}

export class AudioDecision {
  src: string = AUDIO_SRC_TTS;
  reason: string = '';
  clip?: ClipEntry;
  sha: string = '';
}

/** The one decision function: prerendered clip, else the plan's own path (tts or text). Never throws. */
export function selectAudio(index: ClipIndex | undefined, q: ClipQuery): AudioDecision {
  const d = new AudioDecision();
  const fallback: string = q.planSpeechMode === 'text' ? AUDIO_SRC_TEXT : AUDIO_SRC_TTS;
  d.src = fallback;
  if (q.planLabel === VoiceLabel.TEXT_ONLY_USER) {
    d.reason = ClipReason.USER_TEXT_ONLY;
    return d;
  }
  if (index === undefined || index.size() === 0) {
    d.reason = ClipReason.NO_MANIFEST;
    return d;
  }
  d.sha = sha256Hex(q.text);
  const l = index.find(d.sha, q.lang, q.personaId);
  d.reason = l.reason;
  if (l.entry !== undefined) {
    d.src = AUDIO_SRC_PRERENDERED;
    d.clip = l.entry;
  }
  return d;
}

/** Short hash prefix for logs. */
export function shortSha(sha: string): string {
  return sha.length > 12 ? sha.substring(0, 12) : sha;
}

// Suite: ClipSelection.test - modules under test: core/speech/ClipSelection and core/speech/Sha256 (task A13).
// Cases: SHA-256 equals Node's crypto (the render script's hash) for ASCII, Polish, CJK, emoji and [pN] markup;
// manifest parsing (malformed JSON / entries dropped, path safety); selection: hash match, missing clip,
// changed text, language, persona, failed (deleted) clip, the user's text-only choice, no manifest, and Polish
// (platform text-only) getting a clip.
// Phase 2: storyVoicePlan (studio upgrade only with clips, never over the user's text-only or cross-language
// choice), hasLang per persona, storyClipCoverage all/partial/none, exclusion of partly covered stories, and the
// cross-language listen choice getting no clip.
import { describe, it, expect } from '@ohos/hypium';
import { Lang } from '../main/ets/contracts/Model';
import { VoicePlan } from '../main/ets/contracts/Ports';
import { VoiceLabel } from '../main/ets/contracts/Settings';
import { sha256Hex, utf8Bytes } from '../main/ets/core/speech/Sha256';
import {
  AUDIO_SRC_PRERENDERED, AUDIO_SRC_TEXT, AUDIO_SRC_TTS, ClipEntry, ClipIndex, ClipQuery, ClipReason,
  parseClipManifest, selectAudio, shortSha, storiesAllOrNothing, StoryClips, storyClipCoverage, storyVoicePlan
} from '../main/ets/core/speech/ClipSelection';

function vplan(lang: Lang, mode: string, label: VoiceLabel, reason: string, engine: string = ''): VoicePlan {
  const p: VoicePlan = {
    textLang: lang, speechMode: mode, engineLocale: engine, person: engine === '' ? 0 : 13, languageContext: engine,
    label: label, reason: reason
  };
  return p;
}

// Vectors from Node: crypto.createHash('sha256').update(s, 'utf8').digest('hex') (= render-elevenlabs.mjs).
const VECTORS: string[][] = [
  ['', 'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855'],
  ['abc', 'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad'],
  ['This is Barbican.', '6b57aa9020f95bb52345b5d986292da081ea900be66916d2410916c350c39573'],
  ['Zażółć gęślą jaźń', 'bc5348fd7c2dd8bbf411f0b9268265f7c2e0d31ebf314695882b8170c7e1e9d7'],
  ['您已到达巴比肯。', 'b4dd57599ef12b156c3d84f959d5b49433a231c88c8a80f8afeabd5585cc5318'],
  ['emoji \uD83C\uDFF0 ok', 'b0e0fdd9c6bc7d9fec4cbf074f691364edd1b91a86a0a3bae589b77bf221fe3a'],
  ['Look up.[p300] Done', '1b5ef90f5e6c6e06c082df8c9bef4e3e2910c3c44be3d85c1de88cd7a4f83087']
];

const SHA_BARBICAN: string = '6b57aa9020f95bb52345b5d986292da081ea900be66916d2410916c350c39573';
const SHA_PL: string = 'd22ea7a8f6db4277e1e47e56d03abf4c007f9bb3f198523cba8e06e94a14c3b4'; // 'To jest Barbakan.'

function entry(lang: string, persona: string, sha: string, file: string): ClipEntry {
  const e: ClipEntry = {
    lang: lang, poiId: 'poi_stub_barbican', personaId: persona, length: 'full', n: 0, file: file, textSha256: sha,
    durationMs: 1500
  };
  return e;
}

function query(text: string, lang: string, mode: string, label: VoiceLabel, persona: string = 'historian'): ClipQuery {
  const q: ClipQuery = { text: text, lang: lang, personaId: persona, planSpeechMode: mode, planLabel: label };
  return q;
}

function index(): ClipIndex {
  return new ClipIndex([
    entry('en', 'historian', SHA_BARBICAN, 'audio/en/poi_stub_barbican/full_0.mp3'),
    entry('pl', 'historian', SHA_PL, 'audio/pl/poi_stub_barbican/full_0.mp3')
  ]);
}

const MANIFEST: string = '{"schemaVersion":1,"model":"eleven_multilingual_v2","voiceId":"voice123","clips":[' +
  `{"lang":"en","poiId":"poi_stub_barbican","personaId":"historian","length":"full","n":0,` +
  `"file":"audio/en/poi_stub_barbican/full_0.mp3","textSha256":"${SHA_BARBICAN.toUpperCase()}","durationMs":1400},` +
  '{"lang":"en","personaId":"historian","file":"audio/en/x/full_1.mp3","textSha256":"not-a-hash"},' +
  `{"lang":"en","personaId":"historian","file":"audio/../../etc/passwd.mp3","textSha256":"${SHA_PL}"},` +
  `{"lang":"en","personaId":"historian","file":"packs/krakow/pois.json","textSha256":"${SHA_PL}"},` +
  `{"lang":"en","file":"audio/en/x/full_2.mp3","textSha256":"${SHA_PL}"},` +
  'null]}';

export default function clipSelectionTest() {
  describe('ClipSelection', () => {
    it('sha256_matches_node_crypto', 0, () => {
      for (const v of VECTORS) {
        expect(sha256Hex(v[0])).assertEqual(v[1]);
      }
    });

    it('utf8_bytes_multibyte_and_surrogates', 0, () => {
      expect(utf8Bytes('ż').length).assertEqual(2);
      expect(utf8Bytes('巴').length).assertEqual(3);
      expect(utf8Bytes('\uD83C\uDFF0').length).assertEqual(4);
      expect(utf8Bytes('\uD800').length).assertEqual(3);   // lone surrogate -> U+FFFD
    });

    it('parse_manifest_keeps_valid_drops_malformed', 0, () => {
      const p = parseClipManifest(MANIFEST);
      expect(p.error).assertEqual('');
      expect(p.entries.length).assertEqual(1);
      expect(p.dropped).assertEqual(5);
      expect(p.entries[0].textSha256).assertEqual(SHA_BARBICAN);   // normalised to lowercase
      expect(p.entries[0].durationMs).assertEqual(1400);
      expect(p.voiceId).assertEqual('voice123');
      expect(p.model).assertEqual('eleven_multilingual_v2');
    });

    it('parse_manifest_bad_input_never_throws', 0, () => {
      expect(parseClipManifest('{not json').error).assertEqual('json');
      expect(parseClipManifest('null').error).assertEqual('not_object');
      expect(parseClipManifest('{"clips":5}').error).assertEqual('no_clips');
      expect(parseClipManifest('{"clips":[]}').entries.length).assertEqual(0);
    });

    it('hash_match_plays_clip', 0, () => {
      const d = selectAudio(index(), query('This is Barbican.', 'en', 'voice', VoiceLabel.FALLBACK_ZH_READS_EN));
      expect(d.src).assertEqual(AUDIO_SRC_PRERENDERED);
      expect(d.reason).assertEqual(ClipReason.HASH_MATCH);
      expect(d.clip !== undefined && d.clip.file === 'audio/en/poi_stub_barbican/full_0.mp3').assertTrue();
      expect(shortSha(d.sha)).assertEqual('6b57aa9020f9');
    });

    it('missing_or_changed_text_falls_back_to_tts', 0, () => {
      const dyn = selectAudio(index(), query('Turn left in 50 metres.', 'en', 'voice', VoiceLabel.NATIVE));
      expect(dyn.src).assertEqual(AUDIO_SRC_TTS);
      expect(dyn.reason).assertEqual(ClipReason.NO_CLIP);
      const changed = selectAudio(index(), query('This is the Barbican.', 'en', 'voice', VoiceLabel.NATIVE));
      expect(changed.src).assertEqual(AUDIO_SRC_TTS);
      const ws = selectAudio(index(), query('This is Barbican. ', 'en', 'voice', VoiceLabel.NATIVE));
      expect(ws.src).assertEqual(AUDIO_SRC_TTS);   // exact text only
    });

    it('language_must_match', 0, () => {
      const d = selectAudio(index(), query('This is Barbican.', 'zh', 'voice', VoiceLabel.NATIVE));
      expect(d.src).assertEqual(AUDIO_SRC_TTS);
      expect(d.reason).assertEqual(ClipReason.LANG_MISMATCH);
    });

    it('persona_must_match', 0, () => {
      const d = selectAudio(index(), query('This is Barbican.', 'en', 'voice', VoiceLabel.NATIVE, 'kids-legends'));
      expect(d.src).assertEqual(AUDIO_SRC_TTS);
      expect(d.reason).assertEqual(ClipReason.PERSONA_MISMATCH);
    });

    it('failed_clip_falls_back_and_stays_failed', 0, () => {
      const ix = index();
      ix.markFailed('audio/en/poi_stub_barbican/full_0.mp3');
      const d = selectAudio(ix, query('This is Barbican.', 'en', 'voice', VoiceLabel.NATIVE));
      expect(d.src).assertEqual(AUDIO_SRC_TTS);
      expect(d.reason).assertEqual(ClipReason.CLIP_FAILED);
      expect(ix.isFailed('audio/en/poi_stub_barbican/full_0.mp3')).assertTrue();
    });

    it('user_text_only_choice_wins', 0, () => {
      const d = selectAudio(index(), query('This is Barbican.', 'en', 'text', VoiceLabel.TEXT_ONLY_USER));
      expect(d.src).assertEqual(AUDIO_SRC_TEXT);
      expect(d.reason).assertEqual(ClipReason.USER_TEXT_ONLY);
    });

    it('polish_platform_text_only_gets_the_clip', 0, () => {
      const d = selectAudio(index(), query('To jest Barbakan.', 'pl', 'text', VoiceLabel.TEXT_ONLY_PLATFORM));
      expect(d.src).assertEqual(AUDIO_SRC_PRERENDERED);
      const none = selectAudio(index(), query('Inne zdanie.', 'pl', 'text', VoiceLabel.TEXT_ONLY_PLATFORM));
      expect(none.src).assertEqual(AUDIO_SRC_TEXT);
      expect(index().hasLang('pl')).assertTrue();
      expect(index().hasLang('zh')).assertFalse();
    });

    it('story_plan_polish_becomes_studio_voice_with_clips', 0, () => {
      const base = vplan(Lang.PL, 'text', VoiceLabel.TEXT_ONLY_PLATFORM, 'no_voice_for_lang=pl');
      const p = storyVoicePlan(base, true);
      expect(p.label).assertEqual(VoiceLabel.PRERENDERED);
      expect(p.speechMode).assertEqual('voice');
      expect(p.engineLocale).assertEqual('');          // no TTS engine behind it: the rest stays text
      expect(p.reason.indexOf('fallback=text-only-platform') >= 0).assertTrue();
      expect(storiesAllOrNothing(base)).assertTrue();
      const without = storyVoicePlan(base, false);
      expect(without.label).assertEqual(VoiceLabel.TEXT_ONLY_PLATFORM);
      expect(without.speechMode).assertEqual('text');
    });

    it('story_plan_english_keeps_the_fallback_engine_for_other_lines', 0, () => {
      const base = vplan(Lang.EN, 'voice', VoiceLabel.FALLBACK_ZH_READS_EN, 'en_status=DOWNLOADABLE', 'zh-CN');
      const p = storyVoicePlan(base, true);
      expect(p.label).assertEqual(VoiceLabel.PRERENDERED);
      expect(p.engineLocale).assertEqual('zh-CN');
      expect(p.person).assertEqual(13);
      expect(storiesAllOrNothing(base)).assertFalse();  // en/zh fall back per sentence
    });

    it('story_plan_respects_text_only_and_listen_choices', 0, () => {
      const user = vplan(Lang.EN, 'text', VoiceLabel.TEXT_ONLY_USER, 'strategy=text-only');
      expect(storyVoicePlan(user, true).label).assertEqual(VoiceLabel.TEXT_ONLY_USER);
      const listen = vplan(Lang.PL, 'voice', VoiceLabel.NATIVE, 'pl_listen_en en_status=INSTALLED', 'en-US');
      expect(storyVoicePlan(listen, true).label).assertEqual(VoiceLabel.NATIVE);
      const q: ClipQuery = {
        text: 'To jest Barbakan.', lang: 'pl', personaId: 'historian', planSpeechMode: 'voice',
        planLabel: VoiceLabel.NATIVE, planReason: listen.reason
      };
      const d = selectAudio(index(), q);
      expect(d.src).assertEqual(AUDIO_SRC_TTS);
      expect(d.reason).assertEqual(ClipReason.LISTEN_CHOICE);
    });

    it('has_lang_per_persona', 0, () => {
      expect(index().hasLang('en', 'historian')).assertTrue();
      expect(index().hasLang('en', 'kids-legends')).assertFalse();
      expect(index().hasLang('en', '')).assertTrue();
    });

    it('story_coverage_all_partial_none', 0, () => {
      const ix = index();
      const all = storyClipCoverage(ix, ['This is Barbican.'], 'en', 'historian');
      expect(all.state).assertEqual(StoryClips.ALL);
      const part = storyClipCoverage(ix, ['This is Barbican.', 'Not rendered.'], 'en', 'historian');
      expect(part.state).assertEqual(StoryClips.PARTIAL);
      expect(part.matched).assertEqual(1);
      expect(part.total).assertEqual(2);
      expect(part.shas[0]).assertEqual(SHA_BARBICAN);
      expect(storyClipCoverage(ix, ['Nope.'], 'en', 'historian').state).assertEqual(StoryClips.NONE);
      expect(storyClipCoverage(ix, [], 'en', 'historian').state).assertEqual(StoryClips.NONE);
      expect(storyClipCoverage(undefined, ['This is Barbican.'], 'en', 'historian').state).assertEqual(StoryClips.NONE);
    });

    it('excluded_story_sentence_gets_no_clip_until_cleared', 0, () => {
      const ix = index();
      ix.exclude(SHA_PL);
      const d = selectAudio(ix, query('To jest Barbakan.', 'pl', 'text', VoiceLabel.TEXT_ONLY_PLATFORM));
      expect(d.src).assertEqual(AUDIO_SRC_TEXT);
      expect(d.reason).assertEqual(ClipReason.STORY_INCOMPLETE);
      expect(ix.isExcluded(SHA_PL)).assertTrue();
      ix.clearExclusions();
      const again = selectAudio(ix, query('To jest Barbakan.', 'pl', 'text', VoiceLabel.TEXT_ONLY_PLATFORM));
      expect(again.src).assertEqual(AUDIO_SRC_PRERENDERED);
    });

    it('no_manifest_keeps_current_behaviour', 0, () => {
      const a = selectAudio(undefined, query('This is Barbican.', 'en', 'voice', VoiceLabel.NATIVE));
      expect(a.src).assertEqual(AUDIO_SRC_TTS);
      expect(a.reason).assertEqual(ClipReason.NO_MANIFEST);
      const b = selectAudio(new ClipIndex([]), query('This is Barbican.', 'pl', 'text', VoiceLabel.TEXT_ONLY_PLATFORM));
      expect(b.src).assertEqual(AUDIO_SRC_TEXT);
    });
  });
}

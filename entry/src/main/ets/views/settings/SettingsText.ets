/*
 * Display strings for Settings values (task B9): story language rows, app language rows, the voice row.
 */
import { UiLang } from 'common';
import { StoryLang, VoiceRow } from 'common';

/** plSpoken: the A13 clips cover Polish, so the row says spoken instead of text only. */
export function storyLangRes(l: StoryLang, plSpoken: boolean = false): Resource {
  if (l === StoryLang.ZH) {
    return $r('app.string.lang_zh_spoken');
  }
  if (l === StoryLang.PL) {
    return plSpoken ? $r('app.string.lang_pl_spoken') : $r('app.string.lang_pl_text');
  }
  if (l === StoryLang.PL_LISTEN_EN) {
    return $r('app.string.lang_en_listen_pl_read');
  }
  return $r('app.string.lang_en_spoken');
}

export function uiLangRes(u: UiLang): Resource {
  if (u === UiLang.EN) {
    return $r('app.string.lang_english');
  }
  if (u === UiLang.PL) {
    return $r('app.string.lang_polish');
  }
  if (u === UiLang.ZH) {
    return $r('app.string.lang_chinese');
  }
  return $r('app.string.lang_system');
}

export function voiceRowRes(v: VoiceRow): Resource {
  if (v === VoiceRow.LAURA) {
    return $r('app.string.voice_laura_installed');
  }
  if (v === VoiceRow.FALLBACK || v === VoiceRow.PRERENDERED) {
    return $r('app.string.onb_spoken');   // the voice type is not labelled on screen (Settings > About names it)
  }
  if (v === VoiceRow.ZH) {
    return $r('app.string.voice_zh');
  }
  if (v === VoiceRow.TEXT_USER) {
    return $r('app.string.voice_text_only');
  }
  return $r('app.string.voice_text_only_platform');
}

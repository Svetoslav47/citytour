/*
 * Display formatting shared by the view models: distances and durations as string resources (so they follow
 * the app language) and localised names from the pack (fallback order textLang -> en -> pl, ARCHITECTURE §8).
 */
import { Lang, LocalizedText } from '../contracts/Model';
import { VoiceLabel } from '../contracts/Settings';

/** Route-level distance: "180 m" (rounded to 10 m / 20 m) or "2.5 km". */
export function distanceRes(m: number): Resource {
  const v = Math.max(0, m);
  if (v < 100) {
    return $r('app.string.fmt_m', Math.round(v / 10) * 10);
  }
  if (v < 1000) {
    return $r('app.string.fmt_m', Math.round(v / 20) * 20);
  }
  return $r('app.string.fmt_km', (Math.round(v / 100) / 10).toFixed(1));
}

/** "25 min" or "1 h 25 min" (at least 1 min). */
export function durationRes(minutes: number): Resource {
  const total = Math.max(1, Math.round(minutes));
  if (total < 60) {
    return $r('app.string.fmt_min', total);
  }
  return $r('app.string.fmt_h_min', Math.floor(total / 60), total % 60);
}

/** Localised name with the documented fallback order; '' when nothing is available. */
export function localName(names: LocalizedText | undefined, lang: Lang): string {
  if (names === undefined) {
    return '';
  }
  let v: string | undefined = undefined;
  if (lang === Lang.ZH) {
    v = names.zh;
  } else if (lang === Lang.PL) {
    v = names.pl;
  } else {
    v = names.en;
  }
  if (v !== undefined && v.length > 0) {
    return v;
  }
  if (names.en !== undefined && names.en.length > 0) {
    return names.en;
  }
  if (names.pl !== undefined && names.pl.length > 0) {
    return names.pl;
  }
  return names.zh !== undefined ? names.zh : '';
}

/** Spoken-story length estimate: ~150 words per minute (en/pl), ~250 characters per minute (zh). */
export function storyMinutes(sentences: string[], lang: Lang): number {
  let words = 0;
  let chars = 0;
  for (const s of sentences) {
    chars += s.length;
    words += s.split(' ').filter((w: string) => w.length > 0).length;
  }
  const min = lang === Lang.ZH ? chars / 250 : words / 150;
  return min <= 0 ? 0 : Math.max(1, Math.round(min));
}

/** Short label for what the listener hears (VoicePlan.label), e.g. "Fallback voice". */
export function voiceLabelRes(label: VoiceLabel): Resource {
  if (label === VoiceLabel.NATIVE) {
    return $r('app.string.voice_native');
  }
  if (label === VoiceLabel.FALLBACK_ZH_READS_EN) {
    return $r('app.string.voice_fallback_badge');
  }
  if (label === VoiceLabel.PRERENDERED) {
    return $r('app.string.voice_studio');
  }
  return $r('app.string.voice_text_only');
}

/** Language name as shown in the guide row ("English", "中文", "Polski"). */
export function langNameRes(lang: Lang): Resource {
  if (lang === Lang.ZH) {
    return $r('app.string.lang_chinese');
  }
  if (lang === Lang.PL) {
    return $r('app.string.lang_polish');
  }
  return $r('app.string.lang_english');
}

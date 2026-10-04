/*
 * Speech and voice ports for the watch: text only. Core Speech Kit (TTS) does not exist on wearables
 * (AI.TextToSpeech is absent from the SDK's wearable device definition, docs/research/WATCH.md §2), so the voice
 * plan is always speechMode 'text': the shared engine then emits no SPEAK and paces its captions on TICK.
 * speak() is never called in text mode; if it were, the utterance is reported as failed so the engine moves on.
 */
import {
  EnVoiceStrategy, Lang, SpeechCapabilities, SpeechListener, SpeechPort, Utterance, VoiceLabel, VoicePlan, VoicePort,
  VoiceState
} from 'common';

/** Error code reported for an utterance on the watch (no TTS engine). */
export const WATCH_NO_TTS: number = -100;

export class WatchVoice implements SpeechPort, VoicePort {
  private listener: SpeechListener | undefined = undefined;

  init(): Promise<SpeechCapabilities> {
    return this.capabilities();
  }

  capabilities(): Promise<SpeechCapabilities> {
    const c: SpeechCapabilities = { en: VoiceState.UNAVAILABLE, zh: VoiceState.UNAVAILABLE };
    return Promise.resolve(c);
  }

  plan(textLang: Lang): VoicePlan {
    const p: VoicePlan = {
      textLang: textLang, speechMode: 'text', engineLocale: '', person: 0, languageContext: '',
      label: VoiceLabel.TEXT_ONLY_PLATFORM, reason: 'device=wearable tts=absent'
    };
    return p;
  }

  downloadEnglish(onProgress: (pct: number) => void): Promise<boolean> {
    return Promise.resolve(false);
  }

  setStrategy(s: EnVoiceStrategy): void {
  }

  setListener(l: SpeechListener): void {
    this.listener = l;
  }

  speak(u: Utterance): void {
    if (this.listener !== undefined) {
      this.listener.onUtteranceError(u.id, WATCH_NO_TTS);
    }
  }

  prefetch(u: Utterance): void {
  }

  stopNow(): void {
  }

  pause(): void {
  }

  resume(): void {
  }

  isSpeaking(): boolean {
    return false;
  }
}

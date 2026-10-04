// Suite: VoiceChain.test - module under test: core/remote/VoiceChain (SERVER.md §2 fallback chain).
// Cases: clip -> cache -> remote -> tts -> text (Polish); the user's text-only / listen choice; server disabled and
// toggle off; offline and budget back-off; and judging a /v1/tts response: ok, timeout, network error, 429, 5xx,
// 4xx, X-Text-Sha256 mismatch or missing, empty body, wrong content type.
import { describe, it, expect } from '@ohos/hypium';
import {
  BUDGET_BACKOFF_MS, ChainInput, decideVoice, judgeRemote, OFFLINE_BACKOFF_MS, REMOTE_BUDGET_MS, RemoteResult,
  ServerState, serverStateText, VoiceSrc
} from 'common';

const SHA: string = '6b57aa9020f95bb52345b5d986292da081ea900be66916d2410916c350c39573';

function input(): ChainInput {
  const i = new ChainInput();
  i.serverConfigured = true;
  i.toggleOn = true;
  i.nowMs = 1000000;
  return i;
}

function ok(): RemoteResult {
  const r = new RemoteResult();
  r.status = 200;
  r.headerSha = SHA;
  r.contentType = 'audio/mpeg';
  r.bytes = 12000;
  r.elapsedMs = 800;
  return r;
}

export default function voiceChainTest() {
  describe('VoiceChain', () => {
    it('clipFirst', 0, () => {
      const i = input();
      i.localClip = true;
      i.cached = true;
      expect(decideVoice(i).src).assertEqual(VoiceSrc.CLIP);
    });

    it('cacheThenRemote', 0, () => {
      const i = input();
      i.cached = true;
      expect(decideVoice(i).src).assertEqual(VoiceSrc.REMOTE_CACHE);
      i.cached = false;
      const s = decideVoice(i);
      expect(s.src).assertEqual(VoiceSrc.REMOTE);
      expect(s.fallback).assertEqual(VoiceSrc.TTS);
    });

    it('polishFallsBackToText', 0, () => {
      const i = input();
      i.platformText = true;
      expect(decideVoice(i).fallback).assertEqual(VoiceSrc.TEXT);
      i.serverConfigured = false;
      const s = decideVoice(i);
      expect(s.src).assertEqual(VoiceSrc.TEXT);
      expect(s.reason).assertEqual('server_disabled');
    });

    it('userChoiceAndToggle', 0, () => {
      const i = input();
      i.userOptOut = true;
      i.cached = true;
      expect(decideVoice(i).src).assertEqual(VoiceSrc.TTS);
      expect(decideVoice(i).reason).assertEqual('user_choice');
      const j = input();
      j.toggleOn = false;
      j.cached = true;
      expect(decideVoice(j).src).assertEqual(VoiceSrc.TTS);
      expect(decideVoice(j).reason).assertEqual('toggle_off');
    });

    it('backoffSkipsServer', 0, () => {
      const i = input();
      i.offlineUntilMs = i.nowMs + 1;
      expect(decideVoice(i).reason).assertEqual('offline');
      i.offlineUntilMs = 0;
      i.budgetUntilMs = i.nowMs + 1;
      expect(decideVoice(i).reason).assertEqual('budget');
      i.budgetUntilMs = i.nowMs;   // expired
      expect(decideVoice(i).src).assertEqual(VoiceSrc.REMOTE);
      // a cached line still plays offline
      i.offlineUntilMs = i.nowMs + 1;
      i.cached = true;
      expect(decideVoice(i).src).assertEqual(VoiceSrc.REMOTE_CACHE);
    });

    it('limitsAndCourse', 0, () => {
      const i = input();
      i.textSendable = false;
      expect(decideVoice(i).reason).assertEqual('text_limits');
      const j = input();
      j.courseKnown = false;
      expect(decideVoice(j).reason).assertEqual('no_course');
    });

    it('judgeOk', 0, () => {
      const v = judgeRemote(ok(), SHA);
      expect(v.accept).assertTrue();
      expect(v.server).assertEqual(ServerState.ONLINE);
      const upper = ok();
      upper.headerSha = SHA.toUpperCase();
      expect(judgeRemote(upper, SHA).accept).assertTrue();
    });

    it('judgeTimeout', 0, () => {
      const r = ok();
      r.timedOut = true;
      expect(judgeRemote(r, SHA).reason).assertEqual('timeout');
      const late = ok();
      late.elapsedMs = REMOTE_BUDGET_MS + 1;
      expect(judgeRemote(late, SHA).accept).assertFalse();
      expect(judgeRemote(late, SHA).offlineForMs).assertEqual(0);
    });

    it('judgeOfflineAndBudget', 0, () => {
      const net = new RemoteResult();
      const v = judgeRemote(net, SHA);
      expect(v.reason).assertEqual('offline');
      expect(v.server).assertEqual(ServerState.OFFLINE);
      expect(v.offlineForMs).assertEqual(OFFLINE_BACKOFF_MS);
      const r = ok();
      r.status = 429;
      const b = judgeRemote(r, SHA);
      expect(b.reason).assertEqual('http_429');
      expect(b.server).assertEqual(ServerState.BUDGET);
      expect(b.budgetForMs).assertEqual(BUDGET_BACKOFF_MS);
      r.status = 503;
      expect(judgeRemote(r, SHA).server).assertEqual(ServerState.OFFLINE);
      r.status = 403;
      expect(judgeRemote(r, SHA).reason).assertEqual('http_403');
      expect(judgeRemote(r, SHA).server).assertEqual(ServerState.ONLINE);
      expect(judgeRemote(r, SHA).neverRetry).assertTrue();
      r.status = 502;
      expect(judgeRemote(r, SHA).accept).assertFalse();
      expect(judgeRemote(r, SHA).neverRetry).assertFalse();
      r.status = 401;
      expect(judgeRemote(r, SHA).accept).assertFalse();
    });

    it('judgeMismatch', 0, () => {
      const r = ok();
      r.headerSha = 'b'.repeat(64);
      expect(judgeRemote(r, SHA).reason).assertEqual('sha_mismatch');
      r.headerSha = '';
      expect(judgeRemote(r, SHA).reason).assertEqual('sha_missing');
      const e = ok();
      e.bytes = 0;
      expect(judgeRemote(e, SHA).reason).assertEqual('empty_body');
      const t = ok();
      t.contentType = 'application/json';
      expect(judgeRemote(t, SHA).reason).assertEqual('content_type');
      expect(judgeRemote(ok(), '').accept).assertFalse();
    });

    it('serverText', 0, () => {
      expect(serverStateText(ServerState.DISABLED)).assertEqual('server disabled');
      expect(serverStateText(ServerState.BUDGET)).assertEqual('server budget reached');
    });
  });
}

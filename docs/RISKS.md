# CityTour: risk register and spike results

**Written:** Saturday 2026-10-03, 14:10 CEST, by the "pessimist" agent. About 21 hours remain until the 11:00 code freeze.

**Evidence:**
- The throwaway spike lives on branch `exp/risk-spikes` (local commit `934ab75`, not pushed), in the worktree `../citytour-wt/risk-spikes`.
- The spike is one page, `entry/src/main/ets/pages/Index.ets`. Every event is logged with hilog domain `0xC170`, tag `SPIKE`.
- Logs below were captured with `devecocli log --follow`.

**Clock note:** the emulator's clock runs on China Standard Time (UTC+8), so log timestamps read 19:5x while CEST was 13:5x.

**Scores:**
- P is probability and I is impact, each 1–5. Score = P × I.
- "Deadline" is the wall-clock time (Sat/Sun, CEST) at which the cut decision is made, no extensions.

---

## 1. Experiment results (emulator "Pura 90", HarmonyOS 6.1.1(24), Emulator 6.1.1.200, unsigned debug HAP)

| # | What we tested | Result | Evidence (log / observation) |
|---|---|---|---|
| a1 | `textToSpeech.listVoices({online:1})` | **VERIFIED works.** It reports `zh_CN/13 INSTALLED`, `zh_CN/21 GA`, `en_US/8 GA`. | `listVoices OK [{"language":"zh_CN","person":13,...,"status":"INSTALLED"},{"zh_CN",21,"GA"},{"en_US",8,"GA","English US Voice"}]` |
| a2 | `createEngine` zh-CN, person 13, `isBackStage:true` | **VERIFIED works**, in 160–420 ms. Fully offline: the model is preinstalled. | `createEngine zh-CN/13 OK in 160ms` |
| a3 | `speak` zh-CN with default playback (`playType` 1) | **VERIFIED works.** onStart reports `{"sampleRate":16000,"sampleBit":16}`. Synthesis takes about 0.2 s, and "speak complete" arrives about 4.4 s later. | Audio is rendered by the HiAI service process (pid ≠ app, uid 20020015) with **`usage:3` (VOICE_ASSISTANT)**, not by our app. The speech was not checked by ear; the agent cannot hear it. |
| a4 | `createEngine` en-US, person 8 (Laura) | **VERIFIED fails.** Error `1002300005`. | `HyVoiceSynthesizer error: Error: Invalid relative path` / `TTS_RawFileManager: read raw file, path: en_us_front_root/, name: model.irf`, which means the voice model is not on the device. |
| a5 | `downloadVoice` en-US/8 | **VERIFIED fails on the emulator.** The system dialog "Download language package? A Laura voice package is required…" appears. After tapping Download, the call returns `1002300008 downloadVoice failed!`. | HiAI log: `queryModelCloud on OTA catch error is: {"message":"response analyze error","code":11500100}`. The emulator *has* internet (ping 1.1.1.1 OK). Huawei's OTA model cloud does not serve this emulator. |
| a6 | zh-CN engine (person 13) reading **English** text | **VERIFIED synthesizes and plays** (about 9 s for a 20-word sentence). **Quality is UNTESTED.** Docs say the zh engine supports "English in a Chinese context", so expect a Chinese-accented voice. **A human must listen before 15:30.** | `speak(zh-CN, pcm=false) called: Welcome to the Main Market Square…` → `speak complete` |
| a7 | `playType:0` (PCM via `onData`), then our own `AudioRenderer` | **VERIFIED works.** 16 kHz mono S16LE arrives in chunks of about 12.8 KB. 2.76 s of audio (88,186 B) was synthesized in about 95 ms. Our `AudioRenderer` (`STREAM_USAGE_AUDIOBOOK`) moved to RUNNING and then STOPPED. | With `playType:0`, `onComplete` fires only once, with `type:0 "synthesis complete"`. There is **no `type:1`**, so playback end is ours to detect. |
| b1 | Location with the system location switch off (the default on a fresh emulator) | **VERIFIED fails.** Error `3301100 The location switch is off`, returned in 10 ms. | The **jury will hit this on a fresh emulator.** |
| b2 | `requestPermissionsFromUser([APPROXIMATELY_LOCATION, LOCATION])` | **VERIFIED works** on an unsigned HAP. The standard dialog appears, including the "Precise location" toggle. | `perm result [0,0] dialogShown=[true,true]` |
| b3 | `atManager.requestGlobalSwitch(ctx, SwitchType.LOCATION)` | **VERIFIED works.** A system sheet appears; after the user enables the switch, it returns `true`. | `requestGlobalSwitch(LOCATION)=true enabled=true` |
| b4 | `getCurrentLocation` without GUI injection | **VERIFIED: returns a fixed fake fix**, `lat 40, lon 116` (Beijing), `accuracy 6.5`, `direction 45`, `speed 0`, `sourceType 1` (GNSS), in 454 ms. | |
| b5 | `on('locationChange', {interval:1, NAVIGATION})` | **VERIFIED: 1 Hz updates of the same static point.** Speed and course never change, so **course-over-ground logic cannot be exercised on the emulator** without the GUI. | `locationChange #196 lat=40 lon=116 dir=45 speed=0` |
| b6 | `devecocli emulator geolocation` / `power` | **VERIFIED fails.** | "Emulator scene control commands require Emulator 7.0 or later. Current Emulator version is 6.1.1.200." |
| c0 | Turning the screen off from the CLI | **VERIFIED works** with `hdc -t 127.0.0.1:5555 shell power-shell suspend`, and `power-shell wakeup` turns it back on. `hidumper -s 3308 -a -s` confirms `Display State=0`. Home is sent with `hdc shell uitest uiInput keyEvent Home`. | This is our substitute for `devecocli emulator power`. |
| c1 | `startBackgroundRunning(ctx, BackgroundMode.LOCATION, wantAgent)` | **VERIFIED works.** The notification "A positioning task is in progress. Closing this notification will end it." appears. | |
| c2 | App in background **and screen off** for 100 s, with the LOCATION task | **VERIFIED works.** The 10 s JS timer kept ticking; `locationChange` kept arriving at 1 Hz (97 updates in 97 s); and zh TTS spoke every 20 s, with the HiAI renderer starting and "speak complete" logged each time. | TICK 5…14 between 19:56:28 and 19:57:58 while `Display State=0` and `Ability onBackground` |
| c3 | Control: background and screen off **without** a continuous task | **Location stopped** (`locCount` frozen at 4 from the moment of backgrounding). The **JS timer and TTS kept running.** | So the emulator did **not freeze** the process within 90 s. **Real phones freeze background apps within seconds.** This means the emulator is more lenient than a device, and a "works on emulator" result for background behaviour does **not** prove it works on a phone. |
| c4 | Our own PCM `AudioRenderer` playing in the background with the screen off, under a **LOCATION-only** task (no AVSession) | **VERIFIED plays** on the emulator. | `AudioBackgroundManager IsAllowedPlayback … hasSession:0, isBack:1, hasBackgroundTask:1, isFreeze:0`. Docs say an AUDIOBOOK stream in the background needs AVSession plus AUDIO_PLAYBACK. The emulator did not enforce this; a real device probably will. |
| c5 | `startBackgroundRunning(ctx, ['location','audioPlayback'], wa)` (API 12+ overload) | **VERIFIED works** on API 24. | Returns `{"slotType":4,"contentType":8,"notificationId":2,"continuousTaskId":4}`. A second request while one is active fails with `9800005 … has applied for a continuous task`. |
| d1 | AVSession: `createAVSession(ctx,'…','audio')` + `setAVMetadata` + `setAVPlaybackState(PLAY)` + `on(play/pause/playNext/playPrevious)` + `activate()` | **VERIFIED works.** The **Control Center** shows a media card ("Main Market", "CityTour spike", with prev/pause/next). The **lock screen** shows a media pill with pause. | Tapping pause and next in Control Center logged `AVSession cmd pause` and `AVSession cmd next`. **Pause on the lock screen** logged `AVSession cmd pause`. The notification shade did *not* show the card. |
| e1 | Unsigned debug HAP (`entry-default-unsigned.hap`, no `signingConfigs`, not logged in to `devecocli auth`) | **VERIFIED: nothing above was blocked by the lack of a signature.** TTS, Location, permissions, the continuous task and AVSession all work unsigned on the emulator. | Signing is only needed for a **real device**, which is UNTESTED. |
| x1 | Data endpoints, 14:04 CEST from the venue network | OSRM foot `table`: **200 in 1.2 s.** Wikipedia REST: **200.** Kraków ArcGIS: **200.** Wikidata SPARQL: **200** (4,204 items with coordinates in Kraków). **Overpass: DOWN.** | overpass-api.de returned 504 (twice), maps.mail.ru returned 504, and kumi.systems and private.coffee timed out after 30 s. |

**Not tested, and why:**
- **Real-device behaviour** (freezing, GPS, region locks): no device available.
- **TTS quality by ear:** the agent cannot hear audio.
- **GUI location injection and route playback:** this needs the DevEco GUI, and AGENTS.md leaves complex emulator UI to humans.
- **Audio focus against another media app:** no second app installed. Time-boxed out.
- **Long-run (more than 2 min) background survival.**

---

## 2. What the experiments change (read this first)

1. **Spoken English is impossible on the emulator**, and the emulator is where the jury expects the demo. Laura (en-US) is not preinstalled, and `downloadVoice` fails against Huawei's OTA cloud. The brief's acceptance check "narration is spoken in English and Chinese" **cannot be met on the emulator.** Options, for the user to decide by **15:30**:
   - **A. Chinese voice reads the English text.**
     - This is the zh-CN engine reading English sentences (works, quality unknown). Listen to it now.
     - It is honest if labelled: "English narration via the zh-CN voice: the en-US voice cannot be downloaded on the emulator."
   - **B. Speak Chinese, show English, Polish and Chinese as subtitles.**
     - The Chinese voice demonstrates the kit and the subtitles carry the meaning for the jury.
     - The weak point is that the jury does not understand the narration.
   - **C. Keep en-US in the code**, with the `listVoices` → `downloadVoice` flow and graceful fallback to A or B when the voice is not installed. Claim en-US only as "works on devices with the Laura voice", and mark it UNVERIFIED.
   - **Recommendation: C + A.** The fallback is real error handling, which scores technical-execution points, and the demo still talks in English.
   - **DECIDED (user, 2026-10-03, HACKATHON_BRIEF):** C + A. English is spoken by the zh-CN voice, labelled "Fallback voice"; Laura is used automatically where installed. Gate G1 (a human listens) still decides whether the fallback is intelligible; if not, PLAN §0.4 switches English to text-only.
   - Ask the Huawei mentors **today** whether they have a device or emulator image with Laura installed.
2. **The docs say both Core Speech Kit and Location Kit are "China mainland only".**
   - Core Speech Kit intro, 支持的国家/地区: "仅适用于中国境内".
   - Location FAQ faqs-location-27: non-wearables "仅支持中国境内 … 海外可能会导致位置信息异常".
   - The emulator is a CN image, so it works. A mentor's phone with a European/overseas configuration may behave differently. Do not promise "works on any HarmonyOS phone".
3. **Default playback is the wrong audio path for a guided tour.**
   - The audio plays in the HiAI process as VOICE_ASSISTANT, so our AVSession pause cannot stop it except by calling `engine.stop()`.
   - Volume is the Xiaoyi channel (FAQ faqs-core-speech-10).
   - `playType:0` plus our own `AudioRenderer` works (a7) and is what ARCHITECTURE.md D5 already plans. Keep it.
   - Keep default playback as the **emergency fallback** behind one flag, because it is the path verified to speak in the background (c2).
4. **The background architecture is confirmed on the emulator, but proves nothing about phones** (c3: the emulator does not freeze apps). Keep the LOCATION task as the "reason to live", and add `audioPlayback` + AVSession as planned (c5, d1 verified).
5. **Location on the emulator is a static Beijing point.** Without the "Demo walk" source there is no demo at all.
   - The DemoWalk source must feed the *same* pipeline: position **plus speed plus course**.
   - It is the only way to exercise "look left/right" (b5).
   - The app **must** handle `3301100` with `requestGlobalSwitch` (b1, b3), or the jury's first launch shows nothing.
6. **Overpass is unreliable right now.** Do not put it on the critical path. Wikidata SPARQL plus Kraków ArcGIS plus Wikipedia REST all respond. Fetch once, commit the snapshot, and never fetch at runtime.

---

## 3. Ranked risk register

### 3.1 Summary, ranked by score

| Rank | ID | Risk | P | I | Score | Decision deadline |
|---|---|---|---|---|---|---|
| 1 | T1 | English TTS not available on the emulator (VERIFIED) | 5 | 5 | **25** | Sat 15:30 |
| 2 | S1 | Scope explosion: "all locations" + 3 languages + Canvas map + routing + persona model in 21 h | 5 | 5 | **25** | Sat 18:00 / 23:00 |
| 3 | P3 | The demo cannot show the core value (walking, phone locked in pocket) | 5 | 4 | **20** | Sat 20:30 |
| 4 | S3 | Demo video recorded **without the narration audio** (macOS screen recording does not capture system audio by default) | 4 | 5 | **20** | Sat 20:30 |
| 5 | T13 | Data pipeline blocked by Overpass or OSRM outages (Overpass VERIFIED down) | 4 | 4 | **16** | Sat 18:00 |
| 6 | P1 | Originality: "GPS audio tour" already exists (VoiceMap, izi.TRAVEL, SmartGuide, Rick Steves…) | 4 | 4 | **16** | Sat 16:00 (pitch) |
| 7 | T16 | Native Canvas map eats the night | 4 | 4 | **16** | Sat 23:00 |
| 8 | PR1 | Merge conflicts in hotspots, and `main` breaking at the end | 4 | 4 | **16** | Continuous; freeze Sun 09:30 |
| 9 | J1 | Losing technical-execution points: no unit tests, no "bad AI output" handling | 4 | 4 | **16** | Sun 07:00 |
| 10 | T3 | Emulator location is static and the CLI cannot inject, so everything depends on DemoWalk | 5 | 3 | **15** | Sat 19:00 |
| 11 | T6 | Background killing on real phones (emulator too lenient, VERIFIED) | 3 | 4 | **12** | n/a (disclose) |
| 12 | T5 | Course-over-ground "look left/right" is wrong at low speed or when standing | 4 | 3 | **12** | Sun 01:00 |
| 13 | T14 | Data licences: ODbL / CC BY-SA attribution missing or wrong | 4 | 3 | **12** | Sun 08:00 |
| 14 | T4 | GPS jitter in the Old Town (multipath) causes false or missed triggers | 4 | 3 | **12** | n/a on emulator; design now |
| 15 | T10 | AI agents invent HarmonyOS APIs or use API > 20 without guards | 4 | 3 | **12** | Continuous |
| 16 | T12 | Final `.hap` and signing: unsigned only installs on the emulator; signing secrets leak into the public repo | 3 | 4 | **12** | Sun 08:00 |
| 17 | S2 | Sleep deprivation causes bad merges and a bad demo at 08:00 | 4 | 3 | 12 | Plan in §3.4 |
| 18 | T2 | Speech and Location Kits are documented as China-only, so a mentor device may misbehave | 3 | 3 | 9 | Sat 17:00 (ask mentors) |
| 19 | T7 | Audio path complexity (PCM streaming, end detection, focus or interrupts) | 3 | 3 | 9 | Sat 22:00 |
| 20 | P2 | Polish narration is text-only at a Polish hackathon | 4 | 2 | 8 | Already decided; frame it |
| 21 | PR5 | Two agents on one Mac overwrite the same bundle on the same emulator | 4 | 2 | 8 | Now |
| 22 | T9 | ArkTS strict-mode friction (e.g. `arkts-no-structural-typing` on the first spike compile) | 4 | 2 | 8 | Continuous |
| 23 | T8 | TTS engine limits (3 instances per device, unique requestId, 10k chars, engine dies with page) | 2 | 3 | 6 | Sat 22:00 |

### 3.2 Technical

**T1. English voice unavailable on the emulator (VERIFIED: a4, a5).** P5 × I5.
- **Early warning:** already triggered: `1002300005` on createEngine, `1002300008` on downloadVoice, and OTA `11500100`.
- **Mitigation:**
  - The `VoiceManager` calls `listVoices()` at startup.
  - en-US INSTALLED → use Laura.
  - en-US GA → offer the download. On failure, fall back to the zh-CN engine reading the English text, with an on-screen badge "English read by zh-CN voice (en-US voice unavailable on this device)".
  - Text is always shown. Unit-test the fallback decision.
- **CUT/fallback:**
  - **By 15:30, a human listens to button "zh engine speaks English" in the spike.** Either reuse the spike worktree, or run `devecocli run` from it and tap the button.
  - If it is intelligible → option A as the demo voice.
  - If it is not → option B (Chinese voice + subtitles) and drop "spoken English" from README claims.
  - Either way, **change the acceptance check in HACKATHON_BRIEF.md** (the user's decision).

**T13. Data source outages (VERIFIED: Overpass down at 14:04).** P4 × I4.
- **Early warning:** any 504, 429 or timeout from overpass-api.de.
- **Mitigation:**
  - Data is built offline by a script: Python or Node, run once.
  - Sources in order: Wikidata SPARQL (P131 = Kraków, P625 coordinates, sitelinks for pl/en/zh) → Kraków ArcGIS (`Pomnik`, `EOZ_Zabytki_*`) → Overpass only as an optional enrichment.
  - The OSRM matrix covers tour stops only (11×11 = 1 request).
  - **Commit the raw snapshots** (`data/raw/*.json` with fetch date) so the build never needs the network.
- **CUT/fallback:**
  - If the full POI pack is not committed by **18:00**, ship the tour stops (hand-curated JSON, 11 stops) plus the 395 ArcGIS monuments only.
  - If OSRM fails, use haversine × 1.3 as the walking-distance proxy, labelled in README.

**T16. Native Canvas vector map.** P4 × I4.
- **Early warning:** at 22:00 the map still has no correct projection of the tour stops, or pan and zoom are buggy.
- **Mitigation:**
  - Equirectangular local projection around Rynek (fine at city scale).
  - Pre-bake only the streets inside the Planty ring plus the Royal Route to Wawel.
  - No labels except stop numbers. No zoom in v1, only fit-to-route.
- **CUT/fallback:**
  - If it is not drawing streets plus route plus the moving dot by **23:00**, use a **pre-rendered static PNG** of the Old Town (OSM-derived, attributed) with stop markers and the user dot drawn on a Canvas overlay using the same projection.
  - The map is *not* the platform capability. Spend nothing on it after 23:00.

**T3. Emulator location is static, with no CLI injection (VERIFIED: b4–b6).** P5 × I3.
- **Early warning:** any feature that needs speed or course and is "tested" only on the emulator.
- **Mitigation:**
  - A `LocationSource` interface with `KitLocationSource` and `DemoWalkSource`.
  - DemoWalk replays the OSRM route geometry at 1.3 m/s with ±5 m noise, emitting lat, lon, speed and course.
  - A **"SIMULATED: Demo walk"** badge stays visible on every screen.
  - Location-switch handling via `requestGlobalSwitch` (verified).
- **CUT/fallback:** if DemoWalk is not driving stop triggers end to end by **19:00**, the 20:00 checkpoint ships a "Next stop" button that fires the same trigger event (labelled "manual trigger").

**T6. Background killing on real devices.** P3 × I4.
- **Early warning:** none is possible on the emulator. c3 proves the emulator does not freeze. The only test is a mentor device.
- **Mitigation:**
  - Follow the documented contract exactly: LOCATION + AUDIO_PLAYBACK in one call, AVSession active, keep the location subscription alive for the whole tour.
  - Stop and re-request after an audio interrupt (docs: "音频在后台播放时被打断，系统会自行检测和停止长时任务").
  - Register `on('continuousTaskCancel')` and log it.
  - Fallback B from ARCHITECTURE (zero-PCM between items) only if a device shows suspension.
- **CUT:** none. Disclose in README: "Background behaviour verified on emulator only; the emulator does not freeze apps, so device behaviour is unverified."

**T5. "Look left/right" from course over ground.** P4 × I3.
- **Early warning:** the relative direction flips between fixes, or is computed while speed < 0.5 m/s.
- **Mitigation:**
  - Heading = bearing of the smoothed displacement over the last ~15 m (not `Location.direction`).
  - When speed < 0.5 m/s, use the **planned route segment bearing** into the stop, which we always know.
  - Quantize to 8 sectors and use "ahead / ahead-left / left / behind-left…".
  - Unit-test with synthetic tracks.
- **CUT:** if it is not working and tested by **01:00**, say "look for …" plus the landmark description and drop the direction phrase. The text data stays.

**T4. GPS jitter in Old-Town canyons.** P4 × I3. The demo is not affected (emulator), but the jury will ask.
- **Mitigation:**
  - Ignore fixes with accuracy > 30 m.
  - Arrival = inside radius (25–40 m per stop) for ≥ 2 consecutive fixes or ≥ 5 s.
  - Exit hysteresis of 1.5 × radius.
  - Only the *next planned* stop or a not-yet-visited stop can fire, which prevents ping-pong between St Mary's and Sukiennice (about 100 m apart).
  - Unit tests with a jitter track.
- **CUT:** none. It is core logic and cheap. Implement it in the geofence module by **22:00**.

**T7. Audio path complexity.** P3 × I3.
- **Early warning:** gaps or clicks between sentences, a missed "done" event, or narration not pausing from the lock screen.
- **Mitigation:** follow ARCHITECTURE D5 exactly (sentence = utterance, byte-count end detection, look-ahead 1). Handle `audioInterrupt` (pause or duck).
- **CUT:** if the PCM queue is not stable by **22:00**, switch `NarrationPlayer` to default playback (`playType:1`, verified in background, c2). AVSession pause then calls `engine.stop()`. Losing volume control is acceptable.

**T8. TTS engine limits.** P2 × I3.
- Maximum 3 engine instances per device across all apps. `requestId` is single-use. 10,000 characters per speak. An engine shut down in `aboutToDisappear` breaks other pages (FAQ faqs-core-speech-1).
- **Mitigation:** a singleton `VoiceManager` in the ability, not in a page. At most 2 engines (zh plus en-if-installed). UUID requestIds.

**T9. ArkTS learning curve.** P4 × I2.
- The first spike compile failed on `arkts-no-structural-typing` (`Uint8Array.buffer` is `ArrayBufferLike`).
- **Mitigation:** run `devecocli check arkts` before every build (it takes seconds and caught that error). No `any`, no object-literal types, no structural typing.

**T10. AI agents hallucinating APIs.** P4 × I3.
- In this session the pessimist itself first believed the `string[]` overload of `startBackgroundRunning` was API 21+. The docs say 12+; only *multiple concurrent tasks* are 21+. Memory is not evidence.
- **Mitigation:**
  - Every Kit call cites a `devecocli docs` id in the PR or commit message.
  - `check arkts` must be clean.
  - Anything with a `起始版本` > 20 is wrapped with `canIUse()` or a `deviceInfo.sdkApiVersion` check (compatibleSdkVersion is 20).

**T12. Final `.hap` and signing.** P3 × I4.
- **Verified:** an unsigned debug HAP installs and works on the emulator, which is the jury's default.
- **Risks:**
  - (a) Someone runs `devecocli signature generate` for a mentor device, which writes `signingConfigs` (p12 path plus encrypted passwords) into `build-profile.json5`. That gets committed, and the public repo or pre-review flags it.
  - (b) A real device needs a Huawei ID login plus that device's UDID in a debug profile.
- **Mitigation:** add a `.gitignore` or pre-commit grep for `signingConfigs` content, `*.p12`, `*.p7b`, `*.cer`. Release artifact = `entry-default-unsigned.hap` from a tagged commit, with README saying "unsigned debug build; install on emulator with `hdc install`".
- **CUT:** no device signing unless a mentor device is physically in hand by **Sun 06:00**.

**T14. Data licences.** P4 × I3.
- **OSM (ODbL):** "© OpenStreetMap contributors" is required on the map and in About. Our offline POI pack and baked map are a *derived database*: state ODbL for `data/` and keep the build script (that satisfies "offer the database").
- **Wikipedia (CC BY-SA 4.0):** any narration adapted from Wikipedia text (including AI-drafted paraphrase) is an adaptation. It must be CC BY-SA, credited with the article title, a link and "Wikipedia contributors", and must be **separate from the code licence**.
- **Wikidata:** CC0, so no obligation; credit it anyway.
- **Kraków ArcGIS:** **licence UNVERIFIED.** Check the item's "Terms of use" before shipping. If unclear, use it only for coordinates and cite it.
- **OSRM demo server:** fair use only. One 11×11 matrix (plus 110 leg routes at 1 request/s) is fine; batch thousands of POIs is not.
- **Mitigation:** `data/ATTRIBUTION.md`, an in-app About/Sources screen, and per-place `sources[]` in the schema (already in the brief).
- **CUT:** if time runs out, the minimum by **Sun 08:00** is a README section plus the About screen with static text.

**T2. China-only Kits (documented).** P3 × I3.
- **Mitigation:** ask the mentors by **17:00** which device and region they would test on.
- **Fallback:** emulator only, stated plainly in README.

### 3.3 Product

**P1. Originality: "not another audio-guide app".** P4 × I4. GPS-triggered audio tours exist: VoiceMap, izi.TRAVEL, SmartGuide, Rick Steves Audio Europe, and city apps.
- **Early warning:** the pitch sentence starts with "an audio guide that…".
- **Mitigation:** pitch only what those apps lack, and show each one running:
  1. **Fully on-device and account-free:** offline TTS, offline open data, no cloud and no API keys. This is the sovereignty angle.
  2. **Phone locked in pocket, as a first-class OS citizen:** continuous task + AVSession on the lock screen (verified). Headset controls "skip" and "tell me more".
  3. **Spatial "where to look"** from your walking direction, not the compass.
  4. **An optimised route from where you stand**, plus "I have N minutes" if time allows.
  5. **Open, inspectable sources per sentence.**
- **CUT:** none. This is pitch work. Draft it by **16:00**, half an hour, owned by one person.

**P3. The demo cannot show real walking.** P5 × I4.
- **Mitigation:**
  - Demo script: Start tour → DemoWalk (SIMULATED badge) → lock screen with `power-shell suspend` → **narration continues; logs pane shows `locationChange`, `stop arrived`, `speaking`** → wake → lock-screen media pill → pause from the lock screen (verified d1) → resume.
  - Optionally add 10 s of phone footage of the Royal Route as B-roll, clearly marked as "context, not the app".
- **CUT:** if the screen-off segment is flaky on the day, record it separately and cut it in, saying so in the narration.

**P2. Polish is text-only.** P4 × I2. Already decided by the user. Frame it as "Core Speech Kit supports zh/en only; Polish text is complete". Do not spend time on Polish audio.

**P4. "All Kraków locations installed" vs "narrow working solution".** This is folded into S1. "All" should mean *all POIs are on the map, with a sourced Wikipedia summary where one exists*, not narration for each.

### 3.4 Scope and time

**S1. Scope explosion.** P5 × I5.
- Honest capacity: about 21 h wall clock, × 2 people, minus 2 × 4.5 h sleep, minus about 3 h for demo, README and submission. That leaves about **24 person-hours** of build time, with AI agents helping, *and* about 5 h of it at low quality after 02:00.
- The feature list in the brief and the proposals is about 3× that.
- **Early warning:** at 18:00 there is no single path from "Start tour" to "voice speaks a stop" on `main`.
- **CUT:** see §5 for the cut line and §4 for the timeline.

**S2. Sleep and fatigue.** P4 × I3.
- **Mitigation:**
  - Staggered sleep: person A 01:00–05:30, person B 03:00–07:30. No merges to `main` by a single tired person between 02:00 and 07:00.
  - A tag `checkpoint-good` at 20:00 and `night-good` at 01:00.

**S3. Demo recording loses the audio.** P4 × I5. The entire product is a voice.
- macOS screen recording (Cmd-Shift-5, QuickTime) does **not** capture system audio by default.
- **Mitigation:** test **OBS** (macOS ScreenCaptureKit audio capture) or a virtual device (BlackHole) by **20:30**. Make a 30-second test clip: emulator TTS plus screen.
- **CUT:** if no system-audio capture works, record the Mac speaker with a phone microphone in a quiet room, sync it by hand, and say so.

### 3.5 Jury: points we are likely to lose, and why

| Criterion | Likely loss | Why | Fix (deadline) |
|---|---|---|---|
| Technical execution (20%) | −5 to −8 | No unit tests. No visible handling of permission-denied, location-off or voice-missing. AI-drafted scripts without validation. | Hypium/local unit tests for geofence, bearing, Held–Karp and data-pack validation (Sun 07:00). Error states verified for: `3301100` (switch off), permission denied, en voice missing, and malformed pack. A pack validator checks schema, length, language and `sources[]` non-empty, and falls back to the source text. |
| Platform capabilities (20%) | −2 to −6 | If we fall back to default TTS playback, a web view map or no AVSession, we look generic. | Keep **Location Kit + Background Tasks Kit + Core Speech Kit + Audio Kit + AVSession Kit**. All five are VERIFIED on the emulator today. List them in README with code links. |
| Originality (20%) | −4 to −8 | "Audio guides exist." | P1 pitch: on-device, locked phone, where-to-look. |
| Usefulness (20%) | −3 to −6 | A broad half-built app ("all POIs", 3 personas, widgets) reads as unfinished. | One tour, end to end, flawless. |
| Demo (10%) | −2 to −5 | No audio in the recording. Unclear what is simulated. Static Beijing location. | S3, P3. A SIMULATED badge in frame the whole time. |
| Reproducibility (10%) | −1 to −4 | The jury's fresh emulator has location switched off. The en voice is missing. Unsigned-install steps are unclear. AI_WORKFLOW is stale. | README "first launch" section: enable location (or the app prompts), en voice note, `hdc install` of the unsigned HAP. Update AI_WORKFLOW after each merge. |

### 3.6 Process

**PR1. Merge conflicts and `main` breaking.** P4 × I4.
- Hotspots: `module.json5` (permissions and backgroundModes), `string.json` × 3 locales, `main_pages.json`, `EntryAbility.ets`, `Index.ets`.
- **Mitigation:**
  - **Land one "platform skeleton" commit on `main` today, before 16:30.** It holds all permissions with reasons, `backgroundModes: ["location","audioPlayback"]`, the string resource keys for en, pl and zh, and an empty page registry. The spike's `module.json5` diff is a verified starting point.
  - After that, features add files, not lines in shared files.
  - Before any merge, rebase plus `devecocli run` → `Smoke: PASS`, plus a 2-minute manual click-through of the demo path.
  - **Code freeze for features: Sun 09:30.** After that, docs and the demo only.
- **Early warning:** two branches touching `module.json5` in the same hour, or a merge without a smoke run.

**PR5. Shared emulator per Mac.** P4 × I2.
- Every worktree builds the same bundle `com.hackyeah.citytour`. Two agents on one Mac running `devecocli run` overwrite each other's install, and with it each other's test state (this spike did exactly that).
- **Mitigation:** one emulator driver per Mac at a time (announce in chat), or a second emulator instance for the second agent.

**PR3. Transparency drift.** P3 × I2. `AI_WORKFLOW.md` is not updated after agent work. **Mitigation:** each merge to `main` includes an `AI_WORKFLOW.md` line. Do a final pass at Sun 09:00.

---

## 4. Timeline with hard decision points

> **Superseded for execution by `docs/PLAN.md` §3** (gates G1–G12, merge windows, sleep A 00:30–04:00 / B 04:00–07:30, **feature freeze Sun 03:00**, code freeze 09:30, own upload target 10:00). Where this table differs (e.g. the 15:30 default, the 09:30 "feature" freeze in §3.6, the sleep shifts in §3.4), PLAN wins. The 15:30 fallback is now English **text-only** (PLAN §0.4), not option B, because the user chose A.

| When (CEST) | Gate | If not met |
|---|---|---|
| Sat 15:30 | A human listens to the zh voice reading English; the user picks T1 option A, B or C+A | Default to **B** (Chinese voice + trilingual subtitles) |
| Sat 16:30 | Platform skeleton commit on `main` (permissions, backgroundModes, strings) | Everyone stops feature work until it lands |
| Sat 17:00 | Ask the mentors: a device? the Laura voice? which region? | Assume emulator-only; README says so |
| Sat 18:00 | Tour data pack committed (stops + texts + OSRM matrix + sources), with raw snapshots | Hand-curated stops only, plus haversine × 1.3 |
| Sat 19:00 | Vertical slice on `main`: DemoWalk → arrival → narration spoken → text shown | 20:00 checkpoint uses the manual "Next stop" trigger |
| **Sat 20:00** | **Checkpoint upload**: HAP + README + AI_WORKFLOW | Upload whatever is tagged `checkpoint-good` |
| Sat 20:30 | Test demo recording *with system audio* | Phone-mic fallback (S3) |
| Sat 22:00 | PCM queue stable plus AVSession lock-screen controls wired to the tour; geofence hysteresis tested | Default playback path (T7) |
| Sat 23:00 | Map shows route, stops and the moving dot | Static PNG + overlay (T16) |
| Sun 01:00 | "Look left/right" tested; tag `night-good` | Drop the direction phrase (T5) |
| Sun 06:00 | Real device in hand? | No device signing at all (T12) |
| Sun 07:00 | Unit tests green from the CLI; error states visible | Ship the tests that pass and list the gaps honestly |
| Sun 08:00 | Attribution screen and README sources (T14) | Static text in README |
| Sun 08:30 | Record the demo (two takes) | Use the 20:30 test recording plus a voice-over |
| Sun 09:30 | **Feature freeze** | — |
| Sun 10:30 | Submission uploaded (HAP from a tag, video, README, ARCHITECTURE, AI_WORKFLOW) | — |

---

## 5. Top 5 things that will sink us

1. **Spoken English does not work on the emulator (VERIFIED).** If we discover this during demo recording instead of now, the headline feature is silent or Chinese-only in front of an English-speaking jury. Decide at 15:30.
2. **Breadth over depth.** "All Kraków POIs × 3 languages + Canvas map + routing + personas + widgets" in 24 person-hours means no single flow that works flawlessly. The rubric literally says breadth reads as unfinished.
3. **A demo that does not prove the claim.** No walking, no audio in the video, and no visible SIMULATED label. The jury sees a list screen and hears nothing.
4. **Network-dependent data work on the critical path.** Overpass is down right now (VERIFIED), Wikipedia scraping for 3 languages, and an ArcGIS licence nobody checked. A missing data pack at 18:00 blocks everything downstream.
5. **`main` broken at 10:30 on Sunday,** from a tired late merge into `module.json5`/strings, or a signing config with secrets committed for a mentor device.

## 6. Recommended MVP cut line

**Above the line (must ship; this is the demo):**
1. One tour, the Royal Route, 11 stops (2,497 m, 33 min OSRM foot): hand-checked coordinates, Historian scripts in **EN/PL/ZH text**, with `sources[]`.
2. Held–Karp order from the start position, using the committed OSRM matrix (haversine fallback).
3. A `LocationSource` with real Location Kit (permission + `requestGlobalSwitch` + error states) **and** DemoWalk (SIMULATED badge) producing speed and course.
4. Arrival detection with hysteresis, never interrupting mid-sentence (a queue), unit-tested.
5. Narration through Core Speech Kit:
   - zh-CN voice;
   - en-US if installed, otherwise the T1 fallback, with the badge;
   - Polish shown as text.
6. A continuous task (`location` + `audioPlayback`) plus AVSession. Narration continues with the screen off, and lock-screen pause/next works (both verified today).
7. A Now Walking screen: current stop text, next stop plus distance plus arrow, a SIMULATED badge, and a debug log toggle for the demo.
8. README (capabilities with code links, simulated behaviour, first-launch steps, licences/attribution), ARCHITECTURE, AI_WORKFLOW, an unsigned HAP from a tag, and the video with audio.

**Below the line (only after the 22:00 gate is green, in this order):**
1. "Look left/right" (cheap if T5 goes well).
2. Map: Canvas, or the PNG fallback.
3. All-POI layer (map points plus Wikipedia summary; no generated narration).
4. "I have N minutes" subset.
5. Spoken turn-by-turn between stops.

**Do not start this hackathon:** a second persona (keep only the `personaId` field in the schema), Live View Kit (needs Huawei approval), Form Kit widget, spatial audio/HRTF, wearable, free-roam mode, and Polish audio of any kind.

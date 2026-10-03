# CityTour: how this wins first place

> **Author role:** the optimist. This document sets out the upside: the most a 2-person team with AI agents can credibly reach by **Sunday 11:00**.
> - Every idea below is marked **BUILD** (fits the time box), **STRETCH** (only if ahead of schedule) or **ROADMAP** (pitch it, don't build it).
> - Kit and API names were checked with `devecocli docs search` against the offline HarmonyOS docs on 2026-10-03. Anything not verified that way is marked ⚠️.
> - This doc proposes; it doesn't decide. `HACKATHON_BRIEF.md` stays binding.

---

## 0. TL;DR

The winning story is not "an audio guide". It is:

> **"Lock your phone, put it in your pocket and look at the city. The OS is your guide."**

Three things no mainstream app does, combined in one locked-screen experience:

1. **Where to look.** The app says *"the tower on your left, look up"*. It works this out from your **walking course** (GPS course over ground), not from the compass, so it works with the phone in a pocket.
2. **Time-boxed, optimal tour.** *"I have 45 minutes"* picks the best subset of stops and the best order using exact optimisation, not a fixed route.
3. **Sovereign by construction.**
   - Built entirely from **Kraków's own open data** plus OSM and Wikipedia.
   - Runs **fully offline**. No API keys, no Google, no Map Kit, no account.
   - The content format is an open "Tour Pack" that any city, museum or school can publish **without asking a platform's permission**.

Make these visible in the demo through four moments:
- **lock-screen AVSession controls**
- **airplane mode on, tour keeps going**
- **a mid-tour 中文 voice switch**
- **a live "How it works" overlay**

---

## 1. The winning narrative

### 1.1 One-sentence pitch

**CityTour turns a locked HarmonyOS phone into a private walking-tour guide.**
- It plans the best route for the time you have.
- It walks you through Kraków by voice and tells you *where to look* when you arrive.
- It runs entirely on-device, from open city data, with no cloud and no account.

**Short tagline for the slides:**
- English: *"A guide in your pocket. Eyes on the city, not the screen."*
- Chinese: 口袋里的导游 (literally "a guide in your pocket")

### 1.2 Why this beats "an audio-guide app" in the jury's head

| The jury wants | We show it as |
|---|---|
| **Spatial Experiences** (lead area): "sensing, positioning, new forms of interaction with the surrounding environment" | Location and course over ground drive *what* is said, *when* it is said, and *which direction* the listener is told to look. The interaction is your body walking, not a screen. |
| **Human-Centric** (secondary area): cultural experiences, accessibility, digital wellbeing | Eyes-up and screen-off by design. Also a credible accessibility story for blind and low-vision visitors (Microsoft Soundscape, which served them, was discontinued in 2023 ⚠️ from general knowledge). |
| **Intelligent** (light touch): contextual awareness | Dwell-vs-walk-past detection, a time-budget planner, and time-of-day moments (the Hejnał trumpet call, §2). AI is used at build time to draft scripts that a human then reviews, all cited. |
| "Innovation current platforms are missing" | **Course-relative "look" cues** plus **whole-city ambient coverage** plus **open Tour Packs**. See §4. |
| "What an open platform enables when nobody has to ask permission" | The city's own open data goes to the citizen's own device, with no gatekeeper in between. The core runs on OpenHarmony APIs. HarmonyOS-only Kits sit behind interfaces that have fallbacks (§3.3). |

### 1.3 Demo video: the first 60 seconds, shot by shot

The workshop said "the emulator is the expected default" and "say plainly what is real and what is faked". So the video runs mostly on the **Pura 90 emulator**, with an always-visible `SIMULATED WALK` badge, plus one optional real-world clip that is clearly labelled.

**Production format:**
- 1920×1080.
- Emulator on the left (about 40% of the width), live map or `hilog` panel on the right.
- Burned-in subtitles in English. The narration audio is the app's real TTS output, captured from the emulator.

| # | Time | Shot | What's on screen / audio | Rubric hit |
|---|---|---|---|---|
| 1 | 0:00–0:05 | **Cold open (optional real-world clip).** A teammate in Kraków puts in earbuds, locks the phone, pockets it and starts walking. | Caption: *"Real street, staged shot. Audio below is the app's actual output, recorded from the emulator."* If no clip is filmed, use a single still photo of the Rynek with the same caption. | Usefulness, honesty |
| 2 | 0:05–0:10 | Title card | **CityTour: a guide in your pocket.** Built at HackYeah 2026 · HarmonyOS 6.1.1 (API 24) · runs offline. | Demo clarity |
| 3 | 0:10–0:17 | Emulator: Home → **"I have 45 min"** chip | The route draws on the Canvas map. Caption overlay shows the pill: `Best 7 of 11 stops · 2.9 km · 43 min · solved exactly in 9 ms`. | Usefulness, tech |
| 4 | 0:17–0:22 | Tap **Start**, press the emulator's power button | Lock screen shows the media card: **"Stop 1/7 · Sukiennice (Cloth Hall)"** with ⏯ ⏭ controls (AVSession). | **Platform** |
| 5 | 0:22–0:35 | Split screen: lock screen on the left; on the right the **live Demo-walk map** with a moving dot labelled `SIMULATED`, plus a scrolling `hilog` filtered to `CityTour` | Voice (Laura, en-US): *"You're entering the Main Square. The long arcaded hall straight ahead, slightly to your left, is the Cloth Hall…"* The log shows `LOC course=212° speed=1.3m/s → TRIGGER arrive Sukiennice → LOOK left 34°`. | **Spatial**, platform, tech |
| 6 | 0:35–0:41 | The demo walk passes a minor plaque without stopping | Short teaser only: *"On your right, a plaque marks where Copernicus lodged. Tap 'more' later."* Caption: **"Walk past → teaser. Stop → full story."** | Intelligence, originality |
| 7 | 0:41–0:47 | Toggle **airplane mode** in the emulator's quick settings | Tour continues. Caption: **"Offline. No cloud, no API keys, no map vendor."** | **Sovereignty**, platform |
| 8 | 0:47–0:54 | Unlock, tap **中文** | The same stop continues in 聆小珊 (zh-CN). The UI switches to Chinese, and the Polish text transcript shows on swipe. Caption: *"Spoken: EN/中文. Text: EN/PL/中文."* | Human-centric, platform |
| 9 | 0:54–1:00 | Tap the **"How it works"** overlay | The HUD lists the live pipeline: `Location Kit (DEMO source) → Trigger engine → Core Speech TTS (PCM) → AudioRenderer → AVSession · Continuous task: location+audioPlayback ✓`. End card: repo URL. | Platform, transparency |

**After the first 60 seconds**, the video carries on to roughly 2:30 if the rules allow. Check the length limit ⚠️ (the challenge text only says "brief").
- Hejnał moment at St Mary's.
- Place detail with **sources** and the "AI-drafted · human-reviewed" badge.
- Home-screen widget.
- 20 seconds of honesty: "what's real / what's simulated / what we built this weekend", over a `git log --oneline | wc -l` shot and the README capability table.

**Recording tips:**
- Script the demo walk so the arrival at St Mary's happens at simulated `hh:59:50`. The demo clock is part of the Demo-walk source and labelled `SIMULATED TIME`.
- Record at 4× walk speed, but keep TTS at normal speed. The engine queues narration and never cuts a sentence, so speed-up is safe.
- Record a **"safety take" by 20:00 Saturday** with whatever works. Re-record Sunday 07:00–08:30.

### 1.4 Rubric: honest scores for a *great-execution* version

Scores assume the MVP plus the "ahead at 20:00" list in §5. This is an optimistic but plausible ceiling, not a prediction.

| Criterion (weight) | Score | Why this score | What lifts it by +1 to +2 |
|---|---|---|---|
| **Originality** (20%) | **7** | GPS audio tours exist (VoiceMap, SmartGuide). The new parts are course-relative look cues, whole-city ambient coverage, time-budget optimal subsets, and open Tour Packs. The jury may still file it under "audio guide" at first glance. | Lead the pitch with **"where to look"**, not "audio guide". Show **spatial audio** (STRETCH). Publish the **Tour Pack spec** so another city could plug in. Do the Hejnał time-aware moment. |
| **Demonstrated usefulness** (20%) | **8** | A real problem (guides are expensive, fixed-time and fixed-pace; screens pull attention away). One narrow flow works end to end with real Kraków data. | A **real-device clip** near the venue using the ambient layer (all POIs installed, so it works anywhere in Kraków). A "45 min" use case. One quote from a real tourist or teammate's friend. |
| **Technical execution** (20%) | **8** | Pure, testable core: `RoutePlanner` (Held–Karp and orienteering DP), `TriggerEngine` (state machine), `LookCue` (bearing maths), `PackValidator`. Hypium tests. Replay-driven integration test. Explicit fallbacks. | **A replay test:** feed the demo-walk fixture through the engine and assert the exact narration sequence. Show `hvigor test` output in the README. Document error paths (TTS voice missing, GPS lost, pack corrupt, permission denied). |
| **Platform capabilities** (20%) | **8** | Location Kit plus a multi-mode continuous task, Core Speech Kit TTS (PCM), AudioRenderer, AVSession (lock screen, headset, and automatic Live View), Form Kit widget, Notification, vibrator, i18n resources, accessibility attributes. Hard to run unchanged on another OS. | **OHAudioSuite space-render node** (API 23 C API) for directional voice. An "How it works" overlay that *proves* each Kit live. |
| **Demo quality** (10%) | **8** | Runs on the emulator, simulated input is clearly labelled, lock screen is shown. | Split-screen with live `hilog`. The airplane-mode moment. A real-device clip. Explicit captions for what was built this weekend. |
| **Reproducibility** (10%) | **9** | README with versions, `scripts/` that rebuild the data pack from public endpoints, granular commit history, a detailed `AI_WORKFLOW.md`. | `scripts/build-pack.sh` regenerates `rawfile/packs/krakow/` byte-identically from a pinned snapshot. A prebuilt `.hap` attached to a GitHub release. |

**Weighted totals:**
- Base: 0.2·(7+8+8+8) + 0.1·(8+9) = **7.9 / 10**.
- With the lifts landed (8/9/8/9/9/9): **8.6 / 10**. That is first-place territory if competitors are typical hackathon "broad concept" apps.

---

## 2. Wow moments, ranked by jury impact ÷ effort

**How to read this table:**
- **Effort** is wall-clock hours for one person working with Claude Code, assuming the core pipeline (pack, location source, triggers, TTS, AVSession) already exists.
- **Impact** is 1–10.
- **Emulator** says whether it can be demoed on the Pura 90 emulator.

| Rank | Wow moment | Impact | Effort | Ratio | Platform capability | Demo on emulator | Tag |
|---|---|---|---|---|---|---|---|
| 1 | **Airplane-mode proof.** Mid-tour, switch on airplane mode and nothing changes. | 8 | 0.25 h (free if offline-first) | **32** | Offline `rawfile` pack, on-device TTS | ✅ via quick-settings toggle | BUILD |
| 2 | **Hejnał moment.** Near St Mary's at :59: *"Stop here. In a few seconds the trumpeter plays from the taller tower, up to your left. Listen for the melody breaking off."* A time-aware cue, unique to Kraków and very charming. | 7 | 1 h | 7 | Same trigger pipeline plus a clock condition. The demo clock is simulated and labelled. | ✅ | BUILD |
| 3 | **Live 中文 / EN voice switch mid-tour.** For the Huawei jury this lands hard, and Chinese visitors to Kraków are a real audience. | 7 | 1.5 h (if both voices are installed) | 4.7 | Core Speech Kit `textToSpeech` (voices 聆小珊 zh-CN, Laura en-US), resource qualifiers `zh_CN` / `pl_PL` / `en_US` | ⚠️ depends on emulator voice state (`GA` vs `INSTALLED`). Test P0. | BUILD |
| 4 | **"Look up on your left."** Direction cues relative to the course over ground. | 9 | 2 h | 4.5 | `geoLocationManager` `Location.direction` (heading in degrees, 0–360) and `speed` (verified in the API ref) | ✅ via the Demo-walk source supplying course | BUILD |
| 5 | **Grounded sources view.** "Why should I trust this?" Each script shows citations (city register ID, Wikipedia revision, OSM ID) and an "AI-drafted · human-reviewed by \<name\>" badge. | 6 | 1.5 h | 4 | (content and UI) | ✅ | BUILD |
| 6 | **"How it works" live overlay (HUD).** Location source, course, speed, nearest POI and distance, trigger state, TTS state, AVSession state, continuous-task state, spatial-audio support. | 7 | 2 h | 3.5 | Makes all the Kits visible | ✅ | BUILD |
| 7 | **Lock-screen narration with AVSession controls.** ⏯, ⏭ = skip stop, ⏮ = repeat. Lock-screen and control-centre card with stop name and artwork. | 10 | 3 h (core, needed anyway) | 3.3 | AVSession Kit `avSession.createAVSession(ctx, tag, 'audio')`, `setAVMetadata`, `setAVPlaybackState`, `on('play' \| 'pause' \| 'playNext' \| 'playPrevious')`, plus a continuous task. **Bonus:** the docs FAQ says AVSession is *automatically* wired into Live View (实况窗), so we may get a status-bar capsule with no Live View Kit approval. ⚠️ Verify on the emulator. | ✅ (emulator power button) ⚠️ verify the lock-screen card renders | BUILD |
| 8 | **Accessibility pass plus haptic arrival.** A distinct vibration pattern on arrival and on "turn now", `accessibilityText` on every control, and a large-type "Now Walking" view. Pitch: an eyes-free guide also serves blind and low-vision visitors. | 6 | 2 h | 3 | `@ohos.vibrator` (preset or custom effects), ArkUI accessibility attributes (`accessibilityText`, `accessibilityGroup`), screen reader | ⚠️ the emulator has no haptics. Show the code plus a log line. | BUILD (cheap) |
| 9 | **Demo-walk replay with a live map.** A Canvas map of the Old Town; the dot moves along the replayed route at 1×/4×/8×; a `SIMULATED` badge. | 8 | 3 h (core) | 2.7 | ArkUI `Canvas`, same pipeline as Location Kit | ✅ | BUILD |
| 10 | **"I have 45 minutes."** An orienteering DP picks the best subset and order under a time budget (walk time plus dwell). | 8 | 3 h | 2.7 | (algorithm; precomputed OSRM foot matrix) | ✅ | BUILD |
| 11 | **Walk past → teaser, stop → full story.** Speed- and dwell-aware triggers; never cut mid-sentence; priority queue. | 7 | 3 h | 2.3 | Location `speed`. `@ohos.stationary` exists but is about *device* stillness ⚠️ (unclear for a pocketed phone), so use GPS speed. | ✅ | BUILD |
| 12 | **Spatial audio: headphones check (cheap version).** HUD and settings show "Spatial audio on your headphones: supported / on". | 4 | 0.5 h | 8 (but low absolute) | `AudioSpatializationManager` (API 18+): support query and state subscription | ⚠️ the emulator probably reports "not supported". Still shows the capability. | BUILD (cheap) |
| 13 | **Home-screen widget.** "Next: Wawel · 240 m · ↖" plus ⏯. | 5 | 3 h | 1.7 | Form Kit ArkTS widget, `FormExtensionAbility`, `formProvider.updateForm` (pushed while the continuous task runs; passive refresh minimum is 30 min, so push actively) | ✅ | STRETCH |
| 14 | **Time-travel photo.** A then/now slider at the stop with a public-domain historic photo from Wikimedia Commons. | 5 | 3 h | 1.7 | (mostly UI; weak platform value) | ✅ | STRETCH |
| 15 | **Second persona "Legends for kids".** Same stops, different scripts: the Wawel Dragon, Lajkonik, the trumpeter's arrow. | 6 | 4 h (mostly content plus review) | 1.5 | (data model: `persona` key on scripts) | ✅ | STRETCH |
| 16 | **Directional voice: the narration comes from the monument's side** (full spatial audio). | 9 | 6–8 h | 1.3 | **OHAudioSuite** (C API, NAPI), `EFFECT_NODE_TYPE_SPACE_RENDER` (API 23+; fixed-position mode, x/y/z in metres, range −5 to 5), offline-render mode via `OH_AudioSuiteEngine_RenderFrame`. Render each TTS PCM clip with a source position derived from the relative bearing, then play through AudioRenderer. Must call `OH_AudioSuiteEngine_IsNodeTypeSupported()`. Fallback: an ArkTS constant-power stereo pan, which is honest but not a platform feature. | ⚠️ node support on the emulator unknown, and needs headphones to appreciate | STRETCH (3 h timebox spike at 02:00) |
| 17 | **3D model at a stop** (e.g. the Barbican). | 5 | 5 h | 1 | ArkUI `Component3D` / ArkGraphics 3D with a glTF/GLB model | ✅ probably | ROADMAP unless a CC0 model is found in 15 min |
| 18 | **Ask a question by voice** ("这是什么？", "what is this?") | 5 | 4 h | 1.2 | Core Speech Kit `speechRecognizer` is **Chinese-only and offline** (verified), so it can't be a general feature | ⚠️ emulator microphone uncertain | ROADMAP |
| 19 | **On-device grounded Q&A** over the Tour Pack | 7 | 8 h+ | <1 | Data Augmentation Kit RAG (API 20). Its on-device chat model is **PC/2in1 only** (verified). | ❌ on a phone | ROADMAP |
| 20 | **Wearable wrist-tap** "turn left / you've arrived" | 7 | n/a | n/a | Wear Engine Kit **needs a Huawei developer application and approval** (verified) plus a paired real watch. Distributed features don't run on the emulator. | ❌ | ROADMAP |
| 21 | **Custom Live View** "Next: Wawel 240 m" on the lock screen and status bar | 7 | n/a | n/a | Live View Kit `liveViewManager` **needs the AGC service right "开通实况窗服务权益"** (verified). It even has geofence parameters from 6.1.0(23). | ❌ in time | ROADMAP (point to the free AVSession capsule instead) |

**Ordering rule.** Ranks 1–12 are the "great execution" set, about 25 h of focused work on top of the core. That is realistic across 2 people with agents in parallel worktrees.
- **13–16** only if ahead.
- **17–21** go in the pitch as "what the open platform enables next".

---

## 3. Getting the most out of platform capabilities, and making each one *visible*

### 3.1 Capabilities to showcase (in priority order)

All of these were verified in the offline docs on 2026-10-03.

| # | Capability | Kit / API | What it does in CityTour | OpenHarmony / Oniro portable? |
|---|---|---|---|---|
| 1 | Continuous location with the screen locked | **Location Kit** `@ohos.geoLocationManager` `on('locationChange', request)`, `Location.direction`, `Location.speed`, `directionAccuracy` (API 12+) | Feeds the trigger engine and look cues | ✅ OpenHarmony API |
| 2 | Background execution | **Background Tasks Kit** `backgroundTaskManager.startBackgroundRunning(context, ['location', 'audioPlayback'], wantAgent)`. The multi-mode overload is verified (returns `ContinuousTaskNotification`); `updateBackgroundRunning` also exists. | Keeps the guide alive while locked | ✅ |
| 3 | On-device speech | **Core Speech Kit** `textToSpeech.createEngine`, `speak` with `extraParams: { playType: 0 }`, then the `onData` PCM stream (verified FAQ) | The guide's voice, EN and 中文 | ❌ HarmonyOS-only, so it sits behind the `VoiceEngine` interface |
| 4 | Our own audio pipeline | **Audio Kit** `AudioRenderer` (PCM), audio focus/interrupt handling | Avoids the Xiaoyi (Celia) channel volume issue; enables ducking and spatial audio later | ✅ |
| 5 | System media integration | **AVSession Kit** `createAVSession(…, 'audio')`, metadata, playback state, control commands | Lock screen, control centre, headset buttons; and (per the docs FAQ) automatic Live View | ✅ (the OpenHarmony avsession module) |
| 6 | Glanceable status | **Notification Kit** (continuous-task notification); **Form Kit** widget | "Next stop" without opening the app | ✅ |
| 7 | Spatial audio awareness | **Audio Kit** `AudioSpatializationManager` (API 18+); **OHAudioSuite** space render (API 23, C) | Directional narration (STRETCH) | ⚠️ AudioSuite is likely HarmonyOS-only. Unverified for Oniro. |
| 8 | Haptics | **Sensor Service Kit** `@ohos.vibrator` | Arrival and turn cues | ✅ |
| 9 | Accessibility | ArkUI accessibility attributes; **Accessibility Kit** screen reader | Eyes-free use | ✅ |
| 10 | Rendering and i18n | ArkUI `Canvas` (our own OSM vector map), resource qualifiers `en_US` / `pl_PL` / `zh_CN` | No map vendor; three UI languages | ✅ |

**Our sovereignty claim, in one line.** "Everything except the voice is pure OpenHarmony API. The voice is a pluggable engine: Core Speech Kit on HarmonyOS, text-only on Oniro today, and an open TTS (e.g. Piper/eSpeak-NG via NAPI) on the roadmap. That same open TTS would unlock **spoken Polish**, which the HarmonyOS engine can't do."

This turns the Polish limitation into a *pro*-open-platform argument.

### 3.2 Making it visible to the jury

Jurors skim, so every capability needs **three proofs**: README row, in-app evidence, log line.

**1. README "Platform capabilities used" table.** The table already exists; fill it in. Columns:
- Capability
- Kit/API
- **Link to the exact file and line**
- Emulator ✅/⚠️/❌
- OpenHarmony-portable ✅/❌
- Screenshot or GIF link

**2. In-app "How it works" overlay** (wow #6).
- Opened by a long press on the Now Walking header, or an ⓘ button.
- Shows a vertical pipeline with live values and a green or red status dot per Kit:
  ```
  📍 Location Kit      source=DEMO (SIMULATED)  50.0617,19.9373  course 212°  1.3 m/s
  ⏱ Continuous task   modes=[location, audioPlayback]  ✓ running
  🧠 Trigger engine    nearest=Sukiennice 18 m · state=ARRIVED · queue=[teaser:Plaque#311]
  🧭 Look cue          relative bearing −34° → "on your left"
  🗣 Core Speech TTS   engine=en-US Laura (INSTALLED) · playType=0 · PCM 16 kHz
  🔊 AudioRenderer     state=RUNNING · focus=granted
  🎛 AVSession         active · metadata "Stop 1/7 Sukiennice" · cmds [play,pause,next,prev]
  🎧 Spatialization    supported=false (emulator)   ← honest
  ```
- Every row is a real value read from the service. Nothing in it is decorative.

**3. Logs.**
- `hilog` domain `0xC170`, tags `CT.Loc`, `CT.Trig`, `CT.TTS`, `CT.AVS`, `CT.BG`.
- One structured line per event, e.g. `CT.Trig arrive poi=sukiennice d=17.8m v=1.2 course=212 rel=-34 cue=LEFT`.
- The README contains a copy-paste command: `hdc hilog | grep "CT\."`.
- The video shows the log panel scrolling **while the screen is locked**. That is the strongest available proof of background execution.

**4. Tests as evidence.**
- `entry/src/test/` holds local Hypium unit tests for `RoutePlanner`, `LookCue`, `TriggerEngine` and `PackValidator`.
- `entry/src/ohosTest/` holds one instrumented smoke test.
- The README shows the command and a pasted result.

**5. "Simulated" honesty everywhere.**
- `SIMULATED WALK` and `SIMULATED TIME` badges appear in the UI, the HUD, the logs (`source=DEMO`) and the README "Mocked or simulated behavior" section.

### 3.3 Architecture slogan for the slides

```
 Tour Pack (open JSON, rawfile)      LocationSource ─┬─ GnssSource (Location Kit)
          │                                          └─ DemoWalkSource (SIMULATED, same interface)
          ▼                                                   │
 RoutePlanner (Held–Karp / orienteering) ──► TriggerEngine ◄──┘
                                                │ events (arrive / pass / turn / timeCue)
                                                ▼
                                    NarrationQueue (never cuts a sentence)
                                                │
                     VoiceEngine ─┬─ CoreSpeechVoice (HarmonyOS, PCM)
                                  └─ TextOnlyVoice (OpenHarmony/Oniro fallback, PL)
                                                │
                       AudioRenderer ─► (opt) SpaceRender ─► headphones
                                                │
                           AVSession · Notification · Form widget · HUD
```

---

## 4. Originality: how we differ from existing apps

⚠️ The competitor characterisations come from general product knowledge, not checked live today. Keep the pitch wording soft ("most apps…").

| App | What it does well | What it doesn't do (our wedge) |
|---|---|---|
| **Google Maps** | Turn-by-turn directions, POI cards | No storytelling. It isn't a guide, it doesn't optimise a time-boxed cultural walk, and it depends on the cloud and an account. |
| **VoiceMap** | Professionally narrated, GPS-triggered tours; offline | Fixed, linear, pre-recorded routes, paid per tour. No live "where to look" relative to *your* course, no time-budget re-planning, no coverage between tours. Content sits on a closed marketplace. |
| **SmartGuide** | Multilingual GPS audio guides, auto-play, offline | The closest competitor. Proprietary content platform; cities pay to be on it. Our differences: course-relative look cues, exact time-budget optimisation, open and auditable sources per script, an open pack format, and HarmonyOS system integration. |
| **GPSmyCity** | Large catalogue of self-guided walks | Mostly *reading* articles on screen, the opposite of eyes-up. Audio is a paid add-on. |
| **Microsoft Soundscape** | 3D-audio callouts for blind navigation (open-sourced after it was discontinued) | Spatial callouts but **no storytelling**. We merge Soundscape's spatial idea with a guide's narrative. |

**What is genuinely new (say it in this order):**

1. **"Where to look," computed from your walking course.** Not a compass in a pocket and not a canned script. The script stores the monument's facade and feature bearings plus an elevation hint ("up" for towers); the app turns that into left/right/ahead/behind and up for *your* approach direction. Two people arriving from different streets hear different directions.
2. **The whole city is installed.** All 395 city monuments, 923 historic plaques and the heritage register are in the offline pack, so *every* street has an ambient layer of short teasers between curated stops. Curated tours don't cover this long tail.
3. **Exact, time-boxed planning.** "I have 45 minutes" is solved optimally (an orienteering DP over at most 15 stops), not by a heuristic or a fixed route.
4. **Sovereign by construction (the framing for this jury):**
   - **Content:** comes from the city of Kraków's own open ArcGIS services, OSM and Wikipedia. Each script cites its source; AI-drafted text is human-reviewed and labelled.
   - **Distribution:** an open **Tour Pack** format (JSON plus a schema). A municipality, museum, school or local historian can publish a tour **without asking Google, Apple, Huawei or a content marketplace for permission.** The app is a *player*, the same way a podcast app plays RSS.
   - **Runtime:** no API keys in the repo, no cloud calls at runtime, no Map Kit, no account. The core is pure OpenHarmony API and so runs on **Oniro**. HarmonyOS-only Kits sit behind interfaces with fallbacks.
   - **Pitch line:** *"Kraków publishes the data. Your phone tells the story. Nobody in between."*

---

## 5. Stretch roadmap: what to add, in what order

**Assumed baseline at the 20:00 checkpoint (needed to be in the game):**
- Tour Pack loaded.
- Demo-walk source.
- Trigger engine.
- TTS in EN through AudioRenderer.
- Continuous task.
- AVSession lock-screen controls.
- Canvas map with route.
- Held–Karp order.
- README and AI_WORKFLOW kept current.
- A safety demo take recorded.

### If ahead at 20:00

Two people working in parallel worktrees. Order matters.

1. **Look cues** (wow #4), about 2 h. The single most differentiating feature, so it comes first.
2. **Airplane-mode check plus offline audit**, about 0.5 h. Make sure there is no network call at runtime; grep for `http`.
3. **中文 voice switch** (wow #3), about 1.5 h, plus a `zh_CN` UI pass. **Test the TTS voice state on the emulator first**, before anything else this evening.
4. **"45 minutes" planner** (wow #10), about 3 h, with unit tests.
5. **Teaser vs full story** (wow #11), about 3 h, plus the ambient layer from the whole-city pack.
6. **HUD overlay** (wow #6), about 2 h.
7. **Sources view** (wow #5), about 1.5 h.
8. **Hejnał moment** (wow #2), about 1 h.

### If ahead at 02:00

The night shift (one person sleeps 02:00–06:00, the other 06:00–09:00 ⚠️ the team decides).

1. **Replay integration test plus `hvigor test` evidence**, about 1.5 h. Technical-execution points are cheaper here than any new feature.
2. **Accessibility plus haptics pass** (wow #8), about 2 h.
3. **Spatial audio spike** (wow #16), **hard 3 h timebox.**
   - Step 1: `IsNodeTypeSupported(EFFECT_NODE_TYPE_SPACE_RENDER)` on the emulator.
   - If it isn't supported, ship the ArkTS stereo-pan fallback and *say so*.
   - Either way, the code path and HUD row stay.
4. **Form widget** (wow #13), about 3 h.
5. **Second persona "Legends for kids"**, about 4 h (see below).

### Sunday 06:00–11:00 (frozen feature set)

- 06:00–07:30: bug fixes only; README and ARCHITECTURE final; screenshots.
- 07:30–09:00: **record the demo** (emulator), edit it, upload.
- 09:00–10:30: tag a release, attach the `.hap`, hand off to the human for merging, do a clean-clone build test.
- **10:30: stop.**

### Second persona idea: **"Legends for kids" (Smok & Co.)**

**Why this one:** Kraków is unusually rich in legends tied to *exact* spots, which makes them perfect for location triggers:
- The Wawel Dragon (Smok Wawelski) at the Dragon's Den.
- The Hejnał trumpeter shot by a Tatar arrow (St Mary's).
- Lajkonik.
- Pan Twardowski.
- The two brothers and the uneven towers of St Mary's.
- The knife hanging in the Cloth Hall.

**What it proves technically:** the data model (`scripts[poiId][persona][lang]`) plus a persona switch in settings. Same stops, same engine, new voice and tone. Optionally the male voice 凌飞哲 for a different character.

**Human-centric angle:** a family walk where kids look *up* at towers instead of down at a screen.

**Alternative persona** if kids feel off-theme: **"Describer"**, for blind and low-vision visitors. It describes visual details (colours, shapes, heights, textures) instead of dates. It is the strongest accessibility story, but writing the content takes more care.

### Roadmap to pitch (not building)

- An open TTS engine via NAPI, for **spoken Polish** and **Oniro** voice.
- A wearable wrist-tap via Wear Engine (needs approval).
- Custom Live View (needs an AGC right).
- On-device RAG Q&A on 2in1 or tablet (Data Augmentation Kit).
- Distributed handoff: the tour continues from phone to watch or car.
- Free-roam mode on the same engine.
- A Tour Pack authoring tool for cities.
- More cities: any city with open heritage data.

---

## 6. Pitch and demo assets, and the README story

### 6.1 Asset list (owner and deadline in brackets ⚠️ the team assigns)

| Asset | Spec | When |
|---|---|---|
| **Safety demo take** | 30–60 s screen recording of whatever works | Sat 20:00 |
| **Final demo video** | 60–150 s, 1080p, subtitles, `SIMULATED` captions, storyboard from §1.3, uploaded (YouTube unlisted plus linked in README) | Sun 09:00 |
| **Optional real-world clip** | 5–10 s, phone pocketed, earbuds; labelled "staged". If a mentor device is available: a real-device run of the **ambient layer near the venue** (the whole city is installed). ⚠️ Real-device install needs signing with a Huawei ID; try it Saturday evening, not Sunday. | Sun 07:00 |
| **Screenshots** (PNG, emulator, also in `docs/img/`) | 1 Home with the "45 min" chip · 2 tour plan with Canvas route · 3 Now Walking with the look arrow · 4 **lock screen with AVSession card** · 5 HUD overlay · 6 place detail with sources · 7 中文 UI · 8 settings with the Demo walk SIMULATED toggle · 9 widget (if built) | Sun 07:30 |
| **GIFs** for README | Look cue changing as the dot turns a corner; airplane-mode toggle | Sun 07:30 |
| **Slides** (5–6, only if a live pitch happens ⚠️ confirm the format) | 1 Problem (guide = €€, fixed time; screens = eyes down) · 2 Demo (video) · 3 How it works (pipeline diagram §3.3) · 4 Platform capabilities table · 5 Sovereignty: open data → open pack → open OS · 6 Real vs simulated, plus roadmap | Sun 09:30 |
| **Architecture diagram** | §3.3, in `docs/ARCHITECTURE.md` (as SVG or Mermaid) | Sat 20:00 draft |
| **Release** | GitHub release `v1.0-hackyeah` with the signed or unsigned `.hap` (no keys!) plus SHA-256 | Sun 10:00 |

### 6.2 README story (top-down order; the first screen decides the impression)

1. **Hero line:** *"CityTour: a guide in your pocket. Lock your phone, walk Kraków, and hear what you're looking at."* Then a GIF of the lock screen with narration subtitles.
2. **The 20-second explainer:**
   - Who: visitors without a hired guide.
   - Problem: guides are expensive, fixed-time and fixed-pace; screens steal your eyes.
   - What it does: an optimal route for your time; a voice that says where to look; works locked and offline.
3. **Challenge area:**
   - **Lead: Spatial Experiences.** Positioning plus course drive narration and direction.
   - **Secondary: Human-Centric** (cultural heritage, eyes-free, accessible).
4. **Demo video link** plus a "What's real vs simulated" box, right at the top:
   - Real: TTS, AVSession, background, routing, data.
   - Simulated: the location replay and the clock during the demo walk.
5. **Platform capabilities used.** The table from §3.2, each row linked to code.
6. **Why open matters (sovereignty).** Open data sources with licences; no runtime cloud; no API keys; OpenHarmony-portable core; HarmonyOS-only parts and their fallbacks; the Tour Pack spec link.
7. **Build, install, launch.** Already drafted; keep it.
8. **Architecture**, linking to `docs/ARCHITECTURE.md`.
9. **Testing**: the commands and the latest results.
10. **Data pipeline**: `scripts/build-pack.*` with sources and licences (city ArcGIS, OSM ODbL, Wikipedia CC BY-SA), plus the human-review process for scripts.
11. **AI usage**, linking to `AI_WORKFLOW.md`: build-time script drafting (model, prompts, review), plus coding agents.
12. **Known limitations**, stated honestly:
    - Polish is text-only.
    - Spatial audio depends on the device.
    - Emulator location injection doesn't work, hence the Demo walk.
    - Live View and Wear Engine need approvals.
13. **What we built at HackYeah.** A link to the commit range plus a timeline (from the git log).

---

## 7. Risks to the upside (optimist's honesty box)

| Risk | Effect on the upside | Cheap mitigation |
|---|---|---|
| TTS voices not `INSTALLED` on the emulator, or the engine fails to initialise | Kills wows 3 and 7 on the emulator | **Test in the first hour.** Fallbacks: the download API (phone profile); a mentor device; pre-synthesise PCM on a real device and ship it as a declared asset (last resort, clearly labelled). |
| AVSession lock-screen card doesn't render on the emulator | Weakens the hero shot | Show the control centre instead, plus headset-key logs, plus the HUD. Verify early. |
| Background continuous task killed on the emulator when locked | Weakens the core claim | `hilog` proof; real-device clip if possible. |
| Too many wows, nothing polished | The workshop warned "breadth reads as unfinished" | Strict order in §5. The **look cue and lock screen are the one capability end to end**; everything else decorates it. |
| Competitor perception ("just VoiceMap") | Originality score drops to about 5 | Open the pitch with *"where to look"* and *"nobody has to ask permission"*, never with "audio guide". |

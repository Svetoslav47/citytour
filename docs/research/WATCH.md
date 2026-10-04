# CityTour on a Huawei watch: research and plan

Status (2026-10-04): W0-W7 done on branch `cap/wearable`, on top of `feat/common-har` (lands first). Verified on the Watch 5 emulator (HarmonyOS 6.1.1(24), English): full Demo walk 11/11 with all four cues logged and flashed, real-GPS permission/switch/out-of-area path, phone smoke unaffected. Not verified: real vibration, a real watch. Next slices: §3 rows 3-8.

Research was done by Claude Code (Opus 5.5) with three research subagents. They read the installed SDK's device definitions, the official docs through `devecocli docs`, and public web sources. Anything not confirmed is marked **UNVERIFIED**.

## 1. Decisions (user, 2026-10-03)

| Question | Decision |
| --- | --- |
| What the watch version is | A **standalone watch tour**: the watch runs the tour itself (GPS, engine, haptics). Companion mode (the phone drives the watch) stays on the roadmap. |
| Project structure | A **separate watch HAP plus a shared HAR**, following Huawei's multi-device guidance. `core/` and `contracts/` move into a `common` HAR, and a new `wearable` entry module is added. |
| First slice | The **next-stop glance screen with the arrow**, and the **haptic cue language**. |
| Where the watch gets its tour | A **small bundled watch pack**: the Royal Route tour and its stops only, no audio clips, in the watch HAP's rawfile. It works offline from the first launch. |
| Glance layout | **Progress ring**. The outer arc fills as stops are visited, the arrow and distance sit in the centre, and the stop name is at the bottom. A SIMULATED pill shows during the Demo walk. |
| Haptic cues | The 4 patterns in §5. |
| Timing | Start now, on branches. `main` is untouched until the user merges. |

## 2. Platform facts that shape the design

| Topic | Finding | Source |
| --- | --- | --- |
| Which watches can run it | Only **full "Wearable"** watches run ArkTS/Stage apps: WATCH 5 (from 5.1.0(18)), WATCH Ultimate / Ultimate 2, Kids X1 / X1 Pro. **WATCH GT 5/6/7 and FIT 4/5 are Lite Wearables** (JS only) and can't run this app, even though they are marketed as "HarmonyOS 6". | docs `support-device`, `faqs-arkui-1520` |
| Emulator | Images for **HarmonyOS 6.0.0(20) to 6.1.1(24)**, device type `wearable`. It simulates GPS (`emulator geolocation`, with direction), heart rate and steps (`emulator sensor`), and the crown (GUI, mouse wheel). It has **no compass or magnetometer** and no Bluetooth. Its vibrator support is UNVERIFIED (the phone emulator has no motor and returns `14600101`). | `devecocli emulator image list --all`, docs `ide-emulator-more-features` |
| Location Kit | Available on watches (`Location.Location.Core/Gnss/Geocoder`). **The wearable is the only device type supported outside mainland China** (FAQ `faqs-location-27`), which suits a Kraków tour. **There is no Geofence SysCap**; we match distances ourselves anyway. Watch policy allows background GPS only for navigation and fitness. | SDK `device-define/wearable*.json`, docs `location-kit-intro`, `bpta-smartwatch` |
| Text-to-speech | **Not on the watch.** `AI.TextToSpeech` is absent; Core Speech Kit lists Phone, Tablet and PC only. Audio on the watch would have to be the pre-rendered clips through AVPlayer, which is a later slice. | SDK device-define, docs `core-speech-introduction` |
| Haptics | `Sensors.MiscDevice` is present. Preset effects depend on the device, so check `vibrator.isSupportEffect` first and fall back to timed vibrations. | docs `js-apis-vibrator` |
| Sensors | ORIENTATION and ROTATION_VECTOR exist as SysCaps, but the hardware is UNVERIFIED, so check `sensor.getSensorList`. HEART_RATE needs `READ_HEALTH_DATA` and PEDOMETER needs `ACTIVITY_MOTION` (both user_grant). | SDK `PermissionDefinitions.json` |
| Other Kits | AVPlayer, Notification (no `setBadgeNumber`), Form Kit (the 2×3 and 3×3 sizes are watch-only), continuous task (location, audioPlayback), HTTP and AVSession (local only) are all present. **Live View is absent.** | SDK device-define, docs |
| Round UI | `ArcList`, `ArcButton`, `ArcSwiper`, `ArcScrollBar`, `ArcAlphabetIndexer`, `ArcSlider` (all API 18), and `onDigitalCrown` (API 18, wearable only). WATCH 5 is **466×466 px = 233×233 vp**, round, with no rotation and a dark theme recommended. The crown must never be the only way to do something. | SDK `@ohos.arkui.Arc*.d.ts`, docs `arkts-common-events-crown-event`, `bpta-smartwatch` |
| Project layout | One HAP *may* list `["phone","wearable"]`, but Huawei recommends a **separate HAP for wearable** with shared HARs. One `.app` holds both HAPs, split by `deviceTypes`. | docs `bpta-multi-device-ide`, `syscap` |
| Phone ↔ watch link | **Wear Engine** (P2P messages, `notify()` to the watch) is Huawei's own best practice for phone-to-watch navigation (`bpta-smartwatchnavigation`). It needs an AGC application with **1–2 weeks of approval**, its phone side is **mainland China only**, and it does **not run on the emulator**. Distributed data objects, app continuation and `abilityConnectionManager` don't run on the emulator either, and their watch support is UNVERIFIED. | docs `we-business_introduction`, `wearengine_apply`, `abilityconnectmanager-guidelines` |
| Zero-code paths on real devices | Phone notifications forwarded by the Huawei Health app, and the watch's "control phone music" card driving our AVSession. Both are **UNVERIFIED** for our app and need a real Watch 5. | Huawei consumer support pages |

## 3. What makes a watch tour useful (product research)

- **Wrist for haptics and glances, ears for stories.** Apple Watch Maps uses distinct left and right tap patterns. Petal Maps on the watch vibrates for turns "so that you do not have to frequently look down". Citymapper's watch app is one well-timed tap. Sources: [Apple](https://support.apple.com/guide/watch/get-directions-apdea7480950/watchos), [Huawei](https://consumer.huawei.com/uk/support/content/en-gb15830017/), [Citymapper](https://citymapper.com/news/1645/citymapper-on-apple-watch).
- **Interactions under about 5 seconds.** Microinteractions take under 4 s ([Ashbrook](https://www.researchgate.net/publication/44226517_Enabling_mobile_microinteractions)). Frequent phone glances while navigating led to more stops and route errors ([PMC 2025](https://pmc.ncbi.nlm.nih.gov/articles/PMC12594009/)).
- **Haptics are easy on attention and help older and low-vision walkers.** Wrist cues beat AR glasses on perceptibility and awareness of surroundings for older pedestrians ([MTI 2019](https://doi.org/10.3390/mti3010017)). A 2025 scoping review found haptic cues carry less cognitive load than visual or audio ones ([HFES 2025](https://journals.sagepub.com/doi/10.1177/10711813251360706)).
- **Open niche.** We found no watch app from VoiceMap, GPSmyCity, Rick Steves Audio Europe or Smartify.
- **Anti-patterns to avoid:**
  - a map as the main watch screen (Komoot review: unclear cues, render lag)
  - story text to read on the wrist
  - more than about 4 haptic patterns, or buzzing for every event
  - acting on heart rate automatically, or making medical claims
  - running GPS on both devices
  - losing state when the watch sleeps
  - asking for health permissions at install

Ranked feature list from the research, with the slice each one falls in:

| # | Feature | Slice |
| --- | --- | --- |
| 1 | Haptic cue language (arrival, look left, look right, off-route) | **MVP** |
| 2 | Next-stop glance: progress ring, arrow, distance, n/N, name | **MVP** |
| 3 | Studio-voice stop stories on the watch (AVPlayer, existing clips, EN/PL/ZH) + pause/repeat/skip | next |
| 4 | Watch-face card 2×3 "next stop" (reuses `CardModel`) | next |
| 5 | Steps and heart rate in the tour summary (labelled simulated when injected on the emulator) | next |
| 6 | "I'm tired": one tap re-plans to the time left or ends at the nearest stop (suggested, never automatic) | later |
| 7 | Take me back to the start | later |
| 8 | Haptic-only accessibility mode | later |
| 9 | Wear Engine companion (the phone narrates, the wrist buzzes) | roadmap: needs approval and real devices |

## 4. Architecture of the watch slice

```
common (HAR)          contracts/ + core/ (pure; moved from entry, unchanged)
entry (HAP, phone)    unchanged behaviour; imports core/contracts from 'common'
wearable (HAP, watch) WatchAbility + glance page + watch services:
                        location: Location Kit source | Demo walk source (SIMULATED)
                        haptics:  vibrator, cue patterns from a pure CueMap in common
                        speech:   none (no TTS on the watch); story lines are logged, not spoken
                      rawfile/watch/: bundled Royal Route watch pack + demo walk track
```

- The arrow shows the bearing to the next stop minus the current heading. The heading comes from the GPS course, as on the phone. A real watch may later use ROTATION_VECTOR after a `getSensorList` check. The emulator has no compass, so the Demo walk supplies the course.
- Logging uses the app's existing hilog domain with a `Watch` prefix on events (`WATCH_LOC`, `WATCH_CUE`, `WATCH_STOP`), so a logs view can back up the demo.
- Failure states to handle: permission denied, location off or no fix, malformed watch pack, vibrator unsupported (logged, and the cue is shown on screen), tour complete.

## 5. Haptic cue language (approved)

| Cue | Pattern | When |
| --- | --- | --- |
| Arrival | one long buzz, 600 ms | entering a stop's trigger radius |
| Look left | 2 short pulses, 80 ms each | look cue says the monument is on the left |
| Look right | 3 short pulses, 80 ms each | look cue says the monument is on the right |
| Off-route | 2 long buzzes, 300 ms each | the existing off-route detection fires |

Cues are rate-limited so they never stack. Each cue is also logged and flashed on screen, because the emulator may have no motor.

## 6. Task plan

| ID | Branch | Task | Done when (status 2026-10-04: all done) |
| --- | --- | --- | --- |
| W0 | – | Download the wearable image (started 2026-10-03), create a watch emulator, boot it | `devecocli emulator list` shows a running `wearable` instance |
| W1 | `feat/common-har` | Move `contracts/` + `core/` into a `common` HAR; entry imports from `'common'`; update `scripts/test.sh` guards and paths; README/ARCHITECTURE note | Build, `scripts/test.sh` and the Pura 90 smoke run all pass. **Person A gets a heads-up before merge** (every import path changes); merged first. |
| W2 | `cap/wearable` | `wearable` entry module skeleton (deviceTypes `wearable`, min API 20, dark theme), second HAP in the same app | The watch HAP builds and launches on the watch emulator; a hilog line is visible |
| W3 | `cap/wearable` | Watch pack: script emits a small Royal Route pack into the watch rawfile; parsed by the common `PackParser`; test | Unit test parses it; no clips bundled |
| W4 | `cap/wearable` | Watch tour loop: Location Kit source (permission at point of use, location continuous task) + Demo walk source (SIMULATED) driving the common `TourEngine`; speech effects become no-ops plus log lines | Demo walk on the watch emulator reaches stops; `WATCH_STOP` logs |
| W5 | `cap/wearable` | Glance screen (progress ring) with all states: no fix, permission denied, SIMULATED, tour complete | User confirms on the watch emulator; screenshot in docs |
| W6 | `cap/wearable` | Haptic cue language: pure `CueMap` + rate limit (tests) + vibrator service | Tests pass; `WATCH_CUE` logs on the emulator (motor absence logged, no crash) |
| W7 | `cap/wearable` | README (watch section, capability rows, build/run on the watch, simulated behaviour), AI_WORKFLOW | Reproducible from a clean checkout |

Risks to check early:
- how `devecocli build/run` handles two entry modules (W2)
- whether `TourEngine` waits for speech-end events, which the watch must then emit itself (W4)
- emulator vibrator support (W6)
- disk space (about 28 GB free before the image download)

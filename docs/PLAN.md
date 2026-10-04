# CityTour: execution plan (Sat 3 Oct 14:45 → Sun 4 Oct 11:00 CEST)

> **Status:** written Sat 2026-10-03 at about 14:50 CEST by the planning agent. The humans own every product decision. This plan schedules the work that `HACKATHON_BRIEF.md` (binding), `docs/ARCHITECTURE.md` (the how), `docs/DESIGN.md` (UX), `docs/RISKS.md` (spike results, gates, cut line) and `docs/OPPORTUNITIES.md` (upside) already describe.
>
> **Companion file:** `docs/tasks.json` holds one object per task card below (`body_markdown` = the full card), ready to become GitHub issues (§7).
>
> **Hard dates:** checkpoint upload **Sat 20:00**. Code freeze and final submission **Sun 11:00**. **Our own upload target is Sun 10:00.**

**Contents**
- §0 [Ground rules](#0-ground-rules-read-once): binding decisions, verified commands, agent rules, the voice-strategy port
- §1 [Roles, ownership and the T0 contracts](#1-roles-ownership-and-the-shared-contracts)
- §2 [Task cards](#2-task-cards): an index, then every card with DoD and a starter prompt
- §3 [Timeline](#3-timeline-sat-1445--sun-1100): per person, with gates, merge windows, sleep and the recording window
- §4 [Merge order and conflict avoidance](#4-merge-order-and-conflict-avoidance)
- §5 [Cut list and stretch list](#5-cut-list-if-behind-and-stretch-list-if-ahead)
- §6 [First 30 minutes](#6-first-30-minutes-checklists)
- §7 [Turning tasks.json into GitHub issues](#7-turning-tasksjson-into-github-issues)
- §8 [Assumptions and open questions](#8-assumptions-and-open-questions)

---

## 0. Ground rules (read once)

### 0.1 Binding decisions this plan builds on

| Topic | Decision | Source |
|---|---|---|
| Lead theme | Spatial Experiences. Human-Centric is secondary. | HACKATHON_BRIEF |
| Scope | One curated Royal Route tour (11 stops, Barbican → Wawel; OSRM foot 2,497 m / 33 min walking). All Kraków POIs in the offline pack. | HACKATHON_BRIEF, lead's `map-meta.json` |
| **English voice** | **User decision, 2026-10-03:** the **zh-CN voice (聆小珊, person 13) reads the English text**, labelled **"Fallback voice"** in the UI. The en-US Laura (person 8) `listVoices` → `downloadVoice` path **stays in code**, so a real device that has Laura uses it automatically. **Gate G1 (15:30):** a human listens first. If it is unacceptable, the default becomes **English text-only** (a one-line config change, §0.4). | Coordinator message; RISKS §1 a4–a6 |
| Polish | UI and narration text in Polish. No Polish audio. | HACKATHON_BRIEF |
| Map | No Huawei Map Kit. A native ArkUI Canvas map from OSM data, with a pre-rendered PNG base as the fallback. | HACKATHON_BRIEF, ARCHITECTURE §3 |
| Emulator location | A fixed fake point in Beijing (lat 40, lng 116). The **Demo walk** source is mandatory for the demo and labelled **SIMULATED**. | RISKS §1 b4–b6 |
| Background | One continuous task `['location','audioPlayback']` plus AVSession. **Verified** on the emulator, including with the screen locked. | RISKS §1 c1–c5, d1 |
| Data services (14:04) | **Overpass is DOWN.** The OSM main API works when the bbox is split into ~9 tiles (the lead already fetched the Old Town tiles). Wikidata SPARQL, Wikipedia REST, OSRM foot and Kraków ArcGIS are UP. **We fetch once, commit the raw snapshots, and the build never touches the network.** | RISKS §1 x1, lead |
| Tests | `hvigorw test` always exits 0, so `scripts/test.sh` parses the result file (task T1). | ARCHITECTURE §11.1 |

### 0.2 Commands verified on this Mac (Sat 14:50, `devecocli` 1.3.4, emulator "Pura 90" running as `127.0.0.1:5555`)

| Purpose | Command | Notes |
|---|---|---|
| Static check | `devecocli check arkts` | Run before every build; it catches the ArkTS strict-mode errors. Also available: `devecocli check lint`, `devecocli check compat`. |
| Build | `devecocli build` | `--build-mode debug` is the default. Output: `entry/build/default/outputs/default/entry-default-unsigned.hap`. |
| Install + launch | `devecocli run --device "Pura 90"` | Ends with `Smoke: PASS`. `--uninstall` gives a fresh install (first-run flows). `--skip-build` redeploys. |
| Unit tests | `scripts/test.sh` (task T1) | Wraps `hvigorw test` and **fails for real**. |
| Logs | `devecocli log --device "Pura 90" --bundle-name com.hackyeah.citytour --keyword CityTour --tail 300` | Also `--follow`, `--crash`, `--level E`, `--tail N`. |
| Tap by id | `devecocli ui click --device "Pura 90" --id btnDemoWalk` | Needs `.id('btnDemoWalk')` on the component. |
| Screenshot | `devecocli ui screenshot --device "Pura 90" --path docs/img/x.png` | **`--path` is required** (ARCHITECTURE §11.2 omits it). |
| Docs | `devecocli docs search <kw>` / `devecocli docs read <id>` | Offline official docs, mostly in Chinese. |
| hdc | `HDC=/Applications/DevEco-Studio.app/Contents/sdk/default/openharmony/toolchains/hdc` | `hdc` is **not on PATH**. T1's `scripts/env.sh` exports `$HDC`. |
| Screen off / on | `$HDC -t 127.0.0.1:5555 shell power-shell suspend` / `wakeup` | `devecocli emulator power` and `geolocation` **do not work** (they need Emulator 7.0). |
| Open the dev page | `$HDC -t 127.0.0.1:5555 shell aa start -a EntryAbility -b com.hackyeah.citytour --ps page dev` | The `--ps <key> <value>` option was verified in `aa start -h`. EntryAbility routes it (T0). |
| Second emulator | `devecocli emulator start sdk24` | A second phone image (6.1.1(24)) exists, stopped. Use it if two agents on one Mac need a device at the same time; it is memory-heavy. |
| Signing (only for a device) | `devecocli signature generate [--team-id]` | It writes signingConfigs into `build-profile.json5`, which must **never be committed** (T1 hook, S4). |
| Pipeline | `node --test scripts/pack/` | Node v24 is installed. `jq` and `gh` 2.101 are available. `ffprobe` is not. |

### 0.3 Agent rules (every starter prompt points here)

1. **One branch, one worktree, one agent session.** Create it with `scripts/wt.sh new <type>/<slug>`, which puts it in `../citytour-wt/<slug>`. Agents edit **only the files listed in their card** (§1.2 ownership). `contracts/` changes only through a tiny `feat/contracts-<x>` branch that A writes and B reviews.
2. **Two lanes per person.**
   - **Emulator lane:** platform and UI work, the only lane that runs `devecocli run`.
   - **Headless lane:** pure `core/` logic, the Node pipeline, tests and docs. It never touches the emulator.

   This avoids two agents overwriting the same bundle on one emulator (RISKS PR5).
3. **Before using any Kit API:**
   - check it with `devecocli docs search` and put the doc id in the commit message;
   - anything with `起始版本 > 20` needs a `canIUse` or SDK-version guard;
   - `devecocli check arkts` must be clean before each build.
4. **Pure core.** `core/` has no `@kit.*` imports, and the code uses State Management V2 only. `scripts/test.sh` enforces both.
5. **Logging.** Log through `app/Log.ets` only: domain `0xC17A`, tag `CityTour`, format `EVENT k=v`, with the event names from ARCHITECTURE §10.
6. **Honesty labels.**
   - **SIMULATED** on every surface where the Demo walk is active, and `src=demo` in the logs.
   - **"Fallback voice"** wherever English is spoken by the zh-CN voice.
   - **"machine-translated"** on zh/pl stop scripts.
7. **Commit discipline.** Commit after each small working step and push every 2–3 commits. Each task adds an `AI_WORKFLOW.md` row; `.gitattributes` sets `merge=union` so parallel rows never conflict.
8. **Agents never merge to `main`.** An agent finishes by rebasing on `origin/main`, running the card's Verify block and opening a PR (`gh pr create`) that lists what was verified and what was not. A human merges (§4).

### 0.4 Voice strategy: one port, four config switches

This implements the user decision and keeps the alternatives one switch away.

```ts
// contracts/Settings.ets (T0)
export enum EnVoiceStrategy {
  AUTO_NATIVE_THEN_ZH = 'auto-native-then-zh',     // DEFAULT (user decision): Laura if INSTALLED, else zh-CN voice reads English, labelled "Fallback voice"
  AUTO_NATIVE_THEN_TEXT = 'auto-native-then-text', // used if G1 rejects the zh voice: Laura if INSTALLED, else English text-only
  FORCE_ZH = 'force-zh',                           // demo/testing: always the zh-CN voice for English
  TEXT_ONLY = 'text-only' }                        // user choice: never speak
export enum VoiceLabel { NATIVE = 'native', FALLBACK_ZH_READS_EN = 'fallback-zh', TEXT_ONLY_PLATFORM = 'text-only-platform', TEXT_ONLY_USER = 'text-only-user' }
// contracts/Ports.ets (T0)
export interface VoicePlan { textLang: Lang; speechMode: string /* 'voice' | 'text' */; engineLocale: string; person: number;
  languageContext: string; label: VoiceLabel; reason: string; }
export interface VoicePort { capabilities(): Promise<SpeechCapabilities>; plan(textLang: Lang): VoicePlan;
  downloadEnglish(onProgress: (pct: number) => void): Promise<boolean>; setStrategy(s: EnVoiceStrategy): void; }
```

- **Default.** `app/AppConfig.ets` holds `DEFAULT_EN_VOICE_STRATEGY = AUTO_NATIVE_THEN_ZH`. The user can override it in Settings (B9), and the choice persists.
- **Pure resolution.** `core/speech/VoicePolicy.ets` (A4) holds `resolveVoicePlan(textLang, strategy, caps)`. It is unit-tested for 4 strategies × 4 en voice states × 3 languages and logged as `VOICE_PLAN … label=… reason=…`.
- **Where the label shows.**
  - `EngineSnapshot.voiceLabel` drives the "Fallback voice" chip on Now Walking (B5) and the Voice row in Settings (B9).
  - It is added to the AVSession artist line (A6).
  - It goes into the README "Mocked or simulated behavior" section (S1).
- **"A real en voice on a device"** needs no code change: `listVoices` reports en-US/8 `INSTALLED`, so the plan resolves to `NATIVE`. The download path (`downloadVoice`; `1002300010` = already installed, `1002300008` = failed) stays reachable from Settings and Onboarding. On the emulator it fails gracefully and the plan stays `FALLBACK_ZH_READS_EN`.
- **Emergency audio switch.** `AppConfig.USE_SYSTEM_PLAYBACK` switches to `playType 1` (RISKS T7) if the PCM path is not stable by gate G7.

---

## 1. Roles, ownership and the shared contracts

### 1.1 The split (ARCHITECTURE §12 with four justified adjustments)

| | **Person A: Engine & Platform** | **Person B: Data, Map & UI** |
|---|---|---|
| Builds | Contracts, `core/` geo/route/tour/speech/sim, the location sources and the **Demo walk** (with its track generator), TTS + PCM `AudioRenderer` + sentence queue, the continuous task, AVSession, notifications and haptics, `TourController`, the error matrix, the test harness, smoke and replay tests, onboarding (P1), the release HAP and signing hygiene | The data pipeline and raw snapshots, the city pack, the pack loader and validator, all pages and viewmodels except onboarding, the Canvas map, Historian scripts and the human review, i18n en/pl/zh, Settings, Place detail and licences |
| Docs | README: capabilities, simulated behaviour, testing, error handling, first launch | README: data sources and licences, languages, screenshots, limitations; `data/ATTRIBUTION.md` |
| Demo / submission | Drives the emulator and log pane when recording; owns the recording Mac (OBS); drafts the description and slides at 04:30 | Runs the camera/edit pass; finalises and uploads the HackTribe package |

**Adjustments versus ARCHITECTURE §12.3, and why:**
1. **The Demo walk track generator** (`scripts/demo/make-demo-walk.mjs`) and `rawfile/demo/royal-route-walk.json` move to **A**. The track encodes trigger semantics (dwell holds, the pass-by stop, the detour, the accuracy dip), and the Demo walk is on A's critical path to the 19:00 vertical slice. It can bootstrap from the lead's committed OSRM route before B's pack exists.
2. **`pages/DevPanel.ets`** belongs to A. It is a developer-only page, opened with `aa start --ps page dev`, so A can verify TTS, location and background work on the emulator before B's UI exists.
3. **`OnboardingPage` + `OnboardingViewModel`** move to **A** (P1). They are mostly permission and voice-status logic, and B carries the heaviest P0 load.
4. **`core/map/Camera.ets`** (pure camera maths for the map) is **B**-owned, so the map has tested logic without touching A's `core/geo`.

### 1.2 Directory and file ownership (no overlap)

| Path (under `entry/src/main/` unless noted) | Owner | Rule |
|---|---|---|
| `ets/contracts/**` | **A writes, B reviews** | Lands first (T0). Changes only via tiny `feat/contracts-*` PRs, merged before dependents. |
| `ets/app/**`, `ets/entryability/**` | A | B reads `AppContainer` getters only. |
| `ets/core/geo/**`, `core/route/**`, `core/tour/**`, `core/speech/**`, `core/sim/**`, `core/content/Phrases.ets` | A | Pure; tests in `entry/src/test/<Suite>.test.ets`. |
| `ets/core/content/{PackParser,NarrationValidator,LangDetect,NarrationSelector}.ets`, `ets/core/map/**` | B | Pure; B's suites. |
| `ets/services/{tour,location,speech,audio,media,background,notify,haptics}/**` | A | |
| `ets/services/pack/**` (incl. `PackFactory`, `StubPackRepository`) | B (after T0 creates the stubs) | |
| `ets/pages/**`, `ets/viewmodel/**`, `ets/views/**` | B | Exceptions: `pages/DevPanel.ets` (A), `pages/OnboardingPage.ets` + `viewmodel/OnboardingViewModel.ets` (A). |
| `resources/*/element/string.json` | **B** | T0 adds only the `perm_*` keys. **B4 creates every en key up front**, and B10 translates. A asks B for any new key. |
| `resources/*/element/{color,float}.json`, `base/profile/{main_pages,route_map}.json` | B | T0 adds `pages/DevPanel` to `main_pages.json` once. |
| `module.json5` | **A** | All permissions and backgroundModes land in T0. Later changes only via a tiny `fix/module-*` branch (e.g. the widget). |
| `build-profile.json5`, `oh-package.json5`, `hvigorfile.ts` | A | `signingConfigs` stays `[]` in git (hook). No new ohpm dependencies are planned. |
| `rawfile/packs/krakow/**` | B (generated by `scripts/pack/build-pack.sh`) | Never hand-edit. |
| `rawfile/demo/**` | A (generated by `scripts/demo/make-demo-walk.mjs`) | |
| `rawfile/map/**` (PNG fallback base) | B | |
| `entry/src/test/List.test.ets` | A (T1) | T1 pre-registers **every** planned suite as a passing stub, so later tasks only edit their own suite file. |
| `entry/src/test/fixtures/MiniPack.ets`, `DemoTrackMini.ets` | A | |
| `entry/src/test/fixtures/PackJson.ets` | B | |
| `scripts/test.sh`, `scripts/smoke.sh`, `scripts/env.sh`, `scripts/git-hooks/**`, `scripts/demo/**` | A | |
| `scripts/pack/**`, `data/**` | B | |
| `README.md` | Both, **by section** (§4.3) | Small direct commits on `main` (allowed for docs) or a `docs/*` branch. |
| `AI_WORKFLOW.md` | Everyone appends | `merge=union` (T1). |
| `docs/ARCHITECTURE.md`, `docs/DESIGN.md` | Factual deltas only, via S1 | |
| `HACKATHON_BRIEF.md` | **The user only** | E.g. updating the acceptance check after G1. |

### 1.3 What lands first (T0 + T1, merge window M1 at 15:45), and who writes it

**A writes both, in two parallel agent sessions. B reviews T0's contracts for 15 minutes before the merge.**
- **T0 `feat/contracts`:**
  - `contracts/{Model,Ports,EngineTypes,Settings}.ets`, verbatim from ARCHITECTURE §5, §7.3, §9 and §12.2, plus the voice-strategy types, `TourControl.setDemoSpeed/demoJumpToNext`, `EngineSnapshot.{voiceLabel, source, platform}`, `VoicePort` and `PermissionPort`.
  - `app/{Log,LogEvents,AppConfig,AppContainer,Clock}.ets`.
  - `ScriptedTourControl` (a fake that B builds the UI against) and `StubPackRepository` (3 real stops, so A can integrate before B's loader).
  - The `DevPanel` routing.
  - `module.json5` permissions and backgroundModes, plus the `perm_*` strings in 4 locales.
- **T1 `feat/test-harness`:**
  - `scripts/test.sh` (really fails), `scripts/env.sh`, the smoke skeleton.
  - The pre-commit hook against signing material and keys.
  - `List.test.ets` with all suite stubs.
  - `.gitattributes` with `AI_WORKFLOW.md merge=union`.

From 15:45 on, **features add files rather than editing shared ones**. That is the main defence against RISKS PR1.

---

## 2. Task cards

**Conventions:**
- `E/` = `entry/src/main/ets/`, written out in full in the cards.
- **P0** = must ship for the submission. **P1** = should ship (cut in §5 order if behind). **P2** = stretch.
- Estimates are wall-clock hours for one agent session with a human reviewing.
- Every card's DoD implicitly includes the §0.3 rules.
- Human-only tasks (T2, S2–S6) carry an optional helper prompt instead of a coding prompt.

**Load:** A ≈ 18.5 h P0 + 5 h P1; B ≈ 22 h P0 + 0.75 h P1; shared ≈ 6.5 h. That only fits because each person runs **two agent lanes in parallel** (§0.3 rule 2). If a lane slips by more than 45 minutes, apply the cut list (§5); don't push sleep.

### Task index

| ID | Title | Owner | Branch | Pri | Est (h) | Depends on | When |
|---|---|---|---|---|---|---|---|
| [T0](#t0) | Shared contracts + platform skeleton (lands first) | A | `feat/contracts` | P0 | 1.0 | - | Sat 14:50-15:45, merge M1 15:45 |
| [T1](#t1) | Test harness: scripts/test.sh, smoke skeleton, git hooks, suite stubs | A | `feat/test-harness` | P0 | 0.75 | - | Sat 14:50-15:45 (parallel to T0), merge M1 15:45 |
| [T2](#t2) | Gate G1: a human listens to the zh voice reading English (by 15:30) | A | `exp/risk-spikes (existing, no new branch)` | P0 | 0.25 | - | Sat 15:10-15:30 |
| [A1](#a1) | Core geo: GeoMath, Projection, CourseEstimator, FixFilter, GridIndex + tests | A | `feat/core-geo` | P0 | 1.25 | T0, T1 | Sat 15:45-17:00, merge M2 17:30 |
| [A2](#a2) | Route planner: Held-Karp open path + orienteering + NN/2-opt fallback + tests | A | `feat/route-planner` | P0 | 1.25 | T0, T1 | Sat 16:45-17:30 (after A1 in the same lane), merge M2/M3 |
| [A3](#a3) | Tour engine: TriggerPolicy, AnnouncementQueue, TourEngine reducer, Phrases + tests | A | `feat/tour-engine` | P0 | 3.0 | A1 | Sat 17:30-19:30, merge M4 19:40 (gate G7 22:00 for hysteresis tests) |
| [A4](#a4) | Speech: VoicePolicy (strategy switch), TTS engines, PCM AudioRenderer, sentence queue player | A | `cap/tts-pcm` | P0 | 2.5 | T0, T2 | Sat 15:45-18:15, merge M3 18:30 (gate G7 22:00) |
| [A5](#a5) | Location sources: Real (Location Kit + permissions + switch) and Demo walk (SIMULATED) + track generator | A | `cap/location-sources` | P0 | 2.0 | T0, A1, B1 | Sat 18:15-19:30 (generator can start earlier in the headless lane), merge M4 19:40 |
| [A6](#a6) | Continuous task (location + audioPlayback) + AVSession lock-screen controls | A | `cap/background-avsession` | P0 | 1.5 | T0, A4 | Sat 20:30-21:45, merge M5 22:00 (gate G7) |
| [A7](#a7) | TourController: wire engine + sources + speech + platform; real TourControl replaces the fake | A | `feat/controller` | P0 | 2.5 | A2, A3, A4, A5, B3 (soft: StubPackRepository until it merges) | Sat 19:00-19:40 minimal slice (checkpoint), complete 20:30-22:00 alongside A6 |
| [A8](#a8) | Next-stop notification + arrival haptics | A | `cap/notify-haptics` | P1 | 0.75 | A7 | Sat 22:00-22:45, merge M6 00:30 |
| [A9](#a9) | Turn-by-turn guidance + off-route detection and re-plan | A | `feat/turn-by-turn` | P1 | 2.0 | A3, A7, B2 | Sat 22:00-00:15, merge M6 00:30 |
| [A10](#a10) | Error-matrix hardening (ARCHITECTURE §9 rows 1-17) + README error table | A | `fix/error-matrix` | P0 | 1.5 | A7 | Sat 23:00-00:30 and Sun 04:00-05:30 (fix-only) |
| [A11](#a11) | Smoke script + replay integration test (evidence for the jury) | A | `feat/replay-test` | P1 | 1.0 | A3, A5, A7 | Sun 04:00-05:30 (or earlier if ahead) |
| [A12](#a12) | Onboarding (3 steps) with permissions and voice status | A | `feat/onboarding` | P1 | 1.25 | A4, A5, B4 | Sat 23:30-00:30 if A9 is on track, else cut |
| [B1](#b1) | Raw data snapshots committed (ArcGIS, Wikidata, Wikipedia, OSM tiles, OSRM) + curated tour | B | `feat/pack-fetch` | P0 | 1.5 | - | Sat 14:50-16:30, merge M2 17:30 (gate G4 18:00) |
| [B2](#b2) | Offline pack build: merge POIs, routes, map data, extract narrations, validate, emit rawfile pack | B | `feat/pack-build` | P0 | 2.5 | B1, T0 | Sat 16:30-18:15, merge M3 18:30 (gate G4 18:00) |
| [B3](#b3) | App pack loader: PackParser, NarrationValidator, LangDetect, NarrationSelector, RawfilePackRepository + tests | B | `feat/pack-loader` | P0 | 2.0 | T0, B2 | Sat 17:30-19:30, merge M4 19:40 |
| [B4](#b4) | UI shell: Navigation host, Home, Tour detail, Route ready, Before-you-go sheet, tokens, ALL en strings | B | `feat/ui-shell` | P0 | 3.0 | T0 | Sat 15:15 (tokens/strings) -> 18:15, merge M3 18:30 |
| [B5](#b5) | Now Walking screen (all states) + Demo controls sheet + Look cue | B | `feat/now-walking` | P0 | 2.5 | B4 | Sat 18:15-19:40, merge M4 19:40; Look cue dial 20:30+ if ahead |
| [B6](#b6) | Native Canvas vector map (mini map + full map) with PNG fallback | B | `feat/map-canvas` | P0 | 3.5 | B2, B5 | Sat 20:45-23:00 (gate G8 23:00), merge 23:00 or M6 |
| [B7](#b7) | Historian scripts for the 11 stops: AI draft from sources -> human review -> zh/pl MT -> validate | B | `feat/narration-review` | P0 | 3.0 | B1, B2, B3 | Sat 20:45-00:30 (human review 22:00-22:45) |
| [B8](#b8) | Place detail with sources, tier labels and AI disclosure; About & licences page | B | `feat/place-detail` | P0 | 1.25 | B3, B4 | Sat 23:00-00:30, merge M6 |
| [B9](#b9) | Settings: Demo walk toggle + speed, story language, voice (strategy + download), app language | B | `feat/settings` | P0 | 1.25 | B4, A4 | Sun 00:30-01:45, merge M7 02:45 |
| [B10](#b10) | i18n: Polish and Chinese UI strings + in-app language switch | B | `feat/i18n` | P0 | 1.5 | B4 | Sat 23:30-01:30 (agent translation in the headless lane), merge M7 02:45 |
| [B11](#b11) | Tour summary | B | `feat/summary` | P1 | 0.75 | B5, A7 | Sun 01:45-02:30 if on track |
| [B12](#b12) | "How it works" HUD overlay (live Kit status) | B | `feat/hud` | P2 | 1.5 | B5, A7 | only if ahead (first stretch item) |
| [B13](#b13) | All-places layer on the full map + place card (Explore, basic) | B | `feat/explore-layer` | P2 | 2.0 | B6, B8 | only if ahead |
| [B14](#b14) | Form Kit "Next stop" widget | B | `cap/widget` | P2 | 3.0 | A7 | only if everything else is green |
| [S1](#s1) | Docs upkeep: README, ARCHITECTURE deltas, AI_WORKFLOW, ATTRIBUTION (continuous) | both | `docs/<topic> or direct small commits on main` | P0 | 2.5 | - | at every merge window; milestones 19:30, 03:00 (B), 07:00 (A), 09:15 final |
| [S2](#s2) | 20:00 checkpoint upload | both | `none (tag checkpoint-good on main)` | P0 | 0.5 | T0, B4 | Sat 19:40-20:00 |
| [S3](#s3) | System-audio capture test for the demo recording (gate G6 20:30) | A | `none` | P0 | 0.5 | A4 | Sat 20:00-20:30 on the recording Mac (A's) |
| [S4](#s4) | Release artifact and signing hygiene (unsigned HAP from a tag; device signing only if a device appears) | A | `none (tag v1.0-hackyeah)` | P0 | 0.5 | T1 | Sun 06:00 decision (G10), 09:00-09:30 release |
| [S5](#s5) | Demo video: rehearsal, recording (Sun 07:30-09:00), <= 60 s cut | both | `none` | P0 | 2.0 | S3, A7, B5 | Rehearsal Sun 06:00-07:00 (A), record 07:30-09:00 (both), cut 09:00-09:30 (B) |
| [S6](#s6) | HackTribe submission package (<= 10-slide PDF, <= 60 s video, <= 500-word EN description, screenshots, Discord IDs) | both | `docs/submission` | P0 | 1.5 | S5, S4 | A drafts description + slides Sun 04:30-05:30; B finalises 09:00-09:45 with the video; uploaded by 10:00 |
| [X1](#x1) | "I have N minutes" (orienteering) on Route ready | B | `feat/time-budget` | P2 | 1.0 | A2, B4, A7 | only if ahead |
| [X2](#x2) | Mid-tour language switch EN <-> 中文 (voice + captions) | both | `feat/live-language` | P2 | 1.0 | A7, B5 | only if ahead |

<a id="t0"></a>

### T0 · Shared contracts + platform skeleton (lands first)

| Owner | Branch | Priority | Estimate | Depends on | Lane | When |
|---|---|---|---|---|---|---|
| A | `feat/contracts` | P0 | 1.0 h | none | emulator (short run at the end) | Sat 14:50-15:45, merge M1 15:45 |

**Goal.** Land every type, port and hotspot change both halves need, so A and B can work in parallel without touching shared files again.

**Files (exclusive to this task).**
- `common/src/main/ets/contracts/Model.ets`
- `common/src/main/ets/contracts/Ports.ets`
- `common/src/main/ets/contracts/EngineTypes.ets`
- `common/src/main/ets/contracts/Settings.ets`
- `entry/src/main/ets/app/Log.ets`
- `common/src/main/ets/app/LogEvents.ets`
- `entry/src/main/ets/app/AppConfig.ets`
- `entry/src/main/ets/app/AppContainer.ets`
- `common/src/main/ets/app/Clock.ets`
- `entry/src/main/ets/entryability/EntryAbility.ets`
- `entry/src/main/ets/services/tour/ScriptedTourControl.ets`
- `entry/src/main/ets/services/pack/PackFactory.ets + services/pack/StubPackRepository.ets (inline 3 real stops: Barbican, St Mary's, Cloth Hall; both owned by B after merge)`
- `entry/src/main/ets/pages/DevPanel.ets (empty dev page, A-owned)`
- `entry/src/main/resources/base/profile/main_pages.json (add pages/DevPanel; B owns afterwards)`
- `entry/src/main/module.json5`
- `entry/src/main/resources/{base,en_US,pl_PL,zh_CN}/element/string.json (only the perm_* keys from ARCHITECTURE §2.2)`
- `entry/src/test/fixtures/MiniPack.ets (4 POIs, 3x3 matrix, 2 narrations; A-owned)`

**Scope.**
- Copy the interfaces from docs/ARCHITECTURE.md §5 (Fix, LocationSource), §7.3 (Model), §12.2 (SpeechPort, PackRepository, TourControl, EngineSnapshot) exactly; add the missing ports: PermissionPort, BackgroundPort, MediaSessionPort, NotifierPort, HapticsPort, Clock, LoggerPort, AppIssue/IssueCode (ARCHITECTURE §9).
- Voice strategy contract (PLAN §0.4): `enum EnVoiceStrategy { AUTO_NATIVE_THEN_ZH, AUTO_NATIVE_THEN_TEXT, FORCE_ZH, TEXT_ONLY }`, `enum VoiceLabel { NATIVE, FALLBACK_ZH_READS_EN, TEXT_ONLY_PLATFORM, TEXT_ONLY_USER }`, `VoiceState` (INSTALLED | DOWNLOADABLE | UNAVAILABLE | ERROR), `SpeechCapabilities { en, zh }`, `VoicePlan { textLang, speechMode, engineLocale, person, languageContext, label, reason }`; `VoicePort { capabilities(), plan(textLang), downloadEnglish(onProgress), setStrategy(s) }`.
- TourControl additions: `setDemoSpeed(mult: number)`, `demoJumpToNext()`; EngineSnapshot additions: `voiceLabel: VoiceLabel`, `source: FixSource`, `platform: PlatformStatus { bgRunning, avsActive, ttsEngine, sourceKind, realGpsAccuracyM }` (feeds the HUD later).
- `app/AppConfig.ets`: `DEFAULT_EN_VOICE_STRATEGY = EnVoiceStrategy.AUTO_NATIVE_THEN_ZH` (user decision 2026-10-03), `USE_SYSTEM_PLAYBACK = false` (emergency playType 1 switch), `DEMO_DEFAULT_SPEED = 4`.
- `app/Log.ets` wraps hilog (domain 0xC17A, tag CityTour, `"%{public}s"` format); `LogEvents.ets` holds the event codes of ARCHITECTURE §10.
- `AppContainer.init(ctx)` / `shutdown()`; getters `tourControl()` (returns ScriptedTourControl until A7), `packRepository()` (via PackFactory), `voice()`, `permissions()` returning stubs that resolve safely. ScriptedTourControl replays a canned 11-stop snapshot sequence (Walking -> Approaching -> AtStop -> ... -> Finished) every 2 s so B can build UI against it.
- EntryAbility: AppContainer.init in onCreate, shutdown in onDestroy; if `want.parameters["page"] === "dev"` load `pages/DevPanel`, else `pages/Index`. Log `APP_START ver=... pack=none`.
- module.json5 exactly as ARCHITECTURE §2.2 (APPROXIMATELY_LOCATION, LOCATION, KEEP_BACKGROUND_RUNNING, VIBRATE with reason strings; `backgroundModes: ["location","audioPlayback"]`). No INTERNET permission. The spike branch exp/risk-spikes has a verified module.json5 diff to copy from.
- B reviews the contracts for 15 min before the merge (Model.ets must match what the pipeline will emit).

**Definition of Done.**
- [ ] `devecocli check arkts` and `devecocli build` pass on the branch.
- [ ] `devecocli run --device "Pura 90"` prints `Smoke: PASS`; the log shows `APP_START`.
- [ ] The DevPanel opens with `aa start ... --ps page dev`.
- [ ] B has reviewed contracts/ (comment on the PR).
- [ ] AI_WORKFLOW.md row added.
- [ ] Rebased on `origin/main`; PR opened with verified vs unverified list; `AI_WORKFLOW.md` row added.

**Verify.**
```bash
devecocli check arkts
devecocli build
devecocli run --device "Pura 90"                      # -> Smoke: PASS
devecocli log --device "Pura 90" --bundle-name com.hackyeah.citytour --keyword CityTour --tail 300 | grep APP_START
HDC=/Applications/DevEco-Studio.app/Contents/sdk/default/openharmony/toolchains/hdc
$HDC -t 127.0.0.1:5555 shell aa start -a EntryAbility -b com.hackyeah.citytour --ps page dev
devecocli ui screenshot --device "Pura 90" --path /tmp/ct-devpanel.png
```

**Starter prompt** (after `scripts/wt.sh new feat/contracts` and `cd ../citytour-wt/contracts && claude`):
```text
You are a Claude Code agent in the git worktree ../citytour-wt/contracts (branch feat/contracts) of CityTour, a native ArkTS/ArkUI HarmonyOS app (API 20 minimum, compiled against API 24, emulator "Pura 90"). First read AGENTS.md (including Team Flow), HACKATHON_BRIEF.md, AI_WORKFLOW.md, and in docs/PLAN.md: §0 and task card T0. Do task T0: shared contracts and the platform skeleton. Copy the type definitions from docs/ARCHITECTURE.md §5, §7.3, §9 and §12.2 into common/src/main/ets/contracts/ (Model.ets, Ports.ets, EngineTypes.ets, Settings.ets) and add the voice-strategy types, the extra TourControl methods and the EngineSnapshot fields listed in the card. ArkTS has no structural typing, no `any` and no index signatures: use interfaces + classes, enums with string values. Create app/Log.ets, app/LogEvents.ets, app/AppConfig.ets, app/AppContainer.ets, app/Clock.ets, services/tour/ScriptedTourControl.ets (a fake TourControl that replays a canned snapshot sequence for the UI), services/pack/PackFactory.ets + StubPackRepository.ets (an inline 3-stop pack with the real coordinates of Barbican, St Mary's Basilica and Cloth Hall, so A can integrate before B's loader lands), an empty pages/DevPanel.ets, and test fixture entry/src/test/fixtures/MiniPack.ets. Wire EntryAbility (init/shutdown, `page=dev` launch parameter). Apply the module.json5 permissions and backgroundModes from ARCHITECTURE §2.2 (you can copy the verified diff from branch exp/risk-spikes, but drop INTERNET) and add the perm_* reason strings to base, en_US, pl_PL and zh_CN string.json. Keep every file minimal and compiling; no UI beyond the DevPanel title.

Rules (AGENTS.md Team Flow + docs/PLAN.md §0.3): edit only the files listed in your task card; contracts/ is read-only (if a contract must change, stop and tell the human). Verify every Kit/API with `devecocli docs search <keywords>` / `devecocli docs read <id>` before using it and cite the doc id in the commit message; guard anything whose 起始版本 is above API 20 (compatibleSdkVersion is 6.0.0(20)). core/ stays pure (no @kit imports); State Management V2 only (no V1 decorators). Log only through app/Log.ets (domain 0xC17A, tag CityTour, `EVENT k=v`). Anything simulated shows SIMULATED on screen and src=demo in logs. Never crash: try/catch + Promise.catch at every platform call, explicit timeouts, a visible state for each failure. Run `devecocli check arkts` before each build. Commit after every small working step with a descriptive message, push every 2-3 commits. Add or extend unit tests and keep `scripts/test.sh` green. Append one row to AI_WORKFLOW.md (task, what you generated, how it was verified). Only one agent per Mac drives the emulator at a time: tell the human before `devecocli run`. When done: `git fetch && git rebase origin/main`, run every command in the card's Verify block, open a PR with `gh pr create --base main` (title = task id + title, body = 'Closes #<issue>' + verified vs unverified list) and stop. Never merge to main.
```

<a id="t1"></a>

### T1 · Test harness: scripts/test.sh, smoke skeleton, git hooks, suite stubs

| Owner | Branch | Priority | Estimate | Depends on | Lane | When |
|---|---|---|---|---|---|---|
| A | `feat/test-harness` | P0 | 0.75 h | none | headless | Sat 14:50-15:45 (parallel to T0), merge M1 15:45 |

**Goal.** One command that really fails when a test fails (hvigorw test always exits 0), plus guards that keep secrets and V1 decorators out.

**Files (exclusive to this task).**
- `scripts/env.sh`
- `scripts/test.sh`
- `scripts/smoke.sh (skeleton; A11 completes it)`
- `scripts/git-hooks/pre-commit`
- `entry/src/test/List.test.ets`
- `entry/src/test/Harness.test.ets`
- `entry/src/test/<Suite>.test.ets stubs: GeoMath, CourseEstimator, FixFilter, HeldKarp, TriggerPolicy, AnnouncementQueue, TourEngine, Phrases, DemoWalkPlayer, VoicePolicy, LegTracker, Replay (A) / PackParser, NarrationValidator, MapCamera (B)`
- `.gitattributes (`AI_WORKFLOW.md merge=union`)`
- `.gitignore (add `.shots/`, `data/cache/`)`
- `README.md "Testing" section`

**Scope.**
- `scripts/env.sh`: exports DEVECO_SDK_HOME, PATH (DevEco node), HVIGORW and HDC (`/Applications/DevEco-Studio.app/Contents/sdk/default/openharmony/toolchains/hdc`).
- `scripts/test.sh`: delete the old result file first (a stale file would fake a pass), run `hvigorw test -p module=entry -p coverage=false --no-daemon` (ARCHITECTURE §11.1), fail if `entry/.test/default/intermediates/test/coverage_data/test_result.txt` is missing, parse `Tests run: N, Failure: F, Error: E`, exit 1 unless N>0 and F=E=0, print the `test=`/`Error in` lines of failures; guard `grep -rn "@kit\." common/src/main/ets/core` and the V1-decorator regex of ARCHITECTURE §11.1; run `node --test scripts/pack/` when any `*.test.mjs` exists; end with `TESTS: PASS n=<N>`.
- List.test.ets registers every planned suite; each stub has one passing `it` and a header comment naming its owner task, so later tasks only edit their own suite file (no conflicts in List.test.ets).
- pre-commit hook: reject staged *.p12/*.p7b/*.cer/*.csr/*.keystore, a build-profile.json5 whose signingConfigs is not `[]`, and strings matching `sk-ant-|ANTHROPIC_API_KEY=|BEGIN (RSA|EC) PRIVATE KEY`. Install with `git config core.hooksPath scripts/git-hooks` (shared by all worktrees). Document in README.
- `scripts/smoke.sh` skeleton: `devecocli run --device "${DEVICE:-Pura 90}"`, then grep the log for APP_START; A11 adds the demo-walk greps.

**Definition of Done.**
- [ ] `scripts/test.sh` exits 0 on the stubs and prints `TESTS: PASS`.
- [ ] A deliberately failing test makes it exit 1 (show the output in the PR; do not commit the failing test).
- [ ] An `import ... from "@kit.AudioKit"` placed in core/ makes it exit 1 (show, do not commit).
- [ ] The hook blocks a commit of a build-profile.json5 with a fake signingConfigs entry (show, do not commit).
- [ ] Rebased on `origin/main`; PR opened with verified vs unverified list; `AI_WORKFLOW.md` row added.

**Verify.**
```bash
source scripts/env.sh
scripts/test.sh; echo "exit=$?"            # -> TESTS: PASS, exit=0
git config core.hooksPath scripts/git-hooks
scripts/smoke.sh                            # -> Smoke: PASS + APP_START found
```

**Starter prompt** (after `scripts/wt.sh new feat/test-harness` and `cd ../citytour-wt/test-harness && claude`):
```text
You are a Claude Code agent in the git worktree ../citytour-wt/test-harness (branch feat/test-harness) of CityTour, a native ArkTS/ArkUI HarmonyOS app (API 20 minimum, compiled against API 24, emulator "Pura 90"). First read AGENTS.md (including Team Flow), HACKATHON_BRIEF.md, AI_WORKFLOW.md, and in docs/PLAN.md: §0 and task card T1. Do task T1: the command-line test harness. `hvigorw test` exits 0 even when tests fail (verified), so scripts/test.sh must parse entry/.test/default/intermediates/test/coverage_data/test_result.txt (format: `Tests run: 2, Failure: 1, Error: 0, Pass: 1, Ignore: 0`, failing tests appear as `Error in <name>` lines) and delete the stale file before each run. Use the exact command and env from docs/ARCHITECTURE.md §11.1 (put the env in scripts/env.sh). Add the core/ @kit guard and the V1-decorator guard from §11.1. Create entry/src/test/List.test.ets that registers one stub suite file per planned suite (names in the card) so later tasks never edit List.test.ets. Add the pre-commit hook against signing material and keys, .gitattributes with `AI_WORKFLOW.md merge=union`, the scripts/smoke.sh skeleton and a README "Testing" section. Hypium is already a devDependency (@ohos/hypium 1.0.25). Prove the failure paths in your PR description, but commit only green code. This task does not need the emulator except for one smoke.sh run at the end.

Rules (AGENTS.md Team Flow + docs/PLAN.md §0.3): edit only the files listed in your task card; contracts/ is read-only (if a contract must change, stop and tell the human). Verify every Kit/API with `devecocli docs search <keywords>` / `devecocli docs read <id>` before using it and cite the doc id in the commit message; guard anything whose 起始版本 is above API 20 (compatibleSdkVersion is 6.0.0(20)). core/ stays pure (no @kit imports); State Management V2 only (no V1 decorators). Log only through app/Log.ets (domain 0xC17A, tag CityTour, `EVENT k=v`). Anything simulated shows SIMULATED on screen and src=demo in logs. Never crash: try/catch + Promise.catch at every platform call, explicit timeouts, a visible state for each failure. Run `devecocli check arkts` before each build. Commit after every small working step with a descriptive message, push every 2-3 commits. Add or extend unit tests and keep `scripts/test.sh` green. Append one row to AI_WORKFLOW.md (task, what you generated, how it was verified). Only one agent per Mac drives the emulator at a time: tell the human before `devecocli run`. When done: `git fetch && git rebase origin/main`, run every command in the card's Verify block, open a PR with `gh pr create --base main` (title = task id + title, body = 'Closes #<issue>' + verified vs unverified list) and stop. Never merge to main.
```

<a id="t2"></a>

### T2 · Gate G1: a human listens to the zh voice reading English (by 15:30)

| Owner | Branch | Priority | Estimate | Depends on | Lane | When |
|---|---|---|---|---|---|---|
| A | `exp/risk-spikes (existing, no new branch)` | P0 | 0.25 h | none | human + emulator | Sat 15:10-15:30 |

**Goal.** Confirm the binding voice decision is acceptable by ear before we build on it: English narration = zh-CN voice (person 13) reading English, labelled "Fallback voice". If it is unintelligible, switch the default to English text-only.

**Files (exclusive to this task).**
- none committed (the spike is throwaway); result goes into the team chat and later into README by S1

**Scope.**
- In ../citytour-wt/risk-spikes run the spike, tap the "zh engine speaks English" button, listen with headphones on the Mac. Also listen to one Chinese sentence for comparison.
- Judge: can a non-Chinese listener follow two sentences about the Main Square? Note speed and accent.
- Accept -> keep `DEFAULT_EN_VOICE_STRATEGY = AUTO_NATIVE_THEN_ZH`. Reject -> A4 sets `AUTO_NATIVE_THEN_TEXT`, B shows "Text only: no English voice on this device"; the user updates the acceptance check in HACKATHON_BRIEF.md (user-owned file).
- Push the spike branch so B can read its TTS/BG/AVSession code: `git -C ../citytour-wt/risk-spikes push -u origin exp/risk-spikes`.

**Definition of Done.**
- [ ] Verdict (accept/reject + one sentence why) posted in the team chat by 15:30.
- [ ] exp/risk-spikes pushed.

**Verify.**
```bash
cd ../citytour-wt/risk-spikes && devecocli run --device "Pura 90"
devecocli log --device "Pura 90" --bundle-name com.hackyeah.citytour --keyword SPIKE --from 2m | grep -i "speak"
```

**Starter prompt.**
```text
You are a Claude Code agent in the git worktree ../citytour-wt/risk-spikes (branch exp/risk-spikes) of CityTour, a native ArkTS/ArkUI HarmonyOS app (API 20 minimum, compiled against API 24, emulator "Pura 90"). First read AGENTS.md (including Team Flow), HACKATHON_BRIEF.md, AI_WORKFLOW.md, and in docs/PLAN.md: §0 and task card T2. Do task T2 (a human gate). Do NOT change code. Build and launch the existing spike with `devecocli run --device "Pura 90"` from this worktree, tell the human which button speaks English with the zh-CN engine (read entry/src/main/ets/pages/Index.ets), then tail the SPIKE log while the human listens and report the synthesis and completion timings. Afterwards push the branch with `git push -u origin exp/risk-spikes`. Do not edit AI_WORKFLOW.md for this task.

Rules (AGENTS.md Team Flow + docs/PLAN.md §0.3): edit only the files listed in your task card; contracts/ is read-only (if a contract must change, stop and tell the human). Verify every Kit/API with `devecocli docs search <keywords>` / `devecocli docs read <id>` before using it and cite the doc id in the commit message; guard anything whose 起始版本 is above API 20 (compatibleSdkVersion is 6.0.0(20)). core/ stays pure (no @kit imports); State Management V2 only (no V1 decorators). Log only through app/Log.ets (domain 0xC17A, tag CityTour, `EVENT k=v`). Anything simulated shows SIMULATED on screen and src=demo in logs. Never crash: try/catch + Promise.catch at every platform call, explicit timeouts, a visible state for each failure. Run `devecocli check arkts` before each build. Commit after every small working step with a descriptive message, push every 2-3 commits. Add or extend unit tests and keep `scripts/test.sh` green. Append one row to AI_WORKFLOW.md (task, what you generated, how it was verified). Only one agent per Mac drives the emulator at a time: tell the human before `devecocli run`. When done: `git fetch && git rebase origin/main`, run every command in the card's Verify block, open a PR with `gh pr create --base main` (title = task id + title, body = 'Closes #<issue>' + verified vs unverified list) and stop. Never merge to main.
```

<a id="a1"></a>

### A1 · Core geo: GeoMath, Projection, CourseEstimator, FixFilter, GridIndex + tests

| Owner | Branch | Priority | Estimate | Depends on | Lane | When |
|---|---|---|---|---|---|---|
| A | `feat/core-geo` | P0 | 1.25 h | T0, T1 | headless | Sat 15:45-17:00, merge M2 17:30 |

**Goal.** Pure, tested geometry that the engine, the planner and the map all share.

**Files (exclusive to this task).**
- `common/src/main/ets/core/geo/GeoMath.ets`
- `common/src/main/ets/core/geo/Projection.ets`
- `common/src/main/ets/core/geo/CourseEstimator.ets`
- `common/src/main/ets/core/geo/FixFilter.ets`
- `common/src/main/ets/core/geo/GridIndex.ets`
- `entry/src/test/GeoMath.test.ets`
- `entry/src/test/CourseEstimator.test.ets`
- `entry/src/test/FixFilter.test.ets`

**Scope.**
- haversine, bearing, normalizeDeg, relDir buckets (ARCHITECTURE §4.5 table, edges 25/70/120/160, HERE when d<15 m or course unknown), pointToSegment.
- Projection constants of ARCHITECTURE §3.2 (origin Rynek 50.06143, 19.93658). Pin 3 reference points that B2 pins too: origin -> (0,0); Wawel 50.0540,19.9354; Barbican 50.0655,19.9417 (expected values computed from the formula in the test).
- CourseEstimator rules 1-5 of ARCHITECTURE §4.5; FixFilter: accuracy > 40 not trigger-grade, NETWORK provider > 25 m not trigger-grade, out-of-order timestamps dropped, speed median of last 5.
- GridIndex (P1 part): bucket POIs by 100 m cells for nearest/viewport queries.

**Definition of Done.**
- [ ] All cases in the ARCHITECTURE §11.1 rows GeoMath, CourseEstimator and FixFilter pass.
- [ ] `scripts/test.sh` green; no @kit import in core/.
- [ ] Rebased on `origin/main`; PR opened with verified vs unverified list; `AI_WORKFLOW.md` row added.

**Verify.**
```bash
source scripts/env.sh && devecocli check arkts && scripts/test.sh
```

**Starter prompt** (after `scripts/wt.sh new feat/core-geo` and `cd ../citytour-wt/core-geo && claude`):
```text
You are a Claude Code agent in the git worktree ../citytour-wt/core-geo (branch feat/core-geo) of CityTour, a native ArkTS/ArkUI HarmonyOS app (API 20 minimum, compiled against API 24, emulator "Pura 90"). First read AGENTS.md (including Team Flow), HACKATHON_BRIEF.md, AI_WORKFLOW.md, and in docs/PLAN.md: §0 and task card A1. Do task A1: pure geometry in common/src/main/ets/core/geo/ (GeoMath, Projection, CourseEstimator, FixFilter, GridIndex) with Hypium tests in the existing stub files GeoMath.test.ets, CourseEstimator.test.ets and FixFilter.test.ets. Follow docs/ARCHITECTURE.md §3.2 (projection), §4.5 (course over ground and RelDir table) and §2.3 (fix quality rules), and the test table in §11.1. Use the types in contracts/ (Fix, RelDir, LatLng). No platform imports at all. This task needs no emulator.

Rules (AGENTS.md Team Flow + docs/PLAN.md §0.3): edit only the files listed in your task card; contracts/ is read-only (if a contract must change, stop and tell the human). Verify every Kit/API with `devecocli docs search <keywords>` / `devecocli docs read <id>` before using it and cite the doc id in the commit message; guard anything whose 起始版本 is above API 20 (compatibleSdkVersion is 6.0.0(20)). core/ stays pure (no @kit imports); State Management V2 only (no V1 decorators). Log only through app/Log.ets (domain 0xC17A, tag CityTour, `EVENT k=v`). Anything simulated shows SIMULATED on screen and src=demo in logs. Never crash: try/catch + Promise.catch at every platform call, explicit timeouts, a visible state for each failure. Run `devecocli check arkts` before each build. Commit after every small working step with a descriptive message, push every 2-3 commits. Add or extend unit tests and keep `scripts/test.sh` green. Append one row to AI_WORKFLOW.md (task, what you generated, how it was verified). Only one agent per Mac drives the emulator at a time: tell the human before `devecocli run`. When done: `git fetch && git rebase origin/main`, run every command in the card's Verify block, open a PR with `gh pr create --base main` (title = task id + title, body = 'Closes #<issue>' + verified vs unverified list) and stop. Never merge to main.
```

<a id="a2"></a>

### A2 · Route planner: Held-Karp open path + orienteering + NN/2-opt fallback + tests

| Owner | Branch | Priority | Estimate | Depends on | Lane | When |
|---|---|---|---|---|---|---|
| A | `feat/route-planner` | P0 | 1.25 h | T0, T1 | headless | Sat 16:45-17:30 (after A1 in the same lane), merge M2/M3 |

**Goal.** Exact optimal walking order from the user position over the shipped OSRM matrix (the "optimised route" acceptance check).

**Files (exclusive to this task).**
- `common/src/main/ets/core/route/HeldKarp.ets`
- `common/src/main/ets/core/route/Fallback.ets`
- `common/src/main/ets/core/route/Planner.ets`
- `entry/src/test/HeldKarp.test.ets`

**Scope.**
- API exactly as ARCHITECTURE §6.4. Cost = walk duration + dwell; origin row = haversine x detourFactor / 1.30 m/s; stop within 30 m becomes the origin; optional fixedEnd (Royal Route ends at Wawel).
- solveOrienteering from the same DP table (P1 feature, nearly free here).
- n > 16 or NaN -> nearestNeighbour2Opt with exact=false.
- Planner returns TourPlan with order, costS, exact, algo, ms and "savedM vs listed order" (Route ready shows it).

**Definition of Done.**
- [ ] Brute-force equality on 30 random asymmetric 7-node matrices; fixedEnd respected; n = 0/1/2; n = 15 under 1000 ms; orienteering never exceeds budget and matches brute force on 8 nodes; NN+2opt within 1.3x on random 10-node.
- [ ] `scripts/test.sh` green.
- [ ] Rebased on `origin/main`; PR opened with verified vs unverified list; `AI_WORKFLOW.md` row added.

**Verify.**
```bash
source scripts/env.sh && devecocli check arkts && scripts/test.sh
```

**Starter prompt** (after `scripts/wt.sh new feat/route-planner` and `cd ../citytour-wt/route-planner && claude`):
```text
You are a Claude Code agent in the git worktree ../citytour-wt/route-planner (branch feat/route-planner) of CityTour, a native ArkTS/ArkUI HarmonyOS app (API 20 minimum, compiled against API 24, emulator "Pura 90"). First read AGENTS.md (including Team Flow), HACKATHON_BRIEF.md, AI_WORKFLOW.md, and in docs/PLAN.md: §0 and task card A2. Do task A2: Held-Karp open-path TSP, the orienteering variant and the NN+2-opt fallback in common/src/main/ets/core/route/ (HeldKarp.ets, Fallback.ets, Planner.ets) with the tests listed in docs/ARCHITECTURE.md §11.1 (HeldKarp.test row) in entry/src/test/HeldKarp.test.ets. Follow §6.1-6.4 exactly (Float64Array dp, Int8Array parents, hard cap n <= 16). Planner.buildCostInputs uses contracts RouteData (durationsS, detourFactor) and TourStop.dwellS; also compute how many metres the optimal order saves versus the listed order. Use seeded pseudo-random matrices in tests so failures reproduce. No emulator needed.

Rules (AGENTS.md Team Flow + docs/PLAN.md §0.3): edit only the files listed in your task card; contracts/ is read-only (if a contract must change, stop and tell the human). Verify every Kit/API with `devecocli docs search <keywords>` / `devecocli docs read <id>` before using it and cite the doc id in the commit message; guard anything whose 起始版本 is above API 20 (compatibleSdkVersion is 6.0.0(20)). core/ stays pure (no @kit imports); State Management V2 only (no V1 decorators). Log only through app/Log.ets (domain 0xC17A, tag CityTour, `EVENT k=v`). Anything simulated shows SIMULATED on screen and src=demo in logs. Never crash: try/catch + Promise.catch at every platform call, explicit timeouts, a visible state for each failure. Run `devecocli check arkts` before each build. Commit after every small working step with a descriptive message, push every 2-3 commits. Add or extend unit tests and keep `scripts/test.sh` green. Append one row to AI_WORKFLOW.md (task, what you generated, how it was verified). Only one agent per Mac drives the emulator at a time: tell the human before `devecocli run`. When done: `git fetch && git rebase origin/main`, run every command in the card's Verify block, open a PR with `gh pr create --base main` (title = task id + title, body = 'Closes #<issue>' + verified vs unverified list) and stop. Never merge to main.
```

<a id="a3"></a>

### A3 · Tour engine: TriggerPolicy, AnnouncementQueue, TourEngine reducer, Phrases + tests

| Owner | Branch | Priority | Estimate | Depends on | Lane | When |
|---|---|---|---|---|---|---|
| A | `feat/tour-engine` | P0 | 3.0 h | A1 | headless | Sat 17:30-19:30, merge M4 19:40 (gate G7 22:00 for hysteresis tests) |

**Goal.** The heart of the product as a pure reducer: arrive -> say where to look -> tell the story, never cut a sentence, never double-trigger.

**Files (exclusive to this task).**
- `common/src/main/ets/core/tour/TourEngine.ets`
- `common/src/main/ets/core/tour/TriggerPolicy.ets`
- `common/src/main/ets/core/tour/AnnouncementQueue.ets`
- `common/src/main/ets/core/tour/TourConfig.ets`
- `common/src/main/ets/core/content/Phrases.ets (arrival/approach/next/gps-lost/finish lines in en, zh, pl; nav templates come in A9)`
- `entry/src/test/TriggerPolicy.test.ets`
- `entry/src/test/AnnouncementQueue.test.ets`
- `entry/src/test/TourEngine.test.ets`
- `entry/src/test/Phrases.test.ets`

**Scope.**
- State machine ARCHITECTURE §4.1, events/effects §4.2, triggers §4.3 (accuracy-aware distance, enter/exit debounce, exit factor 1.6), queue §4.4 (priorities, preemption at sentence boundaries, expiry, dedupe, skip/pause semantics, text-only reading timer), relDir in the arrival line from CourseEstimator (§4.5) + Poi.view "look up".
- Teaser vs full by dwell/speed behind `UserSettings.adaptiveLength` (proposal, default on). A stop is auto-spoken once per tour.
- Only the next planned stop or a not-yet-visited stop can fire (prevents St Mary's / Cloth Hall ping-pong).
- Effects carry the VoicePlan label so SET_MEDIA_META can append "Fallback voice". Arrival with speechMode TEXT_ONLY emits HAPTIC + NOTIFY + SET_MEDIA_META and paces captions by reading time.
- Gate G9 (00:15): if relDir is not reliable in tests, Phrases falls back to "Look for {feature}" with no left/right.

**Definition of Done.**
- [ ] All rows TriggerPolicy, AnnouncementQueue, TourEngine and Phrases of ARCHITECTURE §11.1 pass, including: +-15 m jitter at the radius edge => exactly one ENTER; acc 80 m => no ENTER; walk-through at 1.4 m/s => teaser only; P1 arriving mid-P2 plays after the current sentence and P2 resumes at its cursor.
- [ ] A scripted 3-stop track drives Idle -> ... -> Finished and the test asserts the exact effect sequence.
- [ ] `scripts/test.sh` green.
- [ ] Rebased on `origin/main`; PR opened with verified vs unverified list; `AI_WORKFLOW.md` row added.

**Verify.**
```bash
source scripts/env.sh && devecocli check arkts && scripts/test.sh
```

**Starter prompt** (after `scripts/wt.sh new feat/tour-engine` and `cd ../citytour-wt/tour-engine && claude`):
```text
You are a Claude Code agent in the git worktree ../citytour-wt/tour-engine (branch feat/tour-engine) of CityTour, a native ArkTS/ArkUI HarmonyOS app (API 20 minimum, compiled against API 24, emulator "Pura 90"). First read AGENTS.md (including Team Flow), HACKATHON_BRIEF.md, AI_WORKFLOW.md, and in docs/PLAN.md: §0 and task card A3. Do task A3: the pure tour engine in common/src/main/ets/core/tour/ (TourEngine reducer `(state, event) => {state, effects}`, TriggerPolicy, AnnouncementQueue, TourConfig) and core/content/Phrases.ets, following docs/ARCHITECTURE.md §4.1-4.5 and the effect/event names in contracts/EngineTypes.ets. The reducer never calls services; it only returns effects. Sentence = utterance: the queue hands out the next sentence only after UTTERANCE_DONE. Use entry/src/test/fixtures/MiniPack.ets and synthetic fix tracks in the tests (rows TriggerPolicy, AnnouncementQueue, TourEngine, Phrases of §11.1). Keep phrase text short and spoken-style (docs/DESIGN.md §5.3-5.5). No emulator needed.

Rules (AGENTS.md Team Flow + docs/PLAN.md §0.3): edit only the files listed in your task card; contracts/ is read-only (if a contract must change, stop and tell the human). Verify every Kit/API with `devecocli docs search <keywords>` / `devecocli docs read <id>` before using it and cite the doc id in the commit message; guard anything whose 起始版本 is above API 20 (compatibleSdkVersion is 6.0.0(20)). core/ stays pure (no @kit imports); State Management V2 only (no V1 decorators). Log only through app/Log.ets (domain 0xC17A, tag CityTour, `EVENT k=v`). Anything simulated shows SIMULATED on screen and src=demo in logs. Never crash: try/catch + Promise.catch at every platform call, explicit timeouts, a visible state for each failure. Run `devecocli check arkts` before each build. Commit after every small working step with a descriptive message, push every 2-3 commits. Add or extend unit tests and keep `scripts/test.sh` green. Append one row to AI_WORKFLOW.md (task, what you generated, how it was verified). Only one agent per Mac drives the emulator at a time: tell the human before `devecocli run`. When done: `git fetch && git rebase origin/main`, run every command in the card's Verify block, open a PR with `gh pr create --base main` (title = task id + title, body = 'Closes #<issue>' + verified vs unverified list) and stop. Never merge to main.
```

<a id="a4"></a>

### A4 · Speech: VoicePolicy (strategy switch), TTS engines, PCM AudioRenderer, sentence queue player

| Owner | Branch | Priority | Estimate | Depends on | Lane | When |
|---|---|---|---|---|---|---|
| A | `cap/tts-pcm` | P0 | 2.5 h | T0, T2 | emulator | Sat 15:45-18:15, merge M3 18:30 (gate G7 22:00) |

**Goal.** Core Speech Kit TTS with playType 0 streaming PCM into our own AudioRenderer, one sentence at a time, with the voice chosen by a config switch: real en-US Laura when installed, else the zh-CN voice reading English labelled "Fallback voice", else text-only.

**Files (exclusive to this task).**
- `common/src/main/ets/core/speech/VoicePolicy.ets`
- `entry/src/main/ets/services/speech/TtsEngines.ets`
- `entry/src/main/ets/services/speech/VoiceManager.ets`
- `entry/src/main/ets/services/speech/NarrationPlayer.ets`
- `entry/src/main/ets/services/audio/PcmPlayer.ets`
- `entry/src/main/ets/pages/DevPanel.ets (speech buttons)`
- `entry/src/main/ets/app/AppContainer.ets (wire voice())`
- `entry/src/test/VoicePolicy.test.ets`

**Scope.**
- `resolveVoicePlan(textLang, strategy, caps)` (pure, tested): en + AUTO_NATIVE_THEN_ZH -> en-US/8 if INSTALLED, else zh-CN/13 with label FALLBACK_ZH_READS_EN, else TEXT_ONLY_PLATFORM; zh -> zh-CN/13; pl -> TEXT_ONLY_PLATFORM unless the user picked "listen in English". Every decision logs `VOICE_PLAN lang=en engine=zh-CN person=13 label=fallback-zh reason=en_status=DOWNLOADABLE`.
- VoiceManager: listVoices at init (map GA -> DOWNLOADABLE), lazy engines with unique names and isBackStage:true (ARCHITECTURE §2.5), `downloadEnglish()` keeps the real downloadVoice path (1002300010 = success, 1002300008 = failed, emulator fails server-side: show and log it, re-plan). Check in the docs whether downloadVoice needs the INTERNET permission in our app; record the doc id (ASSUMPTION: it does not).
- PcmPlayer: AudioRenderer 16 kHz mono S16LE, STREAM_USAGE_AUDIOBOOK, writeData zero-fill, byte-count end detection + buffer delay, audioInterrupt and outputDeviceChangeWithInfo forwarded as listener events.
- NarrationPlayer implements SpeechPort: one utterance in flight, prefetch n+1, unique requestIds, `[pN]` markup kept for TTS, stripped for captions; TEXT_ONLY mode fires start/done on a reading timer. Try `languageContext` "en-US" vs "zh-CN" for the zh engine reading English and keep the one the human prefers (log both).
- AppConfig.USE_SYSTEM_PLAYBACK=true switches to playType 1 (the emergency fallback of RISKS T7).
- DevPanel: buttons "EN sample (3 sentences)", "ZH sample", "Text-only sample", "Strategy: cycle", "Download English voice", with a live status line.

**Definition of Done.**
- [ ] VoicePolicy tests: 4 strategies x en status INSTALLED/DOWNLOADABLE/UNAVAILABLE/ERROR x textLang en/zh/pl.
- [ ] On the emulator, "EN sample" logs VOICE_PLAN label=fallback-zh, then UTT_START/UTT_DONE x3 in order with no overlap; a human heard it.
- [ ] "Download English voice" fails gracefully with VOICE_DL_FAIL code=1002300008 and the plan stays fallback-zh.
- [ ] No crash when the sample is tapped twice quickly.
- [ ] Rebased on `origin/main`; PR opened with verified vs unverified list; `AI_WORKFLOW.md` row added.

**Verify.**
```bash
source scripts/env.sh && devecocli check arkts && devecocli build && scripts/test.sh
devecocli run --device "Pura 90"
$HDC -t 127.0.0.1:5555 shell aa start -a EntryAbility -b com.hackyeah.citytour --ps page dev   # tap "EN sample"
devecocli log --device "Pura 90" --bundle-name com.hackyeah.citytour --keyword CityTour --tail 300 | grep -E "VOICE_STATUS|VOICE_PLAN|TTS_INIT|UTT_START|UTT_DONE|TTS_ERR"
```

**Starter prompt** (after `scripts/wt.sh new cap/tts-pcm` and `cd ../citytour-wt/tts-pcm && claude`):
```text
You are a Claude Code agent in the git worktree ../citytour-wt/tts-pcm (branch cap/tts-pcm) of CityTour, a native ArkTS/ArkUI HarmonyOS app (API 20 minimum, compiled against API 24, emulator "Pura 90"). First read AGENTS.md (including Team Flow), HACKATHON_BRIEF.md, AI_WORKFLOW.md, and in docs/PLAN.md: §0 and task card A4. Do task A4: the speech stack. Binding user decision: English narration uses the zh-CN voice (person 13) reading the English text, labelled "Fallback voice"; the en-US Laura (person 8) listVoices/downloadVoice path stays in code so a device that has Laura uses it automatically; Polish is text-only. Implement core/speech/VoicePolicy.ets (pure, tested), services/speech/{TtsEngines,VoiceManager,NarrationPlayer}.ets and services/audio/PcmPlayer.ets per docs/ARCHITECTURE.md §2.5 and docs/RISKS.md §1 rows a1-a7 (verified facts: en/8 createEngine fails with 1002300005, downloadVoice fails with 1002300008 on the emulator, playType 0 gives 16 kHz mono PCM in ~12.8 KB chunks, onComplete fires once with type 0, so playback end is ours). Reuse working code from branch exp/risk-spikes (entry/src/main/ets/pages/Index.ets) but restructure it into the services. Add DevPanel buttons to exercise it. Implement the SpeechPort/VoicePort contracts from contracts/Ports.ets exactly.

Rules (AGENTS.md Team Flow + docs/PLAN.md §0.3): edit only the files listed in your task card; contracts/ is read-only (if a contract must change, stop and tell the human). Verify every Kit/API with `devecocli docs search <keywords>` / `devecocli docs read <id>` before using it and cite the doc id in the commit message; guard anything whose 起始版本 is above API 20 (compatibleSdkVersion is 6.0.0(20)). core/ stays pure (no @kit imports); State Management V2 only (no V1 decorators). Log only through app/Log.ets (domain 0xC17A, tag CityTour, `EVENT k=v`). Anything simulated shows SIMULATED on screen and src=demo in logs. Never crash: try/catch + Promise.catch at every platform call, explicit timeouts, a visible state for each failure. Run `devecocli check arkts` before each build. Commit after every small working step with a descriptive message, push every 2-3 commits. Add or extend unit tests and keep `scripts/test.sh` green. Append one row to AI_WORKFLOW.md (task, what you generated, how it was verified). Only one agent per Mac drives the emulator at a time: tell the human before `devecocli run`. When done: `git fetch && git rebase origin/main`, run every command in the card's Verify block, open a PR with `gh pr create --base main` (title = task id + title, body = 'Closes #<issue>' + verified vs unverified list) and stop. Never merge to main.
```

<a id="a5"></a>

### A5 · Location sources: Real (Location Kit + permissions + switch) and Demo walk (SIMULATED) + track generator

| Owner | Branch | Priority | Estimate | Depends on | Lane | When |
|---|---|---|---|---|---|---|
| A | `cap/location-sources` | P0 | 2.0 h | T0, A1, B1 | emulator | Sat 18:15-19:30 (generator can start earlier in the headless lane), merge M4 19:40 |

**Goal.** Both sources feed the same pipeline; the emulator demo is impossible without the Demo walk (emulator GPS is a fixed Beijing point).

**Files (exclusive to this task).**
- `entry/src/main/ets/services/location/RealLocationSource.ets`
- `entry/src/main/ets/services/location/DemoWalkSource.ets`
- `entry/src/main/ets/services/location/PermissionService.ets`
- `common/src/main/ets/core/sim/DemoWalkPlayer.ets`
- `scripts/demo/make-demo-walk.mjs`
- `entry/src/main/resources/rawfile/demo/royal-route-walk.json`
- `entry/src/main/ets/pages/DevPanel.ets (location buttons)`
- `entry/src/main/ets/app/AppContainer.ets (wire permissions(), sources)`
- `entry/src/test/DemoWalkPlayer.test.ets`

**Scope.**
- RealLocationSource per ARCHITECTURE §2.3/§5: NAVIGATION scenario, interval 1, same callback ref for off(), locationError mapping, isLocationEnabled -> requestGlobalSwitch (verified b1/b3: fresh emulator has the switch OFF), precise vs approximate handling, requestPermissionOnSetting after denial.
- DemoWalkPlayer (pure) + DemoWalkSource (setInterval 1 s, speed 1/2/4/8, hold while `holdPredicate()` is true, "Demo assist" flag in the snapshot). Real source keeps running in demo mode and its accuracy feeds PlatformStatus.realGpsAccuracyM.
- make-demo-walk.mjs: from the OSRM route geometry (data/raw OSRM snapshot from B1, or the pack routes.json once B2 lands) build the track of ARCHITECTURE §5: jitter sigma 4 m, 1.3 +- 0.15 m/s, course from movement, 40 s dwells with hold flags, one stop passed at walking speed, one 80 m detour, one 10 s accuracy degradation to 60 m; `simulated: true`, `generatedBy`. `--fixture` also writes a short typed track to entry/src/test/fixtures/DemoTrackMini.ets for A11.
- Logs: LOC_SOURCE kind=..., LOC_FIX src=demo|real (rate-limited 1/5 s), LOC_ERR, LOC_SWITCH_OFF, PERM_DENIED, PERM_APPROX_ONLY.

**Definition of Done.**
- [ ] DemoWalkPlayer tests: order, speed multiplier, hold while predicate true.
- [ ] DevPanel "Demo walk x8" logs LOC_FIX src=demo with changing spd/crs for > 60 s.
- [ ] DevPanel "Real GPS" on a fresh emulator shows the switch flow, then fixes at lat 40 lng 116 (Beijing), logged with src=real.
- [ ] Rebased on `origin/main`; PR opened with verified vs unverified list; `AI_WORKFLOW.md` row added.

**Verify.**
```bash
source scripts/env.sh && devecocli check arkts && devecocli build && scripts/test.sh
node scripts/demo/make-demo-walk.mjs && git diff --stat entry/src/main/resources/rawfile/demo/
devecocli run --device "Pura 90"
$HDC -t 127.0.0.1:5555 shell aa start -a EntryAbility -b com.hackyeah.citytour --ps page dev   # tap "Demo walk x8"
devecocli log --device "Pura 90" --bundle-name com.hackyeah.citytour --keyword CityTour --tail 300 | grep -E "LOC_SOURCE|LOC_FIX|LOC_ERR|PERM_"
```

**Starter prompt** (after `scripts/wt.sh new cap/location-sources` and `cd ../citytour-wt/location-sources && claude`):
```text
You are a Claude Code agent in the git worktree ../citytour-wt/location-sources (branch cap/location-sources) of CityTour, a native ArkTS/ArkUI HarmonyOS app (API 20 minimum, compiled against API 24, emulator "Pura 90"). First read AGENTS.md (including Team Flow), HACKATHON_BRIEF.md, AI_WORKFLOW.md, and in docs/PLAN.md: §0 and task card A5. Do task A5: RealLocationSource, PermissionService (PermissionPort), the pure core/sim/DemoWalkPlayer, DemoWalkSource and the track generator scripts/demo/make-demo-walk.mjs (Node 22, stdlib only) that writes entry/src/main/resources/rawfile/demo/royal-route-walk.json. Follow docs/ARCHITECTURE.md §2.3 and §5 and the verified emulator facts in docs/RISKS.md §1 rows b1-b6 (switch off by default -> 3301100 -> requestGlobalSwitch works; static Beijing fix; CLI geolocation injection does not work). The Demo walk is SIMULATED: the track file says so, every fix carries source DEMO and every LOC_FIX log has src=demo. Add DevPanel buttons to start/stop each source and change demo speed.

Rules (AGENTS.md Team Flow + docs/PLAN.md §0.3): edit only the files listed in your task card; contracts/ is read-only (if a contract must change, stop and tell the human). Verify every Kit/API with `devecocli docs search <keywords>` / `devecocli docs read <id>` before using it and cite the doc id in the commit message; guard anything whose 起始版本 is above API 20 (compatibleSdkVersion is 6.0.0(20)). core/ stays pure (no @kit imports); State Management V2 only (no V1 decorators). Log only through app/Log.ets (domain 0xC17A, tag CityTour, `EVENT k=v`). Anything simulated shows SIMULATED on screen and src=demo in logs. Never crash: try/catch + Promise.catch at every platform call, explicit timeouts, a visible state for each failure. Run `devecocli check arkts` before each build. Commit after every small working step with a descriptive message, push every 2-3 commits. Add or extend unit tests and keep `scripts/test.sh` green. Append one row to AI_WORKFLOW.md (task, what you generated, how it was verified). Only one agent per Mac drives the emulator at a time: tell the human before `devecocli run`. When done: `git fetch && git rebase origin/main`, run every command in the card's Verify block, open a PR with `gh pr create --base main` (title = task id + title, body = 'Closes #<issue>' + verified vs unverified list) and stop. Never merge to main.
```

<a id="a6"></a>

### A6 · Continuous task (location + audioPlayback) + AVSession lock-screen controls

| Owner | Branch | Priority | Estimate | Depends on | Lane | When |
|---|---|---|---|---|---|---|
| A | `cap/background-avsession` | P0 | 1.5 h | T0, A4 | emulator | Sat 20:30-21:45, merge M5 22:00 (gate G7) |

**Goal.** The headline platform capability: the guide keeps tracking and talking with the screen locked, controllable from the lock screen.

**Files (exclusive to this task).**
- `entry/src/main/ets/services/background/BackgroundRunner.ets`
- `entry/src/main/ets/services/media/MediaSessionService.ets`
- `entry/src/main/ets/pages/DevPanel.ets (bg/avs buttons)`
- `entry/src/main/ets/app/AppContainer.ets (wire)`

**Scope.**
- One `startBackgroundRunning(ctx, ["location","audioPlayback"], wantAgent)` (verified c5); treat 9800005 (already running) as success; `on("continuousTaskCancel")` and `on("continuousTaskSuspend")` (API 20, guard) -> BG_CANCEL/BG_SUSPEND logs + BG_CANCELLED event; stop audio together with the task.
- AVSession "audio": register play/pause/playNext/playPrevious/toggleFavorite/stop before activate() (verified d1); map to USER_* events (ARCHITECTURE §2.6); metadata title per state, artist "CityTour · Historian" + " · Fallback voice" when VoiceLabel is fallback + " · DEMO" in demo; playback state mirrors the engine; destroy at the end.
- Screen-off test with hdc (devecocli emulator power needs Emulator 7.0, does not work).

**Definition of Done.**
- [ ] Demo walk x4 + screen off for 3 min: LOC_FIX keeps arriving, UTT_START appears while Display State=0, no BG_SUSPEND.
- [ ] Lock screen / Control Center pause and next log AVS_CMD cmd=pause / cmd=playNext and the engine reacts.
- [ ] Screenshot of the lock-screen card saved to docs/img/lockscreen.png (via S1).
- [ ] Rebased on `origin/main`; PR opened with verified vs unverified list; `AI_WORKFLOW.md` row added.

**Verify.**
```bash
source scripts/env.sh && devecocli check arkts && devecocli build && scripts/test.sh
devecocli run --device "Pura 90"
$HDC -t 127.0.0.1:5555 shell power-shell suspend      # screen off; wait 3 min
$HDC -t 127.0.0.1:5555 shell power-shell wakeup
devecocli log --device "Pura 90" --bundle-name com.hackyeah.citytour --keyword CityTour --tail 300 | grep -E "BG_START|BG_SUSPEND|BG_CANCEL|AVS_|UTT_START|LOC_FIX"
devecocli ui screenshot --device "Pura 90" --path docs/img/lockscreen.png
```

**Starter prompt** (after `scripts/wt.sh new cap/background-avsession` and `cd ../citytour-wt/background-avsession && claude`):
```text
You are a Claude Code agent in the git worktree ../citytour-wt/background-avsession (branch cap/background-avsession) of CityTour, a native ArkTS/ArkUI HarmonyOS app (API 20 minimum, compiled against API 24, emulator "Pura 90"). First read AGENTS.md (including Team Flow), HACKATHON_BRIEF.md, AI_WORKFLOW.md, and in docs/PLAN.md: §0 and task card A6. Do task A6: services/background/BackgroundRunner.ets (BackgroundPort) and services/media/MediaSessionService.ets (MediaSessionPort) per docs/ARCHITECTURE.md §2.4 and §2.6. Verified on this emulator (docs/RISKS.md §1 c1-c5, d1): the multi-mode continuous task works, a second request fails with 9800005, AVSession commands from the Control Center and lock screen arrive. Reuse code from branch exp/risk-spikes. Test with the screen off using `$HDC -t 127.0.0.1:5555 shell power-shell suspend` / `wakeup` (devecocli emulator power does not work on Emulator 6.1.1). Remember: the emulator does not freeze background apps, so this proves wiring, not real-phone behaviour; say so in the PR.

Rules (AGENTS.md Team Flow + docs/PLAN.md §0.3): edit only the files listed in your task card; contracts/ is read-only (if a contract must change, stop and tell the human). Verify every Kit/API with `devecocli docs search <keywords>` / `devecocli docs read <id>` before using it and cite the doc id in the commit message; guard anything whose 起始版本 is above API 20 (compatibleSdkVersion is 6.0.0(20)). core/ stays pure (no @kit imports); State Management V2 only (no V1 decorators). Log only through app/Log.ets (domain 0xC17A, tag CityTour, `EVENT k=v`). Anything simulated shows SIMULATED on screen and src=demo in logs. Never crash: try/catch + Promise.catch at every platform call, explicit timeouts, a visible state for each failure. Run `devecocli check arkts` before each build. Commit after every small working step with a descriptive message, push every 2-3 commits. Add or extend unit tests and keep `scripts/test.sh` green. Append one row to AI_WORKFLOW.md (task, what you generated, how it was verified). Only one agent per Mac drives the emulator at a time: tell the human before `devecocli run`. When done: `git fetch && git rebase origin/main`, run every command in the card's Verify block, open a PR with `gh pr create --base main` (title = task id + title, body = 'Closes #<issue>' + verified vs unverified list) and stop. Never merge to main.
```

<a id="a7"></a>

### A7 · TourController: wire engine + sources + speech + platform; real TourControl replaces the fake

| Owner | Branch | Priority | Estimate | Depends on | Lane | When |
|---|---|---|---|---|---|---|
| A | `feat/controller` | P0 | 2.5 h | A2, A3, A4, A5, B3 (soft: StubPackRepository until it merges) | emulator | Sat 19:00-19:40 minimal slice (checkpoint), complete 20:30-22:00 alongside A6 |

**Goal.** Vertical slice on main: Demo walk -> arrival -> narration spoken (Fallback voice) -> text shown, driven by the planned order.

**Files (exclusive to this task).**
- `common/src/main/ets/control/TourController.ets`
- `entry/src/main/ets/app/AppContainer.ets (swap ScriptedTourControl -> TourController)`
- `common/src/main/ets/app/Clock.ets`

**Scope.**
- Implements TourControl: plan() via Planner (origin = current fix; if > 5 km outside the pack bbox -> issue LOC_OUT_OF_AREA and use the tour start: the jury is in Beijing per emulator), start() = BackgroundRunner + AVSession + source + TICK 1 Hz, FIX -> FixFilter -> engine, FIX_TIMEOUT after 25 s.
- Effect executor in order: SPEAK -> NarrationPlayer (text via PackRepository.narration(poi, persona, lang, len) + VoicePlan), STOP_SPEECH, SET_MEDIA_META/STATE -> AVSession (no-op until A6 merged), NOTIFY_NEXT/HAPTIC -> no-op until A8, REQUEST_REPLAN -> Planner, LOG -> Log.
- Snapshot publisher throttled to <= 4 Hz; demo hold predicate = queue.isStoryActive(); setDemoSpeed/demoJumpToNext.
- Logs ROUTE_PLAN algo=heldkarp n= costS= ms= order=..., STATE from= to= ev=, POI_ENTER, STORY_START/END, NARR_SOURCE tier= sources=.

**Definition of Done.**
- [ ] From Home "Try demo walk" (B4, id btnDemoWalk) or DevPanel: PACK_LOAD -> ROUTE_PLAN algo=heldkarp -> LOC_SOURCE kind=demo -> POI_ENTER -> STORY_START -> UTT_DONE, repeated, ending in STATE to=finished at x8.
- [ ] NowWalking (B5) shows next stop, distance and caption live.
- [ ] `scripts/smoke.sh` (or the manual greps) pass.
- [ ] Rebased on `origin/main`; PR opened with verified vs unverified list; `AI_WORKFLOW.md` row added.

**Verify.**
```bash
source scripts/env.sh && devecocli check arkts && devecocli build && scripts/test.sh
devecocli run --device "Pura 90" && devecocli ui click --device "Pura 90" --id btnDemoWalk
sleep 120; devecocli log --device "Pura 90" --bundle-name com.hackyeah.citytour --keyword CityTour --tail 300 | grep -E "PACK_LOAD|ROUTE_PLAN|LOC_SOURCE|POI_ENTER|STORY_START|UTT_DONE|STATE"
```

**Starter prompt** (after `scripts/wt.sh new feat/controller` and `cd ../citytour-wt/controller && claude`):
```text
You are a Claude Code agent in the git worktree ../citytour-wt/controller (branch feat/controller) of CityTour, a native ArkTS/ArkUI HarmonyOS app (API 20 minimum, compiled against API 24, emulator "Pura 90"). First read AGENTS.md (including Team Flow), HACKATHON_BRIEF.md, AI_WORKFLOW.md, and in docs/PLAN.md: §0 and task card A7. Do task A7: services/tour/TourController.ets implementing contracts TourControl, hosting the pure TourEngine and executing its effects through the services (NarrationPlayer, sources, BackgroundRunner, MediaSessionService, Planner, Log), per docs/ARCHITECTURE.md §1.2 (lifecycle), §4, §5, §9 row 8 (out of area) and §10 (logs). Then switch AppContainer.tourControl() from ScriptedTourControl to TourController (keep ScriptedTourControl in the repo for UI previews). Effects whose service is not merged yet must be safe no-ops with a log line. First milestone (by 19:40): the demo walk triggers stop narration end to end; polish afterwards.

Rules (AGENTS.md Team Flow + docs/PLAN.md §0.3): edit only the files listed in your task card; contracts/ is read-only (if a contract must change, stop and tell the human). Verify every Kit/API with `devecocli docs search <keywords>` / `devecocli docs read <id>` before using it and cite the doc id in the commit message; guard anything whose 起始版本 is above API 20 (compatibleSdkVersion is 6.0.0(20)). core/ stays pure (no @kit imports); State Management V2 only (no V1 decorators). Log only through app/Log.ets (domain 0xC17A, tag CityTour, `EVENT k=v`). Anything simulated shows SIMULATED on screen and src=demo in logs. Never crash: try/catch + Promise.catch at every platform call, explicit timeouts, a visible state for each failure. Run `devecocli check arkts` before each build. Commit after every small working step with a descriptive message, push every 2-3 commits. Add or extend unit tests and keep `scripts/test.sh` green. Append one row to AI_WORKFLOW.md (task, what you generated, how it was verified). Only one agent per Mac drives the emulator at a time: tell the human before `devecocli run`. When done: `git fetch && git rebase origin/main`, run every command in the card's Verify block, open a PR with `gh pr create --base main` (title = task id + title, body = 'Closes #<issue>' + verified vs unverified list) and stop. Never merge to main.
```

<a id="a8"></a>

### A8 · Next-stop notification + arrival haptics

| Owner | Branch | Priority | Estimate | Depends on | Lane | When |
|---|---|---|---|---|---|---|
| A | `cap/notify-haptics` | P1 | 0.75 h | A7 | emulator | Sat 22:00-22:45, merge M6 00:30 |

**Goal.** Glanceable "Next: Wawel Cathedral · 240 m" and a haptic on arrival (essential for Polish text-only mode).

**Files (exclusive to this task).**
- `entry/src/main/ets/services/notify/TourNotifier.ets`
- `entry/src/main/ets/services/haptics/Haptics.ets`
- `common/src/main/ets/control/TourController.ets (NOTIFY_NEXT/HAPTIC executor lines only)`

**Scope.**
- ARCHITECTURE §2.7 (id 1001 updated in place, isAlertOnce, consent at tour start, 1600004 -> NOTIF_DENIED) and §2.8 (vibrator; isSupportEffect check; emulator likely no-op -> log only).

**Definition of Done.**
- [ ] Notification visible in the shade during the demo walk and updated on stop change; HAPTIC kind=arrive logged; notification cancelled at tour end.
- [ ] Rebased on `origin/main`; PR opened with verified vs unverified list; `AI_WORKFLOW.md` row added.

**Verify.**
```bash
source scripts/env.sh && devecocli check arkts && devecocli build && scripts/test.sh
devecocli run --device "Pura 90"; devecocli log --device "Pura 90" --bundle-name com.hackyeah.citytour --keyword CityTour --tail 300 | grep -E "NOTIF_|HAPTIC"
```

**Starter prompt** (after `scripts/wt.sh new cap/notify-haptics` and `cd ../citytour-wt/notify-haptics && claude`):
```text
You are a Claude Code agent in the git worktree ../citytour-wt/notify-haptics (branch cap/notify-haptics) of CityTour, a native ArkTS/ArkUI HarmonyOS app (API 20 minimum, compiled against API 24, emulator "Pura 90"). First read AGENTS.md (including Team Flow), HACKATHON_BRIEF.md, AI_WORKFLOW.md, and in docs/PLAN.md: §0 and task card A8. Do task A8: services/notify/TourNotifier.ets (NotifierPort) and services/haptics/Haptics.ets (HapticsPort) per docs/ARCHITECTURE.md §2.7-2.8, then replace the no-op NOTIFY_NEXT/HAPTIC branches in TourController with real calls. Respect the rate rules (update on stop change and every >= 50 m). The vibrator is probably a no-op on the emulator: log it and say so.

Rules (AGENTS.md Team Flow + docs/PLAN.md §0.3): edit only the files listed in your task card; contracts/ is read-only (if a contract must change, stop and tell the human). Verify every Kit/API with `devecocli docs search <keywords>` / `devecocli docs read <id>` before using it and cite the doc id in the commit message; guard anything whose 起始版本 is above API 20 (compatibleSdkVersion is 6.0.0(20)). core/ stays pure (no @kit imports); State Management V2 only (no V1 decorators). Log only through app/Log.ets (domain 0xC17A, tag CityTour, `EVENT k=v`). Anything simulated shows SIMULATED on screen and src=demo in logs. Never crash: try/catch + Promise.catch at every platform call, explicit timeouts, a visible state for each failure. Run `devecocli check arkts` before each build. Commit after every small working step with a descriptive message, push every 2-3 commits. Add or extend unit tests and keep `scripts/test.sh` green. Append one row to AI_WORKFLOW.md (task, what you generated, how it was verified). Only one agent per Mac drives the emulator at a time: tell the human before `devecocli run`. When done: `git fetch && git rebase origin/main`, run every command in the card's Verify block, open a PR with `gh pr create --base main` (title = task id + title, body = 'Closes #<issue>' + verified vs unverified list) and stop. Never merge to main.
```

<a id="a9"></a>

### A9 · Turn-by-turn guidance + off-route detection and re-plan

| Owner | Branch | Priority | Estimate | Depends on | Lane | When |
|---|---|---|---|---|---|---|
| A | `feat/turn-by-turn` | P1 | 2.0 h | A3, A7, B2 | headless then emulator | Sat 22:00-00:15, merge M6 00:30 |

**Goal.** Spoken directions between stops and recovery when the walker leaves the route.

**Files (exclusive to this task).**
- `common/src/main/ets/core/route/LegTracker.ets`
- `common/src/main/ets/core/route/Guidance.ets`
- `common/src/main/ets/core/content/Phrases.ets (nav templates)`
- `common/src/main/ets/core/tour/TourEngine.ets (P1 nav items, off-route)`
- `entry/src/test/LegTracker.test.ets`
- `entry/src/test/Phrases.test.ets`

**Scope.**
- ARCHITECTURE §4.6 (prepare 30 m / now 8 m cues, long continue > 250 m, zh omits Polish street names, leg 0 bearing guidance) and §4.7 (off-route rule, P0 cue once per 60 s, REQUEST_REPLAN).

**Definition of Done.**
- [ ] LegTracker tests: monotonic progress, off-route after 12 s at 50 m, clear when back, prepare/now cues once each; Phrases covers every maneuver x modifier x lang.
- [ ] On the emulator the demo detour logs OFF_ROUTE then REPLAN and NAV_CUE lines.
- [ ] Rebased on `origin/main`; PR opened with verified vs unverified list; `AI_WORKFLOW.md` row added.

**Verify.**
```bash
source scripts/env.sh && devecocli check arkts && scripts/test.sh && devecocli build
devecocli run --device "Pura 90"; devecocli log --device "Pura 90" --bundle-name com.hackyeah.citytour --keyword CityTour --tail 300 | grep -E "NAV_CUE|OFF_ROUTE|ON_ROUTE|REPLAN"
```

**Starter prompt** (after `scripts/wt.sh new feat/turn-by-turn` and `cd ../citytour-wt/turn-by-turn && claude`):
```text
You are a Claude Code agent in the git worktree ../citytour-wt/turn-by-turn (branch feat/turn-by-turn) of CityTour, a native ArkTS/ArkUI HarmonyOS app (API 20 minimum, compiled against API 24, emulator "Pura 90"). First read AGENTS.md (including Team Flow), HACKATHON_BRIEF.md, AI_WORKFLOW.md, and in docs/PLAN.md: §0 and task card A9. Do task A9: LegTracker and Guidance in common/src/main/ets/core/route/, the navigation templates in core/content/Phrases.ets, and the off-route/replan handling in core/tour/TourEngine.ets, per docs/ARCHITECTURE.md §4.6-4.7 and the LegTracker/Phrases test rows of §11.1. Legs and OSRM steps come from the pack (contracts RouteData.legs). Keep it pure and tested first; the emulator run only confirms the demo detour produces OFF_ROUTE and REPLAN.

Rules (AGENTS.md Team Flow + docs/PLAN.md §0.3): edit only the files listed in your task card; contracts/ is read-only (if a contract must change, stop and tell the human). Verify every Kit/API with `devecocli docs search <keywords>` / `devecocli docs read <id>` before using it and cite the doc id in the commit message; guard anything whose 起始版本 is above API 20 (compatibleSdkVersion is 6.0.0(20)). core/ stays pure (no @kit imports); State Management V2 only (no V1 decorators). Log only through app/Log.ets (domain 0xC17A, tag CityTour, `EVENT k=v`). Anything simulated shows SIMULATED on screen and src=demo in logs. Never crash: try/catch + Promise.catch at every platform call, explicit timeouts, a visible state for each failure. Run `devecocli check arkts` before each build. Commit after every small working step with a descriptive message, push every 2-3 commits. Add or extend unit tests and keep `scripts/test.sh` green. Append one row to AI_WORKFLOW.md (task, what you generated, how it was verified). Only one agent per Mac drives the emulator at a time: tell the human before `devecocli run`. When done: `git fetch && git rebase origin/main`, run every command in the card's Verify block, open a PR with `gh pr create --base main` (title = task id + title, body = 'Closes #<issue>' + verified vs unverified list) and stop. Never merge to main.
```

<a id="a10"></a>

### A10 · Error-matrix hardening (ARCHITECTURE §9 rows 1-17) + README error table

| Owner | Branch | Priority | Estimate | Depends on | Lane | When |
|---|---|---|---|---|---|---|
| A | `fix/error-matrix` | P0 | 1.5 h | A7 | emulator | Sat 23:00-00:30 and Sun 04:00-05:30 (fix-only) |

**Goal.** Every failure the jury can hit shows a sensible state and a log line, never a crash.

**Files (exclusive to this task).**
- `entry/src/main/ets/services/** (A-owned files only)`
- `common/src/main/ets/core/tour/** (issue effects)`
- `entry/src/main/ets/app/AppContainer.ets`
- `entry/src/main/ets/app/AppConfig.ets (debug flags to simulate TTS/pack failure)`
- `README.md "Error handling" section (via S1 rules)`

**Scope.**
- AppIssue codes in EngineSnapshot.issues for rows 1-17; B's IssueBanner renders them (ask B for any new string key).
- Reproduce on the emulator: location switch off, permission denied, out of area (Beijing!), en voice missing (default), TTS init fail (debug flag), pack corrupt (unit test), headphones/route change (log only), BG start fail (second start -> 9800005).

**Definition of Done.**
- [ ] README table: condition -> UI -> log -> how verified (emulator/test/unverified).
- [ ] No uncaught exception in `devecocli log --crash` after the full click-through.
- [ ] Rebased on `origin/main`; PR opened with verified vs unverified list; `AI_WORKFLOW.md` row added.

**Verify.**
```bash
source scripts/env.sh && scripts/test.sh && devecocli run --device "Pura 90"
devecocli log --device "Pura 90" --bundle-name com.hackyeah.citytour --crash --from 30m     # must be empty
devecocli log --device "Pura 90" --bundle-name com.hackyeah.citytour --keyword CityTour --tail 300 | grep -E "PERM_|LOC_SWITCH_OFF|LOC_OUT_OF_AREA|TTS_INIT_FAIL|VOICE_|PACK_ERR|BG_FAIL|UNCAUGHT"
```

**Starter prompt** (after `scripts/wt.sh new fix/error-matrix` and `cd ../citytour-wt/error-matrix && claude`):
```text
You are a Claude Code agent in the git worktree ../citytour-wt/error-matrix (branch fix/error-matrix) of CityTour, a native ArkTS/ArkUI HarmonyOS app (API 20 minimum, compiled against API 24, emulator "Pura 90"). First read AGENTS.md (including Team Flow), HACKATHON_BRIEF.md, AI_WORKFLOW.md, and in docs/PLAN.md: §0 and task card A10. Do task A10: walk through docs/ARCHITECTURE.md §9 rows 1-17 and make each one produce the specified AppIssue, log line and safe behaviour, touching only A-owned files (services/, core/tour/, app/). Add debug flags in app/AppConfig.ets (default off) to force a TTS init failure and a corrupt pack so they can be shown in the demo. Reproduce each row you can on the emulator, write the README "Error handling" table with an honest "how verified" column, and list rows you could not reproduce.

Rules (AGENTS.md Team Flow + docs/PLAN.md §0.3): edit only the files listed in your task card; contracts/ is read-only (if a contract must change, stop and tell the human). Verify every Kit/API with `devecocli docs search <keywords>` / `devecocli docs read <id>` before using it and cite the doc id in the commit message; guard anything whose 起始版本 is above API 20 (compatibleSdkVersion is 6.0.0(20)). core/ stays pure (no @kit imports); State Management V2 only (no V1 decorators). Log only through app/Log.ets (domain 0xC17A, tag CityTour, `EVENT k=v`). Anything simulated shows SIMULATED on screen and src=demo in logs. Never crash: try/catch + Promise.catch at every platform call, explicit timeouts, a visible state for each failure. Run `devecocli check arkts` before each build. Commit after every small working step with a descriptive message, push every 2-3 commits. Add or extend unit tests and keep `scripts/test.sh` green. Append one row to AI_WORKFLOW.md (task, what you generated, how it was verified). Only one agent per Mac drives the emulator at a time: tell the human before `devecocli run`. When done: `git fetch && git rebase origin/main`, run every command in the card's Verify block, open a PR with `gh pr create --base main` (title = task id + title, body = 'Closes #<issue>' + verified vs unverified list) and stop. Never merge to main.
```

<a id="a11"></a>

### A11 · Smoke script + replay integration test (evidence for the jury)

| Owner | Branch | Priority | Estimate | Depends on | Lane | When |
|---|---|---|---|---|---|---|
| A | `feat/replay-test` | P1 | 1.0 h | A3, A5, A7 | headless + one emulator run | Sun 04:00-05:30 (or earlier if ahead) |

**Goal.** One command proves the whole pipeline on the emulator; one unit test replays a demo track through the engine and asserts the narration sequence.

**Files (exclusive to this task).**
- `scripts/smoke.sh`
- `entry/src/test/Replay.test.ets`
- `entry/src/test/fixtures/DemoTrackMini.ets (generated by make-demo-walk.mjs --fixture)`
- `README.md "Testing" section (results pasted)`

**Scope.**
- smoke.sh per ARCHITECTURE §11.2 (use `devecocli ui screenshot --path`, which is required), prints `SMOKE+DEMO: PASS` or the missing events.
- Replay.test: feed DemoTrackMini through FixFilter + TourEngine with a fake clock; assert POI order, teaser-only on the pass-by stop, OFF_ROUTE on the detour, no ENTER during the 60 m accuracy window.

**Definition of Done.**
- [ ] `scripts/smoke.sh` prints SMOKE+DEMO: PASS on a fresh install.
- [ ] Replay test green; README shows the command and pasted output.
- [ ] Rebased on `origin/main`; PR opened with verified vs unverified list; `AI_WORKFLOW.md` row added.

**Verify.**
```bash
source scripts/env.sh && scripts/test.sh && scripts/smoke.sh
```

**Starter prompt** (after `scripts/wt.sh new feat/replay-test` and `cd ../citytour-wt/replay-test && claude`):
```text
You are a Claude Code agent in the git worktree ../citytour-wt/replay-test (branch feat/replay-test) of CityTour, a native ArkTS/ArkUI HarmonyOS app (API 20 minimum, compiled against API 24, emulator "Pura 90"). First read AGENTS.md (including Team Flow), HACKATHON_BRIEF.md, AI_WORKFLOW.md, and in docs/PLAN.md: §0 and task card A11. Do task A11: finish scripts/smoke.sh per docs/ARCHITECTURE.md §11.2 (note `devecocli ui screenshot` requires `--path`; the Home demo button has id btnDemoWalk) and write entry/src/test/Replay.test.ets that replays fixtures/DemoTrackMini.ets (generate it with `node scripts/demo/make-demo-walk.mjs --fixture`) through the pure engine and asserts the narration/effect sequence. Paste the passing outputs into the README "Testing" section.

Rules (AGENTS.md Team Flow + docs/PLAN.md §0.3): edit only the files listed in your task card; contracts/ is read-only (if a contract must change, stop and tell the human). Verify every Kit/API with `devecocli docs search <keywords>` / `devecocli docs read <id>` before using it and cite the doc id in the commit message; guard anything whose 起始版本 is above API 20 (compatibleSdkVersion is 6.0.0(20)). core/ stays pure (no @kit imports); State Management V2 only (no V1 decorators). Log only through app/Log.ets (domain 0xC17A, tag CityTour, `EVENT k=v`). Anything simulated shows SIMULATED on screen and src=demo in logs. Never crash: try/catch + Promise.catch at every platform call, explicit timeouts, a visible state for each failure. Run `devecocli check arkts` before each build. Commit after every small working step with a descriptive message, push every 2-3 commits. Add or extend unit tests and keep `scripts/test.sh` green. Append one row to AI_WORKFLOW.md (task, what you generated, how it was verified). Only one agent per Mac drives the emulator at a time: tell the human before `devecocli run`. When done: `git fetch && git rebase origin/main`, run every command in the card's Verify block, open a PR with `gh pr create --base main` (title = task id + title, body = 'Closes #<issue>' + verified vs unverified list) and stop. Never merge to main.
```

<a id="a12"></a>

### A12 · Onboarding (3 steps) with permissions and voice status

| Owner | Branch | Priority | Estimate | Depends on | Lane | When |
|---|---|---|---|---|---|---|
| A | `feat/onboarding` | P1 | 1.25 h | A4, A5, B4 | emulator | Sat 23:30-00:30 if A9 is on track, else cut |

**Goal.** First run explains pocket + headphones, picks the narration language with honest voice status ("Fallback voice" for English, text-only for Polish) and asks for location in context.

**Files (exclusive to this task).**
- `entry/src/main/ets/pages/OnboardingPage.ets`
- `entry/src/main/ets/viewmodel/OnboardingViewModel.ets`
- `route_map.json entry: ask B to add it (B owns the file)`

**Scope.**
- DESIGN §3.1 / Flow A. Uses the onb_* string keys B created in B4 (ask B for missing keys, never edit string.json). Shown once (PersistenceV2 flag), replaceable from Settings.
- Language step shows VoicePlan labels: English "Fallback voice (Chinese voice reads English)" with a Download button that tries Laura; 中文 "Spoken"; Polski "Text only".

**Definition of Done.**
- [ ] Fresh install shows onboarding; permission dialog and switch sheet appear from step 3; second launch goes straight to Home; screenshots en/pl.
- [ ] Rebased on `origin/main`; PR opened with verified vs unverified list; `AI_WORKFLOW.md` row added.

**Verify.**
```bash
source scripts/env.sh && devecocli check arkts && devecocli build && devecocli run --device "Pura 90" --uninstall
devecocli ui screenshot --device "Pura 90" --path /tmp/ct-onb1.png
```

**Starter prompt** (after `scripts/wt.sh new feat/onboarding` and `cd ../citytour-wt/onboarding && claude`):
```text
You are a Claude Code agent in the git worktree ../citytour-wt/onboarding (branch feat/onboarding) of CityTour, a native ArkTS/ArkUI HarmonyOS app (API 20 minimum, compiled against API 24, emulator "Pura 90"). First read AGENTS.md (including Team Flow), HACKATHON_BRIEF.md, AI_WORKFLOW.md, and in docs/PLAN.md: §0 and task card A12. Do task A12: pages/OnboardingPage.ets + viewmodel/OnboardingViewModel.ets per docs/DESIGN.md §2.3 Flow A and §3.1, using AppContainer.permissions() and AppContainer.voice(). This page lives in B's UI area by exception: follow B's patterns in pages/HomePage.ets and views/common/, use only existing string keys (onb_*) and design tokens, and ask the human to have B add the route_map.json entry and any missing key.

Rules (AGENTS.md Team Flow + docs/PLAN.md §0.3): edit only the files listed in your task card; contracts/ is read-only (if a contract must change, stop and tell the human). Verify every Kit/API with `devecocli docs search <keywords>` / `devecocli docs read <id>` before using it and cite the doc id in the commit message; guard anything whose 起始版本 is above API 20 (compatibleSdkVersion is 6.0.0(20)). core/ stays pure (no @kit imports); State Management V2 only (no V1 decorators). Log only through app/Log.ets (domain 0xC17A, tag CityTour, `EVENT k=v`). Anything simulated shows SIMULATED on screen and src=demo in logs. Never crash: try/catch + Promise.catch at every platform call, explicit timeouts, a visible state for each failure. Run `devecocli check arkts` before each build. Commit after every small working step with a descriptive message, push every 2-3 commits. Add or extend unit tests and keep `scripts/test.sh` green. Append one row to AI_WORKFLOW.md (task, what you generated, how it was verified). Only one agent per Mac drives the emulator at a time: tell the human before `devecocli run`. When done: `git fetch && git rebase origin/main`, run every command in the card's Verify block, open a PR with `gh pr create --base main` (title = task id + title, body = 'Closes #<issue>' + verified vs unverified list) and stop. Never merge to main.
```

<a id="a13"></a>

### A13 · ElevenLabs pre-rendered stories (hybrid voice) with native-TTS fallback

| Owner | Branch | Priority | Estimate | Depends on | Lane | When |
|---|---|---|---|---|---|---|
| A | `cap/elevenlabs-voice` | P2 (one of A's last tasks; user decision 2026-10-03) | 2.5 h | A4, A7, B7 (reviewed EN scripts + zh/pl MT), B2/B3 (pack format) | headless pipeline + emulator | Player part can start any time after A7. Rendering starts after the B7 review (~22:30). Gate **G-EL at 01:00**: if it isn't working end to end, drop it. Native TTS stays as is, with nothing to undo. |

**Goal.** The 11 Historian stop stories play in a studio-quality ElevenLabs voice, pre-rendered at build time, in **EN, PL and ZH**. This also gives Polish real audio. Dynamic lines (directions, "look up on your left", welcome, GPS lost) stay on **native on-device TTS** (Core Speech Kit). Whenever a clip is missing, mismatched or fails, the app falls back to native TTS, then to text.

**Why pre-render, not live.** It needs no API key in the app and no network at runtime, so the tour still works offline. The demo is deterministic. A key in the `.hap` would be a committed secret, which breaks the challenge rules and the automated pre-review.

**Files (exclusive to this task).**
- `scripts/voice/render-elevenlabs.mjs`. Node 22, stdlib `fetch` only.
  - Reads `ELEVENLABS_API_KEY` and `ELEVENLABS_VOICE_ID` **from the environment only**. Never prints the key or writes it to disk.
  - Renders one clip per sentence (sentence = utterance, so captions and "never cut mid-sentence" keep working), per language, with the multilingual model.
  - Writes `entry/src/main/resources/rawfile/audio/<lang>/<poiId>/<n>.mp3` plus `rawfile/audio/manifest.json` (`{lang, poiId, n, textSha256, durationMs, voiceId, model, renderedAt}`).
  - Idempotent: it skips clips whose `textSha256` is unchanged. It has a `--dry-run` that prints the character count and cost estimate.
- `entry/src/main/ets/services/audio/ClipPlayer.ets`: plays rawfile mp3 with AVPlayer (fd from the resource manager); end-of-clip callback; pause/resume/stop.
- `entry/src/main/ets/services/speech/NarrationPlayer.ets` (extend A4's file): for each SPEAK of a stop-story sentence, play the clip when the manifest has a matching `textSha256` for that lang/poi/n; otherwise use native TTS (current behaviour). Log `NARR_AUDIO src=prerendered|tts|text reason=…`.
- `entry/src/test/ClipSelection.test.ets` (pure selection logic: hash match / missing / language / persona).
- `scripts/git-hooks/pre-commit`: add a check that rejects `ELEVENLABS_API_KEY=` and `xi-api-key` values.
- `data/ATTRIBUTION.md` and `AI_WORKFLOW.md`: disclose the AI voice (ElevenLabs, model, voice, plan/licence terms).

**Scope / rules.**
- AVSession, lock-screen controls and the continuous task work exactly as before. The clip path goes through the same sentence queue (pause, replay and skip all work).
- UI voice label: stop stories show **"Studio voice (pre-recorded)"**; dynamic lines keep "Fallback voice"/native labels. If the contract's `VoiceLabel` needs a new value, make it a tiny separate contracts commit flagged for B's review.
- Size budget: mono, about 48–64 kbps. Report the total MB in the PR (target under 45 MB).
- The user supplies the key at run time (`export ELEVENLABS_API_KEY=…` in their own shell). Agents never ask for it in chat and never write it to a file.

**Definition of Done.**
- [ ] `node scripts/voice/render-elevenlabs.mjs --dry-run` prints the clip count and characters per language.
- [ ] After rendering: in a demo tour on the emulator, stop stories log `NARR_AUDIO src=prerendered` and dynamic lines log `src=tts`.
- [ ] Deleting one clip makes that sentence fall back to `src=tts` with no crash.
- [ ] Polish stop stories are now spoken; the Polish "text only" label is updated where it applies.
- [ ] `git log -p | grep -i -E "xi-api-key|ELEVENLABS_API_KEY="` finds no key; the pre-commit hook blocks a fake key.
- [ ] README (voice section), ATTRIBUTION and AI_WORKFLOW (AI feature disclosure) are updated.
- [ ] Rebased on `origin/main`, PR opened listing verified and unverified items, and an `AI_WORKFLOW.md` row added.

**Fallback (gate G-EL, 01:00).** If ElevenLabs fails (no key, quota, quality, size, time), close the task as "dropped". The app already runs fully on native TTS.

<a id="b1"></a>

### B1 · Raw data snapshots committed (ArcGIS, Wikidata, Wikipedia, OSM tiles, OSRM) + curated tour

| Owner | Branch | Priority | Estimate | Depends on | Lane | When |
|---|---|---|---|---|---|---|
| B | `feat/pack-fetch` | P0 | 1.5 h | none | headless (network) | Sat 14:50-16:30, merge M2 17:30 (gate G4 18:00) |

**Goal.** Fetch once, commit the snapshots, and never depend on live services again (Overpass is DOWN; the OSM main API, Wikidata SPARQL, Wikipedia REST, OSRM foot and Kraków ArcGIS are UP).

**Files (exclusive to this task).**
- `scripts/pack/lib/http.mjs`
- `scripts/pack/10-fetch-arcgis.mjs`
- `scripts/pack/15-fetch-wikidata.mjs`
- `scripts/pack/20-fetch-osm-tiles.mjs`
- `scripts/pack/30-fetch-wiki.mjs`
- `scripts/pack/50-fetch-osrm.mjs`
- `data/raw/** (gzip anything > 1 MB)`
- `data/raw/SOURCES.md`
- `data/tours/royal-route.json`

**Scope.**
- http.mjs: UA "CityTour-HackYeah2026 (+https://github.com/Svetoslav47/citytour)", 30 s timeout, 3 retries with backoff, per-host rate limit (OSRM and OSM 1 req/s).
- ArcGIS: Pomnik (395), Zabytkowe_tablice_SIM (923), EOZ_Zabytki_* (count each), UNESCO_4f365; paged by resultOffset.
- Wikidata SPARQL instead of Overpass: items located in Kraków with P625, labels en/pl/zh, sitelinks count, P1435, P571, P84, P149.
- OSM map: 9 tiles via `https://api.openstreetmap.org/api/0.6/map?bbox=...` (< 50k nodes each). The lead already fetched them: copy `scratchpad/design/tile1..9.osm` (bbox 19.929-19.947 E, 50.0525-50.0675 N) as `data/raw/osm/tile-N.osm.gz`; only re-fetch if missing.
- Wikipedia REST summaries en/pl/zh (zh with Accept-Language: zh-hans) for the tour stops + top 300 POIs by sitelinks.
- OSRM foot: one table call for the tour stops + `route` with steps=true, overview=full, geometries=geojson for every directed stop pair (11 stops = 110 calls at 1/s). Also commit the lead's `scratchpad/design/route.json` (2,497 m / 33 min) as data/raw/osrm/royal-route-listed-order.json; A5 bootstraps the demo track from it.
- data/tours/royal-route.json (human-curated): 11 stops Barbican -> St Florian's Gate -> St Mary's -> Cloth Hall -> Mickiewicz Monument -> Town Hall Tower -> St Adalbert's -> Sts Peter and Paul -> St Andrew's -> Kanonicza -> Wawel, each with Wikidata QID, checked coordinates, dwellS, prize, triggerRadiusM (Rynek stops 50-70), fixedStart Barbican?, fixedEnd Wawel, view hints (look up/level/down + feature) marked "to review".
- SOURCES.md: URL, retrieval timestamp, licence (OSM ODbL, Wikipedia CC BY-SA 4.0, Wikidata CC0, Kraków ArcGIS: record the item's terms of use or "UNVERIFIED"), counts.

**Definition of Done.**
- [ ] `du -sh data/raw` < 25 MB; every fetch script supports `--offline` (reads disk, no network) and is idempotent.
- [ ] SOURCES.md complete with counts and licences.
- [ ] Gate G4: if anything is missing at 18:00, ship tour stops + 395 monuments + haversine x 1.3 and say so in SOURCES.md.
- [ ] Rebased on `origin/main`; PR opened with verified vs unverified list; `AI_WORKFLOW.md` row added.

**Verify.**
```bash
node --test scripts/pack/ 2>/dev/null || true
for s in scripts/pack/1*-fetch-*.mjs scripts/pack/[2-5]*-fetch-*.mjs; do node "$s" --offline || exit 1; done
du -sh data/raw && cat data/raw/SOURCES.md | head -40
```

**Starter prompt** (after `scripts/wt.sh new feat/pack-fetch` and `cd ../citytour-wt/pack-fetch && claude`):
```text
You are a Claude Code agent in the git worktree ../citytour-wt/pack-fetch (branch feat/pack-fetch) of CityTour, a native ArkTS/ArkUI HarmonyOS app (API 20 minimum, compiled against API 24, emulator "Pura 90"). First read AGENTS.md (including Team Flow), HACKATHON_BRIEF.md, AI_WORKFLOW.md, and in docs/PLAN.md: §0 and task card B1. Do task B1: the fetch half of the offline city-pack pipeline (docs/ARCHITECTURE.md §7.1 stages 1, 3 and 5, adapted: Overpass is down, so POIs come from Wikidata SPARQL + Kraków ArcGIS, and the OSM map comes from 9 tiles of the OSM main API that the lead already downloaded). Write the scripts listed in the card, run them, and commit the raw snapshots under data/raw/ (gzip large files) with data/raw/SOURCES.md. Also create the human-curated data/tours/royal-route.json (stop list in the card; ask the human to confirm the coordinates and view hints). Endpoints and layer names: docs/RISKS.md §1 row x1 and the shared context in docs/PLAN.md §0.

Rules (AGENTS.md Team Flow + docs/PLAN.md §0.3): edit only the files listed in your task card. Node 22+ ESM, stdlib only (no npm dependencies). Every network call sends a User-Agent, has a timeout, retries with backoff and respects the rate limit. The app build must never need the network: everything the pack build reads is committed under data/. No API keys in the repo, in logs or in committed files. Pipeline tests run with `node --test scripts/pack/` (scripts/test.sh runs them too). Commit after every small working step, push every 2-3 commits. Append one row to AI_WORKFLOW.md (task, what you generated, how it was verified). When done: `git fetch && git rebase origin/main`, run every command in the Verify block, open a PR with `gh pr create --base main` (body: 'Closes #<issue>' + verified vs unverified) and stop. Never merge to main.
```

<a id="b2"></a>

### B2 · Offline pack build: merge POIs, routes, map data, extract narrations, validate, emit rawfile pack

| Owner | Branch | Priority | Estimate | Depends on | Lane | When |
|---|---|---|---|---|---|---|
| B | `feat/pack-build` | P0 | 2.5 h | B1, T0 | headless | Sat 16:30-18:15, merge M3 18:30 (gate G4 18:00) |

**Goal.** `scripts/pack/build-pack.sh` turns data/raw into rawfile/packs/krakow/*.json deterministically, offline, validated.

**Files (exclusive to this task).**
- `scripts/pack/schema.mjs`
- `scripts/pack/projection.mjs`
- `scripts/pack/40-merge-pois.mjs`
- `scripts/pack/60-mapdata.mjs`
- `scripts/pack/65-routes.mjs`
- `scripts/pack/75-extract-narrations.mjs`
- `scripts/pack/80-validate.mjs`
- `scripts/pack/90-emit.mjs`
- `scripts/pack/build-pack.sh`
- `scripts/pack/*.test.mjs`
- `entry/src/main/resources/rawfile/packs/krakow/*.json`

**Scope.**
- Schemas mirror contracts/Model.ets (ARCHITECTURE §7.3); manifest with bytes + sha256; builtAt taken from SOURCES.md so rebuilds are byte-identical.
- Merge/dedupe by QID, then name within 30 m, then ArcGIS id; importance from sitelinks/heritage/UNESCO; stable ids.
- routes.json: matrix + legs with projected geometry and steps; detourFactor = median OSRM/haversine.
- map-detail.json: buildings, highways (major/minor/paths), green, water, UNESCO polygon; projected decimetre ints, Douglas-Peucker 0.8 m. Projection constants identical to A1 (shared reference-point test).
- Narrations: SOURCE_EXTRACT (first 1-2 Wikipedia/register sentences, verbatim, attributed) and NAME_ONLY for every POI and language available; tour stops get REVIEWED scripts later in B7.
- 80-validate.mjs implements the validator rules of ARCHITECTURE §7.4 (same expectations as B3's NarrationValidator) and writes validation-report.json.
- Size budget: whole pack <= 15 MB.

**Definition of Done.**
- [ ] `scripts/pack/build-pack.sh` succeeds offline in < 60 s and twice in a row gives identical sha256s.
- [ ] `node --test scripts/pack/` green (projection reference points, merge/dedupe, OSRM parser, validator rules).
- [ ] Counts printed: pois, narrations per lang, legs.
- [ ] Rebased on `origin/main`; PR opened with verified vs unverified list; `AI_WORKFLOW.md` row added.

**Verify.**
```bash
scripts/pack/build-pack.sh && shasum -a 256 entry/src/main/resources/rawfile/packs/krakow/*.json > /tmp/a
scripts/pack/build-pack.sh && shasum -a 256 entry/src/main/resources/rawfile/packs/krakow/*.json | diff - /tmp/a && echo DETERMINISTIC
node --test scripts/pack/ && du -sh entry/src/main/resources/rawfile/packs/krakow
```

**Starter prompt** (after `scripts/wt.sh new feat/pack-build` and `cd ../citytour-wt/pack-build && claude`):
```text
You are a Claude Code agent in the git worktree ../citytour-wt/pack-build (branch feat/pack-build) of CityTour, a native ArkTS/ArkUI HarmonyOS app (API 20 minimum, compiled against API 24, emulator "Pura 90"). First read AGENTS.md (including Team Flow), HACKATHON_BRIEF.md, AI_WORKFLOW.md, and in docs/PLAN.md: §0 and task card B2. Do task B2: the offline build half of the pack pipeline, docs/ARCHITECTURE.md §7.1 stages 4 and 6-9, §7.2 file list and §7.3 schemas (mirror contracts/Model.ets exactly in scripts/pack/schema.mjs). Read only data/raw and data/tours (no network). Use the projection of §3.2 and pin the three reference points listed in task A1 in a test. Implement the validator rules of §7.4 in 80-validate.mjs. Emit to entry/src/main/resources/rawfile/packs/krakow/ with a manifest (bytes + sha256) and keep builds byte-identical.

Rules (AGENTS.md Team Flow + docs/PLAN.md §0.3): edit only the files listed in your task card. Node 22+ ESM, stdlib only (no npm dependencies). Every network call sends a User-Agent, has a timeout, retries with backoff and respects the rate limit. The app build must never need the network: everything the pack build reads is committed under data/. No API keys in the repo, in logs or in committed files. Pipeline tests run with `node --test scripts/pack/` (scripts/test.sh runs them too). Commit after every small working step, push every 2-3 commits. Append one row to AI_WORKFLOW.md (task, what you generated, how it was verified). When done: `git fetch && git rebase origin/main`, run every command in the Verify block, open a PR with `gh pr create --base main` (body: 'Closes #<issue>' + verified vs unverified) and stop. Never merge to main.
```

<a id="b3"></a>

### B3 · App pack loader: PackParser, NarrationValidator, LangDetect, NarrationSelector, RawfilePackRepository + tests

| Owner | Branch | Priority | Estimate | Depends on | Lane | When |
|---|---|---|---|---|---|---|
| B | `feat/pack-loader` | P0 | 2.0 h | T0, B2 | headless + one emulator run | Sat 17:30-19:30, merge M4 19:40 |

**Goal.** The app reads the pack offline, re-validates every record and every narration (defence against bad AI output), and falls back by tier.

**Files (exclusive to this task).**
- `common/src/main/ets/core/content/PackParser.ets`
- `common/src/main/ets/core/content/NarrationValidator.ets`
- `common/src/main/ets/core/content/LangDetect.ets`
- `common/src/main/ets/core/content/NarrationSelector.ets`
- `entry/src/main/ets/services/pack/RawfilePackRepository.ets`
- `entry/src/main/ets/services/pack/NarrationRepository.ets`
- `entry/src/main/ets/services/pack/PackFactory.ets`
- `entry/src/test/PackParser.test.ets`
- `entry/src/test/NarrationValidator.test.ets`
- `entry/src/test/fixtures/PackJson.ets`

**Scope.**
- getRawFileContent + util.TextDecoder (verify exact decode method in docs), parse once at init, log PACK_LOAD ms= pois= narr= legs=.
- Runtime field validation, record drop with reason (PACK_DROP), blocking PACK_ERR on parse/schemaVersion/sha mismatch (ARCHITECTURE §9 row 17).
- NarrationValidator = same rules as 80-validate.mjs, memoised; fallback chain + persona fallback (§7.4-7.5), NARR_FALLBACK logs.
- Only the active text language narrations are loaded.

**Definition of Done.**
- [ ] Tests: valid reviewed EN passes; zh text in an en slot fails; invented year fails; "on your left" fails; 200-word teaser fails; missing reviewedBy fails; fallback returns SOURCE_EXTRACT with reason; malformed JSON -> PACK_ERR; unknown enum dropped.
- [ ] Emulator log shows PACK_LOAD with real counts in < 1500 ms.
- [ ] Rebased on `origin/main`; PR opened with verified vs unverified list; `AI_WORKFLOW.md` row added.

**Verify.**
```bash
source scripts/env.sh && devecocli check arkts && scripts/test.sh && devecocli build
devecocli run --device "Pura 90"; devecocli log --device "Pura 90" --bundle-name com.hackyeah.citytour --keyword CityTour --tail 300 | grep -E "PACK_LOAD|PACK_ERR|PACK_DROP"
```

**Starter prompt** (after `scripts/wt.sh new feat/pack-loader` and `cd ../citytour-wt/pack-loader && claude`):
```text
You are a Claude Code agent in the git worktree ../citytour-wt/pack-loader (branch feat/pack-loader) of CityTour, a native ArkTS/ArkUI HarmonyOS app (API 20 minimum, compiled against API 24, emulator "Pura 90"). First read AGENTS.md (including Team Flow), HACKATHON_BRIEF.md, AI_WORKFLOW.md, and in docs/PLAN.md: §0 and task card B3. Do task B3: core/content/{PackParser,NarrationValidator,LangDetect,NarrationSelector}.ets (pure) and services/pack/{RawfilePackRepository,NarrationRepository,PackFactory}.ets implementing contracts PackRepository, per docs/ARCHITECTURE.md §7.2-7.5 and §9 rows 17-18. The validator must give exactly the same verdicts as scripts/pack/80-validate.mjs; share expectations via entry/src/test/fixtures/PackJson.ets. Local tests cannot read rawfile, so tests use the typed fixture. Switch PackFactory to the real repository at the end.

Rules (AGENTS.md Team Flow + docs/PLAN.md §0.3): edit only the files listed in your task card; contracts/ is read-only (if a contract must change, stop and tell the human). Verify every Kit/API with `devecocli docs search <keywords>` / `devecocli docs read <id>` before using it and cite the doc id in the commit message; guard anything whose 起始版本 is above API 20 (compatibleSdkVersion is 6.0.0(20)). core/ stays pure (no @kit imports); State Management V2 only (no V1 decorators). Log only through app/Log.ets (domain 0xC17A, tag CityTour, `EVENT k=v`). Anything simulated shows SIMULATED on screen and src=demo in logs. Never crash: try/catch + Promise.catch at every platform call, explicit timeouts, a visible state for each failure. Run `devecocli check arkts` before each build. Commit after every small working step with a descriptive message, push every 2-3 commits. Add or extend unit tests and keep `scripts/test.sh` green. Append one row to AI_WORKFLOW.md (task, what you generated, how it was verified). Only one agent per Mac drives the emulator at a time: tell the human before `devecocli run`. When done: `git fetch && git rebase origin/main`, run every command in the card's Verify block, open a PR with `gh pr create --base main` (title = task id + title, body = 'Closes #<issue>' + verified vs unverified list) and stop. Never merge to main.
```

<a id="b4"></a>

### B4 · UI shell: Navigation host, Home, Tour detail, Route ready, Before-you-go sheet, tokens, ALL en strings

| Owner | Branch | Priority | Estimate | Depends on | Lane | When |
|---|---|---|---|---|---|---|
| B | `feat/ui-shell` | P0 | 3.0 h | T0 | emulator | Sat 15:15 (tokens/strings) -> 18:15, merge M3 18:30 |

**Goal.** The tap path the jury follows: Home -> Royal Route -> Route ready (optimised order) -> Start walking, plus a one-tap "Try demo walk".

**Files (exclusive to this task).**
- `entry/src/main/ets/pages/Index.ets`
- `entry/src/main/ets/pages/HomePage.ets`
- `entry/src/main/ets/pages/TourDetailPage.ets`
- `entry/src/main/ets/pages/RouteReadyPage.ets`
- `entry/src/main/ets/viewmodel/AppViewModel.ets`
- `entry/src/main/ets/viewmodel/HomeViewModel.ets`
- `entry/src/main/ets/viewmodel/TourPlanViewModel.ets`
- `entry/src/main/ets/views/common/SimulatedBadge.ets`
- `entry/src/main/ets/views/common/IssueBanner.ets`
- `entry/src/main/ets/views/common/StopList.ets`
- `entry/src/main/ets/views/common/Tokens.ets`
- `entry/src/main/resources/base/profile/main_pages.json`
- `entry/src/main/resources/base/profile/route_map.json`
- `entry/src/main/resources/base/element/{string,color,float}.json`
- `entry/src/main/resources/dark/element/color.json`
- `entry/src/main/resources/en_US/element/string.json`

**Scope.**
- Navigation + NavPathStack + NavDestinations (DESIGN §2.1-2.2), V2 state only. Tokens from DESIGN §4.1-4.5 as color resources (light + dark).
- Create EVERY en string key the app will need now (DESIGN §3 copy and §3.17: home_, tour_, route_, walk_, place_, settings_, onb_, err_, perm_, voice_ incl. `voice_fallback_badge` = "Fallback voice", `label_simulated`). A and B11 never invent keys later without asking B.
- Home: tour card + "Try demo walk" button `.id("btnDemoWalk")` (sets source DEMO x8, plans and starts, goes to NowWalking). Tour detail: stops from pack, "Start tour" `.id("btnStartTour")` -> permission check via AppContainer.permissions() (Flow D: denied -> "Try a demo walk instead"). Route ready: plan via TourControl.plan, "Optimised order: N m shorter" line, `.id("btnBegin")`. Before-you-go sheet `.id("btnStartWalking")` -> tourControl.start().
- Works against ScriptedTourControl until A7 lands; IssueBanner renders AppIssue codes; SimulatedBadge amber whenever snapshot.source is DEMO.

**Definition of Done.**
- [ ] Emulator click-through Home -> Tour detail (11 stops from the pack, or MiniPack before B3) -> Route ready -> sheet -> NowWalking placeholder, no crash; screenshots in docs/img/.
- [ ] `devecocli ui click --id btnDemoWalk` reaches NowWalking.
- [ ] Rebased on `origin/main`; PR opened with verified vs unverified list; `AI_WORKFLOW.md` row added.

**Verify.**
```bash
source scripts/env.sh && devecocli check arkts && devecocli build && scripts/test.sh
devecocli run --device "Pura 90" && devecocli ui click --device "Pura 90" --id btnDemoWalk
devecocli ui screenshot --device "Pura 90" --path docs/img/home.png
```

**Starter prompt** (after `scripts/wt.sh new feat/ui-shell` and `cd ../citytour-wt/ui-shell && claude`):
```text
You are a Claude Code agent in the git worktree ../citytour-wt/ui-shell (branch feat/ui-shell) of CityTour, a native ArkTS/ArkUI HarmonyOS app (API 20 minimum, compiled against API 24, emulator "Pura 90"). First read AGENTS.md (including Team Flow), HACKATHON_BRIEF.md, AI_WORKFLOW.md, and in docs/PLAN.md: §0 and task card B4. Do task B4: the ArkUI shell per docs/DESIGN.md §2 (IA and navigation rules), §3.2-3.5 (Home, Tour detail, Route ready, Before you go) and §4 (tokens), with MVVM + State Management V2 (docs/ARCHITECTURE.md §1.2: views talk only to viewmodels; viewmodels use contracts TourControl/PackRepository via AppContainer). Use the hmos-arkui-develop-skill and hmos-arkui-mvvm-pattern skills. Create all English string keys for every screen up front (list in the card). Give the controls the ids in the card (smoke tests click them). Until A7 lands, AppContainer.tourControl() is the ScriptedTourControl fake. Polish and Chinese translations are task B10, not now.

Rules (AGENTS.md Team Flow + docs/PLAN.md §0.3): edit only the files listed in your task card; contracts/ is read-only (if a contract must change, stop and tell the human). Verify every Kit/API with `devecocli docs search <keywords>` / `devecocli docs read <id>` before using it and cite the doc id in the commit message; guard anything whose 起始版本 is above API 20 (compatibleSdkVersion is 6.0.0(20)). core/ stays pure (no @kit imports); State Management V2 only (no V1 decorators). Log only through app/Log.ets (domain 0xC17A, tag CityTour, `EVENT k=v`). Anything simulated shows SIMULATED on screen and src=demo in logs. Never crash: try/catch + Promise.catch at every platform call, explicit timeouts, a visible state for each failure. Run `devecocli check arkts` before each build. Commit after every small working step with a descriptive message, push every 2-3 commits. Add or extend unit tests and keep `scripts/test.sh` green. Append one row to AI_WORKFLOW.md (task, what you generated, how it was verified). Only one agent per Mac drives the emulator at a time: tell the human before `devecocli run`. When done: `git fetch && git rebase origin/main`, run every command in the card's Verify block, open a PR with `gh pr create --base main` (title = task id + title, body = 'Closes #<issue>' + verified vs unverified list) and stop. Never merge to main.
```

<a id="b5"></a>

### B5 · Now Walking screen (all states) + Demo controls sheet + Look cue

| Owner | Branch | Priority | Estimate | Depends on | Lane | When |
|---|---|---|---|---|---|---|
| B | `feat/now-walking` | P0 | 2.5 h | B4 | emulator | Sat 18:15-19:40, merge M4 19:40; Look cue dial 20:30+ if ahead |

**Goal.** The glanceable mirror of the audio: where next, how far, which way, what am I hearing, pause/replay/skip; SIMULATED and Fallback voice visibly labelled.

**Files (exclusive to this task).**
- `entry/src/main/ets/pages/NowWalkingPage.ets`
- `entry/src/main/ets/viewmodel/NowWalkingViewModel.ets`
- `entry/src/main/ets/views/walk/NowPlayingCard.ets`
- `entry/src/main/ets/views/walk/NextStopBlock.ets`
- `entry/src/main/ets/views/walk/LookCue.ets`
- `entry/src/main/ets/views/walk/WalkControls.ets`
- `entry/src/main/ets/views/walk/DemoControlsSheet.ets`

**Scope.**
- DESIGN §3.6 layout and §3.6.2 states: Heading, Approaching, Arrived/story, Teaser, Paused, Reading (PL text-only: transcript first, controls replaced), Weak/No GPS, Complete. Map slot = placeholder until B6.
- VM subscribes to TourControl snapshots (unsubscribe in aboutToDisappear), @Computed display strings, distance rounding rules.
- Badges: amber SIMULATED pill (tap -> Demo controls: speed 1/2/4/8 via setDemoSpeed, Jump to next stop via demoJumpToNext, labelled "Demo assist") and a neutral "Fallback voice" chip when snapshot.voiceLabel is FALLBACK_ZH_READS_EN (tooltip: "English is read by the Chinese on-device voice; the English voice is not installed on this device").
- Look cue: P0 = caption text from relDir; P1 = the 72 vp dial (DESIGN §3.6.1).

**Definition of Done.**
- [ ] Every state renders with ScriptedTourControl (screenshot per state in docs/img/walk-*.png).
- [ ] With the real controller (after A7): distance and caption update live during the demo walk; pause/skip/replay buttons log USER_* events.
- [ ] Rebased on `origin/main`; PR opened with verified vs unverified list; `AI_WORKFLOW.md` row added.

**Verify.**
```bash
source scripts/env.sh && devecocli check arkts && devecocli build && scripts/test.sh
devecocli run --device "Pura 90" && devecocli ui click --device "Pura 90" --id btnDemoWalk
devecocli ui screenshot --device "Pura 90" --path docs/img/walk-heading.png
```

**Starter prompt** (after `scripts/wt.sh new feat/now-walking` and `cd ../citytour-wt/now-walking && claude`):
```text
You are a Claude Code agent in the git worktree ../citytour-wt/now-walking (branch feat/now-walking) of CityTour, a native ArkTS/ArkUI HarmonyOS app (API 20 minimum, compiled against API 24, emulator "Pura 90"). First read AGENTS.md (including Team Flow), HACKATHON_BRIEF.md, AI_WORKFLOW.md, and in docs/PLAN.md: §0 and task card B5. Do task B5: the Now Walking screen per docs/DESIGN.md §3.6, §3.6.1 and §3.6.2, bound to contracts EngineSnapshot through viewmodel/NowWalkingViewModel.ets. Build every state against ScriptedTourControl first. Show the SIMULATED pill whenever snapshot.source is DEMO and the "Fallback voice" chip whenever snapshot.voiceLabel is FALLBACK_ZH_READS_EN (user decision: English narration is read by the zh-CN voice and must be labelled). Leave a fixed-height slot for the mini map (task B6).

Rules (AGENTS.md Team Flow + docs/PLAN.md §0.3): edit only the files listed in your task card; contracts/ is read-only (if a contract must change, stop and tell the human). Verify every Kit/API with `devecocli docs search <keywords>` / `devecocli docs read <id>` before using it and cite the doc id in the commit message; guard anything whose 起始版本 is above API 20 (compatibleSdkVersion is 6.0.0(20)). core/ stays pure (no @kit imports); State Management V2 only (no V1 decorators). Log only through app/Log.ets (domain 0xC17A, tag CityTour, `EVENT k=v`). Anything simulated shows SIMULATED on screen and src=demo in logs. Never crash: try/catch + Promise.catch at every platform call, explicit timeouts, a visible state for each failure. Run `devecocli check arkts` before each build. Commit after every small working step with a descriptive message, push every 2-3 commits. Add or extend unit tests and keep `scripts/test.sh` green. Append one row to AI_WORKFLOW.md (task, what you generated, how it was verified). Only one agent per Mac drives the emulator at a time: tell the human before `devecocli run`. When done: `git fetch && git rebase origin/main`, run every command in the card's Verify block, open a PR with `gh pr create --base main` (title = task id + title, body = 'Closes #<issue>' + verified vs unverified list) and stop. Never merge to main.
```

<a id="b6"></a>

### B6 · Native Canvas vector map (mini map + full map) with PNG fallback

| Owner | Branch | Priority | Estimate | Depends on | Lane | When |
|---|---|---|---|---|---|---|
| B | `feat/map-canvas` | P0 | 3.5 h | B2, B5 | emulator | Sat 20:45-23:00 (gate G8 23:00), merge 23:00 or M6 |

**Goal.** Our own offline map (no Map Kit, no web view): route, numbered plaques, moving dot; amber hollow dot + SIMULATED chip in demo; OSM attribution.

**Files (exclusive to this task).**
- `entry/src/main/ets/views/map/MapCanvas.ets`
- `entry/src/main/ets/views/map/MapRenderer.ets`
- `entry/src/main/ets/views/map/MapStyle.ets`
- `entry/src/main/ets/viewmodel/MapViewModel.ets`
- `common/src/main/ets/core/map/Camera.ets`
- `entry/src/test/MapCamera.test.ets`
- `entry/src/main/ets/pages/MapPage.ets (P1 full map)`
- `entry/src/main/resources/rawfile/map/oldtown-light.png + oldtown-meta.json (fallback only)`

**Scope.**
- Step 1 (safe, ~1 h, P0): the overlay on Canvas (route legs, numbered plaques, user dot + accuracy ring, amber hollow dot + SIMULATED chip in demo, attribution) over a static base image = the lead's pre-rendered OSM map (scratchpad/design/preview.png or krakow-base-light.svg rasterised; bbox and projection in map-meta.json) copied to rawfile/map/. This alone satisfies gate G8.
- Step 2 (preferred): replace the base image by vector layers from map-detail.json. Start with a 30-min perf spike (throwaway exp/canvas-perf): draw all layers, pan, log `MAP_FRAME ms=`; keep the PNG base if > 33 ms and no mitigation works by 23:00.
- ARCHITECTURE §3.2: one Path2D per layer in world metres, setTransform camera, layer order, LOD thresholds, gesture-time reduced layers. Pack geometry is already projected; UserPos carries x/y, so the renderer needs no projection code. Camera math (fit-to-route, clamp, screen<->world) pure in core/map/Camera.ets with tests.
- Mini map in NowWalking (follow user, non-interactive) is P0; Tour detail preview P0; full map with pan/pinch/tap P1.
- Gate G8 23:00: whatever base is drawing then (vector or PNG) ships; no map work after 23:30.

**Definition of Done.**
- [ ] Mini map shows route, plaques and the moving demo dot during the demo walk; "© OpenStreetMap contributors" visible; MAP_FRAME < 33 ms while panning on the full map (or the fallback is in place and documented).
- [ ] MapCamera tests green.
- [ ] Rebased on `origin/main`; PR opened with verified vs unverified list; `AI_WORKFLOW.md` row added.

**Verify.**
```bash
source scripts/env.sh && devecocli check arkts && devecocli build && scripts/test.sh
devecocli run --device "Pura 90" && devecocli ui click --device "Pura 90" --id btnDemoWalk
devecocli log --device "Pura 90" --bundle-name com.hackyeah.citytour --keyword CityTour --tail 300 | grep MAP_FRAME | tail -5; devecocli ui screenshot --device "Pura 90" --path docs/img/walk-map.png
```

**Starter prompt** (after `scripts/wt.sh new feat/map-canvas` and `cd ../citytour-wt/map-canvas && claude`):
```text
You are a Claude Code agent in the git worktree ../citytour-wt/map-canvas (branch feat/map-canvas) of CityTour, a native ArkTS/ArkUI HarmonyOS app (API 20 minimum, compiled against API 24, emulator "Pura 90"). First read AGENTS.md (including Team Flow), HACKATHON_BRIEF.md, AI_WORKFLOW.md, and in docs/PLAN.md: §0 and task card B6. Do task B6: the native ArkUI Canvas map per docs/ARCHITECTURE.md §3 (decision, rendering, gestures, LOD) and docs/DESIGN.md §4.7-4.8 (plaques and map style). Work in two steps: first the overlay (route, plaques, user dot, SIMULATED chip, attribution) on a static base image so a working map exists early; then, after a 30-minute performance spike on the real map-detail.json, the vector base layers. Keep camera math pure in core/map/Camera.ets with tests. Gate G8 is 23:00: ship whichever base works then and document it.

Rules (AGENTS.md Team Flow + docs/PLAN.md §0.3): edit only the files listed in your task card; contracts/ is read-only (if a contract must change, stop and tell the human). Verify every Kit/API with `devecocli docs search <keywords>` / `devecocli docs read <id>` before using it and cite the doc id in the commit message; guard anything whose 起始版本 is above API 20 (compatibleSdkVersion is 6.0.0(20)). core/ stays pure (no @kit imports); State Management V2 only (no V1 decorators). Log only through app/Log.ets (domain 0xC17A, tag CityTour, `EVENT k=v`). Anything simulated shows SIMULATED on screen and src=demo in logs. Never crash: try/catch + Promise.catch at every platform call, explicit timeouts, a visible state for each failure. Run `devecocli check arkts` before each build. Commit after every small working step with a descriptive message, push every 2-3 commits. Add or extend unit tests and keep `scripts/test.sh` green. Append one row to AI_WORKFLOW.md (task, what you generated, how it was verified). Only one agent per Mac drives the emulator at a time: tell the human before `devecocli run`. When done: `git fetch && git rebase origin/main`, run every command in the card's Verify block, open a PR with `gh pr create --base main` (title = task id + title, body = 'Closes #<issue>' + verified vs unverified list) and stop. Never merge to main.
```

<a id="b7"></a>

### B7 · Historian scripts for the 11 stops: AI draft from sources -> human review -> zh/pl MT -> validate

| Owner | Branch | Priority | Estimate | Depends on | Lane | When |
|---|---|---|---|---|---|---|
| B | `feat/narration-review` | P0 | 3.0 h | B1, B2, B3 | headless + human review (~1 h) | Sat 20:45-00:30 (human review 22:00-22:45) |

**Goal.** Cited, human-reviewed English stories (teaser/full/deep) for each tour stop, plus labelled machine-translated zh and pl.

**Files (exclusive to this task).**
- `scripts/pack/prompts/historian-v1.md (public prompt)`
- `scripts/pack/review/<poiId>.{en,zh,pl}.md`
- `scripts/pack/70-narrate.mjs (reads review files into the pack)`
- `entry/src/main/resources/rawfile/packs/krakow/narrations/*.json (regenerated)`

**Scope.**
- The Claude Code agent drafts from the source texts in data/raw only (no outside facts); each draft lists claims with exact source quotes; provenance kind=llm, model=claude-opus-5-5, promptId=historian-v1. No API key needed or committed.
- Style: DESIGN §5.1 and §5.3; teaser 15-60 words, full 120-420, deep <= 900; sentences <= 45 words; no "on your left/right" (directions are computed at runtime); view hints (look up/down + feature) go into data/tours/royal-route.json for review.
- Human review: B reads all 11 EN files, edits, sets `reviewed: <initials> <date>`; A spot-checks 2. Unreviewed files cannot be emitted as tier reviewed (pipeline fails loudly).
- **Decision (Sat 2026-10-03): no human review this weekend.** All 11 stories ship as tier `grounded-ai`, labelled "AI-drafted from Wikipedia and city records" (pl/zh also "Machine-translated"). The review path stays in the pipeline for later.
- zh/pl translated from the reviewed EN (generatedBy mt, translatedFrom en), validated, labelled "machine-translated" in the UI; ask a Polish speaker at the venue to skim pl if possible.

**Definition of Done.**
- [ ] 11 stops x EN teaser + full (deep for >= 3) with reviewedBy; zh + pl present; 80-validate.mjs 0 failures; pack rebuilt deterministically.
- [ ] In the app PlaceDetail shows "Historian script · reviewed · N sources".
- [ ] Rebased on `origin/main`; PR opened with verified vs unverified list; `AI_WORKFLOW.md` row added.

**Verify.**
```bash
scripts/pack/build-pack.sh && node --test scripts/pack/ && jq '.summary' entry/src/main/resources/rawfile/packs/krakow/validation-report.json
```

**Starter prompt** (after `scripts/wt.sh new feat/narration-review` and `cd ../citytour-wt/narration-review && claude`):
```text
You are a Claude Code agent in the git worktree ../citytour-wt/narration-review (branch feat/narration-review) of CityTour, a native ArkTS/ArkUI HarmonyOS app (API 20 minimum, compiled against API 24, emulator "Pura 90"). First read AGENTS.md (including Team Flow), HACKATHON_BRIEF.md, AI_WORKFLOW.md, and in docs/PLAN.md: §0 and task card B7. Do task B7: write scripts/pack/prompts/historian-v1.md, then draft the Historian narrations for the 11 Royal Route stops into scripts/pack/review/<poiId>.en.md, strictly from the source texts in data/raw (Wikipedia summaries, register entries, Wikidata facts), following docs/ARCHITECTURE.md §7.1 (review loop), §7.4 (tiers, validator) and docs/DESIGN.md §5.1-5.3 (voice, script examples). Every factual sentence needs a claim with an exact quote. Do not mark anything reviewed: a human does that. After the human review, produce zh and pl machine translations and rebuild the pack.

Rules (AGENTS.md Team Flow + docs/PLAN.md §0.3): edit only the files listed in your task card. Node 22+ ESM, stdlib only (no npm dependencies). Every network call sends a User-Agent, has a timeout, retries with backoff and respects the rate limit. The app build must never need the network: everything the pack build reads is committed under data/. No API keys in the repo, in logs or in committed files. Pipeline tests run with `node --test scripts/pack/` (scripts/test.sh runs them too). Commit after every small working step, push every 2-3 commits. Append one row to AI_WORKFLOW.md (task, what you generated, how it was verified). When done: `git fetch && git rebase origin/main`, run every command in the Verify block, open a PR with `gh pr create --base main` (body: 'Closes #<issue>' + verified vs unverified) and stop. Never merge to main.
```

<a id="b8"></a>

### B8 · Place detail with sources, tier labels and AI disclosure; About & licences page

| Owner | Branch | Priority | Estimate | Depends on | Lane | When |
|---|---|---|---|---|---|---|
| B | `feat/place-detail` | P0 | 1.25 h | B3, B4 | emulator | Sat 23:00-00:30, merge M6 |

**Goal.** "Why should I trust this?" answered on screen: transcript, numbered sources with licences, how it was made; attribution obligations met.

**Files (exclusive to this task).**
- `entry/src/main/ets/pages/PlaceDetailPage.ets`
- `entry/src/main/ets/viewmodel/PlaceViewModel.ets`
- `entry/src/main/ets/views/place/SourcesList.ets`
- `entry/src/main/ets/views/place/TierLabel.ets`
- `entry/src/main/ets/views/place/LookBox.ets`
- `entry/src/main/ets/pages/AboutSourcesPage.ets`

**Scope.**
- DESIGN §3.8 (P1 polish: photos, facts) and §3.15. Tier labels from ARCHITECTURE §7.4. "Tell me more" -> TourControl.more() when the place is the current stop.
- About & licences: OSM ODbL + map attribution, Wikipedia CC BY-SA 4.0 (title + link + "Wikipedia contributors"), Wikidata CC0, Kraków ArcGIS terms (or UNVERIFIED), machine-translation note, AI disclosure text.

**Definition of Done.**
- [ ] Place detail for a tour stop (reviewed) and a non-tour POI ("From Wikipedia") render; About page lists all licences; screenshots.
- [ ] Rebased on `origin/main`; PR opened with verified vs unverified list; `AI_WORKFLOW.md` row added.

**Verify.**
```bash
source scripts/env.sh && devecocli check arkts && devecocli build && devecocli run --device "Pura 90"
devecocli ui screenshot --device "Pura 90" --path docs/img/place.png
```

**Starter prompt** (after `scripts/wt.sh new feat/place-detail` and `cd ../citytour-wt/place-detail && claude`):
```text
You are a Claude Code agent in the git worktree ../citytour-wt/place-detail (branch feat/place-detail) of CityTour, a native ArkTS/ArkUI HarmonyOS app (API 20 minimum, compiled against API 24, emulator "Pura 90"). First read AGENTS.md (including Team Flow), HACKATHON_BRIEF.md, AI_WORKFLOW.md, and in docs/PLAN.md: §0 and task card B8. Do task B8: PlaceDetail and an About & licences page per docs/DESIGN.md §3.8 and §3.15, docs/ARCHITECTURE.md §7.1 (licences) and §7.4 (tier labels), and docs/RISKS.md T14 (attribution obligations). Data comes from PackRepository (narration, sources). Keep it static and robust: missing narration shows the fallback tier label, never an empty screen.

Rules (AGENTS.md Team Flow + docs/PLAN.md §0.3): edit only the files listed in your task card; contracts/ is read-only (if a contract must change, stop and tell the human). Verify every Kit/API with `devecocli docs search <keywords>` / `devecocli docs read <id>` before using it and cite the doc id in the commit message; guard anything whose 起始版本 is above API 20 (compatibleSdkVersion is 6.0.0(20)). core/ stays pure (no @kit imports); State Management V2 only (no V1 decorators). Log only through app/Log.ets (domain 0xC17A, tag CityTour, `EVENT k=v`). Anything simulated shows SIMULATED on screen and src=demo in logs. Never crash: try/catch + Promise.catch at every platform call, explicit timeouts, a visible state for each failure. Run `devecocli check arkts` before each build. Commit after every small working step with a descriptive message, push every 2-3 commits. Add or extend unit tests and keep `scripts/test.sh` green. Append one row to AI_WORKFLOW.md (task, what you generated, how it was verified). Only one agent per Mac drives the emulator at a time: tell the human before `devecocli run`. When done: `git fetch && git rebase origin/main`, run every command in the card's Verify block, open a PR with `gh pr create --base main` (title = task id + title, body = 'Closes #<issue>' + verified vs unverified list) and stop. Never merge to main.
```

<a id="b9"></a>

### B9 · Settings: Demo walk toggle + speed, story language, voice (strategy + download), app language

| Owner | Branch | Priority | Estimate | Depends on | Lane | When |
|---|---|---|---|---|---|---|
| B | `feat/settings` | P0 | 1.25 h | B4, A4 | emulator | Sun 00:30-01:45, merge M7 02:45 |

**Goal.** Every simulation and fallback is user-visible and switchable, persisted across restarts.

**Files (exclusive to this task).**
- `entry/src/main/ets/pages/SettingsPage.ets`
- `entry/src/main/ets/viewmodel/SettingsViewModel.ets`
- `entry/src/main/ets/views/settings/*`

**Scope.**
- PersistenceV2 UserSettings (contracts/Settings.ets). P0 rows: Demo walk (simulated location) toggle + replay speed with the amber footnote; Story language (English spoken / 中文 spoken / Polski text only / Listen in English, read in Polish); Voice row showing the VoicePlan label ("Laura · Installed" | "Fallback voice · Chinese voice reads English" | "Text only") with "Download English voice" (VoiceManager, shows the emulator failure gracefully) and a strategy picker (Auto / Chinese voice / Text only); App language (System/English/Polski/中文 via B10).
- P1 rows: trigger distance 20/35/50 m, spoken directions toggle, permissions rows, About link.

**Definition of Done.**
- [ ] Toggling Demo walk logs LOC_SOURCE kind=demo/real on the next start and survives an app restart; changing the strategy logs VOICE_PLAN with the new label.
- [ ] Rebased on `origin/main`; PR opened with verified vs unverified list; `AI_WORKFLOW.md` row added.

**Verify.**
```bash
source scripts/env.sh && devecocli check arkts && devecocli build && devecocli run --device "Pura 90"
devecocli log --device "Pura 90" --bundle-name com.hackyeah.citytour --keyword CityTour --tail 300 | grep -E "SETTINGS|LOC_SOURCE|VOICE_PLAN"; devecocli ui screenshot --device "Pura 90" --path docs/img/settings.png
```

**Starter prompt** (after `scripts/wt.sh new feat/settings` and `cd ../citytour-wt/settings && claude`):
```text
You are a Claude Code agent in the git worktree ../citytour-wt/settings (branch feat/settings) of CityTour, a native ArkTS/ArkUI HarmonyOS app (API 20 minimum, compiled against API 24, emulator "Pura 90"). First read AGENTS.md (including Team Flow), HACKATHON_BRIEF.md, AI_WORKFLOW.md, and in docs/PLAN.md: §0 and task card B9. Do task B9: the Settings page per docs/DESIGN.md §3.11, persisted with PersistenceV2 (contracts/Settings.ets UserSettings), calling AppContainer.voice() and tourControl().setSource(). The voice row must show the active VoicePlan label honestly: by user decision, English is spoken by the zh-CN voice and labelled "Fallback voice" unless the real en-US voice is installed. Log `SETTINGS lang=... voice=... source=...` on change.

Rules (AGENTS.md Team Flow + docs/PLAN.md §0.3): edit only the files listed in your task card; contracts/ is read-only (if a contract must change, stop and tell the human). Verify every Kit/API with `devecocli docs search <keywords>` / `devecocli docs read <id>` before using it and cite the doc id in the commit message; guard anything whose 起始版本 is above API 20 (compatibleSdkVersion is 6.0.0(20)). core/ stays pure (no @kit imports); State Management V2 only (no V1 decorators). Log only through app/Log.ets (domain 0xC17A, tag CityTour, `EVENT k=v`). Anything simulated shows SIMULATED on screen and src=demo in logs. Never crash: try/catch + Promise.catch at every platform call, explicit timeouts, a visible state for each failure. Run `devecocli check arkts` before each build. Commit after every small working step with a descriptive message, push every 2-3 commits. Add or extend unit tests and keep `scripts/test.sh` green. Append one row to AI_WORKFLOW.md (task, what you generated, how it was verified). Only one agent per Mac drives the emulator at a time: tell the human before `devecocli run`. When done: `git fetch && git rebase origin/main`, run every command in the card's Verify block, open a PR with `gh pr create --base main` (title = task id + title, body = 'Closes #<issue>' + verified vs unverified list) and stop. Never merge to main.
```

<a id="b10"></a>

### B10 · i18n: Polish and Chinese UI strings + in-app language switch

| Owner | Branch | Priority | Estimate | Depends on | Lane | When |
|---|---|---|---|---|---|---|
| B | `feat/i18n` | P0 | 1.5 h | B4 | headless (translation) + emulator (switch) | Sat 23:30-01:30 (agent translation in the headless lane), merge M7 02:45 |

**Goal.** Acceptance check: UI in English, Polish and Chinese.

**Files (exclusive to this task).**
- `entry/src/main/resources/pl_PL/element/string.json`
- `entry/src/main/resources/zh_CN/element/string.json`
- `entry/src/main/resources/en_US/element/string.json`
- `entry/src/main/ets/viewmodel/AppViewModel.ets (language switch)`
- `scripts/pack/strings.test.mjs (key parity, runs under node --test)`

**Scope.**
- Translate every key (DESIGN §3.17 drafts first). `i18n.System.setAppPreferredLanguage("pl-PL" | "zh-Hans" | "en-US" | "default")`; verify the pl_PL folder resolves (spike S4) and fall back to getOverrideResourceManager if not.
- strings.test.mjs fails if any locale misses a base key or has an extra key.
- README: translations are machine-drafted; note who checked them.

**Definition of Done.**
- [ ] Screenshots of Home and Now Walking in pl and zh (docs/img/home-pl.png, home-zh.png); key-parity test green.
- [ ] Rebased on `origin/main`; PR opened with verified vs unverified list; `AI_WORKFLOW.md` row added.

**Verify.**
```bash
node --test scripts/pack/ && source scripts/env.sh && devecocli build && devecocli run --device "Pura 90"
devecocli ui screenshot --device "Pura 90" --path docs/img/home-pl.png
```

**Starter prompt** (after `scripts/wt.sh new feat/i18n` and `cd ../citytour-wt/i18n && claude`):
```text
You are a Claude Code agent in the git worktree ../citytour-wt/i18n (branch feat/i18n) of CityTour, a native ArkTS/ArkUI HarmonyOS app (API 20 minimum, compiled against API 24, emulator "Pura 90"). First read AGENTS.md (including Team Flow), HACKATHON_BRIEF.md, AI_WORKFLOW.md, and in docs/PLAN.md: §0 and task card B10. Do task B10: Polish and Chinese translations of every key in entry/src/main/resources/base/element/string.json into pl_PL and zh_CN (use docs/DESIGN.md §3.17 drafts; keep sentence case; no uppercase in zh), a key-parity test in scripts/pack/strings.test.mjs, and the in-app language switch per docs/ARCHITECTURE.md §8 (verify setAppPreferredLanguage in the docs and that pl_PL resolves).

Rules (AGENTS.md Team Flow + docs/PLAN.md §0.3): edit only the files listed in your task card; contracts/ is read-only (if a contract must change, stop and tell the human). Verify every Kit/API with `devecocli docs search <keywords>` / `devecocli docs read <id>` before using it and cite the doc id in the commit message; guard anything whose 起始版本 is above API 20 (compatibleSdkVersion is 6.0.0(20)). core/ stays pure (no @kit imports); State Management V2 only (no V1 decorators). Log only through app/Log.ets (domain 0xC17A, tag CityTour, `EVENT k=v`). Anything simulated shows SIMULATED on screen and src=demo in logs. Never crash: try/catch + Promise.catch at every platform call, explicit timeouts, a visible state for each failure. Run `devecocli check arkts` before each build. Commit after every small working step with a descriptive message, push every 2-3 commits. Add or extend unit tests and keep `scripts/test.sh` green. Append one row to AI_WORKFLOW.md (task, what you generated, how it was verified). Only one agent per Mac drives the emulator at a time: tell the human before `devecocli run`. When done: `git fetch && git rebase origin/main`, run every command in the card's Verify block, open a PR with `gh pr create --base main` (title = task id + title, body = 'Closes #<issue>' + verified vs unverified list) and stop. Never merge to main.
```

<a id="b11"></a>

### B11 · Tour summary

| Owner | Branch | Priority | Estimate | Depends on | Lane | When |
|---|---|---|---|---|---|---|
| B | `feat/summary` | P1 | 0.75 h | B5, A7 | emulator | Sun 01:45-02:30 if on track |

**Goal.** Close the loop: stops heard, distance, time, sources; "Simulated walk" note in demo mode.

**Files (exclusive to this task).**
- `entry/src/main/ets/pages/SummaryPage.ets`
- `entry/src/main/ets/viewmodel/SummaryViewModel.ets`

**Scope.**
- DESIGN §3.10; reached from Now Walking on FINISHED (foreground) or next open.

**Definition of Done.**
- [ ] Summary appears after the x8 demo walk finishes; screenshot.
- [ ] Rebased on `origin/main`; PR opened with verified vs unverified list; `AI_WORKFLOW.md` row added.

**Verify.**
```bash
source scripts/env.sh && devecocli check arkts && devecocli build && devecocli run --device "Pura 90"
```

**Starter prompt** (after `scripts/wt.sh new feat/summary` and `cd ../citytour-wt/summary && claude`):
```text
You are a Claude Code agent in the git worktree ../citytour-wt/summary (branch feat/summary) of CityTour, a native ArkTS/ArkUI HarmonyOS app (API 20 minimum, compiled against API 24, emulator "Pura 90"). First read AGENTS.md (including Team Flow), HACKATHON_BRIEF.md, AI_WORKFLOW.md, and in docs/PLAN.md: §0 and task card B11. Do task B11: the Tour summary page per docs/DESIGN.md §3.10, driven by the final EngineSnapshot (visited stops, walkedM, duration). In demo mode show "Simulated walk: distances and times come from a recorded route."

Rules (AGENTS.md Team Flow + docs/PLAN.md §0.3): edit only the files listed in your task card; contracts/ is read-only (if a contract must change, stop and tell the human). Verify every Kit/API with `devecocli docs search <keywords>` / `devecocli docs read <id>` before using it and cite the doc id in the commit message; guard anything whose 起始版本 is above API 20 (compatibleSdkVersion is 6.0.0(20)). core/ stays pure (no @kit imports); State Management V2 only (no V1 decorators). Log only through app/Log.ets (domain 0xC17A, tag CityTour, `EVENT k=v`). Anything simulated shows SIMULATED on screen and src=demo in logs. Never crash: try/catch + Promise.catch at every platform call, explicit timeouts, a visible state for each failure. Run `devecocli check arkts` before each build. Commit after every small working step with a descriptive message, push every 2-3 commits. Add or extend unit tests and keep `scripts/test.sh` green. Append one row to AI_WORKFLOW.md (task, what you generated, how it was verified). Only one agent per Mac drives the emulator at a time: tell the human before `devecocli run`. When done: `git fetch && git rebase origin/main`, run every command in the card's Verify block, open a PR with `gh pr create --base main` (title = task id + title, body = 'Closes #<issue>' + verified vs unverified list) and stop. Never merge to main.
```

<a id="b12"></a>

### B12 · "How it works" HUD overlay (live Kit status)

| Owner | Branch | Priority | Estimate | Depends on | Lane | When |
|---|---|---|---|---|---|---|
| B | `feat/hud` | P2 | 1.5 h | B5, A7 | emulator | only if ahead (first stretch item) |

**Goal.** Make every platform capability visible live during the demo.

**Files (exclusive to this task).**
- `entry/src/main/ets/views/walk/HowItWorksHud.ets`
- `entry/src/main/ets/pages/NowWalkingPage.ets (menu toggle)`

**Scope.**
- DESIGN §3.6 HUD block, values from snapshot.platform (PlatformStatus) and snapshot fields; nothing decorative.

**Definition of Done.**
- [ ] HUD shows source, course/speed, next/bearing, trigger, voice (incl. Fallback voice), AVSession, background state; screenshot.
- [ ] Rebased on `origin/main`; PR opened with verified vs unverified list; `AI_WORKFLOW.md` row added.

**Verify.**
```bash
source scripts/env.sh && devecocli build && devecocli run --device "Pura 90"
```

**Starter prompt** (after `scripts/wt.sh new feat/hud` and `cd ../citytour-wt/hud && claude`):
```text
You are a Claude Code agent in the git worktree ../citytour-wt/hud (branch feat/hud) of CityTour, a native ArkTS/ArkUI HarmonyOS app (API 20 minimum, compiled against API 24, emulator "Pura 90"). First read AGENTS.md (including Team Flow), HACKATHON_BRIEF.md, AI_WORKFLOW.md, and in docs/PLAN.md: §0 and task card B12. Do task B12: the "How it works" HUD per docs/DESIGN.md §3.6 (HUD block) and docs/OPPORTUNITIES.md §3.2, reading only real values from EngineSnapshot.platform and the snapshot. If a value is unavailable, show "n/a", never a made-up value.

Rules (AGENTS.md Team Flow + docs/PLAN.md §0.3): edit only the files listed in your task card; contracts/ is read-only (if a contract must change, stop and tell the human). Verify every Kit/API with `devecocli docs search <keywords>` / `devecocli docs read <id>` before using it and cite the doc id in the commit message; guard anything whose 起始版本 is above API 20 (compatibleSdkVersion is 6.0.0(20)). core/ stays pure (no @kit imports); State Management V2 only (no V1 decorators). Log only through app/Log.ets (domain 0xC17A, tag CityTour, `EVENT k=v`). Anything simulated shows SIMULATED on screen and src=demo in logs. Never crash: try/catch + Promise.catch at every platform call, explicit timeouts, a visible state for each failure. Run `devecocli check arkts` before each build. Commit after every small working step with a descriptive message, push every 2-3 commits. Add or extend unit tests and keep `scripts/test.sh` green. Append one row to AI_WORKFLOW.md (task, what you generated, how it was verified). Only one agent per Mac drives the emulator at a time: tell the human before `devecocli run`. When done: `git fetch && git rebase origin/main`, run every command in the card's Verify block, open a PR with `gh pr create --base main` (title = task id + title, body = 'Closes #<issue>' + verified vs unverified list) and stop. Never merge to main.
```

<a id="b13"></a>

### B13 · All-places layer on the full map + place card (Explore, basic)

| Owner | Branch | Priority | Estimate | Depends on | Lane | When |
|---|---|---|---|---|---|---|
| B | `feat/explore-layer` | P2 | 2.0 h | B6, B8 | emulator | only if ahead |

**Goal.** Show that "all Kraków locations are installed": dots for every POI with a sourced summary.

**Files (exclusive to this task).**
- `entry/src/main/ets/pages/MapPage.ets`
- `entry/src/main/ets/views/map/PoiLayer.ets`
- `entry/src/main/ets/views/map/PlaceCardSheet.ets`

**Scope.**
- DESIGN §3.7 explore variant (dots by importance/LOD, UNESCO outline, place card -> PlaceDetail). Uses GridIndex (A1).

**Definition of Done.**
- [ ] Full map shows all POI dots with culling; tapping one opens its card; screenshot.
- [ ] Rebased on `origin/main`; PR opened with verified vs unverified list; `AI_WORKFLOW.md` row added.

**Verify.**
```bash
source scripts/env.sh && devecocli build && devecocli run --device "Pura 90"
```

**Starter prompt** (after `scripts/wt.sh new feat/explore-layer` and `cd ../citytour-wt/explore-layer && claude`):
```text
You are a Claude Code agent in the git worktree ../citytour-wt/explore-layer (branch feat/explore-layer) of CityTour, a native ArkTS/ArkUI HarmonyOS app (API 20 minimum, compiled against API 24, emulator "Pura 90"). First read AGENTS.md (including Team Flow), HACKATHON_BRIEF.md, AI_WORKFLOW.md, and in docs/PLAN.md: §0 and task card B13. Do task B13: the explore layer of the full map per docs/DESIGN.md §3.7, drawing every POI from the pack with LOD and viewport culling (core/geo/GridIndex), and a place card sheet that opens PlaceDetail.

Rules (AGENTS.md Team Flow + docs/PLAN.md §0.3): edit only the files listed in your task card; contracts/ is read-only (if a contract must change, stop and tell the human). Verify every Kit/API with `devecocli docs search <keywords>` / `devecocli docs read <id>` before using it and cite the doc id in the commit message; guard anything whose 起始版本 is above API 20 (compatibleSdkVersion is 6.0.0(20)). core/ stays pure (no @kit imports); State Management V2 only (no V1 decorators). Log only through app/Log.ets (domain 0xC17A, tag CityTour, `EVENT k=v`). Anything simulated shows SIMULATED on screen and src=demo in logs. Never crash: try/catch + Promise.catch at every platform call, explicit timeouts, a visible state for each failure. Run `devecocli check arkts` before each build. Commit after every small working step with a descriptive message, push every 2-3 commits. Add or extend unit tests and keep `scripts/test.sh` green. Append one row to AI_WORKFLOW.md (task, what you generated, how it was verified). Only one agent per Mac drives the emulator at a time: tell the human before `devecocli run`. When done: `git fetch && git rebase origin/main`, run every command in the card's Verify block, open a PR with `gh pr create --base main` (title = task id + title, body = 'Closes #<issue>' + verified vs unverified list) and stop. Never merge to main.
```

<a id="b14"></a>

### B14 · Form Kit "Next stop" widget

| Owner | Branch | Priority | Estimate | Depends on | Lane | When |
|---|---|---|---|---|---|---|
| B | `cap/widget` | P2 | 3.0 h | A7 | emulator | only if everything else is green |

**Goal.** A 2x2 home-screen card with next stop, distance and progress.

**Files (exclusive to this task).**
- `entry/src/main/ets/formability/EntryFormAbility.ets`
- `entry/src/main/ets/widget/pages/NextStopCard.ets`
- `entry/src/main/resources/base/profile/form_config.json`
- `entry/src/main/module.json5 (A applies the extensionAbilities entry in a tiny fix/module-form branch)`

**Scope.**
- ARCHITECTURE §2.8 Form widget; updateForm pushed from TourController on stop change (A adds the call).

**Definition of Done.**
- [ ] Widget added on the emulator home screen updates on stop change during the demo walk.
- [ ] Rebased on `origin/main`; PR opened with verified vs unverified list; `AI_WORKFLOW.md` row added.

**Verify.**
```bash
source scripts/env.sh && devecocli build && devecocli run --device "Pura 90"
```

**Starter prompt** (after `scripts/wt.sh new cap/widget` and `cd ../citytour-wt/widget && claude`):
```text
You are a Claude Code agent in the git worktree ../citytour-wt/widget (branch cap/widget) of CityTour, a native ArkTS/ArkUI HarmonyOS app (API 20 minimum, compiled against API 24, emulator "Pura 90"). First read AGENTS.md (including Team Flow), HACKATHON_BRIEF.md, AI_WORKFLOW.md, and in docs/PLAN.md: §0 and task card B14. Do task B14: a Form Kit ArkTS widget per docs/ARCHITECTURE.md §2.8 and docs/DESIGN.md §3.13. module.json5 belongs to A: write the exact extensionAbilities snippet in your PR description and ask the human to have A apply it in a separate tiny branch.

Rules (AGENTS.md Team Flow + docs/PLAN.md §0.3): edit only the files listed in your task card; contracts/ is read-only (if a contract must change, stop and tell the human). Verify every Kit/API with `devecocli docs search <keywords>` / `devecocli docs read <id>` before using it and cite the doc id in the commit message; guard anything whose 起始版本 is above API 20 (compatibleSdkVersion is 6.0.0(20)). core/ stays pure (no @kit imports); State Management V2 only (no V1 decorators). Log only through app/Log.ets (domain 0xC17A, tag CityTour, `EVENT k=v`). Anything simulated shows SIMULATED on screen and src=demo in logs. Never crash: try/catch + Promise.catch at every platform call, explicit timeouts, a visible state for each failure. Run `devecocli check arkts` before each build. Commit after every small working step with a descriptive message, push every 2-3 commits. Add or extend unit tests and keep `scripts/test.sh` green. Append one row to AI_WORKFLOW.md (task, what you generated, how it was verified). Only one agent per Mac drives the emulator at a time: tell the human before `devecocli run`. When done: `git fetch && git rebase origin/main`, run every command in the card's Verify block, open a PR with `gh pr create --base main` (title = task id + title, body = 'Closes #<issue>' + verified vs unverified list) and stop. Never merge to main.
```

<a id="s1"></a>

### S1 · Docs upkeep: README, ARCHITECTURE deltas, AI_WORKFLOW, ATTRIBUTION (continuous)

| Owner | Branch | Priority | Estimate | Depends on | Lane | When |
|---|---|---|---|---|---|---|
| both | `docs/<topic> or direct small commits on main` | P0 | 2.5 h | none | headless | at every merge window; milestones 19:30, 03:00 (B), 07:00 (A), 09:15 final |

**Goal.** The README is the jury's first screen; every claim links to code, a log line or a test.

**Files (exclusive to this task).**
- `README.md (sections by owner, see PLAN §4)`
- `docs/ARCHITECTURE.md (deltas: voice strategy, ownership changes, map fallback if used)`
- `AI_WORKFLOW.md`
- `data/ATTRIBUTION.md`
- `docs/img/*`

**Scope.**
- README order of OPPORTUNITIES §6.2. A owns: Platform capabilities used (Kit, API, file link, emulator status), Mocked or simulated behavior (Demo walk; Fallback voice; emulator does not freeze apps), Testing, Error handling, First launch on a fresh emulator (location switch, voice note, `hdc install` of the unsigned HAP). B owns: Data sources & licences, Languages, Screenshots, Known limitations (Polish text-only; China-region Kits; machine-translated zh/pl).
- AI_WORKFLOW: tools table (Claude Code Opus 5.5, devecocli, skills), important prompts (link scripts/pack/prompts/historian-v1.md), one row per merged task (union merge driver keeps both sides), unsuccessful approaches (Laura download, Overpass down, CLI geolocation), lessons.

**Definition of Done.**
- [ ] README renders on GitHub with working links; every capability row links to a file; AI_WORKFLOW has a row per merged task.
- [ ] Rebased on `origin/main`; PR opened with verified vs unverified list; `AI_WORKFLOW.md` row added.

**Verify.**
```bash
grep -c "^| " AI_WORKFLOW.md; grep -n "Mocked or simulated" -A 12 README.md
```

**Starter prompt.**
```text
You are a Claude Code agent in the git worktree ../citytour-wt/readme-pass (branch docs/readme-pass) of CityTour, a native ArkTS/ArkUI HarmonyOS app (API 20 minimum, compiled against API 24, emulator "Pura 90"). First read AGENTS.md (including Team Flow), HACKATHON_BRIEF.md, AI_WORKFLOW.md, and in docs/PLAN.md: §0 and task card S1. Do task S1 for the current milestone: bring README.md, docs/ARCHITECTURE.md (only factual deltas) and AI_WORKFLOW.md in line with what is merged on main right now. Check every claim against the code and the logs; link each platform capability to its file. Never describe unmerged or unverified features as working; mark them planned or unverified.

Rules (AGENTS.md Team Flow + docs/PLAN.md §0.3): edit only the files listed in your task card. Node 22+ ESM, stdlib only (no npm dependencies). Every network call sends a User-Agent, has a timeout, retries with backoff and respects the rate limit. The app build must never need the network: everything the pack build reads is committed under data/. No API keys in the repo, in logs or in committed files. Pipeline tests run with `node --test scripts/pack/` (scripts/test.sh runs them too). Commit after every small working step, push every 2-3 commits. Append one row to AI_WORKFLOW.md (task, what you generated, how it was verified). When done: `git fetch && git rebase origin/main`, run every command in the Verify block, open a PR with `gh pr create --base main` (body: 'Closes #<issue>' + verified vs unverified) and stop. Never merge to main.
```

<a id="s2"></a>

### S2 · 20:00 checkpoint upload

| Owner | Branch | Priority | Estimate | Depends on | Lane | When |
|---|---|---|---|---|---|---|
| both | `none (tag checkpoint-good on main)` | P0 | 0.5 h | T0, B4 | human | Sat 19:40-20:00 |

**Goal.** Upload a working, honest snapshot at 20:00 whatever state the slice is in.

**Files (exclusive to this task).**
- none (tag + upload)

**Scope.**
- A: after M4, `scripts/test.sh`, `devecocli build`, smoke, `git tag checkpoint-good && git push --tags`, copy the unsigned HAP and its sha256.
- B: upload to HackTribe the checkpoint fields (confirm them by 18:00): repo URL, short description, .hap (or release link), 1-3 screenshots, optional 30-60 s safety clip.
- If gate G5 (vertical slice at 19:00) failed: the checkpoint shows the Demo controls "Jump to next stop" (labelled Demo assist) driving the same trigger path.

**Definition of Done.**
- [ ] Upload confirmed by 20:00; tag pushed.

**Verify.**
```bash
git tag --list "checkpoint-*"; ls -l entry/build/default/outputs/default/*.hap && shasum -a 256 entry/build/default/outputs/default/*.hap
```

**Starter prompt.**
```text
Human task; no agent prompt. Optional helper prompt: "Run scripts/test.sh, devecocli build and scripts/smoke.sh on main, then print the HAP path, size and sha256 and a 5-line summary of what works on main for the checkpoint description. Do not commit anything."
```

<a id="s3"></a>

### S3 · System-audio capture test for the demo recording (gate G6 20:30)

| Owner | Branch | Priority | Estimate | Depends on | Lane | When |
|---|---|---|---|---|---|---|
| A | `none` | P0 | 0.5 h | A4 | human | Sat 20:00-20:30 on the recording Mac (A's) |

**Goal.** The whole product is a voice: prove we can record the emulator's TTS together with the screen.

**Files (exclusive to this task).**
- none (clip stays local; never commit video)

**Scope.**
- Neither OBS nor BlackHole is installed on the lead's Mac (checked). The human installs OBS Studio (official obsproject.com download) and records a 30 s clip: emulator window + macOS audio capture while the DevPanel "EN sample" plays.
- Play it back: voice audible? If not, try BlackHole 2ch as output + OBS input. Fallback (RISKS S3): phone microphone near the Mac speaker, synced by hand, disclosed.

**Definition of Done.**
- [ ] A 30 s test clip with audible narration exists; OBS scene "CityTour demo" saved (emulator left, log terminal right).

**Verify.**
```bash
# play the clip in QuickTime and listen; check the audio track exists:
mdls -name kMDItemAudioChannelCount ~/Movies/<clip>.mov
```

**Starter prompt.**
```text
Human task. Optional helper prompt: "Give me exact step-by-step OBS Studio settings on macOS 15 to capture one window plus system audio (ScreenCaptureKit macOS Audio Capture source), a 1920x1080 canvas with the emulator on the left 40% and a terminal on the right, and how to verify the audio track. Do not install anything yourself."
```

<a id="s4"></a>

### S4 · Release artifact and signing hygiene (unsigned HAP from a tag; device signing only if a device appears)

| Owner | Branch | Priority | Estimate | Depends on | Lane | When |
|---|---|---|---|---|---|---|
| A | `none (tag v1.0-hackyeah)` | P0 | 0.5 h | T1 | human + headless | Sun 06:00 decision (G10), 09:00-09:30 release |

**Goal.** A working .hap the jury can install on the emulator, and zero signing material in the public repo.

**Files (exclusive to this task).**
- `README.md "Install the release HAP" (via S1)`

**Scope.**
- Release = `entry-default-unsigned.hap` built from tag v1.0-hackyeah (verified installable on the emulator, RISKS e1); attach to a GitHub release with sha256: `gh release create v1.0-hackyeah <hap> --notes ...`.
- Only if a mentor device is in hand by Sun 06:00: `devecocli signature generate` (needs `devecocli auth` login) writes signingConfigs into build-profile.json5 locally; build, install, then `git checkout -- build-profile.json5`; the pre-commit hook (T1) blocks accidental commits. Keep materials outside the repo.
- Clean-clone check: `git clone https://github.com/Svetoslav47/citytour /tmp/ct-clean && cd /tmp/ct-clean && devecocli build`.

**Definition of Done.**
- [ ] GitHub release exists with HAP + sha256; clean clone builds; `git log --all -p | grep -n "signingConfigs\": \[ *{"` returns nothing; `git ls-files | grep -E "\.(p12|p7b|cer|csr)$"` returns nothing.

**Verify.**
```bash
git ls-files | grep -E "\.(p12|p7b|cer|csr|keystore)$" ; git log --all -p -- build-profile.json5 | grep -n "storePassword" ; echo "(both must print nothing)"
HDC=/Applications/DevEco-Studio.app/Contents/sdk/default/openharmony/toolchains/hdc; $HDC -t 127.0.0.1:5555 install -r entry/build/default/outputs/default/entry-default-unsigned.hap
```

**Starter prompt.**
```text
Helper prompt: "On main at tag v1.0-hackyeah: run scripts/test.sh, devecocli build, then install the unsigned HAP with hdc on the Pura 90 emulator after uninstalling the app, launch it, and confirm Smoke-equivalent startup in the logs. Then verify no signing material or signingConfigs content exists in git history (commands in docs/PLAN.md task S4). Report; do not create the release yourself."
```

<a id="s5"></a>

### S5 · Demo video: rehearsal, recording (Sun 07:30-09:00), <= 60 s cut

| Owner | Branch | Priority | Estimate | Depends on | Lane | When |
|---|---|---|---|---|---|---|
| both | `none` | P0 | 2.0 h | S3, A7, B5 | human | Rehearsal Sun 06:00-07:00 (A), record 07:30-09:00 (both), cut 09:00-09:30 (B) |

**Goal.** A <= 60 s video that shows the app really running on the emulator with its real voice, labels what is simulated, and says what was built this weekend.

**Files (exclusive to this task).**
- none in git (video uploaded to HackTribe / YouTube unlisted; README links it)

**Scope.**
- Storyboard (adapted from OPPORTUNITIES §1.3): 0-5 s title "A guide in your pocket"; 5-15 Home -> Royal Route -> Route ready "optimised order, Held-Karp, N m shorter"; 15-22 Start walking, SIMULATED pill + Fallback voice chip visible; 22-40 screen locked (`hdc shell power-shell suspend`), narration audio continues, log pane scrolls POI_ENTER / STORY_START / LOC_FIX src=demo; 40-48 wake -> lock-screen AVSession card, pause/next; 48-55 Place detail sources + "reviewed"; 55-60 end card: "Built at HackYeah 2026 · real: TTS, background, AVSession, routing, data · simulated: location replay" + repo URL.
- Two full takes; keep the best; captions burned in. Record a safety take on Saturday evening if the slice works.

**Definition of Done.**
- [ ] <= 60 s MP4 1080p with audible narration and visible SIMULATED label; uploaded; link in README.

**Verify.**
```bash
# duration check (QuickTime > Window > Show Movie Inspector), must be <= 60 s
```

**Starter prompt.**
```text
Human task. Optional helper prompt for the rehearsal: "Prepare the emulator for the demo: uninstall and reinstall the app from main with devecocli run --device \"Pura 90\" --uninstall, enable the location switch, then print the exact sequence of devecocli/hdc commands (power-shell suspend/wakeup, log follow with keyword CityTour) for the recording script. Do not change code."
```

<a id="s6"></a>

### S6 · HackTribe submission package (<= 10-slide PDF, <= 60 s video, <= 500-word EN description, screenshots, Discord IDs)

| Owner | Branch | Priority | Estimate | Depends on | Lane | When |
|---|---|---|---|---|---|---|
| both | `docs/submission` | P0 | 1.5 h | S5, S4 | human + headless | A drafts description + slides Sun 04:30-05:30; B finalises 09:00-09:45 with the video; uploaded by 10:00 |

**Goal.** Everything the jury and the platform need, uploaded by 10:00 with an hour of buffer.

**Files (exclusive to this task).**
- `docs/submission/description.md (<= 500 words, public)`
- `docs/submission/slides.pdf (<= 10 slides)`
- `docs/img/*.png (screenshots)`

**Scope.**
- Slides (8-10): problem; solution + 1 screenshot; demo still; how it works (pipeline diagram ARCHITECTURE §1.1 / OPPORTUNITIES §3.3); platform capabilities table; sovereignty/open data; trust: sources + AI review + validator; tests and evidence; real vs simulated + limits; roadmap.
- Description <= 500 words EN (`wc -w`); repo URL; release link; video link; challenge Huawei "Imagine What's Next"; lead theme Spatial Experiences.
- Both members' Discord IDs entered on HackTribe (collect in the first 30 min; NEVER commit them).
- The user approves the first-minute narrative (HACKATHON_BRIEF field) before 03:00.

**Definition of Done.**
- [ ] HackTribe shows the submission complete by 10:00 (screenshot of the confirmation kept locally).

**Verify.**
```bash
wc -w docs/submission/description.md   # <= 500
mdls -name kMDItemNumberOfPages docs/submission/slides.pdf   # <= 10
```

**Starter prompt** (after `scripts/wt.sh new docs/submission` and `cd ../citytour-wt/submission && claude`):
```text
Helper prompt: "Draft docs/submission/description.md (<= 500 words, English) and a 10-slide outline from README.md, docs/OPPORTUNITIES.md §1 and §3 and docs/RISKS.md §6, describing ONLY what is merged on main and verified (read the code and README). Mark anything simulated as simulated. Print `wc -w`. Commit on branch docs/submission."
```

<a id="x1"></a>

### X1 · "I have N minutes" (orienteering) on Route ready

| Owner | Branch | Priority | Estimate | Depends on | Lane | When |
|---|---|---|---|---|---|---|
| B | `feat/time-budget` | P2 | 1.0 h | A2, B4, A7 | emulator | only if ahead |

**Goal.** Time-boxed optimal subset, solved exactly (A2 already ships solveOrienteering).

**Files (exclusive to this task).**
- `entry/src/main/ets/pages/RouteReadyPage.ets`
- `entry/src/main/ets/viewmodel/TourPlanViewModel.ets`

**Scope.**
- Segmented "All stops | 45 min | 90 min" calling TourControl.plan(tourId, budgetMin); show "Best {k} of 11 stops · {d} km · solved exactly in {ms} ms (values computed at runtime; the full route is 2.5 km)".

**Definition of Done.**
- [ ] Changing the budget re-plans instantly; ROUTE_PLAN log shows budget and chosen stops.
- [ ] Rebased on `origin/main`; PR opened with verified vs unverified list; `AI_WORKFLOW.md` row added.

**Verify.**
```bash
source scripts/env.sh && devecocli build && devecocli run --device "Pura 90"
```

**Starter prompt** (after `scripts/wt.sh new feat/time-budget` and `cd ../citytour-wt/time-budget && claude`):
```text
You are a Claude Code agent in the git worktree ../citytour-wt/time-budget (branch feat/time-budget) of CityTour, a native ArkTS/ArkUI HarmonyOS app (API 20 minimum, compiled against API 24, emulator "Pura 90"). First read AGENTS.md (including Team Flow), HACKATHON_BRIEF.md, AI_WORKFLOW.md, and in docs/PLAN.md: §0 and task card X1. Do task X1: add the time-budget control to Route ready per docs/DESIGN.md §3.4 and docs/ARCHITECTURE.md §6.3, calling the existing TourControl.plan(tourId, budgetMin).

Rules (AGENTS.md Team Flow + docs/PLAN.md §0.3): edit only the files listed in your task card; contracts/ is read-only (if a contract must change, stop and tell the human). Verify every Kit/API with `devecocli docs search <keywords>` / `devecocli docs read <id>` before using it and cite the doc id in the commit message; guard anything whose 起始版本 is above API 20 (compatibleSdkVersion is 6.0.0(20)). core/ stays pure (no @kit imports); State Management V2 only (no V1 decorators). Log only through app/Log.ets (domain 0xC17A, tag CityTour, `EVENT k=v`). Anything simulated shows SIMULATED on screen and src=demo in logs. Never crash: try/catch + Promise.catch at every platform call, explicit timeouts, a visible state for each failure. Run `devecocli check arkts` before each build. Commit after every small working step with a descriptive message, push every 2-3 commits. Add or extend unit tests and keep `scripts/test.sh` green. Append one row to AI_WORKFLOW.md (task, what you generated, how it was verified). Only one agent per Mac drives the emulator at a time: tell the human before `devecocli run`. When done: `git fetch && git rebase origin/main`, run every command in the card's Verify block, open a PR with `gh pr create --base main` (title = task id + title, body = 'Closes #<issue>' + verified vs unverified list) and stop. Never merge to main.
```

<a id="x2"></a>

### X2 · Mid-tour language switch EN <-> 中文 (voice + captions)

| Owner | Branch | Priority | Estimate | Depends on | Lane | When |
|---|---|---|---|---|---|---|
| both | `feat/live-language` | P2 | 1.0 h | A7, B5 | emulator | only if ahead |

**Goal.** Wow moment: the same stop continues in the Chinese voice; captions follow.

**Files (exclusive to this task).**
- `common/src/main/ets/control/TourController.ets (A: setTextLang)`
- `entry/src/main/ets/pages/NowWalkingPage.ets (B: menu item)`

**Scope.**
- A adds a contract method via a tiny feat/contracts-lang branch first, then the controller switch at the next sentence boundary; B adds the ⋯ menu item.

**Definition of Done.**
- [ ] Switch mid-story continues at the next sentence in the other language; VOICE_PLAN logged.
- [ ] Rebased on `origin/main`; PR opened with verified vs unverified list; `AI_WORKFLOW.md` row added.

**Verify.**
```bash
source scripts/env.sh && devecocli build && devecocli run --device "Pura 90"
```

**Starter prompt** (after `scripts/wt.sh new feat/live-language` and `cd ../citytour-wt/live-language && claude`):
```text
You are a Claude Code agent in the git worktree ../citytour-wt/live-language (branch feat/live-language) of CityTour, a native ArkTS/ArkUI HarmonyOS app (API 20 minimum, compiled against API 24, emulator "Pura 90"). First read AGENTS.md (including Team Flow), HACKATHON_BRIEF.md, AI_WORKFLOW.md, and in docs/PLAN.md: §0 and task card X2. Do task X2: mid-tour narration language switch at the next sentence boundary (docs/DESIGN.md §3.6 menu, docs/OPPORTUNITIES.md wow #3). Contract change first, in its own tiny branch, reviewed by the other person.

Rules (AGENTS.md Team Flow + docs/PLAN.md §0.3): edit only the files listed in your task card; contracts/ is read-only (if a contract must change, stop and tell the human). Verify every Kit/API with `devecocli docs search <keywords>` / `devecocli docs read <id>` before using it and cite the doc id in the commit message; guard anything whose 起始版本 is above API 20 (compatibleSdkVersion is 6.0.0(20)). core/ stays pure (no @kit imports); State Management V2 only (no V1 decorators). Log only through app/Log.ets (domain 0xC17A, tag CityTour, `EVENT k=v`). Anything simulated shows SIMULATED on screen and src=demo in logs. Never crash: try/catch + Promise.catch at every platform call, explicit timeouts, a visible state for each failure. Run `devecocli check arkts` before each build. Commit after every small working step with a descriptive message, push every 2-3 commits. Add or extend unit tests and keep `scripts/test.sh` green. Append one row to AI_WORKFLOW.md (task, what you generated, how it was verified). Only one agent per Mac drives the emulator at a time: tell the human before `devecocli run`. When done: `git fetch && git rebase origin/main`, run every command in the card's Verify block, open a PR with `gh pr create --base main` (title = task id + title, body = 'Closes #<issue>' + verified vs unverified list) and stop. Never merge to main.
```


---

## 3. Timeline (Sat 14:45 → Sun 11:00)

### 3.1 Decision gates (from RISKS §4, re-timed to this plan)

| When | Gate | Owner | If not met |
|---|---|---|---|
| **Sat 15:30** | **G1:** a human listens to the zh voice reading English (T2) | A | Default to `AUTO_NATIVE_THEN_TEXT` (English text-only). The user updates the brief's acceptance check. |
| 15:45 (≤ 16:30) | **G2:** T0 + T1 on `main` | A, B merges | Everyone stops feature work until it lands. |
| 17:00 | **G3:** mentors asked: a device? the Laura voice? which region? | B (10 min) | Assume emulator-only; README says so. |
| 18:00 | **G4:** pack committed: stops, OSRM matrix and legs, sources, raw snapshots | B | Hand-curated 11 stops + 395 ArcGIS monuments + haversine × 1.3, labelled in SOURCES.md. |
| 19:00 | **G5:** vertical slice: Demo walk → arrival → narration spoken (Fallback voice) → caption shown | A + B | The checkpoint shows Demo controls "Jump to next stop" (labelled *Demo assist*) driving the same trigger path. |
| **20:00** | **Checkpoint upload** (S2) | B uploads, A builds | Upload whatever is tagged `checkpoint-good`. |
| 20:30 | **G6:** system-audio recording works (S3) | A | Phone-mic fallback, disclosed. |
| 22:00 | **G7:** PCM queue stable, AVSession wired into the tour, hysteresis tests green | A | `USE_SYSTEM_PLAYBACK = true` (playType 1); AVSession pause calls `engine.stop()`. |
| 23:00 | **G8:** map shows route, stops and the moving dot | B | Ship the PNG base (step 1 of B6). No map work after 23:30. |
| 00:15 | **G9:** "look left/right" reliable in tests | A | Phrases say "Look for {feature}" with no side. |
| **03:00** | **Feature freeze.** Tag `freeze-0300`. | B | After this, only `fix/` and `docs/` branches. |
| Sun 06:00 | **G10:** real device in hand? | A | No device signing at all (S4). |
| 07:00 | **G11:** `scripts/test.sh` green; error states visible | A | Ship what passes and list the gaps in README. |
| 08:00 | **G12:** attribution screen + README sources | B (A if B is still recording) | Static text in README. |
| 09:30 | **Code freeze** (docs and upload only after this) | both | — |
| **10:00** | **Submission uploaded** | B | 10:00–11:00 is buffer only. |

### 3.2 Merge windows (a human merges; by default the person who did **not** write the branch)

| Window | Expected merges, in this order |
|---|---|
| **M1 15:45** | T1 → T0 |
| **M2 17:30** | B1 (raw data) → A1 → A2 |
| **M3 18:30** | B2 (pack) → A4 (speech) → B4 (UI shell) |
| **M4 19:40** | B3 (loader) → A3 (engine) → A5 (sources) → A7-min (controller) → B5 (Now Walking). Then tag `checkpoint-good`. |
| **M5 22:00** | A6 (background + AVSession) → A7 rest → B6 step 1 (map overlay) |
| 23:00 (mini) | B6 step 2 (only if G8 is green) |
| **M6 00:30** | A8 → A9 → A10 (part 1) → A12 → B7 (narrations) → B8. Then tag `night-good` before A sleeps. |
| **M7 02:45** | B10 → B9 → B11. Then tag `freeze-0300`. |
| 04:00–09:15 | `fix/*` and `docs/*` only. Single-person merges are allowed **only** with the night rule in §4.2. |
| **M8 09:15** | Last fixes and README. Tag `v1.0-hackyeah` (S4). |

### 3.3 Person A, hour by hour

| Time | Human | Emulator lane (agent) | Headless lane (agent) |
|---|---|---|---|
| 14:45–15:10 | §6 checklist; start both sessions | **T0** contracts + skeleton | **T1** test harness |
| 15:10–15:30 | **T2 / G1:** listen to the zh voice reading English; post the verdict | T0 | T1 |
| 15:30–15:45 | Review T0/T1 PRs with B; **M1** (B merges) | — | — |
| 15:45–17:30 | Review agent output every ~30 min | **A4** speech (VoicePolicy, PCM, queue, DevPanel buttons) | **A1** core geo → **A2** Held–Karp |
| 17:30 | **M2** (merge B1; B merges A1/A2) | | |
| 17:30–19:00 | Review | **A4** finish (M3 18:30) → **A5** location + Demo walk | **A3** tour engine (+ `make-demo-walk.mjs` if the lane frees up) |
| 19:00–19:40 | **G5** with B | **A7-min** controller (vertical slice) | A3 finish |
| 19:40–20:00 | **M4**; build the checkpoint HAP, tag, hand to B (S2) | | |
| 20:00–20:30 | **S3** OBS + system-audio test on the recording Mac (dinner after) | A7 continue | A3 test polish |
| 20:30–22:00 | Review | **A6** background + AVSession into the tour; A7 rest | A10 core-side issue effects |
| 22:00 | **G7**, **M5** | | |
| 22:00–23:30 | Spot-check 2 of B's narrations (B7) | **A8** notification + haptics → **A10** emulator rows | **A9** turn-by-turn + off-route |
| 23:30–00:30 | **G9** at 00:15 | **A12** onboarding (cut first if late) | A9 finish |
| 00:30 | **M6**, tag `night-good`, written handover to B | | |
| **00:30–04:00** | **Sleep (3.5 h).** B is awake. | — | — |
| 04:00–05:30 | Read B's handover and bug list; fix-only | **A10** remaining rows / bug fixes | **A11** smoke + replay test |
| 04:30–05:30 | | | **S6 draft:** `docs/submission/description.md` + slide outline (helper prompt in S6) |
| 05:30–06:30 | README A-sections and AI_WORKFLOW (S1); **G10** at 06:00 | Fix-only | S1 |
| 06:30–07:30 | **Demo rehearsal × 2** (S5): fresh install, the exact command sequence, OBS scene ready; **G11** at 07:00 | — | — |
| **07:30–09:00** | **Record** (S5): A drives the emulator and the log pane | | |
| 09:00–09:30 | **S4** release: tag `v1.0-hackyeah`, clean-clone build, GitHub release with HAP + sha256 | | |
| 09:30–10:00 | Help B upload; check links in a logged-out browser | | |
| 10:00–11:00 | Buffer. Nothing is merged after 10:00 unless the build is broken. | | |

### 3.4 Person B, hour by hour

| Time | Human | Emulator lane (agent) | Headless lane (agent) |
|---|---|---|---|
| 14:45–15:15 | §6 checklist; HackTribe fields and Discord IDs; curate the stop list | **B4** prep: tokens, colours, all en string keys (B-owned files only) | **B1** fetch + commit raw snapshots |
| 15:30–15:45 | **Review T0 contracts** (15 min); **M1** (merge A's T0/T1) | B4 | B1 |
| 15:45–17:30 | Confirm stop coordinates and view hints in `royal-route.json` | **B4** UI shell against ScriptedTourControl | **B1** finish → **B2** pack build |
| 17:00 | **G3:** ask the Huawei mentors (device, Laura voice, region) | | |
| 17:30 | **M2** (merge A1/A2; A merges B1) | | |
| 17:30–18:30 | **G4** at 18:00 | B4 finish (**M3**) → **B5** Now Walking | **B2** finish (**M3**) → **B3** pack loader |
| 18:30–19:40 | Review; **G5** with A | **B5** (states needed for the slice first) | **B3** (**M4**) |
| 19:40–20:00 | **M4**; **S2** checkpoint upload by 20:00 | | |
| 20:00–20:45 | Dinner (A runs S3) | B5 remaining states | **B7** agent drafts the 11 EN scripts from the sources |
| 20:45–22:00 | Review | **B6** map step 1 (overlay + PNG base) → step 2 spike | B7 drafting |
| 22:00–22:45 | **Human review of the 11 EN scripts (B7)**; **M5** | B6 step 2 | B7: apply edits, zh/pl MT, rebuild pack |
| 22:45–23:30 | **G8** at 23:00 | B6 finish → **B8** place detail + About/licences | **B10** pl/zh translations + key-parity test |
| 23:30–00:30 | **M6** at 00:30 with A | B8 | B10 |
| 00:30–01:45 | Alone from 00:30; follow the night rule | **B9** Settings | B10 finish; S1 B-sections + `data/ATTRIBUTION.md` |
| 01:45–02:45 | | **B11** summary (P1) or bug fixes | Screenshots en/pl/zh into `docs/img/` |
| 02:45–03:00 | **M7**, tag `freeze-0300` (**feature freeze**) | | |
| 03:00–04:00 | Full demo dry-run on the emulator; write the bug list + handover note for A | — | — |
| **04:00–07:30** | **Sleep (3.5 h).** A is awake. | — | — |
| **07:30–09:00** | **Record** (S5): B runs OBS and the takes | | |
| 09:00–09:45 | **S6:** cut the ≤ 60 s video, slides PDF (≤ 10), final description (≤ 500 words, `wc -w`), screenshots | | |
| 09:45–10:00 | **Upload to HackTribe** with both Discord IDs | | |
| 10:00–11:00 | Buffer; verify the submission page | | |

**Sleep rule.** Sleep is staggered so one person is always awake: **A 00:30–04:00, B 04:00–07:30**, 3.5 h each. Nobody pushes their sleep to finish a feature. Cut instead (§5).

### 3.5 What the 20:00 checkpoint contains (S2)

- **Main, tagged `checkpoint-good`, building from a clean clone:**
  - Home → Royal Route (11 stops from the real pack) → Route ready with the Held–Karp order (`ROUTE_PLAN algo=heldkarp`) → Now Walking.
  - The Demo walk (SIMULATED pill) triggers stop narration spoken by the **Fallback voice** (or text-only after G1), with the caption shown.
  - If G5 slipped, the same path is driven by "Jump to next stop".
- **`entry-default-unsigned.hap` + sha256.**
- **README:** the current capability table (Location Kit, Core Speech Kit, Audio Kit; Background Tasks and AVSession marked "verified in spike, wiring in progress" if A6 has not merged), Mocked/simulated behaviour (Demo walk, Fallback voice), build/run steps, test command. `AI_WORKFLOW.md` up to date.
- **1–3 screenshots;** optionally a 30–60 s safety clip.
- ⚠️ B confirms the exact checkpoint fields on HackTribe by 18:00.

---

## 4. Merge order and conflict avoidance

### 4.1 Merge procedure (human)

```bash
# in the main checkout, during a merge window
git checkout main && git pull --ff-only
gh pr view <n> --json title,body            # read the agent's verified/unverified list
gh pr merge <n> --merge                      # or: git merge --no-ff origin/<branch> && git push
git pull --ff-only
source scripts/env.sh && scripts/test.sh && devecocli build && devecocli run --device "Pura 90"   # must end in Smoke: PASS
scripts/smoke.sh                             # once A11 has landed
# broken? revert immediately:
git revert -m 1 <merge-sha> && git push
```

- **Order inside a window:**
  1. contracts and hotspot-only branches;
  2. producers before consumers (pack → loader → UI; services → controller);
  3. smaller before larger.
- Every other open branch then runs `git fetch && git rebase origin/main` before its next commit.
- **Tags:** `checkpoint-good` (19:50), `night-good` (00:30), `freeze-0300` (03:00), `v1.0-hackyeah` (09:15).

### 4.2 Night rule (single awake person, 00:30–07:30)

Only `fix/*` and `docs/*` branches are merged, plus B's feature branches until the 02:45 window. Each merge needs:
1. a tag `pre-<slug>` first;
2. `scripts/test.sh`, build and smoke green **on the merge result**;
3. a revert straight away if anything fails.

Never touch `module.json5` or `build-profile.json5` at night.

### 4.3 Hotspot files

| File | Owner | How conflicts are avoided |
|---|---|---|
| `entry/src/main/module.json5` | A | Everything lands in T0 (permissions with reasons, `backgroundModes`). The only later change is the P2 widget, via `fix/module-form`. |
| `build-profile.json5` | A | Never edited after T0. `signingConfigs` stays `[]`; the pre-commit hook blocks anything else. |
| `oh-package.json5` | A | No new dependencies planned. If one is unavoidable: pinned version, its own tiny branch. |
| `resources/*/element/string.json` | B | B4 creates **all** en keys up front; B10 adds pl/zh. A never edits these (except `perm_*` in T0) and requests keys from B in chat. A key-parity test catches gaps. |
| `resources/base/profile/main_pages.json`, `route_map.json` | B | T0 adds `pages/DevPanel` once. A's onboarding route entry is added by B. |
| `entry/src/test/List.test.ets` | A (T1) | All suites are pre-registered as stubs; nobody edits it again. A new suite gets a one-line append, and the conflict is trivial. |
| `EntryAbility.ets`, `app/AppContainer.ets` | A | B reaches services only through AppContainer getters. B's swaps happen inside B-owned files (`PackFactory`). |
| `pages/Index.ets` | B | Navigation host. |
| `README.md` | By section | A: capabilities, simulated, testing, error handling, first launch. B: data and licences, languages, screenshots, limitations. Edit with small direct commits on `main` (docs are allowed there) after `git pull --rebase`, not from long-lived branches. |
| `AI_WORKFLOW.md` | Everyone | `merge=union` in `.gitattributes`; rows are append-only. |
| `rawfile/packs/**` | B | Generated only by `build-pack.sh` (deterministic). If two pack branches conflict, rebuild; never hand-merge. |

### 4.4 Rules of thumb
- If a branch needs a file it doesn't own, it **stops and asks in chat**. The owner makes the change in their own branch, or in a tiny `fix/` branch merged in the next window.
- `contracts/` change requests go to A. A ships them as `feat/contracts-<x>` (≤ 20 lines) for the next window, and B reviews.
- No branch lives more than ~3 hours without being rebased on `main`.

---

## 5. Cut list (if behind) and stretch list (if ahead)

### 5.1 Cut, in this order (top = first to go)

The trigger: a lane is **> 45 min behind** at a gate, or any P0 is red at 23:00.

1. Anything P2 not yet started: B12 HUD, B13 explore layer, B14 widget, X1 time budget, X2 live language switch, Hejnał, spatial audio, a second persona.
2. **A12 Onboarding.** Permissions are requested in context on "Start tour" anyway (B4).
3. **B11 Tour summary.** Replace it with a single "Tour complete" state on Now Walking.
4. **A9 spoken turn-by-turn and off-route/replan.** Keep bearing guidance only: "Next: Cloth Hall, 200 m, ahead left".
5. **A8 notification + haptics.**
6. **B6 step 2 vector base map.** Keep the PNG base with the Canvas overlay (G8).
7. **B5 Look cue dial.** Keep the text caption only. If G9 fails, drop "left/right" from speech: "Look for {feature}".
8. **B7 `deep` narrations and zh/pl MT of scripts.** Keep the EN reviewed teaser + full; zh/pl use SOURCE_EXTRACT, labelled.
9. **B9 P1 rows** (trigger distance, permissions rows). Keep the Demo walk toggle, story language and voice row.
10. **The all-POI pack** shrinks to tour stops + 395 monuments (G4).
11. **The PCM AudioRenderer path:** `USE_SYSTEM_PLAYBACK = true` (G7).

**Never cut:**
- the Demo walk + SIMULATED labels;
- the "Fallback voice" label;
- the continuous task + AVSession;
- trigger engine + Held–Karp with tests, and `scripts/test.sh`;
- the pack with sources and licences;
- README + AI_WORKFLOW;
- the ≤ 60 s video with audible narration;
- an unsigned HAP from a tag.

### 5.2 Stretch, in this order (only when every P0 on the current lane is merged)

1. **Look cue dial** (B5 P1), the signature element; then **B12 "How it works" HUD** (makes every Kit visible live).
2. **Airplane-mode proof:** no `INTERNET` permission is declared, so it's free. Add one README line and one shot in the long video.
3. **B11 summary** and **A12 onboarding**, if they were cut.
4. **X1 "I have N minutes"**: the DP already exists in A2, so it's about 1 h of UI.
5. **X2 mid-tour EN ⇄ 中文 switch.**
6. **Ambient nearby non-tour POI teasers** (P4 queue items, from the all-POI pack).
7. **B13 explore layer.**
8. Hejnał time-aware moment, labelled SIMULATED TIME.
9. Accessibility pass (`accessibilityText` on every control).
10. `AudioSpatializationManager` support query in the HUD.
11. B14 widget.
12. Second persona content.

---

## 6. First 30 minutes (checklists)

### Person A (14:45–15:15)
- [ ] `cd ~/Documents/GitHub/citytour && git pull --ff-only && devecocli emulator list`. Pura 90 is running: `devecocli run --device "Pura 90"` → `Smoke: PASS` from `main`.
- [ ] Push the spike for reference: `git -C ../citytour-wt/risk-spikes push -u origin exp/risk-spikes`.
- [ ] `scripts/wt.sh new feat/contracts` → `cd ../citytour-wt/contracts && claude`, then paste the **T0** starter prompt.
- [ ] `scripts/wt.sh new feat/test-harness` → second terminal, `claude`, then paste the **T1** prompt (headless; tell it not to run the emulator until the end).
- [ ] **By 15:30, G1/T2:** run the spike from `../citytour-wt/risk-spikes`, listen with headphones to the zh voice reading English, and post accept/reject in the team chat.
- [ ] Send your Discord ID to B privately (for HackTribe; never commit it).
- [ ] Prepare the two worktrees for 15:45: `cap/tts-pcm` (A4) and `feat/core-geo` (A1). Create them **after** M1 so they branch from the new `main`.

### Person B (14:45–15:15)
- [ ] Read PLAN §0, §1.2, §3.4 and your cards B1/B4.
- [ ] `git pull --ff-only`; start your own emulator; `devecocli run --device "Pura 90"` → `Smoke: PASS` (toolchain sanity on your Mac).
- [ ] `scripts/wt.sh new feat/pack-fetch` → `claude`, then paste the **B1** prompt.
- [ ] Get the lead's pre-fetched files into the B1 worktree (they are on Svetoslav's Mac): `scratchpad/design/tile1..9.osm`, `route.json`, `map-meta.json`, `preview.png`, `krakow-base-{light,dark}.svg`. Svetoslav copies them or AirDrops them. The B1 agent gzips them into `data/raw/osm/` and `data/raw/osrm/`, and puts the PNG/SVG + meta into a staging folder for B6.
- [ ] Draft `data/tours/royal-route.json` with the agent: 11 stops, QIDs, coordinates. You confirm the coordinates against the map.
- [ ] `scripts/wt.sh new feat/ui-shell` → second session, then paste the **B4** prompt. Until 15:45 it works only on B-owned files (tokens, colours, en strings, page skeletons).
- [ ] HackTribe: confirm the **checkpoint** fields and the **final** fields (≤ 10-slide PDF, ≤ 60 s video, ≤ 500-word EN description, screenshots, both members' Discord IDs). Post them in the chat.
- [ ] **15:30:** review T0's `contracts/` (15 min); then merge T1 → T0 at M1 and run the §4.1 checks.

---

## 7. Turning tasks.json into GitHub issues

```bash
cd ~/Documents/GitHub/citytour
jq -r '.[].labels[]' docs/tasks.json | sort -u | while read -r l; do gh label create "$l" --force >/dev/null; done
jq -c '.[]' docs/tasks.json | while read -r t; do
  gh issue create --title "[$(jq -r .id <<<"$t")] $(jq -r .title <<<"$t")" \
    --body "$(jq -r .body_markdown <<<"$t")" \
    $(jq -r '.labels[] | "--label=" + .' <<<"$t") ; done
```

- PRs close their issue with `Closes #<n>`.
- Dependencies stay in each issue body's "Depends on" column. GitHub doesn't enforce them, so check them at merge time.

---

## 8. Assumptions and open questions

- **HackTribe fields.** The ≤ 10-slide PDF, ≤ 60 s video, ≤ 500-word description, screenshots and Discord IDs come from the coordinator, not from a document this agent could read. B confirms them on HackTribe at 15:00, plus the exact 20:00 checkpoint fields.
- **zh voice reading English.**
  - **Intelligibility:** unverified by ear until G1.
  - **Speed:** about 9 s for 20 words in the spike.
  - **`languageContext`:** which value sounds better is untested (A4 tries `en-US` and `zh-CN`).
- **`downloadVoice` and our INTERNET permission.** ASSUMPTION: the system service downloads, so we don't need `INTERNET`. A4 checks the docs. If it is needed, add it in a tiny `fix/module-internet` branch and drop the "no INTERNET permission" claim.
- **`pl_PL` resource folder** resolution: spike S4 inside B10.
- **Kraków ArcGIS licence:** unverified (RISKS T14). B1 records the terms or writes "UNVERIFIED".
- **Real-device behaviour** (freezing, region locks, signing): unverified. The emulator does not freeze background apps (RISKS c3). README says so.
- **Two people on two Macs** is assumed. If both work on one Mac, the emulator lanes must take turns, or the second one uses `devecocli emulator start sdk24` with `--device sdk24`.
- **No system-audio recorder is installed** on the lead's Mac (OBS and BlackHole are absent). S3 needs the human to install one; downloading is the human's action.
- **Who is A and who is B** is for the team to decide. The plan assumes the person with the spike worktree and the scratchpad files (Svetoslav's Mac) is **A**, and that Mac is also the recording Mac.

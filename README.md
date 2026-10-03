# CityTour

> HackYeah 2026 · Huawei challenge "Imagine What's Next" · native ArkTS/ArkUI app for HarmonyOS / OpenHarmony (API 20+)

**Status: work in progress (built during HackYeah 2026, 3–4 Oct 2026).**

CityTour is a mobile tour guide that follows you through the city. It tracks where you are and which way you are walking. When you reach a place of historic or cultural significance, it explains that place to you.

Project scope and decisions are recorded in [`HACKATHON_BRIEF.md`](HACKATHON_BRIEF.md).

## Challenge area

**Spatial Experiences** (lead), with Human-Centric Technology (cultural experiences) as the secondary area. Recorded in `HACKATHON_BRIEF.md`.

## Platform capabilities used

_Updated as each capability lands. Every entry links to the code that uses it._

| Capability | Kit / API | Where | Status |
| --- | --- | --- | --- |
| — | — | — | planned |
| Next-stop notification (glanceable with the screen off; text-only arrival line) | Notification Kit `notificationManager` (`requestEnableNotification`, `publish` id 1001 `isAlertOnce` SERVICE_INFORMATION slot, `cancel`) | [`services/notify/TourNotifier.ets`](entry/src/main/ets/services/notify/TourNotifier.ets), text rules in [`core/notify/NotifyText.ets`](entry/src/main/ets/core/notify/NotifyText.ets) | verified on emulator (sdk24) |
| Arrival haptic | Sensor Service Kit `vibrator` (`isSupportEffectSync` preset, timed fallback; `ohos.permission.VIBRATE`) | [`services/haptics/Haptics.ets`](entry/src/main/ets/services/haptics/Haptics.ets) | called and logged; the emulator has no motor (`14600101`, logged, no crash) |

## Mocked or simulated behavior

_Every simulated input is labelled in the app UI and listed here._

- None yet.

## Requirements (tested versions)

| Tool | Version |
| --- | --- |
| macOS | 15.1 on Apple Silicon (M3). The DevEco emulator requires Apple Silicon. |
| DevEco Studio | 6.1.1.280 (Mac ARM) |
| HarmonyOS SDK | bundled with DevEco Studio 6.1.1 (API 24) |
| Emulator | DevEco Emulator 6.1.1.200, image HarmonyOS 6.1.1(24) phone, software version 6.1.0.126, device "Pura 90" |
| DevEco CLI | `@deveco/deveco-cli` 1.3.4, patched with the challenge repo's `scripts/apply-devecocli-patches.mjs` |
| Node.js | 22 or later (developed with 24.x) |

API levels in `build-profile.json5`: `compatibleSdkVersion` **6.0.0(20)** (challenge minimum), `compileSdkVersion` / `targetSdkVersion` **6.1.1(24)**.

## Setup from a clean machine

1. Install **DevEco Studio** for Mac ARM from https://developer.huawei.com/consumer/en/download/. Launch it once to finish the first-run setup, then quit it.
2. **Switch the DevEco region to China.** Outside China the emulator only offers watch images. Edit `~/Library/Application Support/Huawei/DevEcoStudio6.1/options/country.region.xml` and set `<countryregion name="CN"/>`. See the [challenge FAQ](https://github.com/onirodeveloper/hackyeah2026-challenge/blob/main/FAQ.md).
3. Restart DevEco Studio. Go to **Tools → Device Manager → New Emulator → Phone**, choose the newest image (API 24) and download it.
4. Install the DevEco CLI and apply the challenge patches:
   ```bash
   git clone https://github.com/onirodeveloper/hackyeah2026-challenge ~/oni
   npm i -g @deveco/deveco-cli@1.3.4
   node ~/oni/scripts/apply-devecocli-patches.mjs
   ```

## Build, install and launch

```bash
devecocli emulator list                 # find your phone emulator
devecocli emulator start "Pura 90"      # or the name of your phone emulator
devecocli run --device "Pura 90"        # builds the .hap, installs it and launches EntryAbility
```

`devecocli run` ends with `Smoke: PASS` once the app has started on the device. To build without deploying:

```bash
devecocli build
```

The debug `.hap` is written to `entry/build/default/outputs/default/`.

### Signing

Debug builds run unsigned on the emulator, and the `.hap` we submit is the **unsigned debug build** from a tagged commit (verified to install and run on the emulator; see `docs/PLAN.md` task S4). Signing is only needed for a physical device: open the project in DevEco Studio and go to **File → Project Structure → Signing Configs → Automatically generate** (this needs a Huawei account). That writes `signingConfigs` into `build-profile.json5`; never commit it. Signing material stays out of git (see `.gitignore`).

## Development workflow

- `main` is always buildable and is the branch the judges see.
- Each feature or capability gets its own branch in its own git worktree:
  ```bash
  scripts/wt.sh new feat/<slug>   # creates ../citytour-wt/<slug> on branch feat/<slug>
  scripts/wt.sh list
  scripts/wt.sh rm <slug>         # after the branch is merged
  ```
- The full working agreement, including what every change must satisfy at runtime, is in [`AGENTS.md`](AGENTS.md).
- AI usage is documented in [`AI_WORKFLOW.md`](AI_WORKFLOW.md).

## Testing

All commands run from the repository root on macOS with DevEco Studio installed in `/Applications`. `scripts/env.sh` exports the toolchain paths (`DEVECO_SDK_HOME`, `HVIGORW`, `OHPM`, `HDC`, and `DEVECO_NODE_BIN`, the Node 18 that `hvigorw` runs on; it is only appended to `PATH` because `devecocli` needs a newer Node); set `DEVECO_HOME` first if DevEco Studio lives elsewhere.

```bash
source scripts/env.sh           # optional (the scripts source it themselves); gives you $HDC and $HVIGORW
scripts/test.sh                 # unit tests + source guards; ends with "TESTS: PASS n=<N>", exit 0
scripts/smoke.sh                # build, install, launch on "Pura 90", then the Demo walk tour; ends with "SMOKE+DEMO: PASS"
DEVICE=sdk24 scripts/smoke.sh   # the same on another emulator or device
SMOKE_DEMO=0 scripts/smoke.sh   # install + launch only; ends with "SMOKE: PASS"
```

**`scripts/test.sh`** runs the ArkTS local unit tests (`@ohos/hypium`, no device needed, about 10 s) with `hvigorw test -p module=entry -p coverage=false --no-daemon`. `hvigorw test` exits 0 even when a test fails, so the script deletes the old result file, then reads `entry/.test/default/intermediates/test/coverage_data/test_result.txt` and exits 1 unless at least one test ran with `Failure: 0, Error: 0`. On failure it prints the failing test lines. It also fails when:

- anything in `entry/src/main/ets/core/` imports `@kit.*` (`core/` holds the pure, unit-tested logic; the local test runner cannot load system APIs);
- any `.ets` file under `entry/src/main/ets/` uses a State Management V1 decorator (`@Component`, `@State`, `@Prop`, `@Link`, `@Observed`, `@Provide`, ...). The project uses V2 only. The unmodified DevEco scaffold page `pages/Index.ets` is exempt until it is replaced;
- `node --test scripts/pack/` fails (only once the data pipeline has `*.test.mjs` files).

**Where tests live.** `entry/src/test/List.test.ets` registers one suite file per module under test (`GeoMath`, `CourseEstimator`, `FixFilter`, `HeldKarp`, `TriggerPolicy`, `AnnouncementQueue`, `TourEngine`, `Phrases`, `DemoWalkPlayer`, `VoicePolicy`, `LegTracker`, `Replay`, `PackParser`, `NarrationValidator`, `MapCamera`) plus `Harness`. Each file starts as a passing stub and names the task that owns it; add cases to the existing file instead of editing `List.test.ets`.

**Replay integration test** (`entry/src/test/Replay.test.ets`, part of `scripts/test.sh`). It replays a recorded, SIMULATED Demo walk track (`entry/src/test/fixtures/DemoTrackMini.ets`, generated by `node scripts/demo/make-demo-walk.mjs --fixture`: Royal Route stops 7-11, with a ~80 m detour, a pass-by stop (9, St Andrew's) and a 10 s accuracy dip to 60 m) through the real pipeline with a fake clock and a fake speech engine (2.5 s per sentence): Held-Karp planner, `DemoWalkPlayer` (holds the walker at a stop while its story plays, like `DemoWalkSource`), `TourEngine` (which runs `FixFilter` on every fix), and in the last case the real `TourController` with fake ports at x8, the same flow as the DevPanel "Start demo tour" button. Each run asserts: every planned stop entered exactly once and in the planned order, no arrival during the detour or the accuracy dip (all dip fixes are not trigger-grade), teaser only at the pass-by stop, no sentence cut or interleaved (no `STOP_SPEECH`, every story item heard to its last sentence), the tour reaches `finished`, and no re-plan or off-route flag on the detour. A deliberately broken engine fails it (arrival that cuts the sentence in flight: 5 of the 6 replay cases fail; ignoring walking speed in the teaser/full decision: 4 fail). Output of `scripts/test.sh` on this branch (each case prints one `REPLAY_SUMMARY` line to `entry/.test/default/intermediates/test/coverage_data/coverage.log`; `enter=[stop@track second]`):

```text
ArkTS: Tests run: 137, Failure: 0, Error: 0, Pass: 137, Ignore: 0
TESTS: PASS n=137
REPLAY_SUMMARY run=engine-voice-x1 enter=[7@1s,8@396s,9@521s,10@711s,11@1066s] full=[7] teaserOnly=[8,9,10,11] sentences=32 stories=16 violations=0 stopSpeech=0 replan=0 offRouteSnaps=0 locPoor=1 triggerGrade=1069/1079 poorInDip=10/10 finished=true simulatedS=1078
REPLAY_SUMMARY run=engine-voice-x8 enter=[7@8s,8@400s,9@536s,10@728s,11@1080s] full=[7,8,10,11] teaserOnly=[9] sentences=41 stories=19 violations=0 stopSpeech=0 replan=0 offRouteSnaps=0 locPoor=1 triggerGrade=187/188 poorInDip=1/1 finished=true simulatedS=189
REPLAY_SUMMARY run=engine-text-x1 enter=[7@1s,8@396s,9@521s,10@711s,11@1066s] full=[7] teaserOnly=[8,9,10,11] sentences=32 stories=16 violations=0 stopSpeech=0 replan=0 offRouteSnaps=0 locPoor=1 triggerGrade=1071/1081 poorInDip=10/10 finished=true simulatedS=1080
REPLAY_SUMMARY run=controller-voice-x8 enter=[7@8s,8@400s,9@536s,10@728s,11@1080s] full=[7,8,10,11] teaserOnly=[9] sentences=41 stories=19 violations=0 stopSpeech=0 replan=0 offRouteSnaps=0 locPoor=1 triggerGrade=192/193 poorInDip=1/1 finished=true simulatedS=195
```

At the demo speed (x8) every dwell stop gets the full story. At x1 (real walking pace) the dwell stops 8, 10 and 11 get only the teaser: the geofence is entered about 25 s before the walker reaches the stop and the teaser/full decision is taken when the (short, fixture) teaser ends, while the walker is still moving. The x1 cases therefore assert only the pass-by and start-stop decisions; this is a known limitation of the current trigger policy, not hidden by the test.

**`scripts/smoke.sh`** runs `devecocli run --device "$DEVICE"` (default `Pura 90`), requires its `Smoke: PASS` (launched, no crash, not blank), then reads the app log (`devecocli log --keyword CityTour`) and requires the `APP_START` event. Then the Demo walk (ARCHITECTURE §11.2): it opens the developer page (`hdc shell aa start -a EntryAbility -b com.hackyeah.citytour --ps page dev`), taps **Start demo tour** (`devecocli ui click --id btnDevDemoTour`, x8 by default), follows the log until `STATE ... to=finished` (at most `SMOKE_DEMO_TIMEOUT` s, default 1500) and requires `PACK_LOAD`, `ROUTE_PLAN algo=heldkarp`, `LOC_SOURCE kind=demo`, `POI_ENTER`, `STORY_START`, `UTT_DONE` and `STATE to=finished`. It prints one line per event and `SMOKE+DEMO: PASS`, or `SMOKE+DEMO: FAIL` with the missing events. Logs and two screenshots (`devecocli ui screenshot --path`) go to `$SMOKE_OUT` (a temp dir by default). `SMOKE_FRESH=1` uninstalls first.

**Pre-commit hook.** `scripts/git-hooks/pre-commit` blocks a commit that stages signing material (`*.p12`, `*.p7b`, `*.cer`, `*.csr`, `*.keystore`), a `build-profile.json5` whose `signingConfigs` is not `[]` (DevEco signing writes real configs there; keep them local), or a private key or Anthropic API key in the added lines. It reports file names only, never the matched text. Enable it once per clone (the setting is shared by all worktrees):

```bash
git config core.hooksPath scripts/git-hooks
```

## Error handling

Every failure a user (or the jury) can hit ends in a visible state and one log line, never a crash (docs/ARCHITECTURE.md §9). The tour controller turns each one into an `AppIssue` (`code`, `severity` INFO / WARN / BLOCKING) in `EngineSnapshot.issues`, which the UI renders with `views/common/IssueBanner.ets`. Log lines go to hilog domain `0xC17A`, tag `CityTour`. To read them, run `devecocli log --device "Pura 90" --bundle-name com.hackyeah.citytour --keyword CityTour --tail 300`.

"Emulator" means the row was reproduced on the Pura 90 emulator (6.0.0(20) image) on 2026-10-03. "Unit test" means a case in `scripts/test.sh` (`TourController.test`, `TourEngine.test`) drives the row with fake ports. Rows 18-22 (narration and route fallbacks, offline, uncaught exceptions) belong to other tasks.

| # | Condition | What the user sees | Log line (`CityTour …`) | How verified |
|---|---|---|---|---|
| 1 | Location permission denied | Tour detail: "CityTour needs your location…" with **Allow location** and **Try a demo walk instead**. If it happens during a tour: `PERM_DENIED` (BLOCKING). | `E PERM_DENIED perm=LOCATION where=request` (controller: `… src=real code=-2 where=controller`) | Emulator (tapped Deny → banner → demo tour started) + unit test |
| 2 | Only approximate location granted | Tour detail banner asking for precise location. During a tour: `PERM_APPROX_ONLY` (WARN). Approximate fixes (> 40 m) never trigger a story because of the engine's accuracy gate. | `W PERM_APPROX_ONLY acc=… where=controller action=stories_need_precise` | Unit test. Not reproduced on the emulator. |
| 3 | Location switch off | Tour detail banner with **Turn on** (`requestGlobalSwitch`). During a tour: `LOC_SWITCH_OFF` (BLOCKING), cleared by the next fix. | `W LOC_SWITCH_OFF src=real code=-4 where=controller action=offer_switch_or_demo` | Emulator (Control Center toggle during a real-GPS tour; the issue appeared and cleared after switching back on) + unit test |
| 4 | No first fix | `LOC_NOFIX` (WARN) 30 s after start. Planning uses a fix less than 2 min old, otherwise the tour's first stop. | `W LOC_NOFIX secs=30 src=…` | Unit test |
| 5 | Fix lost during a tour | `signal=lost`. The guide says once "I've lost the GPS signal…". Stop triggers freeze. `LOC_LOST` (WARN) | `W LOC_LOST secs=26` / `I LOC_BACK acc=7` | Emulator (location switched off during a tour, then on) + unit test |
| 6 | Poor accuracy | `LOC_POOR` (WARN). No false arrival. | `W LOC_POOR acc=… prov=…` (at most once every 30 s) | Unit test |
| 7 | Location service unavailable (`3301000`, `801`) | `LOC_UNAVAILABLE` (BLOCKING), which offers the Demo walk | `E LOC_UNAVAILABLE src=real code=3301000 where=controller action=offer_demo` | Unit test |
| 8 | Far from Kraków (more than 5 km outside the pack) | `LOC_OUT_OF_AREA` (INFO). The route starts at the tour's first stop. | `I LOC_OUT_OF_AREA km=7098 src=real action=plan_from_tour_start` (on the first fix of a tour: `action=suggest_demo`) | Emulator (its fixed Beijing location) + unit test |
| 9 | TTS engine cannot be created | Stories are shown as text. The voice label is `text-only-platform`. `TTS_INIT_FAIL` (WARN). The tour still runs. | `E TTS_INIT_FAIL engine=zh-CN/13 code=1002300005 …` then `E TTS_INIT_FAIL lang=en reason=… action=text_only where=controller` | Emulator (`DEBUG_FAIL_TTS_INIT`) + unit test |
| 10 | English voice not installed | The zh-CN voice reads English, labelled "Fallback voice". `VOICE_UNAVAILABLE` (INFO). A failed download stays on the fallback. | `W VOICE_STATUS lang=en person=8 status=DOWNLOADABLE action=fallback_voice`, `E VOICE_DL_FAIL code=1002300008` | Emulator (its default state) + unit test. The download failure was verified in A4 (RISKS a5). |
| 11 | TTS error while speaking | The sentence is skipped and its caption stays. After 3 errors in a row the tour switches to text only. `TTS_ERR` (WARN). | `E TTS_ERR req=… code=… streak=n` | Unit test |
| 12 | Audio focus lost (call, other app) | The tour pauses (`AUDIO_INTERRUPT`, INFO). On RESUME the interrupted sentence replays. A pause the user made is never undone. | `I AUDIO_INTERRUPT hint=PAUSE action=pause` / `hint=RESUME action=resume` | Unit test (engine + controller). Not reproduced on the emulator: no CLI way to take audio focus. |
| 13 | Headphones disconnected | The tour pauses (`AUDIO_ROUTE_LOST`, WARN) and never resumes on the loudspeaker. The user resumes it. | `I AUDIO_ROUTE device=SPEAKER action=pause` | Unit test. Not reproduced on the emulator: it has no headset to unplug. |
| 14 | Continuous task refused or cancelled | `BG_FAIL` (WARN). The tour continues in the foreground with the screen kept on (`setWindowKeepScreenOn`) until it ends. | `E BG_FAIL where=controller result=false action=foreground_only`, `I SETTINGS keepScreenOn=true why=bg_fail`, `W BG_CANCEL reason=…` | Emulator (`DEBUG_FAIL_BG_START`) + unit test (cancel) |
| 15 | AVSession fails | `AVS_FAIL` (INFO). In-app controls only. | `E AVS_FAIL where=controller result=false` | Unit test |
| 16 | Notifications refused | `NOTIF_DENIED` (INFO). No next-stop notification. Nothing else changes. | `I NOTIF_DENIED where=controller action=no_next_notice` | Unit test. The notifier service (task A8) is not wired yet. |
| 17 | Pack missing or corrupt | Home: "Tour data couldn't be loaded. Reinstall the app." `PACK_ERR` (BLOCKING). No tour can be planned. | `E PACK_ERR file=pois.json reason=parse src=debug` | Emulator (`DEBUG_CORRUPT_PACK`) + unit test |

**Simulating failures.** `entry/src/main/ets/app/AppConfig.ets` has three debug flags. They are `false` in git; set one to `true` and rebuild (`devecocli run --device "Pura 90"`):

- `DEBUG_FAIL_TTS_INIT` makes every `createEngine` reject with `1002300005` (row 9);
- `DEBUG_CORRUPT_PACK` makes the pack report `pois.json` as unparseable (row 17);
- `DEBUG_FAIL_BG_START` makes the continuous task get refused (row 14).

Each simulated failure logs `src=debug`, so a log never presents a fake failure as a real one. Start a tour from the developer page with `$HDC -t 127.0.0.1:5555 shell aa start -a EntryAbility -b com.hackyeah.citytour --ps page dev`, then **Start demo tour**. The status line lists the active issue codes.

## Architecture

_To be written as the implementation lands._

## Pre-existing and third-party components

- Project scaffold: DevEco CLI `devecocli create` (Empty Ability template).
- Hackathon starter files (`AGENTS.md`, `CLAUDE.md`, `GEMINI.md`, `AI_WORKFLOW.md`, `HACKATHON_BRIEF.md`, `hackathon-resources/`) come from https://github.com/onirodeveloper/hackyeah2026-challenge (`default_template/`).

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
scripts/smoke.sh                # build, install, launch on "Pura 90"; ends with "SMOKE: PASS"
DEVICE=sdk24 scripts/smoke.sh   # the same on another emulator or device
```

**`scripts/test.sh`** runs the ArkTS local unit tests (`@ohos/hypium`, no device needed, about 10 s) with `hvigorw test -p module=entry -p coverage=false --no-daemon`. `hvigorw test` exits 0 even when a test fails, so the script deletes the old result file, then reads `entry/.test/default/intermediates/test/coverage_data/test_result.txt` and exits 1 unless at least one test ran with `Failure: 0, Error: 0`. On failure it prints the failing test lines. It also fails when:

- anything in `entry/src/main/ets/core/` imports `@kit.*` (`core/` holds the pure, unit-tested logic; the local test runner cannot load system APIs);
- any `.ets` file under `entry/src/main/ets/` uses a State Management V1 decorator (`@Component`, `@State`, `@Prop`, `@Link`, `@Observed`, `@Provide`, ...). The project uses V2 only. The unmodified DevEco scaffold page `pages/Index.ets` is exempt until it is replaced;
- `node --test scripts/pack/` fails (only once the data pipeline has `*.test.mjs` files).

**Where tests live.** `entry/src/test/List.test.ets` registers one suite file per module under test (`GeoMath`, `CourseEstimator`, `FixFilter`, `HeldKarp`, `TriggerPolicy`, `AnnouncementQueue`, `TourEngine`, `Phrases`, `DemoWalkPlayer`, `VoicePolicy`, `LegTracker`, `Replay`, `PackParser`, `NarrationValidator`, `MapCamera`) plus `Harness`. Each file starts as a passing stub and names the task that owns it; add cases to the existing file instead of editing `List.test.ets`.

**`scripts/smoke.sh`** runs `devecocli run --device "$DEVICE"` (default `Pura 90`), requires its `Smoke: PASS` (launched, no crash, not blank), then reads the app log (`devecocli log --keyword CityTour`) and requires the `APP_START` event once the app emits it. The Demo walk checks are added later.

**Pre-commit hook.** `scripts/git-hooks/pre-commit` blocks a commit that stages signing material (`*.p12`, `*.p7b`, `*.cer`, `*.csr`, `*.keystore`), a `build-profile.json5` whose `signingConfigs` is not `[]` (DevEco signing writes real configs there; keep them local), or a private key or Anthropic API key in the added lines. It reports file names only, never the matched text. Enable it once per clone (the setting is shared by all worktrees):

```bash
git config core.hooksPath scripts/git-hooks
```

## Architecture

_To be written as the implementation lands._

## Pre-existing and third-party components

- Project scaffold: DevEco CLI `devecocli create` (Empty Ability template).
- Hackathon starter files (`AGENTS.md`, `CLAUDE.md`, `GEMINI.md`, `AI_WORKFLOW.md`, `HACKATHON_BRIEF.md`, `hackathon-resources/`) come from https://github.com/onirodeveloper/hackyeah2026-challenge (`default_template/`).

# CityTour: review of the planning docs

**Written:** Sat 2026-10-03, about 15:35 CEST, by the reviewer agent (25 min time box).

**Scope:**
- Read: `HACKATHON_BRIEF.md` (binding), `AGENTS.md`, `README.md`, `AI_WORKFLOW.md`, `docs/{ARCHITECTURE,DESIGN,RISKS,OPPORTUNITIES,PLAN}.md`, `docs/tasks.json`, `docs/design/README.md` + `map-meta.json`, and the challenge text in `~/oni/hackathon_challenge.md` + `FAQ.md`.
- The big docs were read by section and grep, not line by line.
- Nothing was committed.

---

## 1. Verdict

**Ready to start: YES, with five conditions.** The plan is unusually strong:
- verified spikes behind every platform claim;
- clear file ownership;
- gates with fallbacks;
- an honest cut list.

The binding decisions are reflected in PLAN.md and tasks.json. The drift was in DESIGN.md, OPPORTUNITIES.md, ARCHITECTURE.md and RISKS.md, which were written before the voice decision. I fixed it surgically (§6).

**Conditions:**
1. **Run G1 now.** A human listens to the zh-CN voice reading English. Record the verdict before A4's agent starts, because A4's default strategy depends on it. It is already 15:35 and the plan assumed 15:10–15:30.
2. **Re-time the first hour.** PLAN assumes a 14:45 start, so you're about 45 min late. Push M1 to about 16:15 and keep every later gate. Do not push the 20:00 checkpoint.
3. **Agree B's overload up front** (§2, R4). B has about 22 h of P0 against about 12 h of wall clock before the 03:00 feature freeze, plus the human review work.
4. **Add a licence task.** There is no `LICENSE` in the repo, and Wikipedia-derived narration is CC BY-SA (ShareAlike).
5. **Define a "checkpoint floor"** to tag at 19:30, whatever the M4 merges do (R5).

---

## 2. Blocking or near-blocking issues

| # | Issue | Why it matters | Fix |
|---|---|---|---|
| B1 | G1 (does the zh voice reading English sound acceptable?) hasn't been decided yet. | The headline demo voice depends on it. If it is unintelligible, "spoken English" disappears from the demo and README. | Listen now. If it is marginal, try `speed` 0.9 and both `languageContext` values (PLAN §8). The user then updates the brief's acceptance check. |
| B2 | The P0 load is about 47 h (A 18.5, B 22, shared 6.5). The window from 15:30 to the 03:00 freeze is about 11.5 h per person. | This only fits if both agent lanes run at full speed **and** the human review keeps up. B also owns the human tasks: stop coordinates, B7 review, HackTribe and the contracts review. | Rebalance now (R4). Pre-agree that §5.1 cuts 2–6 are likely, not hypothetical. |
| B3 | **No `LICENSE` file, and no task for one.** | A public repo with no licence is "all rights reserved". That clashes with the "open Tour Pack / sovereignty" pitch, with ODbL (the pack is a derived database) and with CC BY-SA ShareAlike (narration adapted from Wikipedia). It is a transparency hit and could be flagged by the pre-review. | Add `LICENSE` for the code (suggest Apache-2.0, as OpenHarmony uses), `data/LICENSE.md` (pack: ODbL; narrations: CC BY-SA 4.0) and `data/ATTRIBUTION.md`. About 15 min, owner B in B1 or S1. |
| B4 | The `AI_WORKFLOW.md` "AI feature disclosure" section is not assigned to anyone. | The product has no runtime model, but the narration is LLM-drafted product content. The challenge asks for the model, flow, data handling, limitations, validation and privacy. | Add it to the S1 DoD. Say "no runtime model", then describe the build-time drafting: model, `historian-v1` prompt, grounding validator, human review, MT labelling and the fallback chain. |

---

## 3. Compliance with the challenge MUSTs

| MUST | Covered by | Owner | Status / gap |
|---|---|---|---|
| API 20+ (minimum declared) | `build-profile.json5` already `compatibleSdkVersion 6.0.0(20)`; PLAN §0.3 rule 3 (`canIUse` for APIs newer than 20); `devecocli check compat` | A (T0) | ✅ Add `devecocli check compat` to `scripts/test.sh` so it's enforced, not just advised. |
| Runs on emulator | Smoke at every merge (§4.1), S4 clean-clone install | A | ✅ |
| Visible platform capability | A4 (Core Speech + Audio), A5 (Location), A6 (Background + AVSession): all P0 and all spike-verified | A | ✅ The strongest part of the plan. |
| Public repo | Exists | – | ✅ Push `exp/risk-spikes` (PLAN §6 does this): it is evidence. |
| Reproducible setup/build/launch | README (already good), S1 "first launch" section, S4 clean-clone build | A + B | ✅ Gap: README must say that a fresh emulator has the location switch **off** (RISKS b1) and how to install the release HAP with `hdc install`. Both are already in the S1 scope. |
| Working `.hap` | S4: unsigned debug HAP from tag `v1.0-hackyeah`, attached to a GitHub release with sha256 | A | ✅ I fixed the README's "signed .hap we submit" contradiction. Open question: also commit the HAP under `release/` in case the pre-review only looks in the tree (§8). |
| Recorded demo | S3 (audio capture test), S5 (record), safety take on Saturday | A + B | ✅ OBS isn't installed yet. Install it **today** (a human download), not at 20:00. |
| Architecture description | README "Architecture" links to `docs/ARCHITECTURE.md` (S1) | both | ⚠️ ARCHITECTURE.md is a 1,200-line *pre-build design* that includes P1/P2 features. The jury asks for a "concise architecture **and implementation** description". Add a ½-page as-built section (R8). |
| `AI_WORKFLOW.md` + AI-feature docs | S1 (tools, prompts, one row per task, unsuccessful approaches) | both | ⚠️ The AI-feature disclosure is not assigned (B4). The "Important prompts" and "Workflow" sections are still template placeholders. |
| No secrets | T1 pre-commit hook, S4 history grep, `.gitignore` | A | ✅ Gap: git hooks are local. Make sure T1 sets `core.hooksPath` (worktrees share it) and add a CI secret scan (R2). |

---

## 4. Rubric coverage: what the jury will see, and where it's weak

Expected scores are on a 0–10 scale for **the plan as written**, assuming the P0 tasks land and some P1 tasks get cut.

| Criterion (weight) | Evidence the jury sees | Weak spots | Expected |
|---|---|---|---|
| **Originality (20%)** | Locked-phone guide, "where to look" from course over ground, an open offline Tour Pack, on-device TTS, no account | GPS audio guides exist (RISKS P1). The two differentiators are fragile:<br>• "where to look" (G9 may cut it);<br>• "optimised route", which is nearly invisible from the Barbican (R3).<br>OPPORTUNITIES leads with "I have 45 min", which is a P2 task (X1). | **5–7** |
| **Usefulness (20%)** | One real Kraków tour, end to end, with real open data and cited stories | An English story in a Chinese-accented voice may read as "not usable". Polish (the host country) is text-only. | **6–8** |
| **Technical execution (20%)** | Pure `core/` with hypium suites (geo, Held–Karp vs brute force, trigger jitter, queue, validator, parser); `scripts/test.sh` that really fails; error matrix A10; validator + fallback chain for "incorrect AI output"; hilog events | **A11 replay integration test is only P1**, yet it is the single best "key scenario" test. Test results aren't published anywhere the jury looks. The validator's grounding rules may reject most LLM drafts late at night (R4). | **6–8** (5 if tests are thin at freeze) |
| **Platform capabilities (20%)** | Location Kit, Background Tasks (multi-mode), Core Speech (PCM), Audio Kit renderer, AVSession lock screen: all VERIFIED-RUN | If G7 fails, there is the fallback to `playType 1` and AVSession becomes thin. | **7–9** |
| **Demo (10%)** | Emulator, a SIMULATED pill, screen off via `power-shell suspend` with the logs scrolling, the lock-screen AVSession card | System audio may not be captured (S3). A ≤ 60 s cut leaves little time to explain "simulated" vs "real". Voice quality is unknown. | **6–8** (4–5 without audio) |
| **Reproducibility & transparency (10%)** | README with versions and setup, granular commits, worktree flow, AI_WORKFLOW rows, planning docs in the repo | No LICENSE. The AI-feature section is missing. The architecture doc is aspirational. The unsigned-install steps aren't written yet. | **7–9** |

**Weighted midpoint:** about 7.0/10 (range about 6.0–8.1). OPPORTUNITIES §1.4's 7.9–8.6 is a ceiling, not a forecast.

**Technical execution, in detail:**
- **Tests of key scenarios:**
  - well planned at the unit level (ARCHITECTURE §11.1 lists concrete cases);
  - missing at the integration level, unless A11 ships (R2).
- **Incorrect AI output:**
  - well covered: there are two validators, in the pipeline and in the app, with rules for schema, length, language, grounding (numbers and proper nouns) and forbidden patterns, plus a logged fallback chain (`NARR_FALLBACK`);
  - make sure one test shows a **hallucinated year being rejected** and the README quotes it.
- **Error handling:**
  - error matrix rows 1–17 (A10 P0) and the location-switch flow (verified);
  - the voice-missing path is now the *default* on the emulator, which is good demo evidence;
  - **show at least one error state in the video** (e.g. location switch off → `requestGlobalSwitch`).
- **Reproducibility:**
  - strong;
  - the risk is drift: README claims vs what is actually merged. S1's "never describe unmerged features as working" rule is right; enforce it at 09:15.

---

## 5. Top 10 recommendations, ranked by expected score impact

1. **Settle G1 now and design around its result** (Demo, Usefulness).
   - If accepted: record a 10 s clip for README/video planning.
   - If marginal: tune `speed`/`languageContext`; English captions are on screen anyway.
   - Also: Polish and English street names spoken by the zh voice will be unintelligible. ARCHITECTURE §4.6 omits them only for zh. Apply the same rule to English-via-Fallback-voice (A9, Phrases).
2. **Promote A11 (replay integration test) to P0, and publish the evidence** (Tech, Repro).
   - A11 feeds the Demo-walk track through the engine and asserts the exact narration/effects sequence.
   - Commit a short `docs/evidence/` (test summary, a log excerpt of a screen-off run).
   - Add a tiny GitHub Action that runs `node --test scripts/pack/` and a secret scan (e.g. gitleaks). HarmonyOS builds can't run in CI, but this shows automated checks to the pre-review. About 30 min.
3. **Make the route optimisation visible, or stop claiming it** (Usefulness, Originality).
   - I ran Held–Karp on the 11 real stops (haversine, start at the Barbican, fixed end at Wawel). The listed order is **near-optimal**: 1,882 m vs 1,733 m, and the only change is swapping Cloth Hall and Mickiewicz.
   - Starting from the tour start, the "optimised" moment is therefore invisible. On the jury's emulator (in Beijing) planning falls back to the first stop.
   - Fixes:
     - start the Demo walk from a realistic off-route origin (Kraków Główny station, or the Main Square as the DESIGN Route-ready screen shows);
     - log `ROUTE_PLAN listed_m=… optimal_m=…`;
     - only show the "N m shorter" line when it is true (DESIGN already says ≥ 50 m).
   - X1 "I have N minutes" is the more convincing optimisation story. It is cheap once A2 lands (the DP already exists).
4. **Rebalance Person B** (all criteria, via finishing).
   - B7 drafting needs only B1's sources, not B2/B3. Start the agent at about 17:00 in B's headless lane instead of 20:45.
   - Split the human review: A takes about 5 of the 11 stops, not 2.
   - Cap "full" scripts at about 200 words for the demo stops.
   - Move B9 Settings (voice strategy + Demo-walk toggle, A's domain) to A, or fold its P0 rows into B5's Demo-controls sheet.
   - Use the already rendered `docs/design/map/krakow-base-*.svg` as B6 step 1 (the PNG base) right away.
5. **Checkpoint floor at 19:30.**
   - Tag `checkpoint-good` on whatever builds: T0/T1 plus the DevPanel (Fallback voice speaking, Demo walk emitting `LOC_FIX src=demo`) plus an updated README.
   - M4 merges five branches at 19:40, which is too tight to be the only path to 20:00.
   - Confirm the HackTribe checkpoint fields **now**, not at 18:00.
6. **Licences** (B3 above): `LICENSE`, `data/LICENSE.md`, `data/ATTRIBUTION.md`, and the ArcGIS terms recorded or marked UNVERIFIED. Put "© OpenStreetMap contributors" on every map surface (B6/B8 already plan it).
7. **AI_WORKFLOW AI-feature disclosure** (B4 above), plus the real prompts (the T0/B7 starter prompts are public-safe; link them). Remove the template placeholders before 09:15.
8. **A concise as-built architecture.**
   - README: ½ page + the mermaid diagram trimmed to what is merged.
   - Add a header to `docs/ARCHITECTURE.md`: "pre-build design; see README for what shipped". Mark P1/P2 sections as planned.
   - This avoids the "nothing for show" penalty when the jury reads about features that aren't there.
9. **Demo recording risk.**
   - Install OBS today and do the S3 audio test as soon as the DevPanel speaks (about 17:00), not at 20:30.
   - Confirm the video length limit (PLAN says ≤ 60 s, OPPORTUNITIES assumes 2:30; both are unverified).
   - If ≤ 60 s is real, the README must carry the "real vs simulated" box, because the video can't.
10. **Honesty pass at 09:15** (S1). Check every claim in §7 below against `main`. In particular, the OPPORTUNITIES TL;DR leads with "where to look" and "I have 45 minutes"; if G9 or X1 are cut, the pitch and slides must change.

Smaller items:
- Make `scripts/wt.sh` set `core.hooksPath`.
- Add `devecocli check compat` to `scripts/test.sh`.
- Tell the B4/B5 agents explicitly that DESIGN.md beats the mockups. The mockups still show Laura and "640 m" (I noted this in `docs/design/README.md`).

---

## 6. Edits I made (surgical, factual or binding-decision fixes only; not committed)

**`docs/DESIGN.md`:**
- Flow A step 3, Onboarding 2/3 table, Flow E (3 places), Settings Voice row, Tour detail Guide row, persona table row, HUD mock, and the Claude Design brief (onboarding, tour detail, settings): "Laura" as the English voice → the zh-CN **"Fallback voice"** (Laura only if `INSTALLED`). The download fails on the emulator (`1002300008`).
- Flow A: the background-location ⚠️ is now ✅ VERIFIED on the emulator (RISKS c2), with a note that a real phone is unverified.
- Flow D: `requestGlobalSwitch` "unverified on emulator" → VERIFIED (RISKS b1/b3).
- Distances:
  - "2.0 km" → **2.5 km** (OSRM 2,497 m) on Home, Tour detail, the a11y string, the widget and the brief;
  - Summary "2.3 km" → 2.5 km;
  - Route ready "2.3 km · 32 min" and "640 m shorter" → `{d}`/`{t}`/`{saved}` placeholders, explicitly marked as computed at runtime.
- Stop numbering, aligned to the real order: Cloth Hall = stop 4 (was 5), St Mary's = stop 3 (was 4). Applies to the Now Walking hero, the states table (4 rows), the widget 2×4 progress row, and the brief's lock-screen and widget lines.
- Pronunciation rule: it now covers the zh-CN Fallback voice.
- Open question 2: marked ANSWERED with the spike results.

**`docs/ARCHITECTURE.md`:**
- "Two platform risks", item 2: added the spike result and the binding Fallback-voice decision.
- §2.1 background status: ASSUMPTION → VERIFIED-RUN (100 s, screen off), with a note that phones are unverified.
- §2.4 Spike S2: marked partly verified.
- §2.5: the en-US row notes that the download fails on the emulator; fallback item 3 is now the verified default.
- §4.6: 12 stops / 132 legs → 11 / 110.
- §7.4: "10–12 tour stops" → 11.
- §8: the voice table en row now says "Laura if INSTALLED, else Fallback voice".
- §12.3: a note that PLAN §1/§3 supersede the ownership and timeline.
- §12.4: "12 stops" → 11.
- §13: a results note for spikes S1/S2.

**`docs/RISKS.md`:**
- §2.1: recorded the user decision (C + A).
- 12×12 → 11×11 (and the 110 leg routes); "10–12 stops" → 11 (2 places).
- §4: a "superseded by PLAN §3" note (feature freeze 03:00, not 09:30; the G1 fallback is now text-only, not option B; different sleep shifts).

**`docs/OPPORTUNITIES.md`:**
- §1.3: a note that PLAN S5 is the real storyboard, and that shots 3, 8 and 9 need P2 tasks.
- §1.3 shot 3: "Best 7 of 11 · 2.9 km" (impossible: more than the full 2.5 km route) → computed placeholders.
- Shot 5 voice and the HUD TTS line: Laura → Fallback voice.
- §3.1 AVSession "automatic Live View" → marked unverified (only the lock-screen pill and the Control Center card are verified).
- §3.2: log domain `0xC170`/`CT.*` → `0xC17A`/`CityTour` (ARCHITECTURE §10 and PLAN are binding), and the log command now uses `devecocli log`.
- §4: "runs on Oniro" → "should run (untested)".

**`docs/PLAN.md` + `docs/tasks.json` (X1):** "Best 7 of 11 stops · 2.9 km" → computed placeholders. `tasks.json` is still valid JSON.

**`README.md`:**
- Challenge area "To be confirmed" → Spatial (lead) + Human-Centric (secondary), per the brief.
- "which way you are facing" → "walking" (the design uses course over ground, not the compass).
- Signing: "the signed .hap we submit" → the unsigned debug HAP (PLAN S4), plus a warning about `signingConfigs`.

**`docs/design/README.md`:** a note listing the stale mockup strings (Laura, "640 m shorter").

**Not edited (recommendations instead):**
- The mockup HTML files.
- ARCHITECTURE §4.6, which says Polish street names spoken in English are "acceptable". That is wrong under the Fallback voice; see R1.
- Task priorities (A11 → P0, B rebalancing).

---

## 7. Honesty and claims to watch

**Already fixed in the docs:**
- "640 m shorter" was a placeholder; the real saving from the Barbican is small.
- "Best 7 of 11 · 2.9 km" was impossible.
- "Automatic Live View" is unverified.
- "Runs on Oniro" is untested.

**Watch at submission:**
- **"Works with the phone locked"** is verified on the emulator only, and the emulator does not freeze apps (RISKS c3). Say so wherever the claim appears.
- **"Fully offline / no INTERNET permission"** is true only if `downloadVoice` doesn't need `INTERNET` (PLAN §8 assumption). Verify it before the airplane-mode shot.
- **"Human-reviewed"** must mean that a human actually read and edited each EN script. zh/pl must say machine-translated. Don't let a 45-minute review at 22:00 rubber-stamp 11 × 300 words (R4).
- **"Where to look"** must only be claimed if G9 passes. Otherwise the pitch says "look for {feature}".
- **"Speaks English"** must be labelled as the Chinese voice reading English, in the UI, README and video (PLAN rule 6 already requires this).
- **Self-scored rubric.** OPPORTUNITIES §1.4 and the file name "how this wins first place" are in a public repo the jury will read. They're harmless but look self-congratulatory. The humans decide (§8).
- **Microsoft Soundscape** "discontinued in 2023" is from general knowledge and already flagged ⚠️. Don't put it in the pitch unless it's checked.

---

## 8. Open questions for the humans

1. **G1 verdict** on the zh voice reading English (and whether `speed` or `languageContext` tuning helps).
2. **HackTribe limits:** what are the exact video length, slide count, description length and checkpoint fields? The PLAN's ≤ 60 s / ≤ 10 slides / ≤ 500 words came from the coordinator, not from a document.
3. **Code licence:** Apache-2.0 (as OpenHarmony uses), MIT, or another? Data: ODbL for the pack and CC BY-SA 4.0 for narrations seem forced by the sources. Please confirm.
4. **Demo origin:** should the Demo walk start off-route (station or Main Square) so the optimiser visibly matters? And should Wawel stay a fixed end?
5. **The `.hap` location:** only a GitHub release asset, or also committed under `release/` for the automated pre-review?
6. **Public planning docs:** keep `OPPORTUNITIES.md` (self-scores, "wins first place") and `RISKS.md` public as transparency, or rename or trim them?
7. **Who is A and who is B, and are there two Macs?** PLAN assumes two, with Svetoslav as A and his Mac as the recording Mac.
8. **Mentor device:** worth asking at 17:00 (G3)? Is a real-device clip worth the signing risk?

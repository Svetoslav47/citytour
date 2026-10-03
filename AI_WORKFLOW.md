# AI Workflow

This project uses AI-assisted development. Keep this document current and public-safe. Do not include credentials, tokens, personal data, private endpoints, or confidential prompts.

## Tools used

| Model, agent, MCP server, or Agent Skill | Version or source | Role in the project |
| --- | --- | --- |
| Claude Code (Claude Opus 5.5, `claude-opus-5-5`) | Anthropic, Claude Code desktop app | Research, environment setup, project scaffolding, workflow documentation, implementation |
| DevEco CLI `devecocli` | `@deveco/deveco-cli` 1.3.4, patched with the challenge repo's `scripts/apply-devecocli-patches.mjs` | Project creation, build, install, launch, emulator control, logs |
| `deveco-cli` Agent Skill | installed by `devecocli init --skill` | Teaches the agent how to use `devecocli` |
| Hackathon Agent Skills: `ohos-app-scaffold`, `ohos-app-dev`, `ohos-system-app-dev`, `ohos-system-dev`, `conductor-dev`, `hmos-arkts-knowledge-retriever`, `hmos-arkui-scenario-development`, `hmos-arkui-develop-skill`, `hmos-arkui-mvvm-pattern` | https://github.com/onirodeveloper/hackyeah2026-challenge/tree/main/skills, installed with `npx skills add -g` | ArkTS/ArkUI grounding, dev loop, UI development (`conductor-dev` installed but not used, per `AGENTS.md`) |
| Local commit-discipline instruction (`CLAUDE.local.md` + a local Agent Skill) | Written by the team for this project; kept local and not published | Tells the agent to commit after each small working step, push regularly, keep feature work on branches/worktrees and check for secrets before committing |

## Important prompts and instructions

- `AGENTS.md` — repository-wide hackathon constraints and working agreement.
- [Summarize the important project prompt or reusable instruction. Include the full public-safe text when practical.]

## AI-assisted work log

| Date | Tool/model | Request or task | Generated or changed | Human review and validation |
| --- | --- | --- | --- | --- |
| 2026-10-03 | Claude Code (Opus 5.5) | Set up the macOS toolchain following the challenge README/FAQ: DevEco region switch, DevEco CLI install and patches, Agent Skills | Local environment only (no repo files) | `devecocli -V` = 1.3.4, the patch script reports "already applied" on its second run, phone emulator profiles visible after the region switch |
| 2026-10-03 | Claude Code (Opus 5.5) + `devecocli create` | Scaffold the app and add the hackathon starter files | Project skeleton, `AGENTS.md`/`CLAUDE.md`/`AI_WORKFLOW.md`/`HACKATHON_BRIEF.md`, API levels (compatible 20, compile/target 24), hardened `.gitignore` | `devecocli run --device "Pura 90"` → build successful, installed, `Smoke: PASS` on the HarmonyOS 6.1.1(24) emulator |
| 2026-10-03 | Claude Code (Opus 5.5) | Write the team workflow: branches and worktrees, jury-facing runtime rules, README with reproducible setup | `AGENTS.md` "Team Flow" section, `scripts/wt.sh`, `README.md` | Reviewed by the team; `scripts/wt.sh list` runs |
| 2026-10-03 | Claude Code (Opus 5.5) + `deveco-cli` skill | Task T1 (#2): command-line test harness, since `hvigorw test` exits 0 even when tests fail | `scripts/test.sh` (parses `test_result.txt`, deletes the stale file first, `core/` @kit guard, V1-decorator guard), `scripts/env.sh`, `scripts/smoke.sh` skeleton, `scripts/git-hooks/pre-commit` (signing material, non-empty `signingConfigs`, key patterns), `List.test.ets` + 15 suite stubs + `Harness.test.ets`, `.gitattributes` (`AI_WORKFLOW.md merge=union`), README "Testing" | `scripts/test.sh` → `TESTS: PASS n=17`; shown to exit 1 for a failing test, an `@kit.AudioKit` import in `core/`, a V1 decorator, and a test that does not compile; hook shown to block a fake `signingConfigs`, a `.p12` and a private key in a scratch clone; `DEVICE=sdk24 scripts/smoke.sh` → `SMOKE: PASS`. The smoke run caught that DevEco's Node 18 first on `PATH` breaks `devecocli`, fixed in `env.sh` |

## Workflow

### Ideation and architecture

[Describe how AI influenced the product idea, scope, architecture, and platform-capability choice.]

### Implementation

[Describe the AI-assisted coding workflow and how generated output was reviewed before acceptance.]

### Testing and debugging

[Record builds, linting, tests, device/emulator runs, UI inspection, logs, screenshots, and manual checks.]

## Unsuccessful approaches

- `devecocli emulator geolocation` (inject GPS location and heading from the CLI) fails with "Emulator scene control commands require Emulator 7.0 or later". The newest emulator available to us is 6.1.1.200, so location simulation has to come from the emulator UI or an in-app, clearly labelled demo source.

## Known limitations

- [Product, platform, model, data, testing, or tooling limitation.]

## Lessons learned

- [Concise lesson that would help reproduce or improve the work.]

## AI feature disclosure

Complete this section only if AI is part of the product itself; otherwise write "Not applicable."

- Model or service: [Name/version/provider]
- Inference flow: [On-device, remote, or hybrid; inputs and outputs]
- Data handling and privacy: [What leaves the device, retention, consent, and safeguards]
- Failure and fallback behavior: [How errors, latency, offline use, and unsafe output are handled]
- Evaluation: [Test cases, quality measures, human review, and known model limitations]

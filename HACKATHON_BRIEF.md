# Hackathon Brief

The user owns the decisions recorded here. Unresolved fields may remain blank; do not ask the user to complete them until the current work depends on them.

## Pitch

**User problem:** Visitors exploring a city on their own miss the stories behind the places they walk past. Hiring a guided walking tour (a guide you follow, listening through earpieces) is expensive, has fixed times and runs at a fixed pace. Reading guidebooks or looking at a phone pulls attention away from the city itself.

**Desired demonstration:** A guided walking tour of Kraków that works with the phone locked in a pocket. The app leads the visitor along an optimised route and speaks about each monument as they reach it, the same way a hired guide with earpieces would, but without the guide.

**Lead challenge theme:** Spatial Experiences

**Distinctive platform capability:** Background location while the screen is locked (continuous task + Location Kit) driving on-device text-to-speech narration (Core Speech Kit); further capabilities are listed in the README as they land.

## Target

- Platform: HarmonyOS (API 20+; compiled against 6.1.1(24))
- API level: 20 or later
- Device type: phone
- Validation target: DevEco emulator "Pura 90", HarmonyOS 6.1.1(24); physical device from the Huawei mentors if available

## Intended user flow

1. Pick the guided tour (or later: build one for the time available).
2. The app plans the walking order of the stops and shows the route.
3. Put headphones in, lock the phone, start walking.
4. The guide leads you to each stop and, when you arrive, tells you about the place and where to look.

## Acceptance checks

- [ ] A guided tour runs end to end with the screen locked (narration triggered by location).
- [ ] Stops are visited in a computed, optimised walking order.
- [ ] Narration is spoken in English and Chinese, and shown as text in English, Polish and Chinese. English is spoken by the built-in Chinese (zh-CN) voice, labelled "Fallback voice" in the UI, because the English voice (Laura) can't be downloaded on the emulator (download error 1002300008, see docs/RISKS.md). A device that has Laura installed uses it automatically.

## Scope boundaries

- In scope:
  - **Guided tour first**: one curated Kraków tour for now.
  - **All Kraków locations installed** in the offline data (not only the tour stops).
  - Languages: **English, Polish, Chinese**.
  - Voice: **on-device text-to-speech** (Core Speech Kit) for all dynamic guidance and as the universal fallback.
  - Voice upgrade (user decision 2026-10-03, task A13, one of Person A's last tasks): stop stories pre-rendered with **ElevenLabs** at build time (EN/PL/ZH, which also gives spoken Polish). Dynamic guidance stays on native TTS. If ElevenLabs doesn't work by gate G-EL (01:00), we stay on native TTS. No API key ever ships in the app or the repo.
  - One guide persona, **"Historian"**. The design must allow a second persona to be added later.
  - Map: **not** Huawei Map Kit (user decision 2026-10-03); use the best alternative chosen in the architecture (see docs/ARCHITECTURE.md).
  - Polish: UI and full narration **text** in Polish; **spoken** narration in English and Chinese only (Core Speech Kit TTS supports only zh-CN and en-US). Documented as a platform limitation.
- Out of scope (for now): a second guide persona (planned for if time allows).
- Mocked or simulated behavior: a "Demo walk" location source for the emulator, clearly labelled in the UI (planned).

## First-minute narrative

[To be decided.]

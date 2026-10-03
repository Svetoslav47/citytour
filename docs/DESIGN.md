# CityTour: UX and UI specification

**Status:** v1, 2026-10-03 (HackYeah, Saturday afternoon). Owner: product/UX.
**Audience:**
1. Claude Design, for high-fidelity mockups. Section 9 is a paste-ready brief.
2. The ArkTS/ArkUI implementers. Sections 2–8 hold the details.

**Binding inputs:** `HACKATHON_BRIEF.md` (user decisions). `docs/OPPORTUNITIES.md` (wow moments) is aligned with this spec.

**How to read the tags:**
- **✅ verified**: checked in the offline HarmonyOS docs (`devecocli docs`) or in the SDK `.d.ts` files of DevEco Studio 6.1.1 (API 24) on this machine.
- **⚠️ assumption**: not verified. Test it on the emulator before relying on it.
- **(proposal)**: an idea from the earlier discussion that the user hasn't confirmed. The UI is designed so it can be dropped.

---

## 0. The design in one paragraph

CityTour is a guide that talks rather than a map that waits to be read. The visitor puts the phone in a pocket, and the product lives in their ears. The screen has three jobs:
- Get the visitor to the moment of locking the phone in under 30 seconds.
- Be readable in one glance if they do pull it out.
- Prove the stories are trustworthy.

**Visual direction:** quiet, native HarmonyOS. That means system navigation, sheets, lists and HarmonyOS Sans throughout, with one restrained accent called **Wawel Patina**. It's the oxidised-copper green of Kraków's old roofs and domes.

**The signature element:** the **Look cue**. It's a small half-dial that shows *where to look* (left, ahead, right, up) relative to the direction you're walking, and it always matches what the guide is saying.

**The signature interaction:** *Stand still to hear more* **(proposal)**. When you walk past a stop you hear a teaser. If you pause, you get the full story. No screen needed.

---

## 1. Experience principles

These are ordered. When two conflict, the higher one wins.

1. **Eyes-free first.**
   - 90% of a tour must work with the screen locked and the phone in a pocket.
   - Every event that matters (approach, arrival, turn, off-route, finish) has an audio form. Most also have a haptic form.
   - The screen is an optional mirror of the audio, never the source of truth.
   - Test it like this: run the whole Royal Route demo walk with the display off, and nothing should be missed.
2. **Glanceable.** If the phone does come out, the answer to "where next, how far, which way" is readable in about 1 second, at arm's length, in sunlight. That means one hero number, one name and one direction glyph. Everything else is secondary and smaller.
3. **The guide's voice is the product.**
   - Copy on screen is written in the guide's voice, and the guide's lines are written to be *heard*: short sentences, landmarks before distances, "on your left" before "in 40 m".
   - Visual chrome stays out of the way of the words.
   - The transcript is set like good reading text, not like a log.
4. **Calm.**
   - No streaks, badges, confetti, autoplaying carousels or gradient blobs.
   - Motion only explains a change.
   - The guide talks only when there's a reason to. Silence while walking is a feature.
5. **Trust through sources.**
   - Every story shows where it came from, as numbered sources with a licence.
   - Every story shows how it was made: "Drafted with AI · reviewed by a person".
   - Shorter descriptions of non-tour places say plainly that they come from Wikipedia or the city register.
   - The guide never invents. If content is missing, it says less.
6. **Honest simulation.**
   - Anything simulated (Demo walk location, a simulated clock for the Hejnał moment) wears an amber **SIMULATED** label on every surface where it's in effect: the walking screen, the map, the summary, and the lock-screen text.
   - Platform limits are stated plainly, never hidden. Example: "Polish narration is text only. On-device speech supports English and Chinese."
7. **Native, not themed.**
   - Use the system's components, gestures, back behaviour, sheets, dark mode and font scaling.
   - Brand lives in exactly four places: the accent colour, the plaque-style stop markers, the Look cue, and the voice.

---

## 2. Information architecture and navigation model

### 2.1 Structure

There is **no tab bar in the MVP**. There's one tour and one primary task, and a tab bar with one meaningful tab would be decoration (HIG `tab-bars.md`: tabs navigate between peer sections, and we don't have peers yet). When free-roam ships we add a 3-tab `Tabs` (Tours · Explore · Settings). Section 6.3 covers this.

```
EntryAbility
└── Index page  (Navigation root, NavPathStack "appStack")
    ├── [first run only] OnboardingFlow  (NavDestination ×3, replaces itself with Home when finished)
    ├── Home  (Navigation home content)
    │   ├── TourDetail(tourId)
    │   │   └── RouteReady(plan)
    │   │       ├── sheet: BeforeYouGo
    │   │       └── NowWalking(session)            ← also reachable from Home "Continue", the widget, and the AVSession/notification tap
    │   │           ├── sheet: StopsSheet
    │   │           ├── sheet: DemoControls        (Demo walk only)
    │   │           ├── overlay: HowItWorksHUD     (toggle)
    │   │           ├── FullMap(mode = tour)
    │   │           │   └── sheet: PlaceCard → PlaceDetail(poiId)
    │   │           ├── PlaceDetail(poiId)          (transcript / "Tell me more")
    │   │           └── TourSummary(sessionId)      (replaces NowWalking in the stack)
    │   ├── FullMap(mode = explore)  ("All places")
    │   │   └── sheet: PlaceCard → PlaceDetail(poiId)
    │   └── Settings
    │       ├── NarrationLanguage
    │       ├── Voice
    │       ├── Guide (persona)
    │       ├── OfflineData
    │       ├── Permissions
    │       └── AboutAndSources
    └── System surfaces (outside the app UI)
        ├── AVSession playback card (lock screen + control centre)
        ├── Continuous-task notification (system-generated; content can't be modified)
        ├── Arrival notification (text-only mode, or when the app has no audio)
        └── Form Kit widget 2×2 and 2×4
```

### 2.2 Navigation rules for implementers

| Concern | Decision | ArkUI |
|---|---|---|
| Root container | One `Navigation` bound to a `NavPathStack` and owned by a router/VM. Pages are `NavDestination`s registered in `route_map.json` (system routing table) or a `navDestination` builder. | `Navigation`, `NavDestination`, `NavPathStack` ✅ |
| System look upgrade (optional) | `HdsNavigation`/`HdsNavDestination` from **UI Design Kit** give the HarmonyOS Design System title bar with scroll-linked dynamic blur. They take the same `NavPathStack`. Swap in only if the plain version is working and there's time. | `@kit.UIDesignKit` `HdsNavigation` (since 5.1.0(18)) ✅ |
| Title style | Home and Settings use the large title (`NavigationTitleMode.Full`, which collapses on scroll). Detail screens use `Mini`. Now Walking hides the system title bar and draws its own compact header over the map. | `.titleMode()`, `.hideTitleBar(true)` ✅ |
| Back | System back gesture and the back button always work. From Now Walking, back goes to **Home and the tour keeps running**. Home then shows the "Now walking" card. Back never ends a tour. | default |
| Ending a tour | Only through **End tour** in the Now Walking menu, with confirmation. Or automatically after the last stop. | `UIContext.showAlertDialog` ✅ |
| Sheets | Only one at a time (HIG `sheets.md`). Resizable sheets show the drag bar and support swipe-to-dismiss. | `.bindSheet(isShown, builder, SheetOptions{ detents, dragBar, showClose, preferType: SheetType.BOTTOM, enableOutsideInteractive })` ✅ |
| Deep links into Now Walking | The widget tap, the AVSession card tap and the continuous-task notification `WantAgent` all open `NowWalking` for the active session. If no session is active, they open Home. | `wantAgent` ✅ |
| Onboarding | Shown once. After completion, `replacePath(Home)` so back can't return to it. It can be replayed later from Settings › About. | `NavPathStack.replacePath` ✅ |
| Immersive map | The Now Walking and Full map map canvases extend under the status bar. All text and controls stay in safe areas. | `.expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP])` ✅ |
| Breakpoints | Phone portrait is the only validated target. At the `md` width class (≥600 vp, e.g. foldable or tablet), Now Walking becomes a two-pane layout: map on the left, panel on the right, fixed 360 vp. Don't spend time on this before Sunday. | `GridRow` / breakpoints (一多) ✅ docs exist |

### 2.3 Complete user flows

The happy path is written as **spoken (🔊)** and **screen (📱)** steps, because the audio is the real interface.

#### Flow A: First run (onboarding and permissions)

1. 📱 **Launch.** The system start window shows the app icon on `bg.canvas`. No splash delay; the offline pack is bundled.
2. 📱 **Onboarding 1/3, "Your guide fits in your pocket."** The one-line value proposition, plus a quiet illustration made of real UI: a route line with three plaque markers. Buttons: **Continue**, and **Skip** (top right).
3. 📱 **Onboarding 2/3, "How should the guide speak?"** The visitor picks a narration language: **English (spoken)**, **中文 (spoken)**, or **Polski (text only)**. Voice status is checked inline:
   - If the voice is `INSTALLED`, a checkmark shows.
   - If the voice is `GA` (downloadable), a **Download voice** button with progress shows. Laura (en-US) is `GA` but **can't be downloaded on the emulator** (error `1002300008`, RISKS a5). **Binding decision (HACKATHON_BRIEF):** English is then spoken by the zh-CN voice (聆小珊) and labelled **"Fallback voice"**; a device with Laura installed uses it automatically.
   - **Play a sample** speaks one line.
4. 📱 **Onboarding 3/3, "Two permissions, and why."** Two rows:
   - **Location.** "Finds the next stop and knows when you've arrived. Used only while a tour is running." Button: **Allow**.
   - **Notifications.** "Tells you when you arrive if your screen is off and audio is paused." Button: **Allow**.

   Each **Allow** opens the *system* dialog directly (HIG `privacy.md`: one button, which clearly opens the system alert). Footer: **Set up later**. The primary **Done** is always enabled. The flow never blocks.
5. 📱 **Home.**

**Background location.** We don't ask for "always" in onboarding:
- ✅ The docs say `LOCATION_IN_BACKGROUND` **can't be granted through a dialog** (the user has to go to Settings).
- ✅ The supported pattern for navigation-type apps is: foreground precise location (`APPROXIMATELY_LOCATION` + `LOCATION`) **plus a LOCATION continuous task** that starts when the user explicitly taps **Start walking**.
- The UX consequence: the only background disclosure the user needs is in the Before-you-go sheet: "While the tour runs, CityTour keeps using your location with the screen locked. You'll see a system notification. Stop any time."
- ✅ VERIFIED on the emulator (RISKS c2): locked-screen location updates keep arriving under the continuous task without `LOCATION_IN_BACKGROUND`. The emulator does not freeze apps, so this is unverified on a real phone. If a device shows otherwise, add a Settings deep-link step to Flow A (step 4b) and use the copy in §3.14.

#### Flow B: Choose → plan → start → lock → walk → arrive → narrate → next → finish

| # | 📱 Screen | 🔊 Audio / haptic | Notes |
|---|---|---|---|
| 1 | **Home**: tap the *Royal Route* card | – | |
| 2 | **Tour detail**: map preview, 11 stops, "2.5 km · about 1 h 20 min with stories" (2,497 m / 33 min walking by OSRM foot; the story time is an estimate). Tap **Start tour** | – | If location isn't granted, the permission request happens *here* (in context). |
| 3 | **Route ready**: "Starting near you at the Cloth Hall. Optimised order: {d} km, {t} min walking." (computed at runtime; illustrative only) Options: start point, time available **(proposal: "I have N minutes")**. Tap **Begin** | – | Held–Karp runs in under 50 ms, so no spinner. If it takes over 300 ms, show an inline `LoadingProgress` (§3.4). |
| 4 | **Before you go** (sheet): ① Headphones in ② Volume check: **Play a test line** ③ "Lock your phone, I'll keep talking." Tap **Start walking** | 🔊 test line on demand | `startBackgroundRunning` (LOCATION + AUDIO_PLAYBACK) is called **here**, because it's user-initiated. That's required by the Background Tasks Kit rules ✅. |
| 5 | **Now Walking** (heading to stop 1) | 🔊 earcon *start* → Welcome line (§5.3 W1). 📳 none | The AVSession card appears on the lock screen. |
| 6 | User locks the phone and walks | 🔊 Directions only at decision points (D1–D3). Silence otherwise. | Optional "nearby" mentions only at Standard/Deep verbosity. |
| 7 | Approach (radius + 30 m) | 🔊 earcon *approach* + A1 "In about 50 metres, on your left: St Mary's Basilica." | |
| 8 | Arrival (inside the trigger radius, 35 m by default) | 🔊 earcon *arrival* + 📳 success + R1 arrival line with the **Look cue** | The lock screen shows the stop name. Widget updates. |
| 9 | Story | 🔊 Story S1… If the user keeps walking: teaser + "Stop for a moment if you'd like the full story" **(proposal)** | Never cut mid-sentence (§5.5). |
| 10 | Story ends | 🔊 T1 transition: "Next, the Cloth Hall, about two minutes ahead." | The Now Walking card flips to the next stop. |
| 11 | Repeat 6–10 | | |
| 12 | Last stop done | 🔊 earcon *finish* + F1 farewell | Continuous tasks stop. AVSession is deactivated. The notification clears. |
| 13 | **Tour summary** next time the app is foregrounded (or straight away if it's open) | – | |

#### Flow C: Resume after an interruption

| Interruption | Behaviour | Copy |
|---|---|---|
| Phone call or resumable audio interrupt (`audioInterrupt`, resumable) | Pause immediately. After the call ends, wait 2 s and resume **from the start of the interrupted sentence**, prefixed with a short re-cue. | 🔊 "Where were we… the Cloth Hall." |
| Another app starts music (not resumable) | Pause and stay paused. AVSession shows paused. Arrival events still fire an earcon and a haptic, and queue the story. | – |
| Headphones disconnected (`outputDeviceChangeWithInfo`, old device unavailable) | Pause **immediately** (HIG `playing-audio.md`: "when disconnecting headphones, they expect playback to pause immediately"). Don't auto-resume when they reconnect; the user presses play. | Lock screen: paused state |
| User swipes away the continuous-task notification | The system stops the task. The tour **pauses** and we don't re-request (that's a compliance rule ✅). Next time the app is foregrounded, show a banner on Now Walking. | "Tour paused: background location stopped when the notification was dismissed. **Resume tour**" |
| App killed or device restarted | The session is persisted (stop index, visited set, plan, language). On next launch, Home shows the **Continue** card. Resuming **re-plans the remaining stops from the current position**. | "The Royal Route · Stop 4 of 11 · paused 12 min ago" · **Resume** · **End tour** |
| GPS lost for over 20 s | Keep the last known position. Show a banner. Speak once, never repeat. | 🔊 "I've lost GPS for a moment. Keep going towards the Cloth Hall, and I'll pick you up again." |
| Off route (over 60 m from the planned leg for 30 s) **(proposal)** | Re-plan the remaining order from here (Held–Karp over the remaining stops). Speak a bearing-based cue. | 🔊 "You've left the route. The Cloth Hall is now about 200 metres behind you, to your right." |

#### Flow D: Permission denied

| Case | Where it shows | UI |
|---|---|---|
| Location denied (first time) | Tour detail › Start tour | Inline `ExceptionPrompt`-style banner above the button: "CityTour needs your location to know when you reach each stop." Buttons: **Allow location**, which calls `requestPermissionOnSetting` ✅ (the system's second-chance sheet). Secondary: **Try a demo walk instead**. |
| Precise location off (approximate only) | Same place | "Turn on precise location. Approximate location is accurate only to about 5 km, which isn't enough to find a doorway." **Turn on** → `requestPermissionOnSetting(['ohos.permission.LOCATION'])` |
| System location switch off | Same place | "Location is off for this phone." **Turn on** → `atManager.requestGlobalSwitch(ctx, SwitchType.LOCATION)` ✅ (VERIFIED on the emulator, RISKS b1/b3: a fresh emulator has the switch off and returns `3301100`). |
| Notifications denied | Settings › Permissions only. Never nag. | Row value "Off" → **Open settings** → `openNotificationSettingsWithResult` ✅ |
| Mid-tour revocation | Now Walking banner | "Location access was turned off. **Allow** to continue." The tour is paused. |

#### Flow E: Voice not installed or unavailable

1. On every **Start tour**, call `listVoices`. If the selected voice is `GA` (downloadable):
   - **Route ready** shows the row "English is read by the Fallback voice (Chinese voice). The English voice (Laura) needs a one-time download."
   - Buttons: **Download** (`downloadVoice` with progress events `start/progress/complete/error` ✅; fails on the emulator with `1002300008`), **Keep Fallback voice** (the default, binding decision), **Read instead (text only)**.
2. While downloading, an inline `Progress` (linear) shows with "Downloading voice… 42%". The user can still tap **Begin**; the tour then starts with the Fallback voice and switches to Laura when the download completes, with a single toast: "Voice ready."
3. If the download fails or there's no network, the row says "Couldn't download the voice. The Fallback voice will read English for now; try again later." with **Try again**.
4. ⚠️ If the TTS engine itself fails (`createEngine` errors, possible on the emulator), CityTour switches globally to **text mode**. A persistent but quiet row in Now Walking reads: "Voice isn't available on this device. Stories appear as text." Earcons and haptics keep working.

#### Flow F: Polish = text-only narration

When the narration language is **Polski**, there are two modes, chosen in onboarding step 2 and in Settings:
- **Read in Polish (text only)** is the default for PL. Arrival = earcon + haptic + an **arrival notification** ("Jesteś przy: Kościół Mariacki", meaning "You're at St Mary's Basilica") that opens the transcript. Now Walking puts the transcript first (§3.6, Reading state) at 20 fp. Directions arrive as short notifications only at decision points, with no audio.
- **Listen in English, read in Polish.** The voice is English. The transcript and on-screen text are Polish (the same content IDs). This is the "subtitles" mode.

Always state the limit once, in the language picker footnote, never as an error:
> "Polish stories are shown as text. HarmonyOS on-device speech currently speaks English and Chinese."

Sentence by sentence (Polish): "Polskie opowieści są wyświetlane jako tekst. Mowa na urządzeniu w HarmonyOS obsługuje obecnie angielski i chiński." ⚠️ Have a native speaker check this translation.

#### Flow G: Demo walk (SIMULATED)

1. **Entry points:**
   - Settings › Demo walk toggle.
   - Contextual: when there's no GPS fix within 15 s on Route ready, or the location permission is denied, the link "No GPS here? **Try a demo walk**" appears.
2. When it's on:
   - The location source replays the recorded Royal Route track (position + course + speed) through the same pipeline.
   - Every walking surface shows the amber **SIMULATED** pill.
   - The AVSession artist line gets the suffix " · Simulated walk".
   - The map's user dot changes to a **hollow** blue ring.
3. Now Walking gets a **Demo controls** sheet, opened from the pill: speed `1× / 2× / 4× / 8×` (SegmentButton), **Jump to next stop**, **Pause replay**, **Simulated clock: 11:59** **(Hejnał moment, proposal)**.
4. The Tour summary shows "Simulated walk: distances and times come from a recorded route."

---

## 3. Screen-by-screen specification

**Common conventions** (they apply unless a screen says otherwise):
- Page side margin: 16 vp. Content max width: 600 vp.
- Text in `fp`, layout in `vp`. All colours come from §4.1 tokens (resource names `color.<token>`, light in `base/`, dark in `dark/`).
- Every interactive element has a hit area ≥ 48×48 vp, even when its visual size is smaller (use `.responseRegion` or padding).
- Every icon-only control has `.accessibilityText($r('app.string.…'))`.
- Cards that read as one item get `.accessibilityGroup(true)` and a composed `.accessibilityText`.
- Capitalisation: **sentence case everywhere** in EN and PL (HarmonyOS English UI convention). Overline labels are uppercase in Latin scripts only, never in ZH.
- **String length:** design every label for **PL ≈ 1.3× EN** length and **ZH ≈ 0.6× EN** characters but taller glyphs. Buttons wrap to two lines rather than truncating. Never set a fixed width on a text container. Key CTAs are listed in §3.17 with PL/ZH drafts.

### 3.1 Onboarding (3 steps)

**Purpose:** set expectations (pocket, headphones), pick a language and voice, explain permissions. It should take under 30 s, and every step can be skipped.

**Layout (all 3 steps)**, as a `NavDestination` with the title bar hidden:

```
┌──────────────────────────────┐
│                       Skip   │  ← Button(TEXTUAL), top-right, 48vp hit
│                              │
│   [visual, 240vp tall]       │
│                              │
│  Title (title1 28fp bold)    │
│  Body (body 16fp, secondary) │
│                              │
│  [step-specific controls]    │
│                              │
│            ● ○ ○             │  ← progress dots (3)
│ [        Continue         ]  │  ← Button(EMPHASIZED, Capsule, 48vp tall, full width)
└──────────────────────────────┘
```

| Step | Visual | Title | Body | Controls |
|---|---|---|---|---|
| 1 | A static vector of the Royal Route: the accent line from Barbican to Wawel over the muted map, three plaque markers (1, 5, 11), and a `headphones` symbol 32 vp next to the route start. No illustration people, no gradient. | **Your guide fits in your pocket** | "Put your headphones in, lock your phone and walk. The Historian leads you through Kraków and tells you about each place as you reach it." | **Continue** |
| 2 | – (controls are the visual) | **How should the guide speak?** | "You can change this any time." | A `List` (card style) of 3 radio rows. Row: language name (body-emph), subtitle (callout), trailing `Radio`. ① *English*, "Spoken · Fallback voice" (zh-CN voice reading English; "Spoken · Laura voice" only if Laura is `INSTALLED`) with a status chip (*Installed* / *Download, ⚠️ size TBD; fails on the emulator*) ② *中文*, "Spoken · 聆小珊" ③ *Polski*, "Text only" with an ⓘ footnote about the platform limit. Below: **Play a sample** (`Button` NORMAL, `speaker_wave_2` symbol). The voice download uses an inline `Progress` (Linear) in the row. |
| 3 | – | **Two permissions, and why** | – | Two `HdsListItem`- or `ListItem`-style rows. Each has a leading symbol (32 vp, accent), title, a 2-line reason and a trailing small **Allow** button. After grant: a `checkmark_circle_fill` in accent plus "Allowed". Footer `Text` (footnote): "Location is used only while a tour is running. Nothing leaves your phone." Primary button: **Done**. Secondary: **Set up later** (TEXTUAL). |

**ArkUI:** a single `Swiper` with `disableSwipe(true)` (so it's button-driven, which avoids accidental swipes during permission prompts) and `indicator(false)` with custom dots. Or use three `NavDestination`s. Either is fine; Swiper is less code.

**Accessibility:**
- Progress dots are `accessibilityText("Step 2 of 3")`.
- Skip has "Skip introduction".
- Each permission row is grouped: "Location. Finds the next stop… Allow, button."

**Dark mode:** same layout, with tokens switching.

**States:**
- Download failing: the row subtitle becomes "Couldn't download. Try again", with a retry icon `arrow_clockwise`.
- Offline: "Connect to the internet to download this voice, or choose another."

### 3.2 Home

**Purpose:** start or continue the one tour. Secondary: browse all places, open settings.

```
┌──────────────────────────────┐
│ CityTour               ⚙︎     │  ← Navigation title (Full mode, collapses), menu: gearshape → Settings
│ Kraków · offline ready ✓     │  ← subtitle (callout, secondary)
│                              │
│ ┌──────────────────────────┐ │  ← [only if a session exists] CONTINUE card
│ │ NOW WALKING        ● live│ │     overline + live dot (accent) / or "PAUSED"
│ │ The Royal Route          │ │
│ │ Stop 4 of 11 · Cloth Hall│ │
│ │ ▬▬▬▬▬▬▬▬▬▬○○○○○○○        │ │  ← Progress (Linear), accent
│ │ [ Open ]       End tour  │ │
│ └──────────────────────────┘ │
│                              │
│ GUIDED TOURS                 │  ← SubHeader
│ ┌──────────────────────────┐ │
│ │ [map thumbnail 16:9]     │ │  ← static pre-rendered route image (Canvas → PixelMap cached)
│ │ The Royal Route          │ │  ← title3
│ │ From the Barbican to     │ │
│ │ Wawel Hill               │ │  ← callout secondary, 2 lines
│ │ 11 stops · 2.5 km ·      │ │
│ │ ~1 h 20 min              │ │  ← footnote, tabular numbers
│ │ The Historian · EN 中文 PL│ │  ← chips (Chip small, outline)
│ └──────────────────────────┘ │
│                              │
│ EXPLORE                      │
│ ┌──────────────────────────┐ │
│ │ ◎ All places in Kraków  ›│ │  ← ListItem: map symbol, "3,412 places, offline" (count from the pack)
│ └──────────────────────────┘ │
└──────────────────────────────┘
```

| Element | ArkUI | Notes |
|---|---|---|
| Title bar | `Navigation` `.title("CityTour")` `.titleMode(NavigationTitleMode.Full)` `.menus([{ value: '', symbolIcon: gearshape, action → Settings }])` | Menu item accessibility text: "Settings". |
| Continue card | `Column` in a card (`bg.surface`, radius `r.lg`), `Progress({ type: ProgressType.Linear })` | Whole card tappable → NowWalking. "End tour" is a TEXTUAL button with a confirmation dialog. |
| Tour card | `Column` → `Image` (16:9, radius `r.md` top), texts, `Chip` row | One tap target. Pressed state uses system `stateStyles` pressed with `interactive_pressed`. |
| Section headers | `SubHeader` (advanced component) ✅ or `Text` overline | |
| Explore row | `List` + `ListItem` (or `HdsListItem`) with leading `SymbolGlyph($r('sys.symbol.map'))` and trailing `chevron_right` | |

**States:**
- **First launch:** no Continue card.
- **Offline pack missing or corrupt** (should never happen, since it's bundled): full-screen `ExceptionPrompt` ✅ with "Tour data couldn't be loaded. Reinstall the app or contact us." It needs no retry action, because the pack is local.
- **Dark mode:** the thumbnail map uses the dark map style (§4.8). Pre-render both variants.

**Accessibility:** the tour card reads "The Royal Route. From the Barbican to Wawel Hill. 11 stops, 2.5 kilometres, about 1 hour 20 minutes. Guide: The Historian. Button." Spell out units in `accessibilityText` (screen readers read "km" badly).

### 3.3 Tour detail

**Purpose:** decide to go. Show the route, the stops, the commitment (distance and time), and that it's trustworthy.

```
┌──────────────────────────────┐
│ ‹                            │  ← NavDestination Mini title, transparent over map; back
│ [MAP PREVIEW 260vp]          │  ← Canvas map, non-interactive; tap → FullMap(tour)
│  route accent, plaques 1…11  │
│                    [ ⤢ ]     │  ← "Expand map" 40vp floating, blur bg
├──────────────────────────────┤
│ The Royal Route              │  ← title1
│ The kings' coronation path,  │
│ from the city gate to the    │
│ castle.                      │  ← body secondary
│                              │
│ ⟟ 2.5 km   ◷ ~1 h 20 min   11 │  ← 3 stat columns (title3 tabular + caption label)
│  walk        with stories  stops
│                              │
│ ┌ Guide ──────────────────┐  │
│ │ ◉ The Historian       › │  │  ← persona row (§6); › only when >1 persona
│ │ English · Fallback voice│  │
│ └─────────────────────────┘  │
│                              │
│ STOPS                        │
│ ① Barbican         1498 · 3 min│  ← ListItem: plaque marker, name, year · story length
│ │                              │  ← 2vp vertical connector line (divider colour) between plaques
│ ② St Florian's Gate     ·2 min │
│ ③ St Mary's Basilica    ·5 min │
│ …                              │
│ ⑪ Wawel Hill            ·6 min │
│                              │
│ ABOUT THESE STORIES          │
│ Drafted with AI, reviewed by │
│ a person. 23 sources cited.  │
│ See sources ›                │  ← → AboutAndSources filtered to this tour
│                              │
│ (spacer 96vp for sticky bar) │
├──────────────────────────────┤
│ [       Start tour        ]  │  ← sticky bottom bar, bg.surface + top divider, safe area
└──────────────────────────────┘
```

| Element | ArkUI |
|---|---|
| Map preview | `Canvas` (or the map component chosen in ARCHITECTURE.md) inside a `Stack`; `.expandSafeArea` top; `.accessibilityText("Map of the Royal Route with 11 stops")`; tap → FullMap |
| Stats | `Row` of 3 `Column`s; numbers `fontFeature("\"tnum\" 1")` ✅ |
| Stops list | `List` + `ListItem`s; leading custom `PlaqueMarker` component (§4.8); `.divider` off; connector drawn as a 2 vp `Line`/`Divider` inside the item |
| Tap stop | → `PlaceDetail(poiId)` (read before you go) |
| Sticky CTA | `Column` pinned with `Stack` alignment Bottom; `Button({ type: ButtonType.Capsule, buttonStyle: ButtonStyleMode.EMPHASIZED, controlSize: ControlSize.NORMAL })`, height 48, full width ✅ |

**States:**
- Location not granted: the banner from Flow D sits above the CTA, and the CTA still reads **Start tour** (tapping it triggers the request).
- Voice needs a download: this is handled on Route ready, not here.

### 3.4 Route ready (planning result)

**Purpose:** show that the app *computed* the best order for *you, from here*. This demonstrates the algorithm for the jury, and it's a trust moment for the user.

```
┌──────────────────────────────┐
│ ‹  Your route                │  ← Mini title
│ [MAP 300vp: optimised route, │
│  user dot, plaques renumbered│
│  in walking order]           │
├──────────────────────────────┤
│ Starting near you            │  ← overline
│ Cloth Hall, 120 m away       │  ← title2
│                              │
│ {d} km · {t} min walking ·   │
│ ~1 h 25 min with stories     │  ← body, tabular
│ ✓ Optimised order: {saved} m │
│   shorter than the listed    │
│   order                      │  ← callout, accent checkmark; only if saving ≥ 50 m. {saved} is computed at runtime: "640 m" in the mockups is a placeholder, not a measured value
│                              │
│ START FROM                   │
│ ( My location | First stop ) │  ← SegmentButton (capsule)
│                              │
│ TIME AVAILABLE  (proposal)   │
│ ( All stops | 45 min | 90 min)│ ← SegmentButton; picks subset (orienteering)
│ "45 min: 6 of 11 stops."     │  ← live result line
│                              │
│ ┌ English voice needs a ───┐ │  ← only if voice GA (Flow E)
│ │ one-time download        │ │
│ │ [Download] Read instead  │ │
│ └──────────────────────────┘ │
├──────────────────────────────┤
│ [          Begin          ]  │  ← opens Before-you-go sheet
└──────────────────────────────┘
```

- **Order list:** collapsed by default. "Show order" (`chevron_down`) expands a compact `List` of renumbered stops, with a leg distance between them ("↓ 180 m").
- **SegmentButton:** `@ohos.arkui.advanced.SegmentButton` ✅ (capsule type, 2 or 3 items). On change, re-plan synchronously and cross-fade the map route (150 ms).
- **States:**
  - **Computing** (over 300 ms only): inline `LoadingProgress` 24 vp next to the "Starting near you" line, with "Planning your route…".
  - **No GPS fix after 15 s:** the line becomes "Waiting for GPS… Step into the open sky." plus the link **Try a demo walk**. Planning falls back to "First stop".
  - **User far from Kraków (over 5 km from the first stop):** "You're 1,240 km from Kraków. Start from the first stop, or try a demo walk." The segment is forced to *First stop*.
  - **Location denied:** the Flow D banner.

### 3.5 Before you go (sheet)

**Purpose:** the ritual. Headphones in, check the volume, lock the phone. It doubles as the user-initiated start of the background tasks.

- `bindSheet` with `detents: [SheetSize.FIT_CONTENT]`, `dragBar: true`, `showClose: true`, title "Before you go".
- Three numbered rows (plaque style, but with neutral plaques):

| # | Symbol | Text | Control |
|---|---|---|---|
| 1 | `headphones` | **Headphones in.** "The guide talks as you walk." | – (if a wired or BT output device is detected ⚠️, show "Connected: \<device name\>" with a checkmark) |
| 2 | `speaker_wave_2` | **Check the volume.** | **Play a test line** (NORMAL button). Speaks: "Hello, I'm your guide. If you can hear me clearly, we're ready." |
| 3 | `lock_fill` | **Lock your phone.** "I'll keep talking and tell you where to look." | – |

- Footnote: "While the tour runs, CityTour uses your location with the screen locked. You'll see a system notification. Stop any time from the app or the notification."
- Primary: **Start walking** (EMPHASIZED, full width).
- In text-only mode (PL): row 1 becomes "Notifications on: you'll feel a vibration and see a note at each stop." Row 2 is hidden.

### 3.6 Now Walking (primary screen)

**Purpose:** the glanceable mirror of the audio. It answers four questions in this order:
1. **Where next?**
2. **How far, and which way?**
3. **What am I hearing?**
4. **How do I pause or replay?**

**Layout (phone portrait, 390×844).** The map sits on top and the panel is anchored below; this is *not* a draggable sheet, for stability and glanceability.

```
┌──────────────────────────────┐
│ ⌄  Royal Route  4/11  ⋯      │  ← custom header over map: ⌄ = back to Home (tour keeps running),
│                [SIMULATED]   │    ⋯ = menu; SIMULATED pill only in demo (amber)
│                              │
│   MINI MAP  (≈ 40% height,   │  ← heading-up map, user dot + cone, next leg in accent,
│   ~320vp) full-bleed under   │    later legs 45% accent, visited grey; tap → FullMap
│   status bar                 │
│                         [◎]  │  ← recenter (only if user panned FullMap… n/a here) / "Expand"
├──────────────────────────────┤  ← panel: bg.surface, radius r.xl top corners, shadow e2
│ NEXT · STOP 4                │  ← overline (caption, secondary)
│ Cloth Hall                   │  ← title2 22fp bold, 2 lines max
│                              │
│  180 m          ╭─•─╮        │  ← display 34fp tabular   |  LOOK CUE / DIRECTION DIAL (72vp)
│  about 2 min    ahead, right │  ← callout                |  caption under the dial
│                              │
│ ┌──────────────────────────┐ │  ← NOW PLAYING card (bg.surfaceSunken, r.lg)
│ │ ▍▍▍ St Mary's Basilica    │ │    waveform glyph (static when paused) + story title (body-emph)
│ │ "The taller tower, on    │ │    current sentence (transcript 18fp, 3 lines, fades older text)
│ │ your left, is where the  │ │
│ │ trumpeter plays…"        │ │
│ │ ▬▬▬▬▬▬○○○○ Story 2 of 3   │ │    segment progress (Linear, thin 3vp) + caption
│ └──────────────────────────┘ │
│                              │
│   ⟲          ❚❚          ⏭    │  ← controls: Replay 56vp · Play/Pause 72vp (accent fill) · Skip 56vp
│ Transcript        Stops (11) │  ← two TEXTUAL buttons, 48vp
└──────────────────────────────┘
```

**Components**

| Element | ArkUI | Spec |
|---|---|---|
| Container | `NavDestination().hideTitleBar(true)`, root `Stack` | Map layer `.expandSafeArea([SafeAreaType.SYSTEM],[SafeAreaEdge.TOP])`. Panel in `Column` aligned bottom. |
| Header | `Row` over the map with a `bg.scrim` background (40% canvas + `BlurStyle.COMPONENT_THICK` ✅) as a capsule, 40 vp tall | ⌄ `chevron_down` "Minimise, tour keeps running". Title "Royal Route", plus "4/11" in tabular. ⋯ uses `dot_grid_1x2` or `ellipsis_circle` and opens a `Menu`: **Stops**, **Full map**, **Language: English ⇄ 中文** (mid-tour switch), **How it works** (HUD toggle), **End tour** (role ERROR, red text). |
| SIMULATED pill | `Text` in a `Row` capsule: `signal.simulated.bg` fill, `signal.simulated.fg` text, caption 12 fp medium, letter-spacing 0.6, symbol `figure_walk` 14 vp | Tap → Demo controls sheet. `accessibilityText("Simulated location. Demo walk is on. Opens demo controls.")` |
| Mini map | Map component (Canvas). **Heading-up** while walking (it rotates with the course over ground, smoothed). A tiny north tick at the edge. | Tap → FullMap. A11y: "Map. Next stop Cloth Hall, 180 metres ahead, slightly right. Double-tap to open full map." |
| Next-stop block | `Column`: overline, `Text` title2 (`maxLines(2)`, `textOverflow(Ellipsis)`), `Row` [distance column, Look cue] | The distance uses `display` 34 fp with `.maxFontScale(1.6)` so it survives large text without overflowing the row. If it overflows, the row wraps: the dial moves under the distance. |
| Distance rounding | – | Under 100 m: 10 m steps. 100–1000 m: 20 m steps. Over 1 km: "1.2 km". Update the text at most every 2 s and only when the rounded value changes. No number animation. |
| Look cue / direction dial | Custom component on `Canvas` or `Shape`/`Path`, 72×72 vp | See §3.6.1. |
| Now playing card | `Column`, `bg.surfaceSunken`, `r.lg`, padding 16 | The waveform glyph is `sys.symbol.waveform` (static) with SymbolGlyph effect strategy *none*. Optional: `SymbolEffect` variable-colour animation **only while playing**, and none if reduce-motion is on. Sentence text: transcript 18 fp/28; the current sentence is `text.primary` and the previous sentence `text.tertiary`; max 3 lines with a fade mask on top. |
| Controls | 3 `Button({type: ButtonType.Circle})` | Replay = `arrow_counterclockwise` ("Replay last part"). Play/Pause = `play_fill`/`pause_fill` on `accent` 72 vp with `onAccent` icon 32 vp. Skip = `forward_end_fill` ("Skip this part"). Spacing 40 vp between centres. No haptic on tap (frequent action). |
| Bottom links | `Button` TEXTUAL ×2 | **Transcript** → PlaceDetail(current stop, anchor = transcript). **Stops (11)** → StopsSheet. |

#### 3.6.1 The Look cue (signature element)

A 72 vp half-dial that is always relative to the direction you're walking.

- **Shape:** a 180° arc (top half) in `divider` colour, 3 vp stroke. A small "you" notch sits at the bottom centre. One **accent dot** (12 vp) is placed on the arc at the target's relative bearing (−90° = left, 0° = ahead, +90° = right). For targets behind you (|bearing| > 110°), the dot moves to the bottom with a `chevron_down` and the caption "behind you".
- **"Up" modifier:** when the script says to look up (towers, façades), a 10 vp `arrow_up` sits above the dot.
- **Caption** (caption 12 fp, under the dial). Use the same words as the voice: *ahead · ahead, slightly right · on your right · behind you, right · on your left · look up, left*.
- **Heading source:**
  - Use **course over ground** from `Location.direction` when speed ≥ 0.6 m/s ✅ (field exists).
  - Below that, freeze the last good course for 20 s, then switch the dial to **"landmark mode"**: the dial is hidden and replaced by the text "Face St Mary's Basilica" with `figure_walk`. A11y and audio do the same thing.
- **Motion:** the dot rotates to a new position with 200 ms `Curve.Friction`, only when the change is ≥ 10°. Reduce motion makes it jump.
- **A11y:** `accessibilityText("Cloth Hall is ahead, slightly right")`. This is identical to the caption plus the name.

#### 3.6.2 Now Walking states (each needs a mockup variant)

| State | Overline | Title | Hero | Look cue | Now playing card | Extra |
|---|---|---|---|---|---|---|
| **Heading to stop** | NEXT · STOP 4 | Cloth Hall | 180 m / about 2 min | dot at the relative bearing | last story or a directions line "Walk down Floriańska Street…" | – |
| **Approaching** (≤ radius + 30 m) | IN 50 M · ON YOUR LEFT | St Mary's Basilica | 50 m | dot left, emphasised (ring) | – | earcon |
| **Arrived / story playing** | YOU'RE HERE · STOP 3 | St Mary's Basilica | "Look left and up" (title3 replaces the distance) | dot left + arrow up | story, Story 1 of 3 | **Tell me more** button appears in the card when the main story ends and a Deep layer exists |
| **Teaser (walking past)** (proposal) | PASSING · STOP 3 | St Mary's Basilica | – | – | teaser text + chip "Short version · stop for a moment to hear the full story" | – |
| **Paused** | PAUSED | (same) | (same, values dimmed to `text.secondary`) | static | play_fill large | – |
| **Reading (text-only PL)** | JESTEŚ TUTAJ · PRZYSTANEK 3 | Kościół Mariacki | – | dot | The card expands to the **full transcript** (scrollable, 20 fp/30), controls hidden, replaced by **Następny przystanek** ("next stop") | the map shrinks to 200 vp |
| **Weak GPS** (accuracy > 30 m) | (normal) | | distance shown with "~" prefix | dot shown at 50% opacity | | banner `exclamationmark_triangle_fill`: "Weak GPS: distances may jump." |
| **No GPS** (> 20 s) | WAITING FOR GPS | Cloth Hall | "—" | hidden | | banner + **Try a demo walk** |
| **Off route** (proposal) | OFF ROUTE | Cloth Hall | 220 m | dot behind, right | | banner "Re-planned from here." |
| **Hejnał moment** (proposal; time-aware) | STOP HERE | St Mary's Basilica | "Trumpet in 0:40" (countdown, `TextTimer` ✅) | dot left + up | "Listen for the melody breaking off." | SIMULATED pill if the clock is simulated |
| **Tour complete** | TOUR COMPLETE | Wawel Hill | – | – | farewell line | auto-navigates to Summary after 3 s **only if the app is in the foreground**, otherwise on next open |

**Banners** sit inline at the top of the panel (above the overline). One at a time, priority: permission > GPS > off-route > info. Use `bg.warningSubtle` with a `text.primary` message, a 20 vp symbol, and an optional single action. Never use a toast for persistent conditions (HIG `feedback.md`).

**How it works HUD** (OPPORTUNITIES #6). A toggle in the ⋯ menu. A translucent (`COMPONENT_THICK` blur) card over the map, monospaced-feel tabular caption text, 8 lines:

```
Location   Demo walk (SIMULATED) · 4×      ← or "Location Kit · GNSS ±6 m"
Course     212° · 1.3 m/s
Next       Cloth Hall · 180 m · bearing +18°
Trigger    approach @65 m · arrive @35 m
Voice      Core Speech TTS · zh-CN reads EN (Fallback voice) · speaking
Session    AVSession active · playing
Background LOCATION + AUDIO_PLAYBACK running
Spatial    not supported on this output     ← proposal
```

It's dismissable and remembers its state per session. It's for demos, but honest and useful.

**Dark mode:** the map uses the dark style. The panel is `bg.surface` dark. The accent Play button keeps `accent` dark (`#6CC3AE`) with `onAccent` dark (`#062A23`), giving 7.4:1.

**Accessibility:**
- Reading order: header → banner → overline + title + distance + Look cue (grouped: "Next stop 5, Cloth Hall, 180 metres, about 2 minutes, ahead slightly right") → now playing (grouped) → controls → links.
- **Don't** re-announce the distance on each update. Announce only on state changes (approaching, arrived), and through the voice guide, not the screen reader, to avoid double speech. When the screen reader is on, the guide still speaks. ⚠️ Test the overlap with the HarmonyOS screen reader.

### 3.7 Full map

**Purpose:** spatial overview. Where am I, where are the stops, what else is nearby? Two modes: **tour** (from Now Walking or Tour detail) and **explore** (all places).

```
┌──────────────────────────────┐
│ [‹]                 [layers] │  ← floating 40vp circular buttons, blur bg, safe area
│                              │
│        full-bleed map        │
│     north-up by default      │
│                              │
│                       [◎]    │  ← recenter / follow-heading toggle (location_up_fill ↔ navigation)
│                       [+][-] │  ← optional zoom buttons (pinch also works); a11y alternative to gestures
├──────────────────────────────┤
│ ① ② ③ ④ ⑤ ⑥ … (tour mode)    │  ← bottom bar: horizontal List of plaque chips; tap → focus + PlaceCard
│ Stop 4 of 11 · 180 m to next │
└──────────────────────────────┘
```

- **Explore mode** replaces the bottom bar with filter `Chip`s, where each chip is filled when active, with a count: *Tour stops*, *Monuments (395)*, *Plaques (923)*, *Heritage*, *Museums*.
  - Category counts come from the pack.
  - Non-tour places are 8 vp neutral dots, clustered under zoom 16 (a cluster is a 24 vp circle with a count).
  - The UNESCO Old Town boundary is a dashed neutral line labelled "UNESCO Old Town" (from `UNESCO_4f365`).
- **Place card** (on tap of a pin or dot): `bindSheet` `detents: [180, SheetSize.MEDIUM]`, `enableOutsideInteractive: true` (the map stays usable), `dragBar: true`.
  - Content: name (title3), type and year (callout), distance and direction from you ("240 m, ahead left"), a 2-line teaser, a provenance label (*Tour story* / *From Wikipedia* / *City heritage register*).
  - Buttons: **Listen** (TTS of the short text) and **Details** → PlaceDetail.
  - In tour mode, one more action: **Go here next** (re-plans; proposal).
- **Gestures:** pan, pinch, double-tap zoom, and two-finger rotate (optional). Gesture-driven motion tracks the finger with no easing.
- **Map states:**
  - Map data failed to render: a muted `ExceptionPrompt` "Map unavailable" with the list fallback below. The tour still works.
  - Location unknown: the user dot is hidden, the recenter button is disabled with a tooltip "Waiting for GPS".

### 3.8 Place detail

**Purpose:** read and listen at your own pace. Transcript, photos, facts, sources, "Tell me more".

```
┌──────────────────────────────┐
│ ‹  St Mary's Basilica   ⤴︎   │  ← Mini title appears on scroll (HdsNavigation blur if adopted); ⤴︎ share (stretch)
│ [PHOTO SWIPER 4:3]           │  ← Swiper of 1–4 images, dots; caption overlay "© author, CC BY-SA 4.0"
│                              │
│ STOP 4 · CHURCH · 14TH C.    │  ← overline
│ St Mary's Basilica           │  ← title1 (2 lines)
│ Kościół Mariacki             │  ← local name, callout secondary (shown when UI ≠ PL)
│ 180 m · ahead, slightly left │  ← live distance (only during a tour / with fix)
│                              │
│ [▶ Listen · 4 min] [Tell me more] │ ← EMPHASIZED small + NORMAL small; Listen ↔ Pause
│                              │
│ ┌ LOOK ───────────────────┐  │  ← "Where to look" box (only for tour stops)
│ │ The taller tower, on    │  │
│ │ your left as you face   │  │
│ │ the front, look up to   │  │
│ │ the top window.         │  │
│ └─────────────────────────┘  │
│                              │
│ Transcript paragraphs        │  ← transcript 18fp/28, max width 600, paragraph spacing 12
│ (currently spoken sentence   │
│  gets accent left rule 3vp)  │
│                              │
│ FACTS                        │  ← 3–5 rows key/value (Built · Architect · Height)
│ SOURCES                      │  ← numbered list; each: title, publisher, licence, link
│ [1] Kraków heritage register  │
│     A-1, entry ID …          │
│ [2] Wikipedia, "St. Mary's…" │
│     rev. 1234567, CC BY-SA   │
│                              │
│ ⓘ Drafted with AI from the   │
│   sources above, reviewed by │
│   a person on 3 Oct 2026.    │  ← footnote, `info_circle`
│   Report a problem ›         │  ← stretch
└──────────────────────────────┘
```

- **ArkUI:** `Scroll` > `Column`; `Swiper` with `.indicator(Indicator.dot())`, `.loop(false)`; images `Image` with `.objectFit(ImageFit.Cover)`, `.alt(placeholder)`. **No photo?** Show a 4:3 map snippet centred on the place (always available offline).
- **Sources:** links open in the system browser through `startAbility` (want with `uri`). While offline, tapping shows the toast "You're offline. The link will open when you're connected." There's no in-app WebView (it loses platform points and adds risk).
- **Non-tour place (explore):** the overline shows the category. The provenance label is visible at the top as a `Chip`: *From Wikipedia* / *From the city heritage register*. "Tell me more" is hidden when there's no deep content. Listen speaks the short text.
- **States:**
  - Loading: none, since everything is local (render synchronously; images decode async with placeholder `bg.surfaceSunken`).
  - Missing translation: the content falls back to EN with the chip "Shown in English".
- **Accessibility:** each image has `.alt` and an `accessibilityText` from the caption. The transcript is selectable text (`copyOption(CopyOptions.LocalDevice)`). The Listen button announces its state.

### 3.9 Stops sheet

- `bindSheet` with `detents: [SheetSize.MEDIUM, SheetSize.LARGE]`, title "Stops", `dragBar`.
- A `List` in walking order. Each row: a plaque (state colours §4.8), name, and status: *Visited ✓ · 3 min ago* / *Next · 180 m* / *Upcoming*.
- Swipe actions, plus a long-press `Menu` with the same items for accessibility:
  - Upcoming stops: **Skip** and **Go here next** (proposal).
  - Visited stops: **Listen again**.
- Footer: "2 of 11 visited · 1.6 km to go".

### 3.10 Tour summary

**Purpose:** close the loop, and let people revisit stories later.

```
┌──────────────────────────────┐
│ Tour complete            Done│  ← Mini title; Done (EMPHASIZED text) → Home (clears session)
│ [MAP 220vp: walked line grey,│
│  plaques all visited ✓]      │
│                              │
│ The Royal Route              │  ← title1
│ Saturday, 3 October          │  ← callout
│ [SIMULATED WALK]             │  ← pill, only if demo
│                              │
│  11/11     2.5 km    1 h 24m │  ← stat trio (title2 tabular + caption)
│  stops     walked    total   │
│                              │
│ YOU HEARD                    │
│ ① Barbican              ›    │  ← List; tap → PlaceDetail
│ …                            │
│                              │
│ Sources and credits ›        │
│ [ Start again ]              │  ← NORMAL button (rarely used)
└──────────────────────────────┘
```

- Partial tour (ended early): the title is "Tour ended", stats show "6/11 stops", and skipped stops are listed under "Still to see" with distance from here.
- No confetti, no rating prompt, no share push. (A share card is stretch.)

### 3.11 Settings

A `NavDestination` with title "Settings" (Full mode) and a `List` with `ListItemGroup`s in card style (`bg.surface`, `r.lg`, 16 vp gaps). Footnotes under groups use footnote 13 fp secondary.

| Group | Row | Control (ArkUI) | Values / copy |
|---|---|---|---|
| **Narration** | Story language | → sub-page with radio `List` | English (spoken) · 中文 (spoken) · Polski (text only) · *Listen in English, read in Polish* |
| | App language | → sub-page | System · English · Polski · 中文 → `i18n.System.setAppPreferredLanguage` ✅ |
| | Voice | → Voice page | "Fallback voice (Chinese voice reads English)" on the emulator; "Laura · Installed" only on a device that has it. The page lists the voices for the language with status, **Download**/progress, **Play a sample**, and **Speed** `Slider` 0.8×–1.4× (step 0.1, `enableHapticFeedback` ✅). TTS speed range is 0.5–2 ✅. We cap it for intelligibility. |
| | Guide | → Guide page (§6) | "The Historian" |
| | Detail level | `SegmentButton` | **Brief** · **Standard** · **Deep**. Footnote changes per value: "Brief: about 1 minute per stop." / "Standard: about 3 minutes per stop, with directions." / "Deep: the full story, plus nearby places along the way." |
| **Walking** | Spoken directions | `Toggle` (Switch) | On. Footnote: "Short directions at turns between stops." |
| | Mention places along the way | `Toggle` | On at Standard and Deep. Off at Brief. |
| | Start the story when I'm within | `SegmentButton` | 20 m · **35 m** · 50 m. Footnote: "Larger works better in narrow streets where GPS drifts." |
| **Sound and haptics** | Arrival chime | `Toggle` | On |
| | Vibrate on arrival | `Toggle` | On (needs `ohos.permission.VIBRATE`) |
| **Offline data** | Kraków pack | → OfflineData page | "3,412 places · 11 tour stories · 48 MB ⚠️ (real numbers from the pack) · Included with the app". The page shows: built date, sources with licences (ODbL OSM, Kraków open data licence ⚠️, Wikipedia CC BY-SA), **Check for update** (stretch, disabled in MVP: hide it instead). |
| **Demo** | Demo walk | `Toggle` | Off. Title "Demo walk (simulated location)". Footnote: "Replays a recorded walk along the Royal Route instead of using GPS. Everything simulated is labelled SIMULATED." When it's on, two more rows appear: **Replay speed** `SegmentButton` 1× · 2× · 4× · 8×, and **Simulated clock** `Toggle` (Hejnał demo; proposal). |
| **Permissions** | Location | value + → | "Precise · while using" / "Off". Action: **Open settings** (`requestPermissionOnSetting`). |
| | Notifications | value + → | "On" / "Off" → `openNotificationSettingsWithResult` ✅ |
| **About** | How these stories are made | → page | the AI disclosure (§3.15) |
| | Sources and licences | → page | |
| | Show introduction again | row | replays onboarding |
| | Version | value | "1.0 (HackYeah 2026 build)" |

There's no in-app light/dark switch; follow the system (HIG `dark-mode.md`: "Avoid offering an app-specific appearance setting").

### 3.12 Lock screen and system surfaces

#### 3.12.1 AVSession playback card (primary lock-screen surface)

- **Session:** `AVSessionManager.createAVSession(ctx, 'CityTour', 'audio')` ✅. The 'audio' template shows favourite, previous, play/pause, next and loop ✅.
- **Metadata mapping** (✅ the fields exist: `title`, `artist`, `album`, `mediaImage`, `lyric`, `singleLyricText` (API 17+), `duration`):

| Field | Heading to a stop | At a stop (story) | Text-only / paused |
|---|---|---|---|
| `title` | "Walking to Cloth Hall" | "St Mary's Basilica" | (same) |
| `artist` | "Next: Cloth Hall · 180 m" (refresh at most every 20 m or 15 s) | "The Historian · Story 2 of 3" | "Paused" |
| `album` | "The Royal Route · Stop 5 of 11" | "The Royal Route · Stop 4 of 11" | |
| `mediaImage` | 512×512 artwork: a plaque with the stop number on `accent`, pre-rendered per stop (stretch: stop photo) | same | |
| `singleLyricText` | current spoken sentence ⚠️ (check how the control centre displays it) | current sentence | – |
| Demo walk | the `artist` suffix " · Simulated walk" | | |

- **Controls:** `on('play')`, `on('pause')`, `on('playPrevious')` = **Replay** (restart the current segment), `on('playNext')` = **Skip** (end the current segment and go to the next queued item).
  - Turn off `setLoopMode`, `toggleFavorite`, `fastForward`, `rewind` and `seek` (`session.off(...)`, so the system greys them out or hides them ✅). HIG `playing-audio.md`: "Avoid repurposing audio controls."
  - "Tell me more" is **not** mapped to a media button. Its eyes-free equivalent is *stand still* (proposal) or the Deep verbosity level.
- **Headset controls:** play/pause and next work through AVSession for free.
- **Tap the card:** the `WantAgent` launches NowWalking.

#### 3.12.2 Continuous-task notification

- System-generated for the LOCATION (+ AUDIO_PLAYBACK) continuous task. **We don't modify its content** (it's forbidden ✅). Since API 20, an AUDIO_PLAYBACK task with AVSession uses the AVSession notification instead of a separate one ✅.
- We only set its `WantAgent` → NowWalking.
- Dismissing it pauses the tour (Flow C).

#### 3.12.3 Our own notifications (Notification Kit)

Use them sparingly. They're only for cases where audio can't carry the event:

| When | Title | Text | Behaviour |
|---|---|---|---|
| Text-only mode, arrival | "You're at St Mary's Basilica" (PL: "Jesteś przy: Kościół Mariacki") | the first sentence of the story | `isAlertOnce`, tap → PlaceDetail transcript, auto-cancel on the next arrival |
| Text-only mode, turn (proposal) | "Turn right onto Grodzka Street" | "Next: St Adalbert's Church · 120 m" | replaces the previous one (same id), so there's never a stack |
| Audio paused by the system for over 2 min during an active tour | "Tour paused" | "Tap to continue the Royal Route." | once per pause |

Never more than **one** CityTour notification visible at a time (HIG `notifications.md`: "Avoid sending multiple notifications for the same thing"). `isOngoing` ✅ exists, but don't use it, because AVSession already provides the persistent surface.

⚠️ **Live View (实况窗)** needs AGC approval (OPPORTUNITIES #21), so it's out of scope. If AVSession automatically gets a status-bar capsule on this device, that's a bonus. Verify it.

### 3.13 Home-screen widget (Form Kit, ArkTS card)

- Dimensions: `2*2` and `2*4` (`Dimension_2_2`, `Dimension_2_4` ✅). `defaultDimension: "2*4"`.
- Updates: `formProvider.updateForm` from the app process on events only (stop change, play/pause, every ~50 m of distance change). Never per GPS fix.
- **Card limits:** only card-supported components ⚠️. Check that `SymbolGlyph` is allowed in cards. If it isn't, use PNG/SVG media icons.

**2×2: Idle (no tour)**
```
┌────────────────┐
│ ◉ CityTour     │  ← caption, secondary + tiny plaque mark
│                │
│ The Royal      │
│ Route          │  ← title3 18fp bold, 2 lines
│ 11 stops       │  ← caption
│ [   Start   ]  │  ← capsule accent, opens TourDetail
└────────────────┘
```

**2×2: Active**
```
┌────────────────┐
│ NEXT · 5/11  ❚❚│  ← overline + 40vp play/pause (call event → app)
│ Cloth Hall     │  ← title3, 2 lines
│ 180 m          │  ← display-small 28fp tabular
│ ahead, right   │  ← caption (same words as the Look cue)
└────────────────┘
```

**2×4: Active**
```
┌──────────────────────────────────┐
│ NEXT · STOP 4 OF 11      [SIMUL.]│
│ Cloth Hall             180 m     │
│ ahead, slightly right  ~2 min    │
│ ●──●──●──◉──○──○──○──○──○──○──○  │  ← progress plaques (visited filled, next ringed)
│ ▍▍ St Mary's Basilica   ⟲  ❚❚  ⏭ │  ← now playing + 3 controls (call events)
└──────────────────────────────────┘
```

- **2×4 Idle:** the route thumbnail at left (1:1), with "The Royal Route · 2.5 km · ~1 h 20 min" and a **Start** button at right.
- **Stale state:** if there's been no update for over 5 min while the tour is active, show "Paused" instead of a distance. Never show a stale distance as if it were live.
- Dark: the system card background. The accent is used only for the button and the next plaque.

### 3.14 System dialogs and our in-app equivalents (copy)

| Purpose string (module.json5 `reason`) | Text |
|---|---|
| `ohos.permission.LOCATION` / `APPROXIMATELY_LOCATION` | "To find the next stop and know when you've arrived. Used only while a tour is running." |
| `ohos.permission.KEEP_BACKGROUND_RUNNING` | (no dialog, but keep the reason for review) "To keep guiding you when your screen is locked." |
| `ohos.permission.LOCATION_IN_BACKGROUND` (only if the fallback is needed) | "To keep guiding you while your phone is locked in your pocket." |
| `ohos.permission.VIBRATE` | (no dialog) "To vibrate when you arrive at a stop." |

**End tour dialog** (`showAlertDialog`):
- Title: "End the tour?"
- Message: "You've visited 4 of 11 stops. You can't resume after ending."
- Buttons: **Keep walking** (default, primary) and **End tour** (destructive role, red).

### 3.15 AI disclosure page ("How these stories are made")

Short, plain, no marketing:
> "Each tour story was drafted with the help of an AI model from the sources listed with it, then checked and edited by a person. Places outside the tour use short descriptions from Wikipedia or Kraków's heritage register, shown as they are. Nothing you do in the app is sent anywhere. Stories, maps and voices are stored on your phone."

Then: who reviewed (name or initials), the date, and how to report an error (email; stretch).

### 3.16 Global empty, loading, error and offline states

| State | Rule |
|---|---|
| Loading | Everything is local, so screens render immediately. Use `LoadingProgress` (24 vp, inline) only for TTS engine creation over 500 ms, voice downloads, and route planning over 300 ms. Never use a full-screen spinner. |
| Offline | **Not an error.** It's the normal state. The only things that need the network are voice download and source links. The Home subtitle "Kraków · offline ready ✓" signals this permanently. |
| Errors | Inline, in the guide's voice, with what happened and what to do. No apology, no codes in the UI. Codes go to hilog. |
| Empty | Visited list empty on Summary: "You ended before the first stop. The tour is still here when you're ready." |

### 3.17 Key strings with PL and ZH drafts (⚠️ have a native speaker check them)

| Key | EN | PL | ZH |
|---|---|---|---|
| `cta_start_tour` | Start tour | Rozpocznij trasę | 开始游览 |
| `cta_begin` | Begin | Zaczynamy | 开始 |
| `cta_start_walking` | Start walking | Ruszamy | 出发 |
| `cta_tell_more` | Tell me more | Opowiedz więcej | 了解更多 |
| `cta_end_tour` | End tour | Zakończ trasę | 结束游览 |
| `cta_keep_walking` | Keep walking | Idę dalej | 继续游览 |
| `label_next` | Next | Następny | 下一站 |
| `label_here` | You're here | Jesteś tutaj | 您已到达 |
| `label_simulated` | SIMULATED | SYMULACJA | 模拟 |
| `look_left_up` | Look left and up | Spójrz w lewo i w górę | 请向左上方看 |
| `offline_ready` | Kraków · offline ready | Kraków · gotowe offline | 克拉科夫 · 可离线使用 |

The PL CTAs run up to 1.6× longer ("Rozpocznij trasę"), so full-width buttons absorb it. In ZH, keep `text.primary` weights at Medium rather than Bold for body-size text; Bold CJK at 14–16 fp clots.

---

## 4. Visual system (design tokens)

**Token naming:** `color.<role>`, `type.<style>`, `space.<n>`, `radius.<n>`, `elev.<n>`, `motion.<name>`.
- Colours live in `resources/base/element/color.json` and `resources/dark/element/color.json` under the same names. ✅ That's the dark-mode resource qualifier mechanism (最佳实践/深色模式适配).
- Where a system token fits exactly, use it (`$r('sys.color.font_primary')`, etc.) and keep our name as an alias. That keeps us in sync with system contrast settings.

### 4.1 Colour

**The accent, Wawel Patina.**
- It's the verdigris green of the oxidised copper roofs over Kraków's old town and the Wawel Cathedral chapels.
- It's specific to the place, calm, and readable on both light and dark grounds.
- It deliberately avoids the three generated-UI defaults (cream with terracotta, black with acid green, broadsheet hairlines).
- **One meaning only:** *the tour / the guide / go*. It's used for the primary button, the route line, the next-stop plaque, the Look cue dot, progress, and selected states. Nothing else.

Contrast was computed with WCAG 2.x formulas from the hex values below.

| Token | Light | Dark | Use | Contrast (light / dark) |
|---|---|---|---|---|
| `bg.canvas` | `#F4F5F3` | `#0F1112` | page background (softened, not pure white; HIG `dark-mode.md`) | – |
| `bg.surface` | `#FFFFFF` | `#1A1D1F` | cards, panel, sheets | – |
| `bg.surfaceSunken` | `#EEEFEC` | `#24292C` | now-playing card, placeholders | – |
| `bg.scrim` | `#F4F5F3` @ 72% + blur | `#0F1112` @ 72% + blur | floating map controls and header | – |
| `text.primary` | `#16181A` | `#ECEEEF` | titles, body | 16.3:1 on canvas / 14.6:1 on surface (dark) |
| `text.secondary` | `#5A6066` | `#A7ADB2` | meta, captions | 5.8:1 on canvas / 7.5:1 on surface |
| `text.tertiary` | `#6B7176` | `#858C91` | past transcript lines, disabled-looking meta (still ≥ 4.5:1) | 4.5:1 on canvas / 5.0:1 on surface |
| `divider` | `#E1E3DF` | `#2E3336` | separators, the Look cue arc | (non-text) |
| `accent` | `#1D6B5B` | `#6CC3AE` | primary actions, route, next plaque | 5.8:1 on canvas / 8.1:1 on surface |
| `onAccent` | `#FFFFFF` | `#062A23` | text and icons on the accent | 6.4:1 / 7.4:1 |
| `accent.subtle` | `#E3F0EC` | `#17332D` | selected rows, chip fill, Look box bg | accent text on it 5.4:1 / 6.5:1 |
| `map.user` | `#2F6FDE` | `#5C93F0` | the user dot and heading cone only ("blue = you", a platform convention) | ⚠️ check against the map land colours (non-text, needs ≥ 3:1) |
| `signal.simulated.fg` | `#7A4F00` | `#F2C46B` | SIMULATED pill text | 6.4:1 on its bg / 8.3:1 |
| `signal.simulated.bg` | `#FFF1D6` | `#3A2C0D` | SIMULATED pill fill | – |
| `signal.warning.bg` | `#FFF6E5` | `#2E2716` | banners (GPS, permission) | text.primary on it ≥ 14:1 |
| `signal.error` | `#B3261E` | `#F2B8B5` | destructive text (End tour) | 6.5:1 on white / 9.9:1 on surface |

**Rules:**
- Amber = simulated or warning, never brand.
- Red = destructive only.
- Blue = the user's location only.
- No colour carries meaning alone: the SIMULATED pill has text, a visited plaque has ✓, and the next plaque is larger and ringed.
- Increased contrast: if the system high-contrast setting is detected ⚠️, swap `text.secondary` → `text.primary` and the divider → `#A9AEB2`.

### 4.2 Typography

**HarmonyOS Sans** is the system default: SC for Chinese, with Latin Extended for Polish diacritics ✅ (system font, no bundling). All sizes are in **fp**, so they follow the system font size and the 适老化 large-text setting ✅. Numbers that update live use tabular figures: `.fontFeature("\"tnum\" 1")` ✅.

| Token | Size / line height (fp) | Weight | Use | Large-text rule |
|---|---|---|---|---|
| `type.display` | 34 / 40 | Bold 700 | the distance hero only | `.maxFontScale(1.6)` |
| `type.title1` | 28 / 34 | Bold | screen large titles, place names on detail | wraps to 3 lines |
| `type.title2` | 22 / 28 | Bold | next-stop name, summary stats | 2 lines + ellipsis |
| `type.title3` | 18 / 24 | Medium 500 | card titles, sheet titles | |
| `type.body` | 16 / 24 | Regular 400 | default | |
| `type.bodyEmph` | 16 / 24 | Medium | row titles | |
| `type.transcript` | 18 / 28 (20 / 30 in Reading mode) | Regular | story text | paragraph spacing 12 vp, max measure 600 vp (about 65 characters) |
| `type.callout` | 14 / 20 | Regular | meta lines | |
| `type.footnote` | 13 / 18 | Regular | footnotes, sources | |
| `type.caption` | 12 / 16 | Medium | labels, pills, dial caption; **12 fp is the floor**, nothing smaller | |
| `type.overline` | 12 / 16 | Medium, letter-spacing 0.6 vp, UPPERCASE (Latin only) | section labels, NEXT · STOP 5 | ZH: no uppercase, letter-spacing 0 |

Chinese line height is +2 fp on body and transcript. Avoid Light weights everywhere (HIG `typography.md`).

### 4.3 Spacing (vp, 4-pt base)

`space.1 = 4`, `space.2 = 8`, `space.3 = 12`, `space.4 = 16` (page margin, card padding), `space.5 = 24` (section gap), `space.6 = 32`, `space.7 = 48` (touch target / sticky bar height), `space.8 = 64`.
- Phone side margin: 16. At ≥600 vp: 24.
- List rows are at least 56 vp tall (single line) or 72 vp (two lines).
- Controls are spaced ≥ 8 vp edge to edge (HIG `accessibility.md`: spacing matters as much as size).

### 4.4 Corner radii (vp)

| Token | Value | Use |
|---|---|---|
| `radius.sm` | 8 | chips, pills, small thumbnails, HUD rows |
| `radius.md` | 12 | images inside cards, input-like rows |
| `radius.lg` | 20 | cards, now-playing card, list groups (close to the system card radius) |
| `radius.xl` | 28 | the Now Walking panel's top corners (sheets use the system default) |
| `radius.full` | 50% | buttons (Capsule/Circle), plaques, map buttons |

Nested radii must be concentric: inner = outer − padding.

### 4.5 Elevation

The design is flat by default. Shadows are only for things that float over the map.

| Token | ArkUI | Use |
|---|---|---|
| `elev.0` | none | cards on canvas (separated by colour, not shadow) |
| `elev.1` | `.shadow(ShadowStyle.OUTER_DEFAULT_XS)` ✅ | floating map buttons, plaques on the map |
| `elev.2` | `.shadow(ShadowStyle.OUTER_FLOATING_SM)` ✅ | the Now Walking panel's edge over the map |
| Material | `.backgroundBlurStyle(BlurStyle.COMPONENT_THICK)` ✅ | header capsule and map controls only (blur lives on the floating functional layer, never on content) |

### 4.6 Iconography: HarmonyOS system symbols (`SymbolGlyph($r('sys.symbol.<name>'))`)

Every name below was **verified to exist** in the SDK `sysResource.js` (DevEco 6.1.1). The style is outline for navigation and meta, and `_fill` for the primary state and media controls. Symbol size follows the adjacent text (`fontSize` in fp). Colour comes from the tokens via `.fontColor([...])`.

| Meaning | Symbol |
|---|---|
| Settings | `gearshape` |
| Back / minimise / disclosure | `chevron_backward` · `chevron_down` · `chevron_right` |
| Close | `xmark` |
| Play / pause | `play_fill` · `pause_fill` |
| Replay part | `arrow_counterclockwise` |
| Skip part | `forward_end_fill` |
| Previous (unused) | `backward_end_fill` |
| Listening / voice | `waveform` · `speaker_wave_2` · `speaker_slash` · `book_badge_speaker` |
| Headphones | `headphones` |
| Map / route | `map` · `route` · `route_plan` · `satellite_map` |
| My location / follow | `location_up_fill` · `navigation` |
| Walking / arrival | `figure_walk` · `figure_walk_arrival` |
| Look up | `arrow_up` · `eye` |
| Directions | `arrow_left` · `arrow_right` · `arrow_up_right` · `arrow_uturn_down` |
| Stops list | `list_number` · `list_bullet` |
| Distance / time | `ruler` · `clock` · `timer` · `stopwatch` |
| Finish | `flag_checkered` |
| Visited / allowed | `checkmark_circle_fill` · `checkmark` |
| Info / provenance | `info_circle` · `doc_text` · `quote` · `link` |
| Warning | `exclamationmark_triangle_fill` |
| Lock phone | `lock_fill` |
| Notifications | `bell` |
| Language | `translate` |
| Download voice | `square_and_arrow_down` · `arrow_down_circle` |
| Offline / no network | `wifi_slash` |
| Photo placeholder | `picture` |
| Bookmark (stretch) | `bookmark` · `bookmark_fill` |
| More menu | `dot_grid_1x2` or `ellipsis_circle` (note: plain `ellipsis` **doesn't exist**) |
| Compass (HUD) | `compass` |
| Monument category | `building` |
| Persona | `person` |
| Text size / reading | `textformat_size_square` |

No emoji anywhere, including notifications.

**Custom glyphs:** the plaque marker and the Look cue are drawn components, not symbols. If we want them as symbols, `symbolRegister` in UI Design Kit ✅ supports custom symbols (stretch).

**App icon:** a single plaque shape in `accent` with an off-white keyhole-like "walking path" mark (a curved line ending in a dot), layered foreground/background per HarmonyOS layered icon rules (1024×1024 ✅). No wordmark, no HarmonyOS logo.

### 4.7 Stop markers ("plaques")

These are inspired by Kraków's numbered historic street plaques (the city register lists 923 of them). Stops are circular plaques with a number in tabular `caption`/`callout` bold.

| State | Size (visual / hit) | Fill | Ring | Number |
|---|---|---|---|---|
| Upcoming | 28 / 48 | `bg.surface` | 2 vp `accent` | `accent` |
| Next | 34 / 48 | `accent` | 3 vp `bg.surface` outer ring | `onAccent` |
| Arrived (current) | 34 / 48 | `accent` | plus an 8 vp halo, `accent` @ 20% | `onAccent` |
| Visited | 24 / 48 | `text.tertiary` @ 85% | none | ✓ glyph in `bg.surface` |
| Skipped | 24 / 48 | `bg.surface` | 1.5 vp dashed `text.tertiary` | `text.tertiary` |
| Non-tour POI (explore) | 8 dot / 44 | `text.secondary` | 1.5 vp `bg.surface` | – |

A11y: "Stop 5, Cloth Hall, next."

### 4.8 Map style

The map is muted so that the route and the plaques are the only saturated things on it. ⚠️ The renderer depends on ARCHITECTURE.md (likely an ArkUI `Canvas` pre-baked vector from OSM). These are the paint values:

| Layer | Light | Dark | Notes |
|---|---|---|---|
| Land / base | `#EEEEEA` | `#151819` | |
| Buildings | `#E2E0DA` (no stroke) | `#202426` | only at zoom ≥ 16 |
| Parks / Planty ring | `#DCE6D6` | `#1A2620` | the Planty ring park is a strong orientation cue in Kraków, so keep it visible |
| Water (Vistula) | `#D3E1E6` | `#14222A` | |
| Streets, pedestrian | `#FFFFFF`, 6–10 vp | `#2A2F32` | |
| Streets, other | `#FFFFFF`, 3–6 vp | `#24292C` | |
| Street labels | `text.secondary`, caption 12 fp, halo 2 vp of the base colour | dark tokens | label only major streets on the route |
| UNESCO boundary | `text.tertiary` 1 vp dashed (6/4) | same | explore mode |
| Route, upcoming leg (next) | `accent`, 6 vp, with a 2 vp `bg.surface` casing | dark accent | |
| Route, later legs | `accent` @ 45%, 5 vp | | |
| Route, walked | `text.tertiary` @ 60%, 5 vp | | |
| User dot | 14 vp `map.user` + 3 vp white ring + `elev.1` | | Demo walk: a **hollow** ring (3 vp `map.user` stroke, no fill) |
| Heading cone | 60° wedge, radius 40 vp, `map.user` alpha 0.30 → 0 radial | | shown only when the course is valid (speed ≥ 0.6 m/s) |
| Accuracy halo | circle, `map.user` @ 12%, radius = accuracy (m → px) | | hidden when under 10 m |

**Attribution** (required): "© OpenStreetMap contributors" in caption 12 fp, `text.secondary`, bottom-left inside the safe area on Full map. On Now Walking and the previews, a tiny ⓘ opens the attribution.

### 4.9 Motion

This follows the rn-motion restraint stance, translated to ArkUI: motion explains a change; it never decorates. Push and pop are the `Navigation` defaults. Sheets use the `bindSheet` defaults. Never hand-roll either.

| Motion | Duration | Curve (ArkUI) | Where |
|---|---|---|---|
| In-place state change (colour, opacity, selected) | 150 ms | `Curve.Sharp` ✅ / `curves.cubicBezierCurve(0.33,0,0.67,1)` | toggles, chip select, paused dimming |
| Element enter/exit (banner, Tell me more button) | 200 ms in / 160 ms out | `Curve.Friction` (in), `Curve.Sharp` (out) | `.transition(TransitionEffect.OPACITY.combine(TransitionEffect.translate({y: 8})))` |
| Next-stop card swap on arrival or advance (**the one orchestrated moment**) | 250 ms | `curves.springMotion(0.35, 0.9)` ✅ | the old title fades up (opacity 1→0, y 0→−8), the new one fades in from y +8. The plaque on the mini map swaps state at the same time. Plus the arrival haptic. |
| Look cue dot | 200 ms | `Curve.Friction` | only when Δ ≥ 10° |
| Map follow / heading rotation | continuous, low-pass filtered (α = 0.2 per fix) | – | the map must never spin. Clamp to ≤ 30°/s. |
| Route re-plan cross-fade | 150 ms | `Curve.Sharp` | Route ready |
| Distance number | **none** | – | updates too often to animate (rn-motion: frequent interactions get no motion) |
| Gesture-driven (map pan, sheet drag) | follows the finger | – | settle uses the system default |

**Rules:**
- Nothing exceeds 350 ms.
- Animate opacity and transforms only.
- Every animation can be interrupted. Nothing blocks input.

**Reduce motion:**
- ⚠️ No public "reduce motion" query was found in the API 24 SDK. So in **Settings › Accessibility** (or under Sound and haptics), offer a "Reduce motion" toggle that substitutes cross-fades (120 ms) for travel and makes the dial and map jump instead of glide. It defaults to off.
- Because motion is already minimal, the app is fully usable either way.
- If a system flag is found later, bind to it and remove the toggle.

### 4.10 Haptics

All haptics are optional (Settings › Vibrate on arrival). Check `vibrator.isSupportEffectSync(id)` ✅ before use and fall back to a 40 ms `time` vibration. The emulator has no haptics, so log each event for the demo.

| Event | Effect |
|---|---|
| Arrival | `EFFECT_NOTICE_SUCCESS` (`haptic.notice.success`) ✅ |
| Turn now (directions on) | `EFFECT_SOFT` ×2, 120 ms apart ✅ |
| Off route / GPS lost (once) | `EFFECT_NOTICE_WARNING` ✅ |
| Tour finished | `EFFECT_NOTICE_SUCCESS` |
| Button taps, toggles | **none**, except the system defaults (`Slider.enableHapticFeedback`) |

---

## 5. Audio UX (the real interface)

### 5.1 Voice of the Historian (persona style guide)

- **Who:** a well-read Kraków local in their 60s. Warm, precise, a little dry. They've told these stories a thousand times and still enjoy them.
- **Grammar:** second person, present tense ("You're standing where…"). Sentences of 8–20 words. One idea per sentence.
- **Structure per stop:**
  1. **Orient** (where to look).
  2. **Hook** (one vivid image).
  3. **Story** (2–4 beats).
  4. **One date at most per paragraph.** Round where you can ("about 700 years ago").
  5. **Close** with a look-again detail.
- **Never:** "As an AI", lists read aloud, URLs, parentheses, abbreviations (write "Saint", not "St."; numbers in words for ZH where natural).
- **Pauses:** use the Core Speech Kit pause markup `[p300]` between sentences that change the subject, and `[p600]` before a "look" instruction ✅ (`[pN]` = N ms of silence). Use `[n1]` for years so they're read as numbers ✅ (`[nN]` number-reading mode). ⚠️ Verify that `[n1]`/`[n2]` behave as expected for years like 1489.
- **Pronunciation:** Polish proper names in EN narration use the English exonym where one exists (St Mary's Basilica, Cloth Hall, Wawel). The first mention adds the Polish name only if it's speakable by the voice in use: Laura (en-US) or, on the emulator, the zh-CN Fallback voice, which mangles Polish names even more ("Sukiennice" will be mangled, so put it on screen, not in audio).

### 5.2 Earcons

These are four short, soft sounds bundled as `rawfile` WAVs at 48 kHz, −18 LUFS. They play through the same AudioRenderer so they duck and mix consistently. They're quieter than the voice by about 6 dB.

| Earcon | Sound | Length | Use |
|---|---|---|---|
| `start` | two rising tones (G4 → D5), marimba-like | 400 ms | tour starts |
| `approach` | a single soft tone (E5) | 180 ms | approach threshold |
| `arrival` | three-note rising arpeggio (C5 E5 G5) | 500 ms | arrival, always before the arrival line |
| `turn` | two quick soft ticks | 200 ms | a direction instruction is about to play |
| `finish` | a four-note resolution | 900 ms | tour complete |

Every earcon is followed by speech within 600 ms, so the earcon is never the only signal. In text-only mode it's followed by the notification and the haptic instead.

### 5.3 Script table: Royal Route examples (EN)

Trigger values use the defaults: radius R = 35 m, approach = R + 30 m. The stop list is **illustrative**, and the content team owns the final list:
1. Barbican
2. St Florian's Gate
3. St Mary's Basilica
4. Cloth Hall
5. Adam Mickiewicz Monument
6. Town Hall Tower
7. St Adalbert's Church
8. Sts Peter and Paul
9. St Andrew's Church
10. Kanonicza Street
11. Wawel Hill

All facts in the examples need to be checked against the cited sources before shipping.

| ID | Event | Trigger | Priority | Earcon / haptic | Verbosity | Example line (EN) |
|---|---|---|---|---|---|---|
| W1 | Welcome | Start walking | P2 | `start` | all | "Hello, I'm your guide for the Royal Route, the road Polish kings took to their coronation. Put your phone away; I'll tell you where to go and where to look. Our first stop, the Barbican, is about three minutes ahead." |
| W1-sim | Welcome, demo walk | Start walking + demo | P2 | `start` | all | "…This is a simulated walk, so I'll move you along the route myself." |
| D1 | Leg start (heading to the next stop) | after the transition | P2 | – | Standard, Deep | "Walk down Floriańska Street, straight ahead, towards the tall brick church at the end." |
| D2 | Turn (decision point on the route geometry, 20 m before) | distance to the turn node ≤ 20 m | P1 | `turn` + soft ×2 | Standard, Deep (Brief: only if the turn is over 60°) | "At the end of the square, bear right, keeping the Town Hall Tower on your left." |
| D3 | Reassurance (long leg over 250 m, halfway) | 50% of the leg | P3 | – | Deep | "You're on the right track. The Cloth Hall is about 150 metres ahead." |
| N1 | Along the way (non-tour POI within 25 m of the route, ≥ 60 s since the last speech, ≤ 1 per 150 m) | proximity | P4 | – | Deep (Standard: plaques and monuments only) | "On your right, a small plaque marks the house where the painter Jan Matejko was born." |
| A1 | Approaching | distance ≤ approach | P1 | `approach` | all | "In about fifty metres, on your left: Saint Mary's Basilica." |
| R1 | Arrived + Look cue | distance ≤ R, or ≤ R + 10 m with speed < 0.5 m/s | P1 | `arrival` + success | all | "You've arrived. [p600] Look left, and up at the taller of the two towers." |
| S1 | Story, full | after R1 if speed < 0.6 m/s within 4 s | P2 | – | Brief: ~45 s, Standard: ~2–3 min | "Every hour, a trumpeter plays a short call from that tower, the hejnał, to all four sides of the city. [p300] Listen to the end: the melody stops mid-note. The legend says a trumpeter was struck by an arrow as he warned the city of an attack, and the call has broken off ever since." |
| S1-t | Story, teaser (walking past) (proposal) | after R1 if speed ≥ 0.6 m/s | P2 | – | all | "Saint Mary's: home of the trumpet call that breaks off mid-note. [p300] Stop for a moment if you'd like the full story." |
| S1-more | Stand still → full (proposal) | after S1-t, speed < 0.5 m/s for ≥ 4 s within 20 s | P2 | – | all | (plays S1 from the top, no re-greeting) |
| M1 | Tell me more (Deep layer) | the button, or auto at Deep after S1 | P2 | – | Deep | "Step inside if it's open. Behind the altar is a carved wooden altarpiece by Veit Stoss, finished in 1489, one of the largest of its kind in Europe…" |
| H1 | Hejnał moment (proposal; time-aware, at stop 3, minute 58–59) | clock + at the stop | P1 | `approach` | all | "Stay here a moment. In under a minute the trumpeter will play from the taller tower, up to your left. Listen for the melody breaking off." |
| T1 | Transition | story end | P2 | – | all | "Next, the Cloth Hall: the long building in the middle of the square, about two minutes ahead, slightly to your right." |
| G1 | GPS lost (once per episode) | no fix > 20 s | P1 | warning | all | "I've lost GPS for a moment. Keep heading towards the Cloth Hall; I'll find you again." |
| O1 | Off route (proposal) | > 60 m from the leg for 30 s | P1 | warning | all | "We've drifted off the route. The Cloth Hall is now about two hundred metres behind you, to your right. I've adjusted the plan." |
| P1r | Resume after an interruption | resume | P2 | – | all | "Where were we… the Cloth Hall." (then restart the interrupted sentence) |
| F1 | Finish | last stop's story ends | P2 | `finish` + success | all | "That's the end of the Royal Route. You've walked the kings' road from the city gate to the castle, about two kilometres and seven centuries. [p600] Thank you for walking with me." |

**ZH narration:** use the same IDs with separate scripts, not machine-translated at runtime. Direction phrases: 左边 / 右边 / 前方 / 抬头看. Distances "大约五十米". Use the 聆小珊 voice (`person: 13`) ✅.

### 5.4 Directions phrasing rules

1. **Landmark before metric:** "towards the tall brick church", then "about 200 metres".
2. **Relative to walking direction**, never cardinal (no "north"). Left and right come from the course over ground. When the course is unknown (standing), use landmarks only: "Face the tall brick church; the Cloth Hall is behind you, slightly left."
3. **Round distances:** under 100 m, round to 10 ("about fifty metres"). Under 500 m, round to 50. Otherwise, use minutes ("about five minutes").
4. **Instruct at decision points only**, 20 m before the node. No "continue straight" chatter. Silence means "keep going".
5. **Bearing bins for "where to look"** (relative bearing b from the course to the target):
   - |b| ≤ 20° → "ahead"
   - 20°–60° → "ahead, slightly left/right"
   - 60°–120° → "on your left/right"
   - 120°–160° → "behind you, to the left/right"
   - over 160° → "behind you"
   - Add "and up" when the script has `look.up = true`.
6. **The screen uses the exact same words** (the caption of the Look cue, the widget, AVSession).

### 5.5 Queue and interruption rules

- **A single speech queue** with priorities: **P1** (safety and navigation: approach, arrival, turn, GPS, off-route) > **P2** (stories, transitions, welcome, finish) > **P3** (reassurance) > **P4** (along-the-way).
- **Never cut a sentence.** A P1 event during a P2 item waits for the **current sentence end**, then plays (earcon + line). The P2 item resumes from the **next** sentence, prefixed with "…" (a short `[p300]`). Implementation: synthesise per sentence (TTS `queueMode` 0, queue mode ✅) or keep sentence boundaries in the script data.
- **Arrival while a story is still playing** (stops closer together than one story): finish the current *paragraph*, play T1-short ("Let's leave that there."), then R1 for the new stop. Ideally, stories are written so the arrival radius rarely overlaps.
- **Dropping:** P3 and P4 items expire after 30 s in the queue. P1 turn instructions expire once the node is passed.
- **User pause** pauses everything, including P1. Events that happen while paused show as UI, a haptic, and the AVSession title, but aren't spoken retroactively except the latest arrival. On resume: "You're at the Cloth Hall now. [p300] …"
- **Skip** (headset or lock screen) ends the current item at the sentence end ("skip" is honoured within ≤ 1 sentence; if the sentence has over 3 s left, cut at a word boundary with a 150 ms fade — the only allowed cut).
- **Volume:** never change the system volume. The earcon/voice mix is relative only (HIG `playing-audio.md`).
- **Stream type:** stories via `STREAM_USAGE_AUDIOBOOK` ✅ with AVSession + AUDIO_PLAYBACK (required for audiobook background playback ✅). ⚠️ The architect decides whether short P1 prompts use `STREAM_USAGE_NAVIGATION` (ducks other apps' music) or the same stream.

### 5.6 Verbosity levels

| Level | Per-stop story | Directions | Along-the-way | Deep layer | Typical tour length |
|---|---|---|---|---|---|
| **Brief** | ~45 s | sharp turns only | off | on request | ~55 min |
| **Standard** (default) | 2–3 min | all decision points | plaques and monuments, ≤ 1 per 150 m | on request ("Tell me more" / stand still) | ~1 h 20 min |
| **Deep** | full + Deep layer auto | all + reassurance | all categories | auto | ~2 h |

Content data needs `story.brief`, `story.standard`, `story.deep`, `look`, `teaser` per stop, per language, per persona (§6).

---

## 6. Persona extensibility

The UI treats the guide as a first-class, swappable object. With one persona, the UI shows it but doesn't make it a choice.

### 6.1 Data shape the UI needs (per persona)

`id`, `displayName` (localised), `tagline` (localised, e.g. "Dates, people and the stories behind the stones"), `audience` (adults/families), `voice` per language (`person`, `speed`, `pitch` ✅ TTS params), `earconSet` (optional override), `monogram` (1–2 letters for the avatar), `sampleLine` per language, and `scripts[stopId][lang] → {teaser, look, brief, standard, deep, sources}`.

### 6.2 Where personas appear

| Surface | Now (1 persona) | Later (≥ 2) |
|---|---|---|
| Tour detail "Guide" row | Shows "The Historian" + "English · Fallback voice" (or "Laura voice" if installed), **no chevron**, not tappable. A11y: "Guide: The Historian." | Chevron → a Guide picker sheet: a list of persona cards (monogram avatar 40 vp on `accent.subtle`, name, tagline, **Play sample**). Selection is a radio. |
| Settings › Guide | A page with one persona card and a sample button. Footnote: "More guides are coming." No disabled placeholders. | The same list as the picker. |
| Now Walking | Persona name in the AVSession artist line only. | Same. Switching persona mid-tour isn't allowed (it changes stories); it's only offered before Start. |
| Tour card on Home | Chip "The Historian" | Chips per available persona |
| Summary | "Guided by The Historian" | same |

**Visual rule:** personas don't change the accent colour or the layout. Identity is carried by the **voice** (pitch and speed) and the **monogram avatar** only. That keeps one design system.

**Second persona** (planned): "Legends" (families). Tagline: "Dragons, trumpeters and clever shoemakers." Voice: 凌飞哲 / Laura at speed 1.05, pitch 1.1 ⚠️.

### 6.3 Future IA when free-roam ships

`Tabs` (or `HdsTabs` ✅) with 3 tabs: **Tours** (`route`), **Explore** (`map`), **Settings** (`gearshape`). A walking session shows as a persistent **mini player bar** above the tab bar (`HdsTabs` has a MiniBar concept ✅ (`HdsTabsMiniBar` type exists); ⚠️ check that it fits). This is not in the hackathon build.

---

## 7. MVP vs stretch (UI work, prioritised)

Ordered by how much it matters to the demo *and* the user. P0 must exist by the 20:00 checkpoint in rough form.

| Pri | Item | Notes |
|---|---|---|
| **P0** | Now Walking: header, next-stop block (name, distance, plain direction text), now-playing card, Play/Pause, Replay, Skip | Rough styling is fine at the checkpoint. |
| **P0** | Demo walk toggle + **SIMULATED** pill + hollow user dot | Required for honesty and the emulator demo. |
| **P0** | Tour detail with stop list + **Start tour** → Before you go → Start walking | |
| **P0** | AVSession lock-screen card with title/artist mapping + play/pause/next/previous | It's the platform-capability showcase. |
| **P0** | Mini map on Now Walking (Canvas, route + plaques + user dot) | |
| **P1** | Route ready screen with the "Optimised: N m shorter" line | Algorithm visibility for the jury. |
| **P1** | Look cue dial (signature) + matching caption | |
| **P1** | Place detail: transcript, sources, AI disclosure | Trust criterion. |
| **P1** | Onboarding 3 steps incl. voice download + permissions | |
| **P1** | Settings: story language, detail level, trigger distance, demo walk, permissions | |
| **P1** | Tour summary | |
| **P1** | Polish text-only Reading state + arrival notification | A binding decision, so it must work. |
| **P1** | Dark mode via resource qualifiers | Cheap if tokens are used from the start. |
| **P1** | "How it works" HUD | Demo value is high. |
| **P2** | Full map (tour mode) with place card sheet | |
| **P2** | Mid-tour language switch EN ⇄ 中文 | Wow moment #3. |
| **P2** | "Time available" segment (orienteering) | Wow moment #10. |
| **P2** | Widget 2×4 active state | |
| **P2** | Hejnał moment state + simulated clock | |
| **P3** | Explore mode (all places, filters, clusters) | Binding data scope, but UI depth is stretch. A basic dot layer is P2. |
| **P3** | Widget 2×2, idle states | |
| **P3** | HdsNavigation blur title bars | |
| **P3** | Stand-still-for-more (if the trigger engine supports it) | |
| **P3** | Persona picker (only once a 2nd persona exists) | |
| **P4** | md-breakpoint two-pane layout, share card, report a problem, custom symbols | |

---

## 8. Open questions and assumptions to verify (owner: devs, on the emulator)

1. ⚠️ Locked-screen location updates with the LOCATION continuous task and **without** `LOCATION_IN_BACKGROUND`. This decides whether onboarding needs a Settings step.
2. ✅ ANSWERED (RISKS a1–a7): zh-CN `createEngine` works and is `INSTALLED`; en-US Laura is `GA`, `createEngine` fails (`1002300005`) and `downloadVoice` fails (`1002300008`) on the emulator. Hence the binding "Fallback voice" decision.
3. ⚠️ AVSession card rendering on the emulator lock screen. Is `singleLyricText` displayed?
4. ⚠️ Are `SymbolGlyph` and custom drawing allowed in ArkTS widgets?
5. ⚠️ Is there a system "reduce motion" or "high contrast" query for ordinary apps? (None was found in the SDK search.)
6. ⚠️ How do the HarmonyOS screen reader and our TTS overlap?
7. ⚠️ Real pack numbers (place count, MB), photo licensing, and the final stop list.
8. ⚠️ PL and ZH string review by native speakers.

---

## 9. Claude Design brief (paste-ready)

> **Design high-fidelity phone mockups for "CityTour", a HarmonyOS (Huawei) app that is an audio walking-tour guide for Kraków, Poland.** The visitor puts headphones in, locks the phone and walks. The app leads them along an optimised route and talks about each monument as they reach it, including where to look. The screen is a calm, glanceable mirror of the audio. The style is native HarmonyOS: clean and professional, Apple-HIG-level restraint, HarmonyOS Sans, generous whitespace, flat cards, system-style bars and bottom sheets. **Don't use** gradient blobs, emoji, illustrations of people, glassmorphism on content, confetti, or a cream-and-terracotta look. Brand appears only through one accent colour, numbered circular "plaque" stop markers, and a small "Look cue" dial.
>
> **Frame:** 390×844 portrait phone with a status bar and a bottom gesture bar. Render every screen in **light mode**, and also render **Now Walking, Place detail and the lock screen in dark mode**. English UI. Use realistic content (Kraków's Royal Route: Barbican → St Florian's Gate → St Mary's Basilica → Cloth Hall → Adam Mickiewicz Monument → Town Hall Tower → St Adalbert's Church → Sts Peter and Paul → St Andrew's Church → Kanonicza Street → Wawel Hill).
>
> **Tokens.**
> - **Colours (light / dark):**
>   - canvas #F4F5F3 / #0F1112
>   - surface #FFFFFF / #1A1D1F
>   - sunken #EEEFEC / #24292C
>   - text primary #16181A / #ECEEEF
>   - text secondary #5A6066 / #A7ADB2
>   - text tertiary #6B7176 / #858C91
>   - divider #E1E3DF / #2E3336
>   - **accent "Wawel Patina" #1D6B5B / #6CC3AE**, on-accent #FFFFFF / #062A23, accent-subtle #E3F0EC / #17332D
>   - user-location blue #2F6FDE / #5C93F0 (map only)
>   - SIMULATED pill: text #7A4F00 on #FFF1D6 / #F2C46B on #3A2C0D
>   - destructive #B3261E / #F2B8B5
> - **Type** (HarmonyOS Sans; sizes in pt ≈ fp): display 34/40 bold (tabular figures, distances only) · title1 28/34 bold · title2 22/28 bold · title3 18/24 medium · body 16/24 · transcript 18/28 · callout 14/20 · footnote 13/18 · caption 12/16 medium · overline 12/16 medium uppercase tracking +0.6.
> - **Spacing** 4-pt grid, 16 side margins. **Radii:** 8 chips, 12 images, 20 cards, 28 panel top, full for buttons and markers.
> - **Shadows:** only on things floating over the map (very soft).
> - **Icons:** HarmonyOS system symbols in outline style (SF-Symbols-like): play_fill, pause_fill, arrow_counterclockwise, forward_end_fill, headphones, map, figure_walk, gearshape, chevron_down, checkmark_circle_fill, info_circle, location_up_fill, lock_fill, translate.
> - **Map style:** muted base #EEEEEA, white streets, buildings #E2E0DA, Planty park ring #DCE6D6, Vistula #D3E1E6. The route is a 6-pt accent line with a white casing. Later legs are accent at 45%; walked legs are grey. Stop markers are circular plaques with numbers: upcoming = white fill with an accent ring and an accent number; next = solid accent with a white number, slightly larger; visited = grey with a ✓. The user is a blue dot with a white ring and a soft 60° heading cone. Dark map: base #151819, streets #2A2F32.
>
> **Screens to render:**
> 1. **Onboarding 1/3.** Top-right "Skip". A static map snippet with the accent route and plaques 1, 5, 11, and a small headphones icon. Title "Your guide fits in your pocket". Body "Put your headphones in, lock your phone and walk. The Historian leads you through Kraków and tells you about each place as you reach it." 3 progress dots. A full-width capsule button "Continue".
> 2. **Onboarding 2/3, "How should the guide speak?"** Three radio rows in a card: English, "Spoken · Fallback voice" with a small "Download English voice" chip; 中文, "Spoken · 聆小珊"; Polski, "Text only". The footnote reads: "Polish stories are shown as text. On-device speech currently speaks English and Chinese." A "Play a sample" secondary button. "Continue".
> 3. **Onboarding 3/3, "Two permissions, and why."** Location row ("Finds the next stop and knows when you've arrived. Used only while a tour is running.") with "Allowed ✓". Notifications row ("Tells you when you arrive if your screen is off.") with a small "Allow" button. Footnote "Nothing leaves your phone." Buttons "Done" and "Set up later".
> 4. **Home.** Large title "CityTour", subtitle "Kraków · offline ready ✓", gear icon. A "NOW WALKING" continue card: "The Royal Route · Stop 4 of 11 · Cloth Hall", an accent progress bar, "Open" and "End tour". Section "GUIDED TOURS": a tour card with a 16:9 route map thumbnail, "The Royal Route", "From the Barbican to Wawel Hill", "11 stops · 2.0 km · ~1 h 20 min", and chips "The Historian", "EN 中文 PL". Section "EXPLORE": a row "All places in Kraków, 3,412 places, offline".
> 5. **Tour detail.** A 260-pt map preview with the full route and 11 plaques under a transparent back button. Title "The Royal Route", description "The kings' coronation path, from the city gate to the castle." A stat row: "2.5 km walk", "~1 h 20 min with stories", "11 stops". A Guide row "The Historian · English · Fallback voice". "STOPS": a vertical list of 11 plaques joined by a thin line, each with a name and "3 min" story length. "ABOUT THESE STORIES: Drafted with AI, reviewed by a person. 23 sources cited." A sticky bottom button "Start tour".
> 6. **Route ready.** Title "Your route". A map with the user dot near the Cloth Hall and renumbered plaques. "Starting near you": "Cloth Hall, 120 m away". "{d} km · {t} min walking · ~1 h 25 min with stories" (computed). An accent check line: "Optimised order: {saved} m shorter than the listed order" (computed at runtime; "640 m" in the mockups is a placeholder). Segmented control "START FROM: My location | First stop". Segmented control "TIME AVAILABLE: All stops | 45 min | 90 min". Bottom button "Begin".
> 7. **Before you go (bottom sheet over Route ready).** Three numbered rows: "Headphones in", "Check the volume" with a "Play a test line" button, "Lock your phone. I'll keep talking and tell you where to look." Footnote about the background location notification. Button "Start walking".
> 8. **Now Walking (hero screen).**
>    - The top 40% is a heading-up map under the status bar. Over it, a floating capsule header: "⌄ Royal Route 4/11 ⋯".
>    - Below, a white panel with 28-pt top corners: overline "NEXT · STOP 4", title "Cloth Hall", a huge "180 m" with "about 2 min" under it, and to the right a 72-pt **Look cue**. The Look cue is a thin top-half arc with a small accent dot at about 20° right of top, captioned "ahead, slightly right".
>    - A sunken "now playing" card: a waveform icon, "St Mary's Basilica", the current sentence in 18-pt text ("The taller tower, on your left, is where the trumpeter plays…"), a thin progress bar and "Story 2 of 3".
>    - A control row: replay (56), a big accent play/pause (72), skip (56). Text buttons "Transcript" and "Stops (11)".
>    - Also render the variants: (a) **Arrived** (overline "YOU'RE HERE · STOP 4", title "St Mary's Basilica", "Look left and up" in place of the distance, the dial dot on the left with a small up arrow, a "Tell me more" button); (b) **Demo walk** with an amber "SIMULATED" pill under the header and a hollow blue user ring; (c) **Dark mode**; (d) **Reading mode (Polish, text-only)** with the map shrunk to 200 pt and the panel showing "JESTEŚ TUTAJ · PRZYSTANEK 4", "Kościół Mariacki" and the full transcript in 20-pt text.
> 9. **Full map.** A full-bleed map, floating round back/layers/recenter buttons, "© OpenStreetMap contributors". A bottom place-card sheet at medium height: "Cloth Hall", "Market hall · 14th c.", "180 m, ahead right", a 2-line teaser, chip "Tour story", buttons "Listen" and "Details". Also render an **Explore** variant: grey dots for all places, small count clusters, a dashed "UNESCO Old Town" boundary, and filter chips "Tour stops · Monuments 395 · Plaques 923 · Heritage · Museums".
> 10. **Place detail.**
>     - A 4:3 photo with page dots and a licence caption. Overline "STOP 3 · CHURCH · 14TH C.", title "St Mary's Basilica", "Kościół Mariacki", "180 m · ahead, slightly left".
>     - Buttons "▶ Listen · 4 min" (accent) and "Tell me more".
>     - A "LOOK" box on accent-subtle: "The taller tower, on your left as you face the front. Look up to the top window."
>     - Transcript paragraphs with the current sentence marked by a 3-pt accent left rule. FACTS rows (Built · Height · Altarpiece).
>     - SOURCES as a numbered list with licences. An info footnote: "Drafted with AI from the sources above, reviewed by a person on 3 Oct 2026."
>     - Light and dark.
> 11. **Tour summary.** "Tour complete" with "Done". A map with the grey walked line and all plaques ✓. "The Royal Route · Saturday, 3 October". A stat trio "11/11 stops · 2.5 km walked · 1 h 24 min". The "YOU HEARD" list. "Sources and credits".
> 12. **Settings.** Grouped card list:
>     - Narration: Story language (English), App language (System), Voice (Fallback voice · zh-CN reads English), Guide (The Historian), Detail level segmented (Brief | Standard | Deep) with a footnote.
>     - Walking: Spoken directions toggle, Mention places along the way toggle, "Start the story when I'm within" segmented (20 m | 35 m | 50 m).
>     - Sound and haptics: Arrival chime, Vibrate on arrival.
>     - Offline data: "Kraków pack · 3,412 places · 48 MB · Included".
>     - Demo: "Demo walk (simulated location)" toggle ON, revealing "Replay speed" 1× 2× 4× 8× and an amber footnote "Everything simulated is labelled SIMULATED".
>     - Permissions: Location "Precise · while using", Notifications "On".
>     - About.
> 13. **Lock screen (light and dark).** A HarmonyOS lock screen with the system media card for CityTour: artwork = an accent plaque with "4", title "Walking to Cloth Hall", subtitle "Next: Cloth Hall · 180 m", controls ⏮ (replay), ⏯, ⏭ (skip), and a one-line lyric "Walk down Floriańska Street, towards the brick church." Below it, a small system notification "CityTour is using your location".
> 14. **Home-screen widgets** on a neutral wallpaper.
>     - 2×2 active: "NEXT · 4/11", "Cloth Hall", "180 m", "ahead, right", a play/pause icon.
>     - 2×4 active: "NEXT · STOP 4 OF 11", "Cloth Hall · 180 m · ~2 min", "ahead, slightly right", a row of 11 small plaques with 3 filled and the 4th ringed, and a now-playing line "St Mary's Basilica" with ⟲ ⏯ ⏭.
>     - 2×2 idle: "The Royal Route · 11 stops", "Start".
>
> **Quality bar:** every text ≥ 12 pt; every touch target ≥ 48 pt; contrast ≥ 4.5:1 for text; the accent used only for primary actions, the route, the next-stop marker and progress; one SIMULATED style (amber) used consistently; sentence case everywhere except overlines.

---

*End of spec. Changes after review go here with a date. Keep this file the single source of truth for the UI; ARCHITECTURE.md owns the data and engine contracts.*

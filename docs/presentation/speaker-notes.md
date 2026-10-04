# CityTour keynote: speaker notes

HackYeah 2026 · Huawei challenge. The slides are in [`CityTour-keynote.pdf`](CityTour-keynote.pdf).

## 1. CityTour

Good morning. This is CityTour. Kraków's stories, told where they happened. Everything you'll see today is the real app, running on the HarmonyOS emulator.

## 2. Every city is full of stories.

Every city is full of stories. But most visitors walk right past them, because nobody is there to tell them.

## 3. Today, you have to choose.

Today a visitor has three options, and each one costs something. A guided tour has great stories, but it costs money, runs on a timetable and moves at the group's pace. A guidebook or an app is cheap, but your eyes go down to a screen. Or you just walk, and the history stays invisible.

## 4. Your guide fits in your pocket.

So we built CityTour. Your guide fits in your pocket: you put your headphones in and keep your eyes on the city. The phone becomes your guide. This is the real lock screen: the tour keeps running in the background, and you control it like music.

## 5. Three walks through Kraków.

CityTour now has three walks through Kraków: the classic Royal Route from the Barbican to Wawel, Scholars and Saints through the university quarter, and Kazimierz: Two Faiths, One Town. Each one comes with stories in English, Polish and Chinese, in a studio voice. You can start a walk straight away, or download it to keep it fully offline.

## 6. Four steps. One pocket.

Four steps. Tap Start on a walk: CityTour plans the best order from where you're standing, with no extra screen. Then keep your eyes on the city: the guide talks you to each stop, turn by turn. When you arrive, it tells you where to look, then the story. And when you finish, you get a summary of every story you heard. All four screens are the real app on the emulator.

## 7. Spatial Experiences.

We lead with Spatial Experiences. In CityTour, your position and the direction you walk decide what the guide says, when it says it, and where you should look. The interaction is your body moving through the city, not a screen. Our second area is Human-Centric Technology: it's a cultural experience, in three languages, designed to keep your eyes on the city instead of on your phone.

## 8. Your guide points it out.

This is where Spatial Experiences comes in. When you reach the Barbican, the guide says: look up, at the seven turrets that crown the round brick walls. That's real text from the app. Your direction comes from the way you're walking, not a compass, so it works with the phone in your pocket. And direction words like "on your left" are worked out live, never written into the script.

## 9. It listens to how you walk.

CityTour also listens to how you walk. If you stop at a monument, you hear the full story. If you just walk past, you get a short teaser and keep going. Your walking speed decides, so you never have to touch the phone. Our replay tests check this on a full recorded walk: full stories at the stops where the walker pauses, the teaser only at the one they pass.

## 10. “In 150 metres, turn right.”

Between stops, the guide gives you spoken directions, like "In 150 metres, turn right." If you wander off the route, it notices, tells you, and re-plans the remaining stops from where you are now. Our replay tests include a deliberate detour to check exactly that.

## 11. budget

Short on time? Tell CityTour you have 30 minutes, and it picks the best seven of the eleven stops that fit, in the best order. It isn't a guess: an exact solver over real walking times, running on the phone in a few milliseconds. The same solver orders a full walk from wherever you're standing.

## 12. A real voice. In three languages.

Stories are spoken in a real studio voice. Across the three walks there are 3,524 clips in English, Polish and Chinese, generated with ElevenLabs at build time, so the app never needs a key. You can switch language in the middle of a story: the current sentence finishes, and the next one continues in the new language. Any line without a clip is rendered once by our server and cached, and with no connection the phone's own voice reads it.

## 13. Lock screen. Home screen. Wrist.

Your next stop is always a glance away. On the lock screen, as a playback card you control like music. On the home screen, as a Next stop widget that updates live during the tour. And on your wrist: we built a Huawei watch app too.

## 14. The whole tour, on your wrist.

We also built a Huawei watch app. It runs the same tour engine as the phone, from one shared core. You start the Royal Route on the watch, follow an arrow to the next stop, and when you arrive the watch tells you where to look with a pattern of taps on your wrist: two pulses for left, three for right, two long ones if you leave the route. On the emulator you can't feel a vibration, so each cue also flashes on the screen. These are real screenshots from the Watch 5 emulator, on the simulated demo walk.

## 15. Download once.

Walks come from our course server. You can start one instantly, streaming only what it needs, or download it once and walk with no signal at all: the maps, the stories and the studio voice stay on the phone. Every catalog and file is signed and checked before it's used. There are no accounts, and the server never learns where you are.

## 16. Built deep into HarmonyOS.

CityTour couldn't run unchanged on another OS. It uses twelve HarmonyOS kits. Location Kit on the phone and the watch. Background Tasks to keep the tour alive with the screen locked. AVSession for lock-screen and headset controls. Media Kit for the studio clips and Core Speech Kit for on-device voice. Form Kit for the live home-screen widget, Notification Kit for the next stop, and the Sensor Service Kit for haptics. Network Kit, Crypto Architecture and Core File Kit download walks safely: every file is signed, checked and installed in one atomic step. And Localization Kit gives three interface languages. Minimum API 20, built against API 24.

## 17. Two apps. One engine.

Here's how it fits together. At build time, a data pipeline turns OpenStreetMap, Wikidata, Wikipedia and OSRM walking routes, plus the ElevenLabs studio voice, into city and walk packs. Our course server, written in Express and TypeScript, serves a signed catalog, the city packs, the walks and the voice clips, and renders any missing line once. On the devices there are two apps, phone and watch, built on one shared core: the tour engine, the route planner, geo maths and content handling. The core has no platform imports, so it's fully unit-tested, and the platform kits sit in thin adapters around it.

## 18. Open data. Open core.

This challenge is about what an open platform makes possible, so we built CityTour to be open in three ways. The data is open: maps, places and stories come from OpenStreetMap, Wikidata and Wikipedia, and the app credits them. The core is portable: the tour engine has no platform imports, and our tests fail if anyone adds one, so it's built to move to OpenHarmony and Oniro. To be precise, some kits we use, like Core Speech Kit, are HarmonyOS-only; they sit in adapters outside the core. And walks are data: a new walk or a new city is a pack on our server, not new code.

## 19. Built to actually work.

We didn't just build screens. 438 unit tests pass. A replay test drives a recorded walk through the real engine six times, at different speeds, and checks every stop is reached once, in order, without a sentence being cut. Seventeen failure cases, from a denied permission to a lost GPS signal, each end in a clear on-screen state instead of a crash. The phone and the watch are two apps over one shared tour engine. Our course server is live and signs every walk it delivers. And all of it is public: more than 400 commits since Saturday.

## 20. From an empty template, in 14 hours.

Everything you've seen was built here at HackYeah. Our first commit, at 13:07 on Saturday, was the empty DevEco template. By 14:10 we had the architecture and our platform tests on the emulator. The Kraków data pipeline landed around 17:00, the studio voice and spoken Polish just after 19:00, and the course server before 22:00. Three walks were live before midnight, the watch app at 2 in the morning, and we tagged version 1.0, with the installable .hap, just after 3. The only things we didn't write are the DevEco scaffold and the challenge's starter files. Every time on this slide comes from our public git history.

## 21. Nothing hidden.

This slide is about how we built CityTour, and what is real versus simulated. What we simulate: the emulator's GPS is one fixed point, so our Demo walk replays a recorded route through the real tour engine; on the watch, the emulator has no vibration motor, so each haptic cue also flashes on screen. Every simulated screen, on the phone and the watch, is labelled SIMULATED. Why the phone and watch aren't linked: phone–watch sync on Huawei goes through Wear Engine, and both must be real devices paired through the Huawei Health app. The jury watches the app on emulators, so a synced version would have nothing to show and couldn't be checked, and our AGENTS.md rules require every claim to run as described. It also needs Huawei's approval through AppGallery Connect, and a hackathon weekend isn't long enough. And a standalone watch still works without the phone: it has its own GPS and its own copy of the stops, so you can leave the phone in your pocket or at the hotel; haptic cues, the arrow and arrival alerts all run on the watch alone, while a companion watch would stop working whenever the connection drops. How we worked: we built with Claude Code agents, and every task is logged in AI_WORKFLOW.md and in more than 400 public commits. Our rule, from the challenge's AGENTS.md: claim only what runs as described, and clearly label anything mocked or simulated. The tour stories were drafted by AI from cited Wikipedia text and checked against those sources, but no historian or native speaker has reviewed them yet.

## 22. On a real device, it walks with you.

Some things can't run on an emulator, so here's how they work on a real device. Location: on the emulator, our Demo walk replays a recorded route, always labelled SIMULATED. On a real phone or watch, live GPS from Location Kit feeds exactly the same tour engine; you switch the source in Settings. Watch cues: the emulator has no vibration motor, so each cue flashes on screen; on a real watch you feel them, two taps for left and three for right. And the voice: the emulator has no English system voice, so lines without a studio clip are read by the Chinese voice; a device with the English voice installed uses it automatically. To be clear, we haven't run it on real hardware yet, and we'd love to try it on a mentor's device.

## 23. Try it yourself.

Anyone can reproduce this. Clone the public repository, run one command to build, install and launch the phone app on the Pura 90 emulator, and tap Demo walk on any walk. Or skip the build and install the .hap from our v1.0-hackyeah release on GitHub. The deliverables are all there: setup, build and launch instructions in the README, the working .hap, the architecture docs, AI_WORKFLOW.md, which documents how we used AI, and our demo recording.

## 24. One city today. Any city tomorrow.

What's next. More cities: the server already delivers city packs and walks, so adding a city is new data, not new code. A phone and watch companion through Wear Engine, where the phone tells the story and the wrist taps, once Huawei approves it and we can test on real devices. And an open tour format that museums, schools and cities can publish themselves, without asking anyone for permission.

## 25. CityTour

CityTour. Eyes on the city, not the screen. Everything is public on GitHub: the code, the build instructions and our AI workflow. Thank you, and we're happy to show you the live demo.


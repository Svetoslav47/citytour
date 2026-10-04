# CityTour: 5-minute pitch (demo included)

Slides: [`CityTour-pitch-5min.pdf`](CityTour-pitch-5min.pdf), 8 slides taken from the full keynote. One speaker. About 430 spoken words plus the demo, so it fits in about 4:30 and leaves room for a slip.

Every slide earns points on one of the Huawei criteria: originality 20, usefulness 20, technical execution 20, platform 20, demo quality 10, reproducibility and transparency 10.

| # | Time | Slide | Criterion |
|---|---|---|---|
| 1 | 0:00 | CityTour (title) | |
| 2 | 0:10 | Today, you have to choose. | usefulness |
| 3 | 0:30 | Your guide fits in your pocket. | originality, usefulness |
| — | 0:50 | **Demo** (video, about 65 s, or live) | demo quality |
| 4 | 2:00 | Your guide points it out. | Spatial Experiences, originality |
| 5 | 2:30 | Built deep into HarmonyOS. | platform |
| 6 | 3:05 | Built to actually work. | technical execution |
| 7 | 3:40 | Try it yourself. | reproducibility and transparency |
| 8 | 4:05 | CityTour (close) | |

## 1. CityTour (0:00, 10 s)

Hi, we're [team]. This is CityTour: a city's stories, told where they happened.

## 2. Today, you have to choose. (0:10, 20 s)

A visitor today has three options. A guided tour is great, but it costs money and runs on a timetable. An app or guidebook is cheap, but your eyes end up on a screen. Or you just walk, and the history stays invisible.

## 3. Your guide fits in your pocket. (0:30, 20 s)

So we built CityTour for HarmonyOS. Put your headphones in and keep your eyes on the city. CityTour plans your route, talks you to each stop, and tells each place's story the moment you arrive, with the screen off. Let us show you.

## Demo (0:50, about 70 s)

Play the demo video (`citytour-demo.mp4` on the GitHub release), or run it live on the emulator: Demo walk on any card.

If you talk over it, three lines only:
- "This is a real Huawei phone at the venue: live GPS, and it knows we're in Kraków."
- "On the emulator, the Demo walk replays a recorded route through the same engine. It's labelled SIMULATED."
- "Mid-story we switch from English to Polish to Chinese, at the next sentence."

## 4. Your guide points it out. (2:00, 30 s)

This is our challenge area, Spatial Experiences. Your position and the direction you walk decide what the guide says and where you should look: "look up, at the seven turrets". The direction comes from how you walk, not a compass, so the phone stays in your pocket. Stop at a monument and you hear the full story; walk past and you get the short version. Wander off and it re-plans.

## 5. Built deep into HarmonyOS. (2:30, 35 s)

This couldn't run unchanged on another OS. Location Kit tracks you, and Background Tasks keep the tour alive with the screen locked. AVSession gives lock-screen and headset controls. Form Kit adds a live Next-stop widget, and Notification Kit shows the next stop with the screen off. Crypto and Network Kit check every signed walk the app downloads. And the same engine runs as a Huawei watch app that taps your wrist: two pulses for left, three for right.

## 6. Built to actually work. (3:05, 35 s)

Every claim is backed by code and tests. We have more than 440 unit tests, and a replay test drives a recorded walk through the real engine and checks that every stop comes in order with no sentence cut off. Seventeen failure cases, from denied permissions to lost GPS, each end in a clear state instead of a crash. A live course server signs every walk, and the app works fully offline once a walk is downloaded.

## 7. Try it yourself. (3:40, 25 s)

It's all public and reproducible: one command builds and launches it on the emulator, or install the .hap from our GitHub release. We built it here this weekend with Claude Code agents. Every task is logged in AI_WORKFLOW.md and in more than 400 public commits. Anything simulated is labelled SIMULATED.

## 8. CityTour (4:05, 10 s)

CityTour. Eyes on the city, not the screen. Thank you. We're happy to show it live.

## Before you present

- Slide 8 still says "Built by [team names]". Fill in the names in the deck source and re-export, or say the names out loud.
- Slide 7 points to the `v1.0-hackyeah` release. The latest is `v1.0.2-hackyeah`, and the "latest release" link works either way.
- Have the video ready to play offline, not streamed from the venue network.

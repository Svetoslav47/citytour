# Attribution

## Narration voice (AI-generated audio)

Narration voice generated with ElevenLabs (eleven_multilingual_v2, voice 'George'); scripts AI-drafted, see review status.

- Provider: ElevenLabs, model `eleven_multilingual_v2`, premade voice "George" (voice id `JBFqnCBsd6RMkjVDRZzb`), output `mp3_44100_64`.
- What: one clip per sentence of the Historian teaser and full stop stories, in English, Polish and Chinese (489 clips, 22.4 MB) in `entry/src/main/resources/rawfile/audio/`, listed in `audio/manifest.json`. Deep stories, directions and other live lines have no clip and use the on-device HarmonyOS voice (Core Speech Kit) or text.
- How: rendered once at build time by `scripts/voice/render-elevenlabs.mjs`. The app makes no network call to ElevenLabs and contains no API key.
- Scripts: the story texts are AI-drafted (Claude, from the cited sources; Polish and Chinese are machine translations). Each story shows its own review status in the app (Place detail, Tour detail).
- The app labels this audio "Studio voice" and discloses it in About & licences.

## Map and place data

See the in-app **About & licences** page: © OpenStreetMap contributors (ODbL), Wikipedia (CC BY-SA), Wikidata (CC0), Kraków open data (ArcGIS), OSRM routes over OSM data.

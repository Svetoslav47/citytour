# Attribution

## Narration voice (AI-generated audio)

Narration voice generated with ElevenLabs (eleven_multilingual_v2, voice 'George'); scripts AI-drafted, see review status.

- Provider: ElevenLabs, model `eleven_multilingual_v2`, premade voice "George" (voice id `JBFqnCBsd6RMkjVDRZzb`), output `mp3_44100_64`.
- What: one clip per sentence of the Historian teaser and full stop stories, in English, Polish and Chinese, plus the fixed system, arrival and turn-by-turn lines (1155 clips in total) in `data/course/krakow/audio/`, listed in `audio/manifest.json`. They are part of the Kraków course that the app downloads from the course server (the HAP contains no clips). Deep stories and lines with a live number have no clip and use the on-device HarmonyOS voice (Core Speech Kit) or text.
- How: rendered once at build time by `scripts/voice/render-elevenlabs.mjs`. The app makes no network call to ElevenLabs and contains no API key.
- Scripts: the story texts are AI-drafted (Claude, from the cited sources; Polish and Chinese are machine translations). Each story shows its own review status in the app (Place detail, Tour detail).
- The app labels this audio "Studio voice" and discloses it in About & licences.

## Map and place data

Shown in the app under **Settings › About › Sources and licences**, and per place under **Place detail › Sources**. Full provenance (endpoints, queries, retrieval times, counts) is in [`raw/SOURCES.md`](raw/SOURCES.md); the course pack (downloaded by the app) carries one record per source in `data/course/krakow/packs/krakow/sources.json`. All snapshots were retrieved on 2026-10-03.

- **OpenStreetMap**: © OpenStreetMap contributors, [ODbL 1.0](https://www.openstreetmap.org/copyright). The offline Old Town map (`map-detail.json`); the credit is drawn on every map in the app.
- **OSRM** (foot profile, FOSSGIS server `routing.openstreetmap.de`): the 110 walking legs between the tour stops (distances, durations, turn-by-turn steps). Derived from OSM data, ODbL 1.0.
- **Wikidata**: [CC0 1.0](https://creativecommons.org/publicdomain/zero/1.0/). The 4,290 places: coordinates, names in en/pl/zh, type, heritage status, dating. Credited even though CC0 requires no attribution.
- **Wikipedia** (en, pl, zh): [CC BY-SA 4.0](https://creativecommons.org/licenses/by-sa/4.0/). Place summaries are shown verbatim with the article title and link; the 11 tour-stop articles are the cited source of the Historian scripts. Each text names its article in Place detail › Sources.
- **City of Kraków (Gmina Miejska Kraków), Zintegrowana Platforma GIS** (ArcGIS feature services: municipal heritage register `EOZ_Zabytki`, `otwarte_dane_eoz`, UNESCO zone `UNESCO_4f365`): **licence unverified**. No terms are published for these items (checked 2026-10-03), so the data is used only for coordinates, register facts and the UNESCO outline, cited with the service URL and retrieval date (docs/RISKS.md T14).

## AI-drafted text

- Historian stop scripts (teaser, full, deep) for the 11 Royal Route stops: drafted by Claude (Anthropic) from the cited Wikipedia text with the prompt in `scripts/pack/prompts/`, validated by `scripts/pack/80-validate.mjs`, and labelled "AI-drafted, not yet reviewed" in the app until a person approves them (`scripts/pack/review/`).
- Polish and Chinese versions of those scripts and of the UI strings are machine translations by the same model and have not been checked by native speakers.

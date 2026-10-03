# CityTour server: courses + studio voice

Status: design, agreed Sat 2026-10-03 evening. Implementation: `server/` (Express + TypeScript) and the app's
`services/remote/`. **Update (Sat night, product decision): the app ships no built-in course.** The Kraków course
(pack + 1155 clips, 1167 files, ~40 MB) lives in `data/course/krakow/` and is downloaded from the server on first
use; after that the app is fully offline-capable (downloaded pack, downloaded clips, built-in voice as the last
resort). Without the server and without a downloaded course the app shows a clear empty/offline state, never a
crash.

## 1. What the server does

| Job | How |
|---|---|
| **Course catalog** | Lists the published courses: tour, stops, km, minutes, languages and download size. |
| **Course download** | A signed manifest plus content-addressed files: the pack JSONs (tours, pois, routes, narrations, map) and the pre-rendered ElevenLabs clips. |
| **Runtime studio voice** | Turns a sentence the app needs but has no clip for into ElevenLabs audio, then caches it forever. |

There are no user accounts, no personal data and no location upload. The server never learns where the user is.

## 2. Fallback chain in the app (per sentence)

1. A clip in the **downloaded** course manifest (sha256 of the exact sentence) gives Studio voice.
2. Otherwise, if online: **`POST /v1/tts`**, with a 2.5 s budget. The first request for a line also has an on-device cache (filesDir/tts/<sha>.mp3) and prefetch of the next sentence. This gives Studio voice.
3. Otherwise **built-in TTS** (Core Speech Kit) gives "Fallback voice". For Polish with no clip and no server, the line is text only.

The label always shows the voice actually speaking.

## 3. API (v1)

Base URL: build-time config `entry/src/main/ets/app/RemoteConfig.ets`. It holds the public URL and public key; no
secrets.

| Method and path | Auth | Response |
|---|---|---|
| `GET /healthz` | none | `{ok:true, version}` |
| `POST /v1/installs` | none, rate-limited per IP | `{token, expiresAt}`. The token is an HMAC-signed `{iid, iat, exp}` for 30 days. It is not identity, only a throttle key. |
| `GET /v1/catalog` | none | signed envelope `{payload:{courses:[CourseSummary], cities:[CitySummary]}, sig}` (`cities` is absent in catalogs written before city packs) |
| `GET /v1/courses/:courseId/manifest` | none | signed envelope `{payload:CourseManifest, sig}` |
| `GET /v1/cities/:cityId/manifest` | none | signed envelope `{payload:CityManifest, sig}`; same caching as the course manifest; 404 `not_found` for an unknown or malformed id |
| `GET /v1/blobs/:sha256` | none | the file bytes. Content-addressed, `Cache-Control: public, max-age=31536000, immutable`, `ETag`. |
| `POST /v1/tts` | `Authorization: Bearer <token>` | `audio/mpeg`, with headers `X-Text-Sha256` and `X-Cache: hit\|miss` |

`CourseSummary` = `{id, version, title:{en,pl,zh}, city, cityId?, stops, km, minutes, langs:[...], bytes, coverBlob?, coverCredit?}`

`cityId` names the city pack the course's places come from (present for courses published with `--city-id`; `city`
is then that city's `names.en` unless overridden). `bytes` counts the course's own files only; the city is a
separate download.

`CitySummary` = `{id, version, names:{en,pl,zh}, places, bytes}` (`places` = the city pack's POI count, `bytes` =
the sum of its files).

`coverBlob` is the sha256 of the pack's cover photo (`packs/<packId>/cover.jpg`, 1280×800 JPEG, ≤ 250 KB), served by
`GET /v1/blobs/:sha256` like any blob; `coverCredit` is `"<author>, <licence>"` from the pack's `cover.json` (full
credit: author, licence + URL, Commons page, changes; data/ATTRIBUTION.md). Both are absent for a course without a
cover. The app fetches the cover for a catalog row before download (verifies the sha256, caches it as
`filesDir/covers/<sha>.jpg`), and reads `cover.jpg`/`cover.json` from the installed pack afterwards.

`CourseManifest` = `{schemaVersion:1, courseId, version, publishedAt, packId, files:[{path, sha256, bytes}],
audio:{manifestPath, clips:N}, allowedTtsSha:<sha256 of the allowed-lines file>, cityId?}`

`CityManifest` = `{schemaVersion:1, cityId, version, publishedAt, packId, files:[{path, sha256, bytes}]}`

**Signatures.** The envelope is `{payload, sig}`, where `sig` is an Ed25519 signature over the
canonical JSON of `payload` (sorted keys, UTF-8). It is base64.
- The app ships the **public key** and rejects any catalog or manifest that fails verification.
- Every blob is verified against its sha256 before it is used.
- A course is installed to a temp folder, then swapped in atomically. A failed or partial download never replaces a working course.

**`POST /v1/tts` body:** `{courseId, lang:"en"|"pl"|"zh", text}`. The body is at most 1 KB and `text` at most 400 chars.

### 3.1 Implementation details the app relies on (added with `server/`, shape above unchanged)

**Canonical JSON (what is signed).** `sig = base64(Ed25519(privateKey, utf8(canonical(payload))))`, where
`canonical(v)` is:
- `null`, `true`, `false` as is; a **string** or **number** exactly as `JSON.stringify` writes it (ECMAScript
  Number::toString, so `2.5`, `40307550`, `1e+21`; `-0` becomes `0`; NaN/Infinity are never present). Non-ASCII
  characters are written raw (not `\u` escaped), only `"`, `\` and control characters (and lone surrogates) are escaped;
- an **array**: `[` + its elements' canonical forms joined by `,` + `]`, order kept;
- an **object**: `{` + `"key":value` pairs joined by `,` + `}`, keys sorted ascending by UTF-16 code units (the
  default `Array.prototype.sort()`; every key we emit is ASCII, so this equals byte order), keys written with
  `JSON.stringify`; no member is ever `undefined`;
- no whitespace anywhere.
In ArkTS this is the same recursive function over the parsed `payload` (`JSON.stringify` for each primitive and
key). Verify against the **raw** `sig` string and the `payload` object of the envelope; the server signs exactly
what it serves (the files are signed once at publish time). Reference implementations:
`server/src/canonical.ts` and the 15-line copy in `server/scripts/smoke.mjs`.

**Public key encodings.** `npm run keygen` prints the same key three ways: raw 32 bytes (base64), SPKI DER
(base64, `MCowBQYDK2VwAyEA` + raw) and PEM. HarmonyOS `cryptoFramework` `Ed25519` `convertKey` takes the SPKI DER.

**Manifest `files[].path`.** Paths are relative to the course root (repo `data/course/<id>/`, the server's
`SEED_FILES_DIR/<id>/`; on the device `filesDir/courses/<id>/<version>/`): the pack folder's path relative to the
course root + `/<file>` for every file of the pack (including `manifest.json` and `narrations/<lang>.json`), i.e.
`tour/<file>` for a course overlay (city packs, below) and `packs/<packId>/<file>` for an older self-contained full
pack; `audio/manifest.json`, and every clip under the path the clip manifest already uses
(`audio/<lang>/<group-or-poi>/<hash>.mp3`). Download each `files[i]` from `/v1/blobs/<sha256>`, check
`sha256(bytes) == files[i].sha256` and `bytes.length == files[i].bytes`, then write it to `<courseDir>/<path>`.
`version` = `<pack version>-a<first 8 hex of sha256(audio/manifest.json)>`, plus `-c<first 8 hex of sha256(<cover.jpg sha>:<cover.json sha>)>` when the pack has a cover photo, so it changes when any of them changes. The cover files sit in the pack folder but are not listed in the pack's own `manifest.json` (the rest of the pack stays byte-identical); publish-course signs every file of the pack folder.
`allowedTtsSha` = sha256 of the exact `allowed.json` bytes (a JSON array of sorted lowercase hex strings).

**City packs.** A city's places (all POIs, their narrations in en/pl/zh, sources and the city map) are one signed
download shared by every course of that city; a course carries only its tour (`scripts/pack/split-city.mjs`,
docs/ARCHITECTURE.md §7.2a).
- City pack folder (repo `data/city/<cityId>/`, the server's `SEED_CITY_FILES_DIR/<cityId>/`; on the device a city
  folder of its own): `city.json`, `manifest.json`, `pois.json`, `narrations/{en,pl,zh}.json`, `sources.json`,
  `map-detail.json`. `CityManifest.files[].path` is relative to that city root (exactly those names). `city.json` =
  `{schemaVersion:1, cityId, names:{en,pl,zh}, origin:{lat,lng}, bbox, defaultBounds:[minLat,minLng,maxLat,maxLng], properNouns?}`.
  The city's `version` is the city pack manifest's version (`<YYYY.MM.DD>-<8 hex>`); download and verify it like a course.
- Course overlay `data/course/<id>/tour/`: `tours.json`, `routes.json`, `personas.json`, the stops' `pois.json`,
  `narrations/<lang>.json` and `sources.json` (same record formats as the full pack), `map-detail.json` only when the
  course's map differs from the city's, `demo-walk.json` (SIMULATED Demo walk track), `cover.jpg`/`cover.json`,
  `manifest.json` (pack format + `cityId`). The app overlays the course's records on the city's (same ids win from
  the course) and uses the city map when the overlay has none.
- City ids use the course id regex `^[a-z0-9][a-z0-9-]{0,63}$` in their own namespace (`cities/<id>/`), so city
  `krakow` and course `krakow` coexist.
- Deploy order: `publish-city` first, then `publish-course --city-id` for each of its courses (it fails with
  "publish the city first" otherwise; it reads the published city from `DATA_DIR`). Re-publishing an unchanged city
  keeps its `publishedAt`, so its signed manifest stays byte-identical.

**Allowed set content.** Narration sentences of every narration file of the pack and, for a course with a
`cityId`, of every narration file of the published city pack (the app plays the city's places with the course's
`courseId`); every system/arrival/nav line
of `scripts/voice/system-lines.mjs` for every tour (all 110 legs); and the numeric lines (approach with/without
direction, next stop with distance, off-route bearing with/without direction) for every tour stop x every RelDir x
every wording `distancePhrase` can produce up to 60 minutes (10..100 m step 10, 150..500 m step 50, 6..60 min), in
en/pl/zh. Golden-tested against the app (`SystemLines.test.ets`). Lines further than 60 min are not allowed and fall
back to the built-in voice.

**`POST /v1/tts` responses.** 200 `audio/mpeg` with `X-Text-Sha256` (sha256 of the request `text`), `X-Cache:
hit|miss`, `X-Blob-Sha256`. Errors are JSON `{error}`: 400 `bad_request` (zod: unknown fields, `text` 1..400 chars),
401 `unauthorized`, 403 `not_allowed`, 404 `unknown_course`, 413 `payload_too_large` (body over 2 KB; Chinese text
is up to 3 bytes per char, so the limit is 2 KB, not 1 KB), 429 `rate_limited` or `budget` (with `Retry-After`),
502 `tts_upstream`, 503 `tts_unavailable` (breaker open, `Retry-After`). Every non-200 means: use the fallback.
Shipped clips are pre-seeded in `tts-index.json` at publish time, so they are always cache hits (no credits).

**Deploy data.** `publish-city --seed server/seed` and `publish-course --seed server/seed` also write the signed
metadata to `server/seed/` (committed). The Docker image bundles it plus the course files from `data/course/` and the
city packs from `data/city/`, and on boot copies anything missing to `DATA_DIR` (verifying every sha256). See
`server/README.md`.

## 4. Security

**The ElevenLabs key lives only in the server's environment.** It is never in the app, the repo or the logs.

**No free-text TTS.** The server synthesises a `text` only if `sha256(text)` is in the course's **allowed-lines
set**. That set is built at publish time from:
- every narration sentence of the course (all lengths and languages), and of its city pack when it has one;
- every system and nav line (`scripts/voice/system-lines.mjs`, golden-tested against the app's `Phrases.ets`);
- the **numeric** variants (distance buckets, minutes, all directions, all stop names), with the same rounding as the app.

So the endpoint cannot be used as a general TTS service. The worst case is generating our own finite line set once, because every result is cached by sha.

**Spend caps.**
- A global daily character budget (`TTS_DAILY_CHAR_BUDGET`). Once it is hit, the server returns 429 and the app falls back.
- A per-token and per-IP rate limit (express-rate-limit).
- A circuit breaker on ElevenLabs 401, 429 or 5xx.

**Hardening.**
- Input and limits: `helmet`, no CORS (native client only), `express.json({limit:'2kb'})`, zod validation on every input.
- Upstream calls: request timeouts, and a 10 s upstream timeout with AbortController.
- Responses and logs: no stack traces in responses. Structured logs (pino) with the key, tokens and full text redacted (the sha only).
- Paths: blobs are served only by `^[a-f0-9]{64}$` from `DATA_DIR/blobs`, so there is no path input.
- Process: the container runs as non-root, secrets are validated at boot (fail fast), `npm audit` runs in CI, and dependencies are pinned.

**Admin.** There are no admin HTTP endpoints. Courses are published with a CLI on the maintainer's machine
(`npm run publish-city`, `npm run publish-course`), which sign with the private key and upload the data dir.

**Secrets (environment only):**

| Variable | Purpose |
|---|---|
| `ELEVENLABS_API_KEY` | ElevenLabs key |
| `ELEVENLABS_VOICE_ID` | George, `JBFqnCBsd6RMkjVDRZzb` |
| `TOKEN_SECRET` | 32+ random bytes, signs install tokens |
| `SIGNING_PRIVATE_KEY` | Ed25519 private key (PEM). Only the publish CLI needs it; the API only serves signed files. |
| `TTS_DAILY_CHAR_BUDGET` | Daily ElevenLabs character cap |
| `DATA_DIR` | Location of the data directory |

## 5. Storage layout (`DATA_DIR`)
```
catalog.json                     signed envelope
cities/<cityId>/manifest.json    signed envelope (city pack)
courses/<courseId>/manifest.json signed envelope
courses/<courseId>/allowed.json  sorted sha256 list for /v1/tts
blobs/<sha256>                   city and course pack files, clips, cached runtime TTS mp3s (content-addressed)
tts-index.json                   sha -> blob for runtime-rendered lines (+ chars, renderedAt)
usage/<yyyy-mm-dd>.json          characters spent per day
```
The server runs on one instance with a persistent volume. That is enough for a hackathon, and S3 can replace it later.

## 6. App changes
- `ohos.permission.INTERNET`. Calls go through Network Kit `http`; large downloads use `@ohos.request` agent with progress.
- `CourseRepository` manages the **downloaded** courses (`filesDir/courses/<id>/<version>/`); there is no bundled course. `PackRepository` (ActivePackRepository) reads from the active course, or from an empty pack until the first download (Home: "Download your first walk"). The first download becomes active; deleting the active course activates another downloaded one or none.
- **City places packs (app side).** A second `CourseStore` keeps `filesDir/cities/<cityId>/<version>/`. Downloading a
  course with a `cityId` first fetches `GET /v1/cities/<cityId>/manifest` when that city is not installed or the catalog
  lists another version (`CourseRules.cityNeedsDownload`), installs it with the same verified, resumable, atomic
  installer, then the course; **one progress bar** covers both (the Download size includes the city while it is not
  installed, `downloadBytes`). An installed older city keeps working when the city manifest cannot be fetched. The
  active pack is `CityCoursePackRepository`: the course's own pack (`tour/`) over the city pack, a course record wins
  over a city record with the same id (POIs, narrations, sources), tours/routes/personas come from the course, the map
  from the course when it ships `map-detail.json`, else from the city. Both packs must share one projection origin
  (refused otherwise). Deleting the last course of a city deletes the city pack too (`orphanCities`, log
  `COURSE event=city_removed`). A course without `cityId` (an older self-contained pack) still loads as before.
- **Nothing city-specific in the app.** The projection origin and the out-of-area bbox come from the pack manifest
  (the city's), the "All places" map opens on `city.json` `defaultBounds`, every user-visible city name comes from
  `city.json` `names` (UI language, nominative slot), the media session album is `"{city} · {tour}"`, the
  narration check's city-specific proper nouns come from `city.json` `properNouns`, and the SIMULATED Demo walk is
  the course pack's own `demo-walk.json` (offered for any course that ships one).
- **Courses screen:** shows catalog rows with *Download* (size), progress + *Cancel*, *Downloaded*, *Update*, *Try again* (resumes: verified files in the temp folder are kept after a failure), and *Delete*. The last good catalog is kept for offline use.
- **Streaming a course ("Play now", no server change).** Courses offers *Play now* (primary) next to *Download*.
  `CourseRepository.stream` verifies the signed catalog, course and city manifests as for a download, then installs
  with the same verified atomic installer only `StreamRules.streamCourseFiles` (every course file except the clips:
  `tour/*` and `audio/manifest.json`) into `filesDir/stream/<id>/<version>/` (plus `stream-clips.json`: the clip
  files' `{path, sha256, bytes}` from the signed manifest) and, when the city is not downloaded,
  `streamCityFiles` (`manifest.json`, `city.json`, `map-*.json`) into `filesDir/stream-cities/<cityId>/<version>/`
  (the city's places, stories and sources are not fetched; the course overlay holds its stops' records and stories;
  `SourcePackRepository` partial mode). `krakow`: 13 + 3 files, ~2.5 MB, vs 1168 + 7 files, ~41 MB. A streamed course
  can be the active one (also after a restart); a download of the same course wins (`courseSource`). Clips:
  `StreamClips` fetches `/v1/blobs/<sha>` on demand (size + SHA-256, `.part` + rename, cached), `RemoteVoice` waits at
  most 3 s (`STREAM_CLIP_BUDGET_MS`) and prefetches the next 3 sentences of the story (`prefetchAfter`); a late clip
  falls back for that sentence (marked unavailable until it arrives); a network failure skips the wait for 30 s.
  "All places" needs the downloaded city (`allPlacesAvailable`). *Download* copies the stream's already verified files
  (`InstallOptions.seedDir`, re-verified) and then removes the stream; *Delete* removes both.
- `RemoteVoice` (SpeechPort decorator) implements step 2 of the fallback chain. It checks `X-Text-Sha256` against the sha of its own text, and drops the audio on any mismatch.
- The online studio voice is always on (no toggle). The HUD shows `server: online|offline|budget`.

## 7. Deploy
The server ships as a Docker image (`server/Dockerfile`, node:22-alpine, non-root, healthcheck). Any host with a
persistent volume and HTTPS works (Fly.io, Render or Railway). Steps:
1. Create the app and volume, and set the secrets.
2. Generate the Ed25519 keypair and put the public key in `RemoteConfig.ets`.
3. Run `npm run publish-city` for krakow, then `npm run publish-course --city-id krakow` for each Kraków course.
4. Deploy.
5. Run the smoke test: `curl /healthz`, then fetch the catalog, verify it and request one TTS line.

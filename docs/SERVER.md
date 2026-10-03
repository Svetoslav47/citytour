# CityTour server: courses + studio voice

Status: design, agreed Sat 2026-10-03 evening. Implementation: `server/` (Express + TypeScript) and the app's
`services/remote/`. **The app must work with no server at all**: the bundled Kraków course and the built-in voice
stay, so the jury build is fully offline-capable.

## 1. What the server does

| Job | How |
|---|---|
| **Course catalog** | Lists the published courses: tour, stops, km, minutes, languages and download size. |
| **Course download** | A signed manifest plus content-addressed files: the pack JSONs (tours, pois, routes, narrations, map) and the pre-rendered ElevenLabs clips. |
| **Runtime studio voice** | Turns a sentence the app needs but has no clip for into ElevenLabs audio, then caches it forever. |

There are no user accounts, no personal data and no location upload. The server never learns where the user is.

## 2. Fallback chain in the app (per sentence)

1. A clip in the **bundled** or **downloaded** course manifest (sha256 of the exact sentence) gives Studio voice.
2. Otherwise, if online and "Online studio voice" is on: **`POST /v1/tts`**, with a 2.5 s budget. The first request for a line also has an on-device cache (filesDir/tts/<sha>.mp3) and prefetch of the next sentence. This gives Studio voice.
3. Otherwise **built-in TTS** (Core Speech Kit) gives "Fallback voice". For Polish with no clip and no server, the line is text only.

The label always shows the voice actually speaking.

## 3. API (v1)

Base URL: build-time config `entry/src/main/ets/app/RemoteConfig.ets`. It holds the public URL and public key; no
secrets.

| Method and path | Auth | Response |
|---|---|---|
| `GET /healthz` | none | `{ok:true, version}` |
| `POST /v1/installs` | none, rate-limited per IP | `{token, expiresAt}`. The token is an HMAC-signed `{iid, iat, exp}` for 30 days. It is not identity, only a throttle key. |
| `GET /v1/catalog` | none | signed envelope `{payload:{courses:[CourseSummary]}, sig}` |
| `GET /v1/courses/:courseId/manifest` | none | signed envelope `{payload:CourseManifest, sig}` |
| `GET /v1/blobs/:sha256` | none | the file bytes. Content-addressed, `Cache-Control: public, max-age=31536000, immutable`, `ETag`. |
| `POST /v1/tts` | `Authorization: Bearer <token>` | `audio/mpeg`, with headers `X-Text-Sha256` and `X-Cache: hit\|miss` |

`CourseSummary` = `{id, version, title:{en,pl,zh}, city, stops, km, minutes, langs:[...], bytes, coverBlob?}`

`CourseManifest` = `{schemaVersion:1, courseId, version, publishedAt, packId, files:[{path, sha256, bytes}],
audio:{manifestPath, clips:N}, allowedTtsSha:<sha256 of the allowed-lines file>}`

**Signatures.** The envelope is `{payload, sig}`, where `sig` is an Ed25519 signature over the
canonical JSON of `payload` (sorted keys, UTF-8). It is base64.
- The app ships the **public key** and rejects any catalog or manifest that fails verification.
- Every blob is verified against its sha256 before it is used.
- A course is installed to a temp folder, then swapped in atomically. A failed or partial download never replaces a working course.

**`POST /v1/tts` body:** `{courseId, lang:"en"|"pl"|"zh", text}`. The body is at most 1 KB and `text` at most 400 chars.

## 4. Security

**The ElevenLabs key lives only in the server's environment.** It is never in the app, the repo or the logs.

**No free-text TTS.** The server synthesises a `text` only if `sha256(text)` is in the course's **allowed-lines
set**. That set is built at publish time from:
- every narration sentence of the course (all lengths and languages);
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
(`npm run publish-course`), which signs with the private key and uploads the data dir.

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
courses/<courseId>/manifest.json signed envelope
courses/<courseId>/allowed.json  sorted sha256 list for /v1/tts
blobs/<sha256>                   pack files, clips, cached runtime TTS mp3s (content-addressed)
tts-index.json                   sha -> blob for runtime-rendered lines (+ chars, renderedAt)
usage/<yyyy-mm-dd>.json          characters spent per day
```
The server runs on one instance with a persistent volume. That is enough for a hackathon, and S3 can replace it later.

## 6. App changes
- `ohos.permission.INTERNET`. Calls go through Network Kit `http`; large downloads use `@ohos.request` agent with progress.
- `CourseRepository` merges the **bundled** course (rawfile, always present) with **downloaded** courses (`filesDir/courses/<id>/<version>/`). `PackRepository` reads from whichever course is active.
- **Courses screen:** shows catalog rows with *Download* (size), progress, *Downloaded*, *Update*, and *Delete*. The last good catalog is kept for offline use.
- `RemoteVoice` (SpeechPort decorator) implements step 2 of the fallback chain. It checks `X-Text-Sha256` against the sha of its own text, and drops the audio on any mismatch.
- Settings has an "Online studio voice" toggle (default on). The HUD shows `server: online|offline|budget`.

## 7. Deploy
The server ships as a Docker image (`server/Dockerfile`, node:22-alpine, non-root, healthcheck). Any host with a
persistent volume and HTTPS works (Fly.io, Render or Railway). Steps:
1. Create the app and volume, and set the secrets.
2. Generate the Ed25519 keypair and put the public key in `RemoteConfig.ets`.
3. Run `npm run publish-course` for krakow.
4. Deploy.
5. Run the smoke test: `curl /healthz`, then fetch the catalog, verify it and request one TTS line.

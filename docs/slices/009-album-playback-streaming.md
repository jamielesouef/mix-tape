---
slice_id: "009"
title: Album playback, streamed from the server
priority: P0
complexity: L
ladder: "audio auth v1 of 2 — v2 is header-only, shared seam: AudioURLProvider in AppInfrastructure, the single place an audio URL is built"
depends_on:
  - { id: "008", type: hard, note: "playback starts from the album detail screen" }
  - { id: "S001", type: hard, note: "decides whether /audio can be its own FileMiddleware root" }
previous_slice: "008"
next_slice: "010"
parent_slice: none
covers: ["3.audio", "6.playbackRules"]
created: 2026-08-31
---

# 009 — Album playback, streamed from the server

← [previous](008-album-detail-and-artwork.md) · [Master Checklist](MASTER-CHECKLIST.md) · [next](010-album-download-offline.md) →

> **Status, owner and blockers live in the master checklist, not here.** Dependencies live in this page's front matter and nowhere else. Each fact has one home; if you find yourself writing it twice, one of the two copies is going to be wrong in a fortnight.

## 1. Objective

Serve `GET /audio/**` with correct HTTP `Range` handling and play an album through it. Value observable on its own: pick an album, it plays, it finishes, you are back at the wallet. That sentence is the product.

## 2. Business Value & Priority

This is the slice where Mix Tape becomes a music player. Everything before it browses; this plays.

The rule that defines the product is implemented here and nowhere else: **the queue is the album.** Loading an album replaces the `AVQueuePlayer` queue entirely. Next on the final track stops playback and does nothing else — it never advances to another album. That is the CD-wallet concept, not an oversight, and the plan says explicitly that it gets a comment in the source so nobody "fixes" it. Write that comment.

`FileMiddleware` does all `Range` work, including multi-range and `If-Range`. The handoff forbids hand-rolling byte-range streaming, and the reason is that seeking in a FLAC over a range request has a long tail of edge cases that a framework has already dealt with. Any pull towards a custom handler in this slice is a signal to re-read that constraint.

**Ladder L7 — audio authentication (this slice ships the crude rung).** The plan's open question 2 asks for `?token=` or a header. **v1 is `?token=`.** `AVPlayerItem` streaming a remote URL with a bearer header depends on `AVURLAssetHTTPHeaderFieldsKey`, which is undocumented — building the product's core interaction on an unsupported key is a worse trade than a token in an access log on a single-owner box in a cupboard. The seam is `AudioURLProvider` in `AppInfrastructure`: **one type, the only place in the codebase an audio URL is constructed.** v2 switches to headers inside that type if a documented mechanism appears, and no caller changes. Named seam, so this is a ladder and not debt.

The route accepts **both** a bearer header and `?token=`, because slice 010's background `URLSession` uses the header and this slice uses the query parameter. Two mechanisms, one check.

## 3. Scope

**In scope:**

- `GET /audio/**` as a **catch-all wildcard route** — `relativePath` contains slashes, so it cannot be a single path parameter
- Percent-decoding the remainder and resolving it against the music root; **any resolved path escaping that root is rejected with `404`**
- Serving with `FileMiddleware`, which handles `Range`, multi-range and `If-Range`
- Accepting the token as `Authorization: Bearer` **or** `?token=`
- `AudioURLProvider` in `AppInfrastructure/` — the single construction point for an audio URL
- `PlaybackService` — `@MainActor @Observable final class` in `AppServices/Playback/`, wrapping `AVQueuePlayer`, holding the current album, the current index and a `PlaybackState`
- `load(album:)` building one `AVPlayerItem` per track and replacing the queue entirely
- Play, pause, next, previous, and selecting a specific track within the album. Nothing else — the handoff's list is exhaustive
- Stopping at the end of the final track, with the explanatory comment in the source
- `AVAudioSession` category `.playback` and the background audio capability
- `MPNowPlayingInfoCenter` and `MPRemoteCommandCenter`, so lock screen and CarPlay controls work
- `NowPlayingScreen` in `AppPresentation/Screens/Playback/`
- `PlaybackState` in `AppDomain/`

**Out of scope** (name the slice it is deferred to):

- Choosing a local file over the server → **011**. This slice always streams
- Downloads → **010**
- Shuffle, repeat, a cross-album queue, gapless playback, crossfade, an equaliser → out of scope for v1, permanently in the case of shuffle and cross-album queue. These are not missing features, they are the design
- AirPlay beyond what the system provides for free → out of scope for v1
- Transcoding, on either side → out of scope permanently

**Plan requirements covered:**

- `3.audio` — `GET /audio/**`, bearer **or** `?token=`, `Range`-served by `FileMiddleware`, with escape rejection.
- `6.playbackRules` — the queue is the album, next on the final track stops, `.playback` category plus background audio, `MPNowPlayingInfoCenter` and `MPRemoteCommandCenter`.
- **One addition the plan does not cover, recorded as F5 in Section 6:** filename hazards on the wildcard route. A real music library on a NAS contains `#`, `?`, `+`, `&` and `%` in filenames, and a share written from macOS carries NFD-decomposed unicode while a URL built on iOS is typically NFC. The plan says "percent-decoded and resolved against the music root" and stops there. Every one of these produces a `404` on a track that plays fine locally, and it will present as "some albums do not work".

**Verification note carried into implementation:** the plan's claims about `AVURLAssetHTTPHeaderFieldsKey` being undocumented, `AVAudioSession` category behaviour and `AVQueuePlayer` end-of-queue semantics were **not re-verified against Apple's documentation during planning, because the documentation tool was not available in that session.** Check each against `apple-docs` before implementing. If a documented header mechanism now exists, that is a ladder **L7** v2 opportunity — record it as a decision row and take it if it is cheap, rather than shipping the query parameter out of habit.

## 4. Pre-Flight Validation

Complete **before the first line of code**, not at close.

For **each id in `depends_on`**, in order — do not summarise, walk the list:

- [ ] **008** — opened. Its decision log still says `AlbumDetailScreen` lists tracks and is where playback will start from.
- [ ] **S001** — spike. It is answered, and **the answer, not the hoped-for answer**, is what this route is built on. Note whether the fallback was taken.
  - Favourable: `FileMiddleware` rooted at the music directory, mounted at `/audio`.
  - **Fallback taken:** one `FileMiddleware` at the cache root with music beneath it. The URL shape changes, `AudioURLProvider` changes with it, and ladder **L1**'s seam was already recorded as weakened in slice 003.
  - Confirm the pass-through behaviour S001 measured. If the middleware terminates on a miss, route registration order in this slice matters and every route must be registered **before** the catch-all.
Then two **transitive** checks. Neither **004** nor **005** is in this page's `depends_on` and neither should be added — each is already reachable through a declared edge, and restating it here would put a dependency fact in a second home. They are walked anyway because this slice reads a specific field from each, and the chain is named so a reader can see the front matter is complete rather than short:

- [ ] **004**, reached via `008 → 004a → 004` — confirm `TrackDTO.relativePath` is stored exactly as it appears under the music root, with no normalisation applied at scan time. If the scanner normalised unicode, the id hash and the served path have already diverged and fork **F5** is a bigger problem than it looks.
- [ ] **005**, reached via `008 → 007 → 006 → 005` — confirm the middleware can accept a query-parameter token, or that adding that path is in this slice's scope. Slice 005 built header-only.
- [ ] Re-read the Apple documentation for the three behaviours named in Section 3.
- [ ] Architecture standards doc re-read: `docs/plan/v1-architecture.md` sections 3 and 6.

**Drift found:** `none` — or what changed, plus a row in the checklist's Drift Log.

## 5. Acceptance Criteria

- [ ] `GET /audio/<relativePath>` with a valid `?token=` returns the bytes. With a valid bearer header, the same.
- [ ] With neither, `401`. With an invalid token in either position, `401`.
- [ ] A `Range: bytes=0-1023` request returns `206` with a correct `Content-Range` and exactly 1024 bytes.
- [ ] **Every shipped audio extension is served with a correct `Content-Type`** — FLAC, ALAC/m4a, MP3, AAC, WAV and AIFF, checked one at a time. **S001 measured a `.flac` coming back with no `Content-Type` header at all** from Hummingbird's default media-type map, invisible to a byte-level test because `Range` still works. The header being *present and correct* is the assertion; do not assume the gap is FLAC-only.
- [ ] A suffix range (`bytes=-1024`) and an open range (`bytes=1024-`) both behave correctly.
- [ ] **Path traversal returns `404` and never a file.** Test `../`, `%2e%2e%2f`, a doubly-encoded form, and an absolute path.
- [ ] **F5 — filename hazards.** A fixture library containing these exact filenames plays, every one:
  - `AC-DC/Back In Black/01 Hells Bells #1.flac`
  - `Artist/Album/02 What Is It? .mp3`
  - `Artist/Album/03 Rock + Roll & Blues.m4a`
  - `Björk/Homogénic/04 Jóga.flac` — **written from macOS**, so its filename is NFD-decomposed on disk
  - `Artist/Album/05 100% Pure.wav`
  This is the criterion fork **F5** exists for, and it must be a real fixture on disk, not a unit test over strings.
- [ ] Selecting an album plays it from track one.
- [ ] Next and previous move within the album.
- [ ] Selecting a specific track within an album starts there.
- [ ] **Next on the final track stops playback and does nothing else.** It does not advance to another album, does not wrap to track one, and does not clear the wallet. Explicitly tested, and the source carries the comment explaining why.
- [ ] Loading a second album replaces the queue entirely. The first album's remaining tracks are gone — assert the queue length, not just what is playing.
- [ ] Playback continues when the device locks. **This is where a missing `.playback` category or background capability shows up**, and it is invisible in the simulator — test on a device.
- [ ] The lock screen shows the album, track, artist and artwork, and its controls work.
- [ ] A `.flac`, an `.m4a`, an `.mp3`, a `.wav` and an `.aiff` all play. Direct play, no transcoding, per format.
- [ ] Seeking within a streamed FLAC works — this is `FileMiddleware`'s `Range` handling being exercised for real.
- [ ] Losing the network mid-track surfaces a distinguishable state, not a silent stall.
- [ ] `PlaybackService` is `@MainActor @Observable final class`. No `DispatchQueue`, no Combine.
- [ ] `AudioURLProvider` is the **only** place an audio URL is built. Verified by grep for the token query parameter — one hit. Ladder **L7**'s seam is worthless if a second construction site exists.
- [ ] `NowPlayingScreen` has a `#Preview` covering playing, paused, loading and failed.
- [ ] Runs on iOS, iPadOS and macOS.

## 6. Decision Log

**Write the row before you implement the decision, not after.** This is the whole mechanism. A decision log filled in at close is reconstructed from memory, and the rejected alternatives — the part the next slice's pre-flight actually needs — are exactly what memory loses first.

| Date | Decision | Alternatives rejected | Why |
|---|---|---|---|
| 2026-09-01 | **Audio is served by its own `FileMiddleware` rooted at the music directory and mounted at `urlBasePath: "/audio"`, second alongside the artwork instance** — the plan's layout, proven by **S001** | S001 §5's single-root fallback; hand-rolled byte-range streaming, which the handoff forbids outright | S001 confirmed two instances on two roots coexist on Hummingbird 2.26.0, and that `Range: bytes=0-99` returns `206` with `Content-Range: bytes 0-99/200000` from the middleware with no work on our side. It calls `next` first, so the token-checking routes registered around it are never shadowed. Path traversal — both `../` and the percent-encoded `%2e%2e%2f` — is rejected `400` before any file lookup, which is a stronger answer than the `404` this slice assumed |
| 2026-09-01 | **A `mediaTypeFileExtensionMap` covering the shipped audio extensions is passed to the audio `FileMiddleware`, and "the response carries a correct `Content-Type`" becomes an acceptance criterion** | Rely on Hummingbird's default map; set the header in a wrapping middleware after the file middleware has run | **S001 found this while answering a different question**: a `.flac` came back `200` with `Accept-Ranges` and a correct `Content-Length` but **no `Content-Type` header at all** — the default map has no entry and the header is simply omitted. `Range` still works, so it is invisible to a byte-level test and would surface as `AVPlayer` behaving differently on device from in a probe. The init already takes the map, which makes this configuration rather than a workaround. **Verify per extension** — FLAC, ALAC/m4a, MP3, AAC, WAV, AIFF — rather than assuming the gap is FLAC-only |
| 2026-08-31 | **v1 authenticates streamed audio with `?token=` (ladder **L7**, plan open question 2)** | Header-only via `AVURLAssetHTTPHeaderFieldsKey`; a short-lived signed URL; a per-session cookie | The header approach depends on an **undocumented** key, and the product's core interaction would rest on it. The cost of the query parameter is the token appearing in access logs on a single-owner box the owner controls — a real but small cost. The seam is `AudioURLProvider`, the one construction point; v2 is a change inside it. **Not put to the owner as a question**, because a crude option that works exists and the seam is nameable |
| 2026-08-31 | The route accepts both a header and a query parameter | Query parameter only; header only | Slice 010's background `URLSession` sets the header and cannot use the query parameter cleanly; this slice needs the query parameter. Both mechanisms feed the same verification, so it is one check with two sources, not two auth systems |
| 2026-08-31 | **F5 — filename hazards are in scope with a named fixture set. An addition to the plan** | Assume percent-decoding suffices, as the plan implies; normalise filenames at scan time | The plan says "percent-decoded and resolved against the music root" and stops. A real NAS library has `#`, `?`, `&`, `+`, `%` and NFD unicode from macOS. Each produces a `404` on a track that is plainly there, reported as "some albums don't work" — the worst kind of bug to receive. Normalising at scan time was rejected because `TrackDTO.id` hashes the path, so normalising would change every id and break slice 010's downloads on upgrade |
| 2026-08-31 | `FileMiddleware` does all `Range` work | A custom range handler | Multi-range, `If-Range` and suffix ranges have a long tail the framework has already handled. Explicitly forbidden by the handoff. Recorded because "just this one case" is how it starts |
| 2026-08-31 | Next on the final track stops. The source carries a comment saying why | Wrap to track one; advance to the next album; shuffle on | This is the CD-wallet concept and the reason the product exists. It reads as a bug to anyone who has not read the brief, which is exactly why the comment is mandatory rather than nice |
| | **S001 outcome.** Row to be written when the spike lands | | |

## 7. Sub-Slices

Not split — delivered as a single slice. The route and the player are separable on paper, but a route with no player is untested against a real `AVPlayerItem`, and range-serving bugs only appear under a real player seeking in a real file.

## 8. Testing Strategy

- **Integration (server):** the range matrix — full, prefix, suffix, open-ended, multi-range, `If-Range`, and an unsatisfiable range. Plus the four traversal forms, and both auth positions.
- **Integration (server):** the **F5** fixture filenames, requested exactly as `AudioURLProvider` would encode them. This must round-trip through the same encoding the client uses, or the test proves nothing about the client.
- **Unit (app):** `AudioURLProvider` — percent-encoding of each hazardous filename, asserted against the expected literal URL string.
- **Unit (app):** `PlaybackService` queue behaviour against a stubbed player: loading replaces the queue, next at the end stops, selecting a track starts there. The end-of-album case is the one that encodes the product decision.
- **UI:** one XCUITest — grid to detail to play, asserting the now-playing screen appears. Accessibility identifiers, never visible text.
- **Manual, and required:** on a **real device** — lock the screen and confirm playback continues; confirm the lock screen controls; seek within a streamed FLAC. None of these are trustworthy in the simulator, and the background audio capability in particular fails silently there.
- **Test targets required:** `Server/Tests/ServerTests/`, `App/Tests/MixTapeTests/`, `App/Tests/MixTapeUITests/` — all created by slice 001.

## 9. Keeping this document true

This slice is done when the page describes what was actually built — not when the code works. The discipline is **ordering**: the write happens *before* the thing it describes, so it sits on the critical path instead of after it, where it gets skipped.

| Before you… | Write this first |
|---|---|
| implement a decision | the Section 6 row, including what you rejected |
| start work | flip status in the master checklist |
| stop on a blocker | the Active Blockers row |
| build on a spike | that spike's Result section |
| widen scope | Section 3, and `depends_on` on any slice that is now affected |

And in the same commit as the code, not a follow-up: **commit this file alongside it**, with the slice id in the commit subject (`009: add streamed album playback`).

Nothing checks any of this. That is the point of putting the writes first — a write you have to do to proceed is one you do; a write you are supposed to do afterwards is one you do not.

## 10. Definition of Done

- [ ] Acceptance criteria met
- [ ] Tests passing, in a target that exists
- [ ] Every `covers:` requirement satisfied, or forked with a decision row — **F5 is an addition and has one**
- [ ] Decision log written as you went, not reconstructed, **including the S001 outcome row**
- [ ] Pre-flight completed and drift resolved, **including the Apple-documentation check named in Section 3**
- [ ] Master checklist row current
- [ ] `next_slice`'s `depends_on` reflects what actually shipped, not what was planned
- [ ] Both link directions checked: this page's `next_slice` and `010`'s `previous_slice`

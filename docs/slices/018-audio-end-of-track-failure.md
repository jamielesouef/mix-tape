---
slice_id: "018"
title: Audio end-of-track failure (Triage 7 v2)
priority: P2
complexity: M
ladder: "exact-end seek handling v2 of 2 — v1 (slice 015) clamps the seek to runtime − 1 s behind MusicPlayerService.seek(to:); v2 root-causes the failure and deletes the clamp. Shared seam: MusicPlayerService.seek(to:)"
depends_on:
  - { id: "015", type: hard, note: "v1 of the ladder and the measurement this slice starts from: on 'King Of Terrors' (FLAC) a seek to runtime − 1 s makes AVPlayerItem fail with FigFilePlayer err=-12864 — status .failed, no onEnded — while the ALAC albums end cleanly" }
  - { id: "013", type: hard, note: "MixtapeServicesTests and MixtapePresentationTests, and the gate that reads docs/slices/test-count.txt" }
previous_slice: "017"
next_slice: "019"
parent_slice: none
covers: []
created: 2026-09-05
---

# 018 — Audio end-of-track failure (Triage 7 v2)

← [previous](017-spec-document-reconciliation.md) · [Master Checklist](MASTER-CHECKLIST.md) · [next](019-codex-review-bounded-fixes.md) →

> **Status, owner and blockers live in the master checklist, not here.** Dependencies live in this page's front matter and nowhere else. Each fact has one home; if you find yourself writing it twice, one of the two copies is going to be wrong in a fortnight.

## 1. Objective

Seeking any track to any position ends the track normally. Observable on its own: drag the Now Playing scrubber to its end on a FLAC track and the album finishes, exactly as it does on an ALAC track today.

## 2. Business Value & Priority

Triage 7 recorded a "stall" at the exact end of a track. Slice 015 measured it and found something different: on "King Of Terrors" (FLAC, served by `/Audio/{id}/universal`), a seek that lands one second before the end makes `AVPlayerItem` fail — `FigFilePlayer err=-12864`, `onFailure` fires, `status` becomes `.failed`, and `onEnded` never comes — where the four ALAC albums end cleanly from the same gesture. So v1's clamp (`MusicPlayerService.endSeekMargin`) is a margin around a decode failure, not around a seek race, and the margin that is safe for FLAC is unknown.

**Second observation, 2026-09-05 (016's tvOS acceptance run):** it is not only seeks. On the Apple TV simulator the FLAC track "In the Name of the Father" (King Of Terrors, 3:47) was left to play from the start; `/Sessions` then showed the Apple TV session stuck on that track with `PositionTicks` 2271608163 — the full runtime — re-reported every 10 s for the next quarter of an hour, through a sign-out and a Quick Connect sign-in, while the album's remaining tracks never started and the queue never finished. So the natural end of a FLAC track fails the same way the seek-to-end did, the report loop keeps running on the failed item, and the failure survives sign-out. Reproduce with the album playing untouched, not only with the scrubber; and check what `stop()` on sign-out should do to the report loop.

P2 because the natural end of every track is unaffected and the gesture is a deliberate drag to the end; it is a slice rather than a deferral because AC17i does not allow an open triage item without an owner. This is the second rung of the ladder 015 opened; the shared seam is `MusicPlayerService.seek(to:)`, and the deliverable of this rung is to delete the clamp there and change nothing else.

## 3. Scope

**In scope:**

- Reproduce the failure against the dev server with `scripts/jf-probe.swift` reading `/Sessions`, and capture the server's response for the last bytes of the FLAC stream (`/Audio/{id}/universal` with `container=flac,…`) — whether the container/codec the server picks for FLAC is one AVPlayer can seek to within its final second.
- Decide, with a decision row, whether the fix is client-side (the `universal` container list or `transcodingContainer`, `BuildAudioStreamURLUseCase`) or a server finding recorded in the drift log with the clamp kept.
- If client-side: delete `endSeekMargin` from `MusicPlayerService.seek(to:)`, update the `MixtapeServicesTests` seek test, and demonstrate the drag-to-end on the FLAC album.

**Out of scope** (name the slice it's deferred to):

- Any change to what a report contains, or to the §1.1 invariants. The queue is the album.
- Anything on tvOS beyond confirming the fix there: 016's tvOS checks closed on 2026-09-05 (`scripts/tv-remote.sh`), and the see-through Now Playing cover is Triage 23, a separate owner.

**Plan requirements covered:** none. This is a defect rung, gated on builds, tests and the scripts, plus the demonstration above.

## 4. Pre-Flight Validation

- [x] **015** — opened. `endSeekMargin` was still 1 s behind `seek(to:)` (`MusicPlayerService.swift:26,148`) and the evidence paragraph's FLAC finding read as recorded.
- [x] **013** — opened. `docs/slices/test-count.txt` is the count the gate reads; this slice renames one test in `MixtapeServicesTests` and adds none, so the manifest is unchanged.
- [x] Dev server: "King Of Terrors" present once, six FLAC tracks under album `414bfd285d27e8f649d7025bcaf3b793`; the wallet lists it once (`wallet.sleeve.414bfd…`).
- [x] Architecture standards doc re-read.

**Drift found:** one item, outside this slice's seam. While testing the alternatives, the decision-23 HLS fallback (`container=` without the track's container → `transcodingContainer=ts`, `transcodingProtocol=hls`, `audioCodec=aac`) was exercised for the first time — no track in the library has ever needed it. On the host, `AVPlayer` loads the master playlist, then fails on `main.m3u8` with `CoreMediaErrorDomain -16845 "HTTP 400"`, while `jf-probe.swift` gets 200 for the same `main.m3u8` path. The master playlist copies `ApiKey` into the child URL, so it is not the missing token. Unverified on iOS and not this slice's defect; recorded as Triage 24 in the checklist.

## 5. Acceptance Criteria

- [x] **AC18a** — On a FLAC track, dragging the scrubber to its end ends the track and the album finishes; `music.status` never reaches `.failed`.
- [x] **AC18b** — The same on an ALAC track, unchanged from 015.
- [x] **AC18c** — `endSeekMargin` is gone, or a decision row says why it stays and what bounds it.
- [x] `xcodebuild build` and `test` pass for both schemes; layer, glass and swiftformat clean.

**Evidence, 2026-09-07.** *Root cause, on the host (macOS 26.6.2, `swift` script driving `AVPlayer`, `scratchpad/flac-repro.swift`):* the failure reproduces against the local `.flac` file exactly as against `/Audio/{id}/universal` and `/Audio/{id}/stream?static=true` — the server's responses are correct (`206`, `Accept-Ranges: bytes`, `Content-Type: audio/flac`, `Content-Length` present), so it is not a server finding. After a seek to runtime − 1 s the item's clock runs past its duration and `didPlayToEndTime` never arrives (60 s window: clock at 285 s of a 227 s track); the natural end of the same file, unseeked, fires on time. The overshoot grows with the file: an 8 s clip ends on time, a 20 s clip 2.8 s late, a 40 s clip 10.4 s late, a 90 s clip not within 14 s. Not the `SEEKTABLE` (removing it changes nothing; adding one to the 8 s clip changes nothing), not the embedded `PICTURE`, not the encoder (a `flac` re-encode fails the same way), not the seek tolerance (`toleranceBefore: .zero, toleranceAfter: .zero` fails the same way). ALAC of the same audio ends on time from the same gesture. `AVFoundation` is estimating the FLAC seek target by bitrate and then trusting its estimate: the audio it decodes is earlier than the time it reports, so the reported clock reaches the duration before the decoder reaches the file's end. Opting the asset into precise timing — `AVURLAsset(url:, options: [AVURLAssetPreferPreciseDurationAndTimingKey: true])` — makes the same seek end the track on time, on the local file and on the `universal` URL. Two alternatives were measured and rejected in the decision log below. *Acceptance, iPhone 17 Pro simulator (iOS 26.5) against `localhost:8096`, driven with `idb ui tap`/`swipe` and read through `jf-probe.swift /Sessions` filtered to the app's own device (drift log 2026-09-03):* AC18a — "King Of Terrors" (FLAC, direct: no `TranscodingInfo`), Now Playing open, the scrubber's thumb dragged to the slider's end: track 1 → track 2 within 2 s (`/Sessions` `NowPlayingItem` "Fearless", `PositionTicks` 20000000, `IsPaused` false), again track 2 → track 3, then on track 6 the album finished — Now Playing dismissed, the wallet on screen, `/Sessions` with no `NowPlayingItem` and still none 11 s later. `nowPlaying.playPauseButton` read "Pause" throughout; no failure state was shown and the report loop stopped. AC18b — "Sundowning" (ALAC, `Container` `mov,mp4,m4a,…`, direct), the same drag: track 1 → "The Offering" within 3 s. AC18c — `endSeekMargin` deleted, `seek(to:)` is `max(.zero, requested)` and nothing else. The tvOS natural-end observation in §2 did not reproduce on the host (the 227 s FLAC ended on time unseeked); the fix lives in the shared `AudioPlayerController`, so it applies to tvOS unchanged, and any recurrence there is a new triage row, not this one.

## 6. Decision Log

**Write the row before you implement the decision, not after.**

| Date | Decision | Alternatives rejected | Why |
|---|---|---|---|
| 2026-09-07 | The fix is client-side and lives where the `AVPlayerItem` is made: `AudioPlayerController.load(url:)` builds the item from an `AVURLAsset` with `AVURLAssetPreferPreciseDurationAndTimingKey: true`. `MusicPlayerService.seek(to:)` loses `endSeekMargin` and the clamp, and changes nothing else. `BuildAudioStreamURLUseCase`, the `universal` container list and `isNativeAudioContainer` are untouched, so FLAC stays DirectPlay and §12.13f / decision 43 stand. | (a) A server finding with the clamp kept — ruled out by the local-file reproduction. (b) Drop `flac` from the `container=` list so the server transcodes it: measured, and the HLS/AAC route is lossy, flips AC13f to `Transcode`, and on the host fails with HTTP 400 on `main.m3u8` (Triage 24) — a second defect traded for the first. (c) Server remux to ALAC over plain HTTP (`transcodingContainer=mp4`, `transcodingProtocol=http`, `audioCodec=alac`): the server answers `200 video/mp4` with `Accept-Ranges: none` and no length, and `AVPlayer` fails it with `-12939` before playing — not seekable, so it cannot fix a seek. (d) Fire `onEnded` from the controller when position ≥ duration: masks the symptom, cuts the audio the estimate skipped, and does nothing for the `-12864` failure 015 saw on iOS. | One option ends the track on time, keeps the audio lossless, keeps every decision, and is one line where the item is built — the seam every FLAC seek already passes through. |

## 7. Sub-Slices

Not split.

## 8. Testing Strategy

- **Unit:** `MixtapeServicesTests` (`.service`): the seek path with and without the clamp; a stub controller that reports failure near the end if the fix is client-side.
- **Integration:** none against the live server in an automated test.
- **UI:** none — decision 4.
- **Acceptance:** AC18a and AC18b on the iOS simulator against `localhost:8096`, read through `scripts/jf-probe.swift`.
- **Test targets required:** `MixtapeServicesTests` (exists).

## 9. Keeping this document true

| Before you… | Write this first |
|---|---|
| implement a decision | the Section 6 row, including what you rejected |
| start work | flip status in the master checklist |
| stop on a blocker | the Active Blockers row |
| widen scope | Section 3, and `depends_on` on any slice that's now affected |

Commit this file alongside the code, with the slice id in the subject (`018: …`).

## 10. Definition of Done

- [x] Acceptance criteria met
- [x] Tests passing, in a target that exists
- [x] Triage 7 closed in the master checklist, v2 included
- [x] Decision log written as you went, not reconstructed
- [x] Pre-flight completed and drift resolved
- [x] Master checklist row current

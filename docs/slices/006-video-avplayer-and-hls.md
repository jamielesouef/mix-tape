---
slice_id: "006"
title: "Video: AVPlayer direct and HLS"
priority: P0
complexity: L
ladder: "AVPlayer path v1 of 2 — the direct-VLC path is slice 007, shared seam: the `VideoPlayerControlling` protocol (defined here, in `MixtapeInfrastructure`) and the `PlaybackMethod.directVLC` case this slice's use case already resolves to but does not yet play"
depends_on:
  - { id: "005", type: hard, note: "needs MovieDetailScreen (Play button wired here), RootTabScreen, AppContainer and the @Entry wiring, and LibraryService for item detail" }
  - { id: "S002", type: hard, note: "answers whether AVPlayer can carry the MediaBrowser Authorization header on a stream request, or must fall back to ApiKey in the query string (decision 33). This slice's auth wiring is built on that answer, not the hoped-for one" }
previous_slice: "005"
next_slice: "007"
parent_slice: none
covers: ["§1.10", "§12.6", "§12.8"]
created: 2026-09-03
---

# 006 — Video: AVPlayer direct and HLS

← [previous](005-browse.md) · [Master Checklist](MASTER-CHECKLIST.md) · [next](007-video-vlc.md) →

> **Status, owner and blockers live in the master checklist, not here.** Dependencies live in this page's front matter and nowhere else. Each fact has one home; if you find yourself writing it twice, one of the two copies is going to be wrong in a fortnight.

## 1. Objective

Resolve a video item's playable source from the server and play it in-app through AVPlayer, on both the direct-play and HLS-transcode branches. On its own, without slice 007 landing: the Avatar `mp4`/h264 movie plays via `.directAVPlayer` with no transcode session, and, with the DEBUG launch argument this slice adds, the F1 `mkv`/h264/aac movie can be forced through the same device to demonstrate `.transcodeHLS` with a transcode session visible in Jellyfin's dashboard — both server-observable outcomes, both reachable with only this slice built on top of 005.

## 2. Business Value & Priority

P0. Playing video is capability 10 of 15 and the reason the app exists; nothing downstream (resume, reporting) has anything to report against until a video actually plays. This is the first of two player rungs: AVPlayer covers direct play and HLS transcode today, direct play through VLCKit is deferred to slice 007. The shared seam is the `VideoPlayerControlling` protocol this slice defines in `MixtapeInfrastructure` and the `PlaybackMethod` enum (already in `MixtapeDomain` from slice 002) whose `.directVLC` case this slice's `ResolveVideoPlaybackUseCase` already resolves to correctly — it simply has no controller to hand that plan to until 007 lands.

## 3. Scope

**In scope:**
- `JellyfinPlaybackRepository.resolveVideo(itemID:startAt:session:)` in `MixtapeData`, calling `POST /Items/{itemId}/PlaybackInfo?userId={uid}` with the permissive §8 device profile (containers `mp4,m4v,mov,mkv,webm`; video codecs `h264,hevc,vp9,av1`; audio codecs `aac,mp3,ac3,eac3,flac,alac,opus,dts`; one `hls`/`ts`/`h264`/`aac` transcoding profile) and returning the response's media sources per decision 12 — a mapped value type carrying id, container, codecs, `supportsDirectPlay`, `supportsDirectStream`, `transcodingUrl` and `runTimeTicks`. The repository does not choose a method; it only returns data.
- `ResolveVideoPlaybackUseCase` in `MixtapeUseCase`, which does choose the method: picks the first media source or throws `.noPlayableSource`; if `supportsDirectPlay || supportsDirectStream`, builds the stream URL `/Videos/{itemId}/stream?static=true&mediaSourceId={id}&playSessionId={psid}&deviceId={did}` (`deviceId` is new versus the doc's line 570, per decision 26) and sets the method via `isAVPlayerNative(container:videoCodec:audioCodec:)` — native gives `.directAVPlayer`, otherwise `.directVLC` (a `nil` audio codec is native per decision 39; the Avatar mp4's `MediaStreams` holds one video entry and no audio, so this is the row AC6 rides on); if instead a `transcodingUrl` is present, passes it through **verbatim** (decision 7's carve-out — never strip or rebuild its embedded `ApiKey`, `PlaySessionId`, `Tag` or `TranscodeReasons`) and sets `.transcodeHLS`; otherwise throws `.noPlayableSource`. Sets `PlaybackPlan.playMethod` (the wire `PlayMethod`) from whichever support flag was true, per decision 11.
- Stream authentication on URLs this slice's use case builds (the `.directAVPlayer` and `.directVLC` stream URL — not the server's `TranscodingUrl`, which already carries `ApiKey`): the `Authorization: MediaBrowser …` header, carrying the token, on every request per decision 7 — **unless** S002's result for AVPlayer says the header cannot be delivered to `AVURLAsset` through public API, in which case AVPlayer-bound URLs take the pre-authorised fallback and carry `ApiKey` in the query string instead (decision 33). Whichever answer S002 returns is what ships; this slice does not guess ahead of it. Never the private `AVURLAssetHTTPHeaderFieldsKey` — decision 33 forbids it outright, and taking the documented fallback is correct where the header genuinely cannot be delivered.
- `VideoPlayerControlling` protocol, defined in `MixtapeInfrastructure` per engineering doc §7 (`load(url:startAt:headers:)`, `play()`, `pause()`, `seek(to:)`, `teardown()`, `makeView() -> AnyView`, plus the `onPositionChange` / `onEnded` / `onFailure` callbacks). This is the seam slice 007's `VLCPlayerController` conforms to next.
- `AVPlayerController`, `@MainActor final class` in `MixtapeInfrastructure`, conforming to `VideoPlayerControlling`, owning an `AVPlayer`. `makeView()` returns a `VideoPlayer` (AVKit)-backed representable per decision 18 — not a raw `AVPlayerLayer` — so Picture in Picture, AirPlay and transport controls come from the platform rather than being rebuilt by hand.
- `VideoPlaybackService`, `@MainActor @Observable` in `MixtapeServices`, exposing `plan`, `status` (`.idle`/`.preparing`/`.playing`/`.paused`/`.failed`), `position`, `duration`, and `play(item:)` / `togglePlayPause()` / `seek(to:)` / `stop()`. It owns a `VideoPlayerControlling` selected by `plan.method`; for `.directAVPlayer` and `.transcodeHLS` that is `AVPlayerController`. It imports `MixtapeInfrastructure` for that controller and for nothing else (decision 36). On `play` it calls `ReportPlaybackStartUseCase` once; progress and stopped reports are slice 008.
- `ReportPlaybackStartUseCase` in `MixtapeUseCase` and `PlaybackRepositoryProtocol.reportStart` in `JellyfinPlaybackRepository`, posting the §8 body to `POST /Sessions/Playing` with `PlayMethod` from `PlaybackPlan.playMethod` (decision 11) and `CanSeek: true`. Moved here from build step 8 by decision 37: `/Sessions` shows no `NowPlayingItem`, `PlayMethod` or `TranscodingInfo` until this report has been sent, so AC6 and AC8 cannot be gated without it. Failures are logged on `network` and swallowed.
- `VideoPlayerScreen`, a full-screen cover in `MixtapePresentation` hosting the controller's `makeView()` plus a custom overlay. `MovieDetailScreen`'s Play button (built inert in slice 005) is wired to `VideoPlaybackService.play(item:)`.
- `DeviceProfile` as a value injected into `JellyfinPlaybackRepository` rather than hardcoded inside it, so a different profile can be substituted without touching the repository. In DEBUG builds only, the launch argument `-mixtape-force-transcode` makes `AppContainer` inject a restrictive profile (declaring only `webm`/`vp9`/`opus`) in place of the shipped permissive one, so AC8 is demonstrable in-app against the existing F1 `mkv` — see Section 6. The shipped, non-DEBUG profile is untouched and stays permissive, because AC6, AC7 (slice 007) and AC13f (slice 009) all depend on it continuing to produce no transcode for the library's real files.

**Out of scope** (name the slice it's deferred to):
- `VLCPlayerController` and the `.directVLC` playback path — deferred to **007**. This slice's `ResolveVideoPlaybackUseCase` correctly resolves F1's ordinary (non-forced) `PlaybackInfo` response to `.directVLC`; `VideoPlaybackService` has no controller for that method yet, so playing F1 without the force flag is not a demonstrable path until 007 lands.
- Progress and stopped reports, and resume — deferred to **008**. Only the start report lands here (decision 37); nothing else is told to the server yet.
- tvOS-specific player chrome (system transport vs. a Siri Remote overlay) — deferred to **011**. This slice only requires the `tvOS` scheme to build; `VideoPlayerScreen` and `AVPlayerController` are shared code, since AVKit's `VideoPlayer` works on both platforms without a platform split.
- Music playback — deferred to **009**.
- The wallet — deferred to **010**.

**Plan requirements covered:**
- `§1.10` — "Play video: direct play (AVPlayer), direct play (VLCKit), or HLS transcode (AVPlayer)." This slice delivers the AVPlayer-driven two thirds of that capability — direct play and HLS transcode. The VLCKit third is 007's `covers:` entry, not this one's.
- `§12.6` — an `.mp4/h264/aac` movie plays via `.directAVPlayer` with no transcode session in the dashboard. Claimed in full here: the start report makes the session visible, and `/Sessions` shows `PlayMethod: DirectPlay` with no `TranscodingInfo` (decision 37).
- `§12.8` — a source the device profile rejects plays via `.transcodeHLS` and the dashboard shows a transcode. Claimed in full here: the DEBUG launch argument forces F1 through the restrictive profile (decision 14), and with the start report sent `/Sessions` shows `PlayMethod: Transcode` and `TranscodingInfo` present (decision 37).

No requirement is covered here in a way that departs from the engineering doc or an existing `SPEC-DECISIONS.md` entry without a decision row — see Section 6.

## 4. Pre-Flight Validation

Complete **before the first line of code**, not at close.

For **each id in `depends_on`**, in order — don't summarise, walk the list:

- [ ] `005` opened. Its decision log still says what this slice assumed: `MovieDetailScreen` renders an inert Play/Resume button, `RootTabScreen` is the signed-in root, `AppContainer` builds the graph with one `@Entry` per service, and `MediaItem.playback.position` is mapped from `PlaybackPositionTicks`.
- [ ] `005` is not a spike — n/a.
- [ ] `005`'s state matches what this slice assumed when drafted, not when it was written.
- [ ] Architecture standards doc re-read; nothing changed underneath this slice.
- [ ] `S002` opened. Its decision log still says what this slice assumed about AVPlayer's ability to carry the `Authorization` header.
- [ ] `S002` is a spike: confirm it is answered, and that the answer — not the hoped-for "AVPlayer can carry the header" answer — is what this slice's auth wiring is built on. Note whether the fallback (`ApiKey` in the query string on AVPlayer-bound URLs) was taken.
- [ ] `S002`'s state matches what this slice assumed when drafted: that the question is answered per player, and that the fallback is pre-authorised by decision 33 rather than something this slice invents if the header route fails.
- [ ] Architecture standards doc (`docs/architecture.md`) re-read; nothing changed underneath this slice — in particular, that `MixtapeInfrastructure` still depends only on `MixtapeDomain` and VLCKit, so `VideoPlayerControlling` and `AVPlayerController` have a home there.
- [ ] Decision 36 is in `SPEC-DECISIONS.md` and slice 001 applied it: `Package.swift` declares `MixtapeServices` → `MixtapeInfrastructure` and `check-layer-imports.sh` permits that import, so `VideoPlaybackService` can own a `VideoPlayerControlling` from §7 without a layer violation.

**Drift found:** none.

## 5. Acceptance Criteria

Mechanical:
- [ ] `xcodebuild build` passes for both the `iOS` and `tvOS` schemes.
- [ ] `xcodebuild test -skip-testing:iOSUITests` (iOS scheme) and `-skip-testing:tvOSUITests` (tvOS scheme) pass, unit tests only.
- [ ] `./scripts/check-layer-imports.sh` exits 0 — `AVPlayerController` and the new `VideoPlayerControlling` protocol live in `MixtapeInfrastructure`; nothing in `MixtapeUseCase` or `MixtapeDomain` imports `AVFoundation`.
- [ ] `swiftformat --lint .` is clean.

Behavioural:
- [ ] `MixtapeUseCaseTests`, tagged `.useCase`: `ResolveVideoPlaybackUseCase` covers one case per `PlaybackMethod` branch (`.directAVPlayer`, `.directVLC`, `.transcodeHLS`) plus `.noPlayableSource`, plus a case asserting `PlaybackPlan.playMethod` is set correctly (`DirectPlay` vs `DirectStream` vs `Transcode`) for each branch, plus a source with `mp4`/`h264` and no audio stream resolving to `.directAVPlayer` (decision 39). The `.directVLC` case only asserts the resolved plan's `method`, since no controller consumes it yet.
- [ ] `MixtapeDataTests`, tagged `.repository`: `JellyfinPlaybackRepository.resolveVideo` against a captured `PlaybackInfo` fixture, stubbed `URLProtocol`, never a live server.
- [ ] `MixtapeServicesTests`, tagged `.service`: `VideoPlaybackService` status transitions (`.idle` → `.preparing` → `.playing` → `.paused` → `.failed`) against a stub `VideoPlayerControlling`, and exactly one start report per `play(item:)` against a stub `ReportPlaybackStartUseCase`, carrying the plan's `playMethod`.
- [ ] `MixtapeUseCaseTests`, tagged `.useCase`: `ReportPlaybackStartUseCase` — success, and a repository failure swallowed rather than thrown.

Acceptance (server-observable, against `http://localhost:8096`):
- [ ] AC6: play the Avatar `mp4`/h264 movie; `GET /Sessions` shows this device's session with `NowPlayingItem` set, `PlayMethod: DirectPlay`, and no `TranscodingInfo`. The session is visible because the start report was sent (decision 37); without it this check cannot fail, so an absent `NowPlayingItem` is itself a failure.
- [ ] AC8: relaunch with the `-mixtape-force-transcode` launch argument, play the F1 `mkv` movie; `GET /Sessions` shows this device's session with `NowPlayingItem` set, `PlayMethod: Transcode`, and `TranscodingInfo` present.

## 6. Decision Log

**Write the row before you implement the decision, not after.** This is the whole mechanism. A decision log filled in at close is reconstructed from memory, and the rejected alternatives — the part the next slice's pre-flight actually needs — are exactly what memory loses first.

| Date | Decision | Alternatives rejected | Why |
|---|---|---|---|
| 2026-09-03 | Stream auth for AVPlayer-bound URLs follows S002's recorded answer (header, or `ApiKey` query fallback per decision 33); never the private `AVURLAssetHTTPHeaderFieldsKey` | Asserting header delivery through `AVURLAsset` options ahead of the spike | Decision 33 makes decision 7 provisional per player and forbids the private key; the row is replaced with the per-player answer once S002 runs |
| 2026-09-03 | `VideoPlaybackService` imports `MixtapeInfrastructure` to own its `VideoPlayerControlling`, over the edge decision 36 adds in slice 001 | Declaring the protocol in `MixtapeServices` and conforming in the app target | Cited from decision 36 — `makeView() -> AnyView` pins the protocol to a SwiftUI-importing module; the added edge is the shape without a retroactive-conformance warning |
| 2026-09-03 | `ReportPlaybackStartUseCase` and `reportStart` land here, not in 008 (decision 37, cited not re-argued) | Keeping all three reports in 008 and gating AC6/AC8 on `TranscodingInfo` alone | Measured: `/Sessions` carries no `NowPlayingItem`, `PlayMethod` or `TranscodingInfo` until `POST /Sessions/Playing` is sent, and `/Videos/ActiveEncodings` is 405; without the start report AC6's gate cannot fail and AC8's cannot pass |
| 2026-09-03 | DEBUG-only launch argument `-mixtape-force-transcode` makes `AppContainer` inject a restrictive `DeviceProfile` in place of the shipped one, so AC8 plays live against the existing F1 `mkv` | Leaving AC8 as a fixture-only unit test with no in-app demonstration; changing the shipped device profile itself to be restrictive | `SPEC-DECISIONS.md` decision 14 established that AC8 is a test-fixture problem, not a missing-media-file problem, and that the permissive profile the app actually ships must stay unchanged because AC6, AC7 and AC13f depend on it never transcoding the library's real files. A DEBUG-only launch argument demonstrates the transcode branch live, on the same simulator build used for AC6, without touching production behaviour |

Decisions already settled in `SPEC-DECISIONS.md` and applied without re-argument here: decision 7 and its `TranscodingUrl` carve-out (auth mechanism and verbatim passthrough), decision 9 (unmapped 4xx → `.transport`, inherited from slice 003's client), decision 11 (`PlaybackPlan.playMethod`), decision 12 (repository returns sources, use case selects method), decision 18 (`AVPlayerController` presents via `VideoPlayer`), decision 26's `deviceId` addition to the stream URL, and decision 33 (per-player auth question, S002-gated, fallback pre-authorised).

## 7. Sub-Slices

Not split — delivered as a single slice.

## 8. Testing Strategy

- **Unit / Integration / UI:** unit tests only. No XCUITest, no CI gate — both are deferred per decision 4. Repositories are tested against a stubbed `URLProtocol`; nothing in this slice's test suite touches the live Jellyfin server. `http://localhost:8096` is used only for the manual acceptance checks (AC6, AC8) via `curl`/the Jellyfin dashboard and the simulator, never from an automated test.
- **Test targets required:** `MixtapeUseCaseTests` (`ResolveVideoPlaybackUseCase` and `ReportPlaybackStartUseCase`, `.useCase`), `MixtapeDataTests` (`JellyfinPlaybackRepository`, `.repository`, fixture under `Tests/MixtapeDataTests/Fixtures/`), `MixtapeServicesTests` (`VideoPlaybackService`, `.service`). All three targets already exist from slice 001; this slice adds cases to them, it creates no new test target.

## 9. Keeping this document true

This slice is done when the page describes what was actually built — not when the code works. The discipline is **ordering**: the write happens *before* the thing it describes, so it sits on the critical path instead of after it, where it gets skipped.

| Before you… | Write this first |
|---|---|
| implement a decision | the Section 6 row, including what you rejected |
| start work | flip status in the master checklist |
| stop on a blocker | the Active Blockers row |
| build on a spike | that spike's Result section |
| widen scope | Section 3, and `depends_on` on any slice that's now affected |

And in the same commit as the code, not a follow-up: **commit this file alongside it**, with the slice id in the commit subject (`006: add AVPlayer direct and HLS playback`).

Nothing checks any of this. That's the point of putting the writes first — a write you have to do to proceed is one you do; a write you're supposed to do afterwards is one you don't.

## 10. Definition of Done

- [ ] Acceptance criteria met
- [ ] Tests passing, in a target that exists
- [ ] Every `covers:` requirement satisfied, or forked with a decision row
- [ ] Decision log written as you went, not reconstructed
- [ ] Pre-flight completed and drift resolved
- [ ] Master checklist row current
- [ ] `next_slice`'s `depends_on` reflects what actually shipped, not what was planned
- [ ] Both link directions checked: this page's `next_slice` and that page's `previous_slice`

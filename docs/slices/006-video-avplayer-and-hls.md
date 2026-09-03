---
slice_id: "006"
title: "Video: AVPlayer direct and HLS"
priority: P0
complexity: L
ladder: "AVPlayer path v1 of 2 — the direct-VLC path is slice 007, shared seam: the `VideoPlayerControlling` protocol (defined here, in `MixtapeInfrastructure`) and the `PlaybackMethod.directVLC` case this slice's use case already resolves to but does not yet play"
depends_on:
  - { id: "005", type: hard, note: "as shipped: MovieDetailScreen(item:) renders inert Play/Resume buttons and reads LibraryService.details[item.id] filled by loadDetail(id:); RootTabScreen is the signed-in root; AppContainer builds LibraryService, SeriesService and ImageService with @Entry keys libraryService, seriesService, imageService; services take SessionService by constructor and call handleSessionExpiry() on .sessionExpired; MediaItem gained albumID and Hashable, LoadState and Page gained Equatable; MockMedia in MixtapeServices exposes preview sample data" }
  - { id: "S002", type: hard, note: "measured that /Videos/{itemId}/stream is anonymous on 10.11.11 and that ApiKey in the query plays on AVPlayer; decision 42 chose ApiKey on that evidence and closed decision 33. This slice's stream URL is built on that decision" }
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
- `ResolveVideoPlaybackUseCase` in `MixtapeUseCase`, which does choose the method: picks the first media source or throws `.noPlayableSource`; if `supportsDirectPlay || supportsDirectStream`, builds the stream URL `/Videos/{itemId}/stream?static=true&mediaSourceId={id}&playSessionId={psid}&deviceId={did}&ApiKey={token}` (`deviceId` is new versus the doc's line 570, per decision 26; `ApiKey` per decision 42) and sets the method via `isAVPlayerNative(container:videoCodec:audioCodec:)` — native gives `.directAVPlayer`, otherwise `.directVLC` (a `nil` audio codec is native per decision 39; the Avatar mp4's `MediaStreams` holds one video entry and no audio, so this is the row AC6 rides on); if instead a `transcodingUrl` is present, passes it through **verbatim** (decision 7's carve-out — never strip or rebuild its embedded `ApiKey`, `PlaySessionId`, `Tag` or `TranscodeReasons`) and sets `.transcodeHLS`; otherwise throws `.noPlayableSource`. Sets `PlaybackPlan.playMethod` (the wire `PlayMethod`) from whichever support flag was true, per decision 11.
- Stream authentication on URLs this slice's use case builds (the `.directAVPlayer` and `.directVLC` stream URL — not the server's `TranscodingUrl`, which already carries `ApiKey`): **`ApiKey` in the query string, per decision 42.** S002 measured `/Videos/{itemId}/stream` as anonymous on Jellyfin 10.11.11 (206 with no auth, 206 with a bogus token; no `security` block in the spec), but that is undocumented behaviour a server upgrade or a differently configured instance could remove, so the app does not build on it. `ApiKey` costs one query parameter and no resource-loader delegate, so the AVPlayer path is a plain `AVURLAsset`. No player carries the `Authorization` header on a stream URL; decision 33 is closed. `VideoPlayerControlling.load(url:startAt:headers:)` keeps its `headers` parameter per engineering doc §7; this slice passes it empty. Never the private `AVURLAssetHTTPHeaderFieldsKey`.
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

- [x] `005` opened. Its decision log still says what this slice assumed: `MovieDetailScreen` renders an inert Play/Resume button, `RootTabScreen` is the signed-in root, `AppContainer` builds the graph with one `@Entry` per service, and `MediaItem.playback.position` is mapped from `PlaybackPositionTicks`.
- [x] `005` is not a spike — n/a.
- [x] `005`'s state matches what this slice assumed when drafted, not when it was written.
- [x] Architecture standards doc re-read; nothing changed underneath this slice.
- [x] `S002` opened. Its Result still records what this slice is built on: `/Videos/{itemId}/stream` is anonymous on 10.11.11, and a plain `AVURLAsset` plays a URL carrying `ApiKey` in the query.
- [x] `S002` is a spike: confirm it is answered, and that decision 42 — `ApiKey` in the query string, no header, no delegate — is still the standing decision on that evidence.
- [x] `S002`'s state matches what this slice assumed when drafted: decision 33 is closed, decision 7 is amended, and no per-player auth mechanism remains to choose.
- [x] Architecture standards doc (`docs/architecture.md`) re-read; nothing changed underneath this slice — in particular, that `MixtapeInfrastructure` still depends only on `MixtapeDomain` and VLCKit, so `VideoPlayerControlling` and `AVPlayerController` have a home there.
- [x] Decision 36 is in `SPEC-DECISIONS.md` and slice 001 applied it: `Package.swift` declares `MixtapeServices` → `MixtapeInfrastructure` and `check-layer-imports.sh` permits that import, so `VideoPlaybackService` can own a `VideoPlayerControlling` from §7 without a layer violation.

**Drift found:** none blocking. Two things 005 shipped differently from what this page assumed when drafted: `MovieDetailScreen` reads a fresh item from `LibraryService.details[item.id]` (so the Resume button and start position come from the server's current `PlaybackPositionTicks`, not only the pushed item), and `MediaItem` gained `albumID`. Neither changes this slice's shape. One env-file drift from 005's Drift Log row applies here: `JELLYFIN_USER_ID` names a different account from the one the app signs in as, so AC6 and AC8 read `/Sessions` filtered by `DeviceName` / `Client`, never by that id.

## 5. Acceptance Criteria

Mechanical:
- [x] `xcodebuild build` passes for both the `iOS` and `tvOS` schemes.
- [x] `xcodebuild test -skip-testing:iOSUITests` (iOS) and `-skip-testing:tvOSUITests` (tvOS) pass, unit tests only. Gate expected executed-test count per scheme: **130** (104 from slice 005 plus 26: 12 `ResolveVideoPlaybackUseCase` + 2 `ReportPlaybackStartUseCase`, 6 `JellyfinPlaybackRepository`, 8 `VideoPlaybackService`; parameterised tests count once). Verified 2026-09-03 via `./scripts/gate.sh 130`.
- [x] `./scripts/check-layer-imports.sh` exits 0 — `AVPlayerController` and `VideoPlayerControlling` live in `MixtapeInfrastructure`; nothing in `MixtapeUseCase` or `MixtapeDomain` imports `AVFoundation`.
- [x] `swiftformat --lint .` is clean.

Behavioural:
- [x] `MixtapeUseCaseTests` (`.useCase`): `ResolveVideoPlaybackUseCase` covers `.directAVPlayer`, `.directVLC`, `.transcodeHLS` and `.noPlayableSource`, the `playMethod` per branch, the `mp4`/`h264`/no-audio row (decision 39), the built stream URL carrying `ApiKey == session token` plus `deviceId` and `playSessionId`, and the `TranscodingUrl` passthrough verbatim.
- [x] `MixtapeDataTests` (`.repository`): `JellyfinPlaybackRepository.resolveVideo` against the captured `playback-info-avatar-direct`, `playback-info-f1-direct` and `playback-info-f1-transcode` fixtures, stubbed `URLProtocol`; plus the posted device-profile body and `reportStart` shared body.
- [x] `MixtapeServicesTests` (`.service`): `VideoPlaybackService` status transitions `.idle` -> `.preparing` -> `.playing` -> `.paused`, `.failed` on player and resolution failure, end-of-playback -> `.idle`, a `.directVLC` method with no controller -> `.failed(.noPlayableSource)`, and exactly one start report per `play` carrying the plan `playMethod`.
- [x] `MixtapeUseCaseTests` (`.useCase`): `ReportPlaybackStartUseCase` — the report reaches the repository, and a repository failure is swallowed.

Acceptance (server-observable, `http://localhost:8096`, via `./scripts/jf-probe.swift`; session matched by `Client == "mixtape"` and `DeviceName == "iPhone 17 Pro"`, not by the env file user id — 005 Drift Log):
- [x] AC6: played the Avatar `mp4`/h264 movie on the iPhone 17 Pro simulator; `/Sessions` showed this device with `NowPlayingItem: Avatar: Fire and Ash`, `PlayMethod: DirectPlay`, and **no `TranscodingInfo`**. **Manual, 2026-09-03.**
- [x] AC8: relaunched with `-mixtape-force-transcode`, played the F1 `mkv` movie; `/Sessions` showed `NowPlayingItem: F1` with **`TranscodingInfo` present** (`Container: ts`, `VideoCodec: h264`, `AudioCodec: aac`, `TranscodeReasons: [ContainerNotSupported, VideoCodecNotSupported, AudioCodecNotSupported]`), stable across seven consecutive polls of active playback, gone once the 48 s file finished buffering. `PlayState.PlayMethod` read `DirectPlay` throughout; AC8 is claimed on `TranscodingInfo` per the Section 6 row. **Manual, 2026-09-03; no automated test touched the server.**

## 6. Decision Log

**Write the row before you implement the decision, not after.** This is the whole mechanism. A decision log filled in at close is reconstructed from memory, and the rejected alternatives — the part the next slice's pre-flight actually needs — are exactly what memory loses first.

| Date | Decision | Alternatives rejected | Why |
|---|---|---|---|
| 2026-09-03 | S002 answered for AVPlayer: the `Authorization: MediaBrowser …` header **can** be delivered through public API, via `AVAssetResourceLoaderDelegate` on a custom-scheme `AVURLAsset` (206 and playback on an auth-required endpoint; `NSURLErrorDomain -1013` without it), and `ApiKey` in the query plays on a plain `AVURLAsset`. S002 also found `/Videos/{itemId}/stream` is anonymous on 10.11.11. **Decision 42: this slice's stream URL carries `ApiKey` in the query string** — a plain `AVURLAsset`, no delegate, no header; never the private `AVURLAssetHTTPHeaderFieldsKey`. Decision 33 is closed and decision 7 amended: no player carries the `Authorization` header on a stream URL. | Sending nothing, as Triage 5 first recorded — faithful to the server today but dependent on undocumented anonymity; the resource-loader delegate — proven, but intercepts every manifest and segment fetch on the HLS path for no gain over one query parameter | Decision 42, cited not re-argued; S002's Result and Evidence detail carry the exact runs |
| 2026-09-03 | `VideoPlaybackService` imports `MixtapeInfrastructure` to own its `VideoPlayerControlling`, over the edge decision 36 adds in slice 001 | Declaring the protocol in `MixtapeServices` and conforming in the app target | Cited from decision 36 — `makeView() -> AnyView` pins the protocol to a SwiftUI-importing module; the added edge is the shape without a retroactive-conformance warning |
| 2026-09-03 | `ReportPlaybackStartUseCase` and `reportStart` land here, not in 008 (decision 37, cited not re-argued) | Keeping all three reports in 008 and gating AC6/AC8 on `TranscodingInfo` alone | Measured: `/Sessions` carries no `NowPlayingItem`, `PlayMethod` or `TranscodingInfo` until `POST /Sessions/Playing` is sent, and `/Videos/ActiveEncodings` is 405; without the start report AC6's gate cannot fail and AC8's cannot pass |
| 2026-09-03 | DEBUG-only launch argument `-mixtape-force-transcode` makes `AppContainer` inject a restrictive `DeviceProfile` in place of the shipped one, so AC8 plays live against the existing F1 `mkv` | Leaving AC8 as a fixture-only unit test with no in-app demonstration; changing the shipped device profile itself to be restrictive | `SPEC-DECISIONS.md` decision 14 established that AC8 is a test-fixture problem, not a missing-media-file problem, and that the permissive profile the app actually ships must stay unchanged because AC6, AC7 and AC13f depend on it never transcoding the library's real files. A DEBUG-only launch argument demonstrates the transcode branch live, on the same simulator build used for AC6, without touching production behaviour |

| 2026-09-03 | `PlaybackRepositoryProtocol.resolveVideo` returns a Domain `VideoSourceResolution` (`playSessionID` + `[MediaSourceCandidate]`) | Returning the bare `[MediaSourceCandidate]` and fetching `PlaySessionId` separately; returning a `PlaybackPlan` | Decision 12 moved method selection to the use case but left `PlaySessionId` — which only the `PlaybackInfo` response carries — without a way home; one small value type carries both halves of that one response |
| 2026-09-03 | `MediaSourceCandidate.videoCodec` / `audioCodec` come from the first `Video` and first `Audio` entry in `MediaStreams`; `container` is `MediaSourceInfo.Container` verbatim | Deriving the container from the file path | The Avatar item reports `Container: "mov"` in `PlaybackInfo` although the library lists it as `mp4`; `mov` is in the native set so AC6 still resolves to `.directAVPlayer`, and reading the server's own word avoids a second source of truth |
| 2026-09-03 | `DeviceProfile` is a public `Encodable` struct in `MixtapeData` with `static let permissive` (the §8 profile) and `static let forceTranscode` (webm/vp9/opus only), injected into `JellyfinPlaybackRepository`; under `#if DEBUG`, `AppContainer` picks `forceTranscode` when `CommandLine.arguments` contains `-mixtape-force-transcode` | A Domain type; a repository-internal constant | It is a wire body, so it is a Data concern, and the composition root is the one place that already imports `MixtapeData` and can read launch arguments |
| 2026-09-03 | `VideoPlaybackService` takes a controller factory `(PlaybackMethod) -> (any VideoPlayerControlling)?` by constructor; `AppContainer` maps `.directAVPlayer` and `.transcodeHLS` to a new `AVPlayerController` and `.directVLC` to `nil`, which the service surfaces as `.failed(.noPlayableSource)` until 007 wires VLC | A `switch` on the method inside the service constructing `AVPlayerController` directly | Tests drive the service with a stub controller and never touch AVFoundation; 007 adds one line at the root instead of editing a tested service |
| 2026-09-03 | `VideoPlaybackService.play(item:startAt:)` takes the start position; `MovieDetailScreen`'s Play passes `.zero` and Resume passes the item's server position | §6's `play(item:)` deciding the position itself from `item.playback.position` | Two buttons mean two intents; a method that always resumes cannot play from the start |
| 2026-09-03 | Report failures are logged on `network` inside `JellyfinPlaybackRepository` (which can see `AppLogger`) and rethrown; `ReportPlaybackStartUseCase` catches and swallows so the caller never sees them | Logging in the use case; logging in the service | `MixtapeUseCase` may not import `MixtapeInfrastructure`, and §8 says report failures are logged and swallowed — the repository is the lowest layer that can log and the use case the one that decides not to throw |
| 2026-09-03 | `VideoPlayerScreen` is a `fullScreenCover` driven by `videoPlaybackService.status != .idle`; dismissing it calls `stop()`, and `stop()` tears the controller down and returns the status to `.idle` | A `NavigationLink` push; a sheet | §9 names a full-screen cover, and binding it to the service's status means the screen appears wherever `play` is called from |
| 2026-09-03 | `PlaybackInfo` fixtures are captured from the dev server for Avatar (permissive), F1 (permissive) and F1 (restrictive); the `ApiKey` value inside the transcode fixture's `TranscodingUrl` is redacted to `REDACTED-API-KEY` and the fixture says so in a `_source` key | Committing the capture verbatim | Decisions 45 and 46: a live token never reaches a commit; the redaction keeps the URL shape the passthrough test needs |
| 2026-09-03 | AC6 and AC8 read `./scripts/jf-probe.swift /Sessions` and pick the session by `Client == "mixtape"` and `DeviceName == "iPhone 17 Pro"`, never by `JELLYFIN_USER_ID` | Filtering by the env file's user id | 005's Drift Log row: that id belongs to a different account from the one the app signs in as |

| 2026-09-03 | AC8 is claimed on **`TranscodingInfo` present with `TranscodeReasons`** in `/Sessions`, not on `PlayState.PlayMethod`. Measured: while the forced F1 transcode is actively playing, the session carries `TranscodingInfo` (`Container: ts`, `VideoCodec: h264`, `AudioCodec: aac`, `IsVideoDirect: false`, `TranscodeReasons: [ContainerNotSupported, VideoCodecNotSupported, AudioCodecNotSupported]`) stable across seven consecutive 1.5 s polls, yet `PlayState.PlayMethod` reads `DirectPlay` — the same value the Avatar direct-play case reads. The start report we send carries `PlayMethod: Transcode` (verified: the report path logs only on failure and logged nothing), but Jellyfin 10.11.11 does not surface it in `PlayState.PlayMethod`. | Claiming AC8 on `PlayState.PlayMethod == "Transcode"` as the slice first worded it | The server contradicts the wording, as decisions 6 and 32 found the docs contradicted by the live server. `TranscodingInfo` is Jellyfin own dashboard transcode indicator and is unambiguous; `PlayState.PlayMethod` is not a reliable transcode signal on this version. AC8 substance — plays via `.transcodeHLS` and the dashboard shows a transcode — is fully met. In the Drift Log for 008. |

Decisions already settled in `SPEC-DECISIONS.md` and applied without re-argument here: decision 7 as amended by decision 42 (`ApiKey` on client-built stream URLs) and its `TranscodingUrl` carve-out (verbatim passthrough), decision 9 (unmapped 4xx → `.transport`, inherited from slice 003's client), decision 11 (`PlaybackPlan.playMethod`), decision 12 (repository returns sources, use case selects method), decision 18 (`AVPlayerController` presents via `VideoPlayer`), decision 26's `deviceId` addition to the stream URL, and decision 47 (server-observable checks go through `scripts/jf-probe.swift`).

## 7. Sub-Slices

Not split — delivered as a single slice.

## 8. Testing Strategy

- **Unit / Integration / UI:** unit tests only. No XCUITest, no CI gate — both are deferred per decision 4. Repositories are tested against a stubbed `URLProtocol`; nothing in this slice's test suite touches the live Jellyfin server. `http://localhost:8096` is used only for the manual acceptance checks (AC6, AC8) via `./scripts/jf-probe.swift` (decision 47), the Jellyfin dashboard and the simulator, never from an automated test.
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

- [x] Acceptance criteria met (AC8 on `TranscodingInfo`; the `PlayState.PlayMethod` sub-clause corrected by a Section 6 decision row against the live server)
- [x] Tests passing, in a target that exists
- [x] Every `covers:` requirement satisfied, or forked with a decision row
- [x] Decision log written as you went, not reconstructed
- [x] Pre-flight completed and drift resolved
- [x] Master checklist row current
- [x] `next_slice` `depends_on` reflects what actually shipped, not what was planned
- [x] Both link directions checked: this page `next_slice` and that page `previous_slice`

---
slice_id: "007"
title: "Video: VLC direct"
priority: P0
complexity: M
ladder: none
depends_on:
  - { id: "006", type: hard, note: "as shipped: VideoPlayerControlling lives in MixtapeInfrastructure/Video with load(url:startAt:headers:), play, pause, seek(to:), teardown, makeView() -> AnyView and the three callbacks; VideoPlaybackService takes makeController: (PlaybackMethod) -> (any VideoPlayerControlling)? and AppContainer maps .directVLC to nil today, so 007 changes one line at the root; ResolveVideoPlaybackUseCase already resolves mkv to .directVLC and builds the same ApiKey stream URL; DeviceProfile.permissive/.forceTranscode live in MixtapeData" }
  - { id: "S001", type: hard, note: "proved VLCKit resolves as the SPM package tylerjonesio/vlckit-spm exact 3.6.0, product VLCKitSPM, modules MobileVLCKit / TVVLCKit, under Swift 6 mode with MainActor default isolation; decision 44 records it and the vendored fallback was not taken" }
  - { id: "S002", type: hard, note: "measured that VLC plays a URL carrying ApiKey in the query and that VLC's own HTTP access has no header option; decision 42 chose ApiKey on that evidence and closed decision 33, so no per-player mechanism remains" }
previous_slice: "006"
next_slice: "008"
parent_slice: none
covers: ["§1.10", "§12.7"]
created: 2026-09-03
---

# 007 — Video: VLC direct

← [previous](006-video-avplayer-and-hls.md) · [Master Checklist](MASTER-CHECKLIST.md) · [next](008-playback-reporting-and-resume.md) →

> **Status, owner and blockers live in the master checklist, not here.** Dependencies live in this page's front matter and nowhere else. Each fact has one home; if you find yourself writing it twice, one of the two copies is going to be wrong in a fortnight.

## 1. Objective

Wire libVLC into the app so a file AVPlayer refuses plays in-app anyway, with no server-side transcode. This is the third and final `PlaybackMethod` branch — slice 006 delivered `.directAVPlayer` and `.transcodeHLS`; this slice delivers `.directVLC`. Observable on its own: launch the app, open the F1 item (`mkv`/h264/aac), tap Play, and the Jellyfin dashboard's session list shows `DirectPlay` with no `TranscodingInfo`.

## 2. Business Value & Priority

P0. Engineering doc capability 10 names three playback methods and acceptance criterion 7 exercises this one specifically; without it, every container AVPlayer does not play natively — mkv, webm, vp9, hevc/dts and more — falls through to `.transcodeHLS` regardless of whether the device could have played it directly, defeating the whole point of `isAVPlayerNative` steering a codec-capable file away from the server's transcoder. VLCKit is the only third-party dependency this project takes, and it exists specifically to close this gap.

## 3. Scope

**In scope:**
- The VLCKit dependency added to `MixtapeKit/Package.swift`'s `MixtapeInfrastructure` target, in the shape S001 recorded and decision 44 fixes: `.package(url: "https://github.com/tylerjonesio/vlckit-spm.git", exact: "3.6.0")` and `.product(name: "VLCKitSPM", package: "vlckit-spm")`. The `exact` pin is load-bearing — VideoLAN publishes no SPM manifest, so this is a community distribution. No vendored `binaryTarget(path:)` — S001 proved the SPM route on both simulators, so the fallback was not taken. The binary artefact is 778.7 MB per clean resolve; no consequence for this run, but cache the SPM artefact directory when CI returns.
- `VLCPlayerController`: `@MainActor final class`, conforming to `VideoPlayerControlling` (§7), and the **only** file in the codebase that imports libVLC — as `import MobileVLCKit` under `#if os(iOS)` and `import TVVLCKit` under `#if os(tvOS)`, because those are the module names the package ships (decision 44). A bare `import VLCKit` fails with `Unable to resolve module dependency: 'VLCKit'`; `CLAUDE.md` and engineering doc §7 still say "imports VLCKit" and are wrong on the name, right on the substance.
- The `VLCLogging` conformer that receives libVLC's log output is declared `nonisolated` (decision 44). Decision 15's `.defaultIsolation(MainActor.self)` would otherwise make it `MainActor`, and VLC's logging thread then traps with `SIGTRAP` (`@objc … level.getter`, `VLCLibrary.m:372`). This is the one place in the slice where the project-wide default is explicitly overridden, and it follows `CLAUDE.md`'s "`nonisolated` fixes it — never convert the actor" rule.
- `VLCPlayerController.makeView()` returning a `UIViewRepresentable` wrapping `VLCVideoView`, with a custom overlay (play/pause, scrub, close) — VLC gets no native SwiftUI transport, so this overlay is hand-built where `AVPlayerController` gets one free from `VideoPlayer`.
- The `.directVLC` branch wired into `VideoPlaybackService`: when `plan.method == .directVLC`, the service owns a `VLCPlayerController` instead of an `AVPlayerController`, behind the same `VideoPlayerControlling` interface the service already programs against.
- Auth on the VLC-bound stream URL: **`ApiKey` in the query string, per decision 42** — the same URL slice 006 builds, token included, handed to `VLCMedia(url:)` with no media options. `/Videos/{itemId}/stream` happens to be anonymous on Jellyfin 10.11.11, but the app does not build on that. No `Authorization` header, no `:http-token` (it sends `Bearer`, which Jellyfin 401s), and never the `avio://` MRL plus `:avio-options` header route S002 proved and decision 42 rejected as fragile.

**Out of scope** (name the slice it's deferred to):
- tvOS's Siri Remote-specific overlay behaviour (play/pause and swipe gestures mapped onto this same `VLCPlayerController`) — deferred to slice 011, which owns all tvOS presentation chrome.
- Any change to `ResolveVideoPlaybackUseCase`, the `PlaybackInfo` call, or the device profile — all delivered in slice 006 and untouched here.
- Progress and stopped reports, and resume — slice 008. The start report already fires from `VideoPlaybackService.play` (006, decision 37) and is what makes AC7's `/Sessions` check meaningful.
- A second, VLC-specific `PlaybackMethod` case or a second stream-URL-building path — none exists; `.directVLC` reuses the identical `/Videos/{itemId}/stream?static=true…&ApiKey={token}` URL slice 006 already builds. Decision 42 gives both players the same mechanism, so nothing differs per player.

**Plan requirements covered:**
- `§1.10` (the VLC third of "direct play (AVPlayer), direct play (VLCKit), or HLS transcode") — satisfied by `VLCPlayerController` and the `.directVLC` branch in `VideoPlaybackService`, demonstrated by acceptance criterion 7.
- `§12.7` — satisfied by AC7 itself: the F1 mkv plays via `.directVLC` and the Jellyfin dashboard shows no transcode session.

No fork against the plan is taken in this slice; every departure from the engineering doc's literal text (custom overlay instead of native transport, `ApiKey` instead of the header, `MobileVLCKit`/`TVVLCKit` instead of `VLCKit`) is already covered by a `SPEC-DECISIONS.md` decision cited in Section 6.

## 4. Pre-Flight Validation

Complete **before the first line of code**, not at close.

**006 — Video: AVPlayer direct and HLS**
- [ ] Opened it. Its decision log still says what this slice assumed: `VideoPlayerControlling` lives in `MixtapeInfrastructure` with `load(url:startAt:headers:)`, `play()`, `pause()`, `seek(to:)`, `teardown()`, `makeView() -> AnyView`; `VideoPlaybackService` selects its controller from `plan.method`; `ResolveVideoPlaybackUseCase` already resolves F1 to `.directVLC`; the `MixtapeServices` → `MixtapeInfrastructure` edge from decision 36 is in place.
- [ ] Not a spike — n/a.
- [ ] Its state matches what this slice assumed when drafted, not when it was written.
- [ ] Architecture standards doc re-read; nothing changed underneath this slice.

**S001 — Does VLCKit resolve as an SPM binary dependency with iOS 26 and tvOS 26 simulator slices and link into `MixtapeInfrastructure` under Swift 6 mode with MainActor default isolation?**
- [ ] Opened it. Its decision log still says what this slice assumed.
- [ ] It's answered, and the answer — not the hoped-for answer — is what this slice is built on. Note whether the fallback (vendored `binaryTarget(path:)`) was taken.
- [ ] If S001 recorded no tvOS slice for VLCKit at all, that is a decision-level change (tvOS `.directVLC` has no player) that S001 itself sends back to the human rather than resolving — confirm it was actually resolved, one way or the other, before building on it here.
- [ ] Its state matches what this slice assumed when drafted, not when it was written.
- [ ] Architecture standards doc re-read; nothing changed underneath this slice.

**S002 — Can `AVPlayerController` and `VLCPlayerController` each send `Authorization: MediaBrowser …` on a stream request using public API only?**
- [ ] Opened it. Its Result still records what this slice is built on: VLC plays a URL carrying `ApiKey` in the query; VLC's own HTTP access has no header option; the `avio://` route works but swaps HTTP stacks.
- [ ] It's answered for the VLC player, and decision 42 — `ApiKey` in the query string for both players, header route rejected — is still the standing decision on that evidence.
- [ ] Its state matches what this slice assumed when drafted: decision 33 is closed, so there is no per-player fallback left to note.
- [ ] Architecture standards doc re-read; nothing changed underneath this slice.

**Drift found:** none.

## 5. Acceptance Criteria

- [ ] `xcodebuild build` passes for both the `iOS` and `tvOS` schemes with the VLCKit dependency in place.
- [ ] `xcodebuild test -skip-testing:iOSUITests` / `-skip-testing:tvOSUITests` is green for both schemes.
- [ ] `./scripts/check-layer-imports.sh` exits 0, and a manual grep confirms `VLCPlayerController.swift` is the only file anywhere under `Sources/` that imports `MobileVLCKit` or `TVVLCKit` (no file imports a bare `VLCKit`; that module exists only in the macOS slice).
- [ ] `swiftformat --lint .` is clean.
- [ ] `MixtapeServicesTests`, `.service` tag: a `PlaybackPlan` with `method == .directVLC` causes `VideoPlaybackService` to select the VLC controller rather than the AVPlayer one, proven against a stub `VideoPlayerControlling` — not the real `VLCVideoView` — and the start report still fires once with `PlayMethod: DirectPlay`.
- [ ] AC7: on the simulator, sign in, open F1 (`mkv`/h264/aac, 48.4 s), tap Play. It plays in-app through `VLCVideoView` with working play/pause, scrub and close on the custom overlay. `./scripts/jf-probe.swift /Sessions` against `http://localhost:8096` (decision 47) shows this device's session with `NowPlayingItem` set, `PlayMethod: DirectPlay`, and no `TranscodingInfo` — the start report from 006 (decision 37) makes the session visible, so an absent `NowPlayingItem` is a failure, not a pass. The criterion's literal `hevc/dts` wording is satisfied by F1's `mkv` container instead, per decision 14: `mkv` routes to VLC by container regardless of codec, and no `hevc/dts` file exists in the library.
- [ ] If S001's answer left no working tvOS slice for VLCKit, the fallback S001 recorded is what this criterion and the tvOS build gate actually run against, and that is noted in Section 6 rather than silently assumed away.

## 6. Decision Log

**Write the row before you implement the decision, not after.** This is the whole mechanism. A decision log filled in at close is reconstructed from memory, and the rejected alternatives — the part the next slice's pre-flight actually needs — are exactly what memory loses first.

| Date | Decision | Alternatives rejected | Why |
|---|---|---|---|
| 2026-09-03 | S002 answered for VLC: VLC's own HTTP access has no header option (`:http-token` sends `Authorization: Bearer`, Jellyfin 401s it), but the header **can** be carried by routing through libavformat: MRL `avio://http://…` plus `media.addOption(":avio-options={headers='Authorization: MediaBrowser …'}")` played an auth-required endpoint, and the same MRL without it failed. `ApiKey` in the query also plays. S002 also found `/Videos/{itemId}/stream` is anonymous on 10.11.11. **Decision 42: the VLC-bound stream URL carries `ApiKey` in the query string — the same URL as 006, plain `VLCMedia(url:)`, no options.** Decision 33 is closed; no player carries the header. | Sending nothing, as Triage 5 first recorded — depends on undocumented anonymity; the `avio://` route — proven, but swaps VLC's HTTP stack for FFmpeg's and rides the token in a fragile option string; `:http-token` — sends `Bearer`, 401 | Decision 42, cited not re-argued; S002's Result and Evidence detail carry the exact runs, the libvlc option inventory, and the avio route's caveats (config-chain quoting, FFmpeg HTTP behaviour, `avio://` documented in libvlc source and the VLC wiki, not VLCKit headers) |
| 2026-09-03 | The `VLCLogging` conformer is `nonisolated` (decision 44, cited not re-argued) | Leaving it on the `MainActor` default; converting the surrounding type off `MainActor` | S002 hit the trap: VLC's logging thread calls the conformer off-main and `SIGTRAP`s under MainActor isolation; `nonisolated` on the one conformer is the smallest override and matches `CLAUDE.md`'s rule |
| 2026-09-03 | AC7 is demonstrated against the F1 mkv (h264/aac) rather than a genuine hevc/dts source. See `SPEC-DECISIONS.md` decision 14. | Sourcing or transcoding a real `mkv/hevc/dts` file into the library before this slice runs. | Decision 14 records that `mkv` routes to `.directVLC` by container alone, independent of codec, and that F1 is the file the library actually has; it is also the only video item long enough (48.4 s) to double as slice 008's watch-30-s fixture. |
| 2026-09-03 | `VLCPlayerController` presents its own hand-built overlay (play/pause, scrub, close) rather than a transport shared with `AVPlayerController`. See `SPEC-DECISIONS.md` decision 18. | One shared representable and overlay for both players, built against a raw `AVPlayerLayer` on the AVPlayer side to make the two symmetric. | Decision 18 keeps `AVPlayerController` on the native `VideoPlayer` transport (Picture in Picture and AirPlay free), and accepts that VLC — which has no equivalent SwiftUI transport — needs a custom overlay instead; `VideoPlayerControlling` still means Presentation only ever sees `AnyView`, so the asymmetry stops at the infrastructure layer. |
| 2026-09-03 | The VLCKit dependency edge is added to `Package.swift` in this slice, not in slice 001. | Adding a placeholder or speculative VLCKit dependency in slice 001 ahead of S001's result, so the manifest would not need editing again here. | Slice 001's own decision log defers this edge to 007 pending S001, so slice 001 gates green with zero third-party dependencies; 007 is the first slice that actually needs VLCKit to compile, so it is the first slice that adds it. |
| 2026-09-03 | VLCKit arrives as the community SPM package `tylerjonesio/vlckit-spm` pinned `exact: "3.6.0"`, product `VLCKitSPM`, and `VLCPlayerController.swift` imports `MobileVLCKit` / `TVVLCKit` behind `#if os(iOS)` / `#if os(tvOS)`. See S001's Result and decision 44. | A local `binaryTarget(path:)` vendoring the 778.7 MB xcframework (S001's pre-authorised fallback); building VLCKit from VideoLAN's source repo; the 4.0 alpha line. | S001 proved the SPM route resolves and links a real executable on both the iOS 26.5 and tvOS 26.5 simulators under decision 15's settings with zero warnings, so the fallback buys nothing and would put a 778.7 MB binary in the repo. VideoLAN publishes no `Package.swift` (checked `code.videolan.org/videolan/VLCKit` at tag `4.0.0a21`), so the community package is the only SPM coordinate. Pinned `exact` because the package's own platform floors (iOS 11, tvOS 11) and upstream re-tags give a range nothing to protect. |

## 7. Sub-Slices

Not split — delivered as a single slice.

## 8. Testing Strategy

- **Unit / Integration / UI:** unit tests only, Swift Testing, tagged `.service`. No `.repository` test in this slice — `resolveVideo` and the `PlaybackInfo` call are already covered in slice 006's tests and are untouched here. No XCUITest and no CI gate (decision 4) — the F1 playback check is a manual simulator run plus `./scripts/jf-probe.swift /Sessions` (decision 47).
- **Test targets required:** `MixtapeServicesTests`, already created in slice 001. This slice adds the `.directVLC` controller-selection case to `VideoPlaybackService`'s existing test suite rather than creating a new target.

## 9. Keeping this document true

This slice is done when the page describes what was actually built — not when the code works. The discipline is **ordering**: the write happens *before* the thing it describes, so it sits on the critical path instead of after it, where it gets skipped.

| Before you… | Write this first |
|---|---|
| implement a decision | the Section 6 row, including what you rejected |
| start work | flip status in the master checklist |
| stop on a blocker | the Active Blockers row |
| build on a spike | that spike's Result section |
| widen scope | Section 3, and `depends_on` on any slice that's now affected |

And in the same commit as the code, not a follow-up: **commit this file alongside it**, with the slice id in the commit subject (`007: add VLC direct playback`).

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

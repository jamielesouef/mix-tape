---
slice_id: "007"
title: "Video: VLC direct"
priority: P0
complexity: M
ladder: none
depends_on:
  - { id: "006", type: hard, note: "conforms to the VideoPlayerControlling protocol 006 defines and wires into the VideoPlaybackService 006 builds; reuses 006's stream URL" }
  - { id: "S001", type: hard, note: "VLCKit must resolve as an SPM dependency (or vendored xcframework fallback) and link into MixtapeInfrastructure under Swift 6 mode with MainActor default isolation before this slice can add the dependency edge" }
  - { id: "S002", type: hard, note: "needs the per-player answer on whether VLCPlayerController can carry the Authorization header on a stream request, or must fall back to ApiKey in the query string" }
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
- The VLCKit dependency added to `MixtapeKit/Package.swift`'s `MixtapeInfrastructure` target, in the shape S001's spike result recorded — either the VLCKit SPM package, or a local `binaryTarget(path:)` vendoring the xcframework if S001 took that fallback.
- `VLCPlayerController`: `@MainActor final class`, conforming to `VideoPlayerControlling` (§7), and the **only** file in the codebase that imports `VLCKit`.
- `VLCPlayerController.makeView()` returning a `UIViewRepresentable` wrapping `VLCVideoView`, with a custom overlay (play/pause, scrub, close) — VLC gets no native SwiftUI transport, so this overlay is hand-built where `AVPlayerController` gets one free from `VideoPlayer`.
- The `.directVLC` branch wired into `VideoPlaybackService`: when `plan.method == .directVLC`, the service owns a `VLCPlayerController` instead of an `AVPlayerController`, behind the same `VideoPlayerControlling` interface the service already programs against.
- Auth on the VLC-bound stream URL, following S002's recorded per-player answer: the `Authorization: MediaBrowser …` header if S002 proved libVLC can carry it through documented `VLCMedia` options, otherwise `ApiKey` in the query string of VLC-bound URLs only (decision 33).

**Out of scope** (name the slice it's deferred to):
- tvOS's Siri Remote-specific overlay behaviour (play/pause and swipe gestures mapped onto this same `VLCPlayerController`) — deferred to slice 011, which owns all tvOS presentation chrome.
- Any change to `ResolveVideoPlaybackUseCase`, the `PlaybackInfo` call, or the device profile — all delivered in slice 006 and untouched here.
- Progress and stopped reports, and resume — slice 008. The start report already fires from `VideoPlaybackService.play` (006, decision 37) and is what makes AC7's `/Sessions` check meaningful.
- A second, VLC-specific `PlaybackMethod` case or a second stream-URL-building path — none exists; `.directVLC` reuses the same `/Videos/{itemId}/stream?static=true…` URL slice 006 already builds, differing only in which auth mechanism decision 33 assigns it.

**Plan requirements covered:**
- `§1.10` (the VLC third of "direct play (AVPlayer), direct play (VLCKit), or HLS transcode") — satisfied by `VLCPlayerController` and the `.directVLC` branch in `VideoPlaybackService`, demonstrated by acceptance criterion 7.
- `§12.7` — satisfied by AC7 itself: the F1 mkv plays via `.directVLC` and the Jellyfin dashboard shows no transcode session.

No fork against the plan is taken in this slice; every departure from the engineering doc's literal text (custom overlay instead of native transport, per-player auth fallback) is already covered by a `SPEC-DECISIONS.md` decision cited in Section 6.

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
- [ ] Opened it. Its decision log still says what this slice assumed.
- [ ] It's answered specifically for the VLC player (S002 answers per player, not jointly) — the answer, not the hoped-for answer, decides whether `VLCPlayerController` sends the header or falls back to `ApiKey` in the query string.
- [ ] If the fallback was taken for VLC, that is noted here and the reason carried into Section 6 rather than re-litigated.
- [ ] Its state matches what this slice assumed when drafted, not when it was written.
- [ ] Architecture standards doc re-read; nothing changed underneath this slice.

**Drift found:** none.

## 5. Acceptance Criteria

- [ ] `xcodebuild build` passes for both the `iOS` and `tvOS` schemes with the VLCKit dependency in place.
- [ ] `xcodebuild test -skip-testing:iOSUITests` / `-skip-testing:tvOSUITests` is green for both schemes.
- [ ] `./scripts/check-layer-imports.sh` exits 0, and a manual grep confirms `VLCPlayerController.swift` is the only file anywhere under `Sources/` that imports `VLCKit`.
- [ ] `swiftformat --lint .` is clean.
- [ ] `MixtapeServicesTests`, `.service` tag: a `PlaybackPlan` with `method == .directVLC` causes `VideoPlaybackService` to select the VLC controller rather than the AVPlayer one, proven against a stub `VideoPlayerControlling` — not the real `VLCVideoView` — and the start report still fires once with `PlayMethod: DirectPlay`.
- [ ] AC7: on the simulator, sign in, open F1 (`mkv`/h264/aac, 48.4 s), tap Play. It plays in-app through `VLCVideoView` with working play/pause, scrub and close on the custom overlay. `curl` against `GET /Sessions` on `http://localhost:8096` shows this device's session with `NowPlayingItem` set, `PlayMethod: DirectPlay`, and no `TranscodingInfo` — the start report from 006 (decision 37) makes the session visible, so an absent `NowPlayingItem` is a failure, not a pass. The criterion's literal `hevc/dts` wording is satisfied by F1's `mkv` container instead, per decision 14: `mkv` routes to VLC by container regardless of codec, and no `hevc/dts` file exists in the library.
- [ ] If S001's answer left no working tvOS slice for VLCKit, the fallback S001 recorded is what this criterion and the tvOS build gate actually run against, and that is noted in Section 6 rather than silently assumed away.

## 6. Decision Log

**Write the row before you implement the decision, not after.** This is the whole mechanism. A decision log filled in at close is reconstructed from memory, and the rejected alternatives — the part the next slice's pre-flight actually needs — are exactly what memory loses first.

| Date | Decision | Alternatives rejected | Why |
|---|---|---|---|
| 2026-09-03 | Auth on the VLC-bound stream URL follows S002's recorded per-player answer: the `MediaBrowser` header if S002 proved libVLC can carry it via documented `VLCMedia` options, otherwise `ApiKey` in the query string of VLC-bound URLs only. See `SPEC-DECISIONS.md` decision 33. | Reaching for an undocumented libVLC header-injection option to preserve one-mechanism auth (decision 7) regardless of what S002 found. | Decision 33 pre-authorises the per-player `ApiKey` fallback precisely so this slice does not stall on a spike result that came back negative; shipping an undocumented option to avoid the fallback is the outcome decision 33 exists to rule out. |
| 2026-09-03 | AC7 is demonstrated against the F1 mkv (h264/aac) rather than a genuine hevc/dts source. See `SPEC-DECISIONS.md` decision 14. | Sourcing or transcoding a real `mkv/hevc/dts` file into the library before this slice runs. | Decision 14 records that `mkv` routes to `.directVLC` by container alone, independent of codec, and that F1 is the file the library actually has; it is also the only video item long enough (48.4 s) to double as slice 008's watch-30-s fixture. |
| 2026-09-03 | `VLCPlayerController` presents its own hand-built overlay (play/pause, scrub, close) rather than a transport shared with `AVPlayerController`. See `SPEC-DECISIONS.md` decision 18. | One shared representable and overlay for both players, built against a raw `AVPlayerLayer` on the AVPlayer side to make the two symmetric. | Decision 18 keeps `AVPlayerController` on the native `VideoPlayer` transport (Picture in Picture and AirPlay free), and accepts that VLC — which has no equivalent SwiftUI transport — needs a custom overlay instead; `VideoPlayerControlling` still means Presentation only ever sees `AnyView`, so the asymmetry stops at the infrastructure layer. |
| 2026-09-03 | The VLCKit dependency edge is added to `Package.swift` in this slice, not in slice 001. | Adding a placeholder or speculative VLCKit dependency in slice 001 ahead of S001's result, so the manifest would not need editing again here. | Slice 001's own decision log defers this edge to 007 pending S001, so slice 001 gates green with zero third-party dependencies; 007 is the first slice that actually needs VLCKit to compile, so it is the first slice that adds it. |

## 7. Sub-Slices

Not split — delivered as a single slice.

## 8. Testing Strategy

- **Unit / Integration / UI:** unit tests only, Swift Testing, tagged `.service`. No `.repository` test in this slice — `resolveVideo` and the `PlaybackInfo` call are already covered in slice 006's tests and are untouched here. No XCUITest and no CI gate (decision 4) — the F1 playback check is a manual simulator run plus a `curl` against `/Sessions`.
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

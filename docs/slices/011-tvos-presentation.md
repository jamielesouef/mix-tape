---
slice_id: "011"
title: tvOS Presentation
priority: P1
complexity: L
ladder: none
depends_on:
  - { id: "005", type: hard, note: "LibraryService, SeriesService, ImageService and the shared library/detail screens this slice gives tvOS chrome to" }
  - { id: "006", type: hard, note: "ResolveVideoPlaybackUseCase, AVPlayerController and VideoPlaybackService — the .directAVPlayer and .transcodeHLS paths replayed here" }
  - { id: "007", type: hard, note: "VLCPlayerController and the .directVLC branch — the path this slice gives a Siri Remote overlay" }
  - { id: "008", type: hard, note: "playback reporting — AC6/AC7 are read off GET /Sessions, which only reflects reality once reporting is wired" }
  - { id: "009", type: hard, note: "AudioPlayerController and MusicPlayerService — the album queue this slice drives from the Siri Remote" }
  - { id: "010", type: soft, note: "AlbumGrid becomes tvOS-only there; this slice reuses it unchanged rather than building a new tvOS album grid type" }
previous_slice: "010"
next_slice: "012"
parent_slice: none
covers: ["§1.5", "§1.6", "§1.8", "§1.10", "§1.12"]
created: 2026-09-03
---

# 011 — tvOS Presentation

← [previous](010-wallet.md) · [Master Checklist](MASTER-CHECKLIST.md) · [next](012-accessibility-and-reduce-transparency.md) →

> **Status, owner and blockers live in the master checklist, not here.** Dependencies live in this page's front matter and nowhere else. Each fact has one home; if you find yourself writing it twice, one of the two copies is going to be wrong in a fortnight.

## 1. Objective

tvOS gets its own focus-driven chrome for every signed-in surface — library shelves, detail screens, the tab structure — and every video and music capability already proven on iOS is demonstrable, unmodified in its service layer, on the Apple TV simulator.

Observable value on its own: sit on the Apple TV, sign in (already true from slice 004), and browse, watch and listen without touching an iPhone or the wallet.

## 2. Business Value & Priority

Slices 004 through 009 built the services, use cases and repositories once, shared across both platforms, but the presentation those slices shipped is iOS chrome — a tab bar, poster grids, a full-screen player sheet, a mini player. None of that reads on a ten-foot interface, and tvOS has been building against the shared layers only because `check-layer-imports.sh` and the `tvOS` scheme's build gate kept it compiling, not because it was usable.

This is P1, not P0: it does not gate the video and music slices (004–009 are demonstrable on iOS alone), but it is what makes tvOS a real second platform rather than a compile target. It is not a rung on a version ladder — there is no deferred tvOS-v2 this sets a seam for.

## 3. Scope

**In scope:**
- `RootTabScreen` (tvOS): a top `TabView` with five tabs — Home, Movies, Shows, Music, Settings — per decision 26. Same type name as the iOS `RootTabScreen` from slice 005; a second file, `#if os(tvOS)`, no mini player slot.
- `MovieLibraryShelf`: the tvOS counterpart to `MovieLibraryGrid` (005) — a focus-driven `LazyVGrid` shelf inside a `ScrollView`, same `/Items` call and `LibraryService` paging, no layout code shared with the iOS grid file.
- `SeriesLibraryShelf`: mirrors `MovieLibraryShelf` exactly as `SeriesLibraryGrid` mirrors `MovieLibraryGrid` on iOS (decision 26) — same generic `/Items` call, same shelf layout rules.
- The music library's shelf: `AlbumGrid`, built generically in 005 and scoped tvOS-only by slice 010, is reused as-is. It already renders as a `LazyVGrid` and already only needs to work under tvOS focus navigation after 010 lands — no new type, no rename.
- `MovieDetailScreen` (tvOS): full-bleed backdrop image with the metadata block (title, year, runtime, overview, Play/Resume) anchored bottom-left, per engineering doc §9's tvOS screen table. Same type name as the iOS `MovieDetailScreen` from 005; a second file, `#if os(tvOS)`.
- `VideoPlayerScreen` (tvOS): for the `.directAVPlayer` and `.transcodeHLS` paths, the AVKit `VideoPlayer` representable from `AVPlayerController.makeView()` (decision 18) already supplies tvOS's system transport controls — no new code, confirmed by AC6 and AC7 replayed here. For the `.directVLC` path, 007's custom overlay (play/pause, scrub, close) was built touch-first and does not read on a Siri Remote; this slice adds its tvOS counterpart, driven by the remote's Play/Pause button for transport and swipe gestures for scrub, per engineering doc §9's tvOS row. `VideoPlayerScreen` itself keeps one type name across platforms; only the VLC overlay it hosts gets a second, tvOS-specific file.
- No mini player, no wallet anywhere on tvOS. Absent, not disabled — per §1.1, the wallet metaphor is iOS-only and tvOS keeps a conventional grid.
- Accessibility identifier enums for every new tvOS-only view, one enum per file (decision 17), even though XCUITest itself is deferred (decision 4).
- Every file this slice adds that diverges from its iOS counterpart is a second file, `#if os(iOS)` / `#if os(tvOS)`, named for what it is — never one file branching inside a view body.

**Out of scope** (name the slice it's deferred to):
- Sign-in and Quick Connect chrome on tvOS — already built and AC3 already claimed in slice 004; not reopened here.
- `SeriesDetailScreen`, `EpisodeRow`, `NowPlayingScreen`, `SettingsScreen` — built generically in 005 and 009, already compile and behave correctly on the `tvOS` scheme with no layout divergence called for in engineering doc §9's tvOS table. Left untouched.
- The Wallet, the mini player, and any return-to-sleeve behaviour — never built on tvOS, per §1.1. Not a deferral to a later slice; a deliberate, permanent absence.
- Accessibility labels, Dynamic Type audit, Reduce Transparency and Reduce Motion passes — deferred to slice 012.
- XCUITest — deferred this round (decision 4).
- Series → season → episode ordering acceptance (AC11) — the library holds 0 series and 0 episodes (decision 14); unverifiable, not claimed here or anywhere yet.
- AC13f (FLAC album, no transcode) — unverifiable until the FLAC album from decision 35 exists; not claimed here. The album played on tvOS to demonstrate §1.12 is one of the existing 46 `m4a`/`alac` tracks.

**Plan requirements covered:**
- `§1.5` (list the user's libraries) — `RootTabScreen`'s Movies/Shows/Music tabs and `HomeScreen` all read from `LibraryService`, unchanged from 005, now inside tvOS chrome.
- `§1.6` (browse a movie library; movie detail screen) — `MovieLibraryShelf` plus the tvOS `MovieDetailScreen`.
- `§1.8` (browse a music library → albums → tracks) — `AlbumGrid` shelf plus the shared `AlbumDetailScreen` from 005/009.
- `§1.10` (direct AVPlayer, direct VLC, HLS transcode) — replayed on tvOS: AC6 and AC7 are demonstrated on the Apple TV simulator, read off `GET /Sessions`.
- `§1.12` (album queue, next/prev, lock-screen/remote controls) — demonstrated on tvOS as an album playing through with the Siri Remote's next/previous, via the same `MusicPlayerService` and `MPRemoteCommandCenter` wiring from 009.

Each of these rows is a **tvOS demonstration** of a capability already covered end to end by an earlier slice's iOS acceptance criteria — this slice adds no new service, use case or domain behaviour, only tvOS presentation and, for VLC, a tvOS-specific overlay.

## 4. Pre-Flight Validation

Complete **before the first line of code**, not at close.

- [ ] **005** opened. `LibraryService`, `SeriesService`, `ImageService`, `MovieLibraryGrid`/`SeriesLibraryGrid`, `MovieDetailScreen` and `RootTabScreen` exist and build on the `tvOS` scheme as shared code. Its decision log still matches — no change to the library repository or its mappers since it landed.
- [ ] **006** opened. `ResolveVideoPlaybackUseCase`, `AVPlayerController`, `VideoPlaybackService` and `VideoPlayerScreen` exist; the `.directAVPlayer` and `.transcodeHLS` branches are proven on iOS via AC6/AC8. Confirm `AVPlayerController.makeView()` still returns the AVKit `VideoPlayer` representable per decision 18 — that is what supplies tvOS's system transport for free.
- [ ] **007** opened. `VLCPlayerController` and the `.directVLC` branch exist and the `tvOS` scheme builds with VLCKit linked (per S001's answer). Note whether S001's fallback (vendored xcframework) was taken, and whether S001 recorded a tvOS gap — if it did, that is a decision-level change escalated to the human per S001's own template, and this slice cannot proceed on the VLC path until it is resolved.
- [ ] **008** opened. `ReportPlaybackStartUseCase`/`ProgressUseCase`/`StoppedUseCase` are wired into `VideoPlaybackService` and fire on start/10 s/pause/seek/stop. AC6 and AC7's `GET /Sessions` checks depend on this being true on tvOS exactly as it is on iOS — same service, no platform branch.
- [ ] **009** opened. `AudioPlayerController` and `MusicPlayerService` exist, `MPRemoteCommandCenter` wiring is in place, and the §1.1 invariants suite (queue is one album, no shuffle/repeat/enqueue) passes. Confirm nothing in that slice assumed an iOS-only presentation host — the service itself must be presentation-agnostic for this slice to drive it from tvOS chrome.
- [ ] **010** opened (soft dependency). Confirm `AlbumGrid` was in fact scoped tvOS-only there, and that its layout still renders correctly as a focus-driven `LazyVGrid` with no wallet-specific assumptions baked in.
- [ ] Architecture standards doc (`docs/architecture.md`) re-read; nothing about the six-target layout or the tvOS deployment target (decision 2, 26.0 everywhere) has changed underneath this slice.

**Drift found:** `none` at time of writing — record here if pre-flight finds otherwise, and log it in the checklist's Drift Log before writing code.

## 5. Acceptance Criteria

- [ ] `xcodebuild build` passes for both the `iOS` and `tvOS` schemes.
- [ ] `xcodebuild test` passes for both schemes with `-skip-testing:iOSUITests` (iOS) / `-skip-testing:tvOSUITests` (tvOS) — unit tests only, none skipped, none commented out.
- [ ] `./scripts/check-layer-imports.sh` exits 0.
- [ ] `swiftformat --lint .` is clean.
- [ ] On the Apple TV simulator, signed in: Home, Movies, Shows and Music tabs are all reachable and focus-navigable; Movies shows the two-item library via `MovieLibraryShelf`; Music shows the album shelf via `AlbumGrid`.
- [ ] **AC6 replayed on tvOS**: the `mp4`/h264 Avatar item plays via `.directAVPlayer` with system transport controls; `GET /Sessions` shows `PlayMethod: DirectPlay` and no `TranscodingInfo`.
- [ ] **AC7 replayed on tvOS**: the `mkv`/h264/aac F1 item plays via `.directVLC` with the Siri Remote overlay (play/pause on the remote's Play/Pause button, scrub on swipe); `GET /Sessions` shows `PlayMethod: DirectPlay` and no `TranscodingInfo`.
- [ ] An album (all 46 tracks are `m4a`/`alac`) plays through on tvOS: the Siri Remote's next/previous buttons advance and step back through the queue, and `GET /Sessions` shows a music session with `NowPlayingItem` and `PlayMethod: DirectPlay` while it plays.
- [ ] AC3 (tvOS Quick Connect) is **not** re-demonstrated here — it was claimed in slice 004 and nothing about sign-in changes in this slice.

## 6. Decision Log

**Write the row before you implement the decision, not after.** This is the whole mechanism. A decision log filled in at close is reconstructed from memory, and the rejected alternatives — the part the next slice's pre-flight actually needs — are exactly what memory loses first.

| Date | Decision | Alternatives rejected | Why |
|---|---|---|---|
| 2026-09-03 | Five tvOS tabs (Home, Movies, Shows, Music, Settings), cited from `SPEC-DECISIONS.md` decision 26 | Four tabs, matching iOS's `RootTabScreen` | Decision 26 already settled this: engineering doc §9's "same information architecture" prose was the error, not the five-tab structure it described alongside it. Not re-argued here. |
| 2026-09-03 | `AlbumGrid` from 005/010 is reused unchanged as the tvOS music shelf; no new `AlbumLibraryShelf` type is added | Naming a new type `AlbumLibraryShelf` to match the `MovieLibraryShelf` / `SeriesLibraryShelf` pattern | `AlbumGrid` is already a `LazyVGrid` and slice 010 already made it tvOS-exclusive — there is no iOS variant left for it to diverge from, so a rename or a platform split would be a file for its own sake, not a behaviour difference. |
| 2026-09-03 | The `.directVLC` path gets a new tvOS-only overlay file rather than reusing 007's touch overlay as-is | Shipping 007's play/pause-scrub-close touch overlay unchanged on tvOS | A Siri Remote has no tap surface for a scrub bar or a close button; the touch affordances from 007 are not operable from the remote, so AC7 cannot be demonstrated on tvOS without a remote-driven counterpart. |
| 2026-09-03 | `SeriesDetailScreen`, `EpisodeRow`, `NowPlayingScreen` and `SettingsScreen` are left as single shared files, no `#if os(tvOS)` counterpart added | Pre-emptively splitting these into platform-specific files | Engineering doc §9's tvOS screen table names no divergence for any of the four, and they already build and behave correctly on the `tvOS` scheme from 005/009 — a split with no behaviour difference is speculative scope, not a fix for anything broken. |
| 2026-09-03 | `VideoPlayerScreen` needs no new code for the `.directAVPlayer` / `.transcodeHLS` paths on tvOS | Building tvOS-specific transport controls for the AVPlayer paths | Decision 18 already chose the AVKit `VideoPlayer` representable specifically because it supplies transport controls, Picture in Picture and platform-appropriate remote handling for free; reimplementing that here would contradict the reasoning decision 18 already recorded. |

## 7. Sub-Slices
Not split — delivered as a single slice.

## 8. Testing Strategy
- **Unit / Integration / UI:** this slice introduces no new domain rule, use case or service behaviour — `LibraryService`, `SeriesService`, `VideoPlaybackService`, `MusicPlayerService` and every repository are exactly what 005 through 009 shipped and already tested. Their existing suites run unchanged against both schemes, because `MixtapeDomain`, `MixtapeUseCase`, `MixtapeServices` and `MixtapeData` carry no platform split — the same test binary runs whichever scheme is under test. No XCUITest is written (decision 4), so the tvOS-specific presentation work in this slice (the shelves, the tvOS `MovieDetailScreen`, the Siri Remote overlay) is proven by the acceptance criteria in Section 5 — build, layer-import and format gates plus the manual/`GET /Sessions` checks on the Apple TV simulator — not by a new automated suite.
- **Test targets required:** none created by this slice. `MixtapeDomainTests`, `MixtapeUseCaseTests`, `MixtapeServicesTests` and `MixtapeDataTests` already exist from slice 001 onward and are exercised by `xcodebuild test` on both the `iOS` and `tvOS` schemes as part of the mechanical gate.

## 9. Keeping this document true

This slice is done when the page describes what was actually built — not when the code works. The discipline is **ordering**: the write happens *before* the thing it describes, so it sits on the critical path instead of after it, where it gets skipped.

| Before you… | Write this first |
|---|---|
| implement a decision | the Section 6 row, including what you rejected |
| start work | flip status in the master checklist |
| stop on a blocker | the Active Blockers row |
| build on a spike | that spike's Result section |
| widen scope | Section 3, and `depends_on` on any slice that's now affected |

And in the same commit as the code, not a follow-up: **commit this file alongside it**, with the slice id in the commit subject (`011: add tvOS presentation`).

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

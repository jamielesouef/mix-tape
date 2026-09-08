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
  - { id: "008", type: hard, note: "progress and stopped reporting and resume — the tvOS AC6/AC7 replays read the full session lifecycle off GET /Sessions" }
  - { id: "009", type: hard, note: "AudioPlayerController and MusicPlayerService — the album queue this slice drives from the Siri Remote" }
  - { id: "010", type: soft, note: "AlbumGrid becomes tvOS-only there; this slice keeps the type and gives it the .card focus style and a shelf header rather than building a new tvOS album grid type" }
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
- A focusable "Now Playing" button in the Music tab while music is active, pushing the shared `NowPlayingScreen` (drift (b): 009 left it reachable only through the iOS mini player, and the Siri Remote has no skip buttons, so §1.12's next/previous had no tvOS entry point). Not a mini player: it is a navigation affordance, adds no transport of its own, and `NowPlayingScreen` is unchanged.
- `LibraryTabScreen`, one tvOS-only view behind the Movies, Shows and Music tabs: resolves the first library of its kind from `LibraryService` and hosts `LibraryDestination`, replacing 010's `MusicTabScreen+tvOS.swift`. `MovieLibraryGrid`, `SeriesLibraryGrid` and `PosterGrid` become iOS-only; `PosterGrid+tvOS.swift` becomes `PosterShelf`, the shelf both new shelves share.
- Accessibility identifier enums for every new tvOS-only view, one enum per file (decision 17), even though XCUITest itself is deferred (decision 4).
- Every file this slice adds that diverges from its iOS counterpart is a second file, `#if os(iOS)` / `#if os(tvOS)`, named for what it is — never one file branching inside a view body.

**Out of scope** (name the slice it's deferred to):
- Sign-in and Quick Connect chrome on tvOS — already built and AC3 already claimed in slice 004; not reopened here.
- `SeriesDetailScreen`, `EpisodeRow`, `NowPlayingScreen`, `SettingsScreen` — built generically in 005 and 009, already compile and behave correctly on the `tvOS` scheme with no layout divergence called for in engineering doc §9's tvOS table. Left untouched.
- The Wallet, the mini player, and any return-to-sleeve behaviour — never built on tvOS, per §1.1. Not a deferral to a later slice; a deliberate, permanent absence.
- Accessibility labels, Dynamic Type audit, Reduce Transparency and Reduce Motion passes — deferred to slice 012.
- XCUITest — deferred this round (decision 4).
- Series → season → episode ordering acceptance (AC11) — the library holds 0 series and 0 episodes (decision 14); unverifiable, not claimed here or anywhere yet.
- AC13f (FLAC album, no transcode) — claimed by slice 009 once the FLAC album from decision 35 was added; not re-claimed here. The album played on tvOS to demonstrate §1.12 is one of the `m4a`/`alac` ones.

**Plan requirements covered:**
- `§1.5` (list the user's libraries) — `RootTabScreen`'s Movies/Shows/Music tabs and `HomeScreen` all read from `LibraryService`, unchanged from 005, now inside tvOS chrome.
- `§1.6` (browse a movie library; movie detail screen) — `MovieLibraryShelf` plus the tvOS `MovieDetailScreen`.
- `§1.8` (browse a music library → albums → tracks) — `AlbumGrid` shelf plus the shared `AlbumDetailScreen` from 005/009.
- `§1.10` (direct AVPlayer, direct VLC, HLS transcode) — replayed on tvOS: AC6 and AC7 are demonstrated on the Apple TV simulator, read off `GET /Sessions`.
- `§1.12` (album queue, next/prev, lock-screen/remote controls) — demonstrated on tvOS as an album playing through with the Siri Remote's next/previous, via the same `MusicPlayerService` and `MPRemoteCommandCenter` wiring from 009.

Each of these rows is a **tvOS demonstration** of a capability already covered end to end by an earlier slice's iOS acceptance criteria — this slice adds no new service, use case or domain behaviour, only tvOS presentation and, for VLC, a tvOS-specific overlay.

## 4. Pre-Flight Validation

Complete **before the first line of code**, not at close.

- [x] **005** opened (2026-09-04). `LibraryService`, `SeriesService`, `ImageService`, `MovieLibraryGrid`/`SeriesLibraryGrid`, `MovieDetailScreen` and `RootTabScreen` exist and build on the `tvOS` scheme as shared code. Its decision log still matches — no change to the library repository or its mappers since it landed.
- [x] **006** opened. `AVPlayerController.makeView()` returns `AnyView(VideoPlayer(player:))` — decision 18 holds. `ResolveVideoPlaybackUseCase`, `AVPlayerController`, `VideoPlaybackService` and `VideoPlayerScreen` exist; the `.directAVPlayer` and `.transcodeHLS` branches are proven on iOS via AC6/AC8. Confirm `AVPlayerController.makeView()` still returns the AVKit `VideoPlayer` representable per decision 18 — that is what supplies tvOS's system transport for free.
- [x] **007** opened. S001 took the SPM route (`tylerjonesio/vlckit-spm` 3.6.0, `TVVLCKit` on tvOS); no fallback, no tvOS gap recorded. 007's overlay already shows a read-only `ProgressView` on tvOS and names this slice for the remote scrub. `VLCPlayerController` and the `.directVLC` branch exist and the `tvOS` scheme builds with VLCKit linked (per S001's answer). Note whether S001's fallback (vendored xcframework) was taken, and whether S001 recorded a tvOS gap — if it did, that is a decision-level change escalated to the human per S001's own template, and this slice cannot proceed on the VLC path until it is resolved.
- [x] **008** opened. `VideoPlaybackService` reports start / 10 s / pause / seek / stop with no platform branch. `ReportPlaybackProgressUseCase`/`StoppedUseCase` (008) and `ReportPlaybackStartUseCase` (006, decision 37) are wired into `VideoPlaybackService` and fire on start/10 s/pause/seek/stop. AC6 and AC7's `GET /Sessions` checks depend on this being true on tvOS exactly as it is on iOS — same service, no platform branch.
- [x] **009** opened. `MusicPlayerService` is presentation-agnostic; but no tvOS surface reaches `NowPlayingScreen` — drift (b) below. `AudioPlayerController` and `MusicPlayerService` exist, `MPRemoteCommandCenter` wiring is in place, and the §1.1 invariants suite (queue is one album, no shuffle/repeat/enqueue) passes. Confirm nothing in that slice assumed an iOS-only presentation host — the service itself must be presentation-agnostic for this slice to drive it from tvOS chrome.
- [x] **010** opened (soft dependency). `AlbumGrid.swift` is wrapped in `#if os(tvOS)`, type unchanged; it uses `.buttonStyle(.plain)` and a `LazyVGrid`, which is focusable on tvOS but shows no focus effect — this slice gives it the `.card` style and shelf header (Section 6). Confirm `AlbumGrid` was in fact scoped tvOS-only there, and that its layout still renders correctly as a focus-driven `LazyVGrid` with no wallet-specific assumptions baked in.
- [x] Architecture standards doc (`docs/architecture.md`) re-read; nothing about the six-target layout or the tvOS deployment target (decision 2, 26.0 everywhere) has changed underneath this slice.

**Drift found:** four items, logged in the master checklist drift log (2026-09-04): the tvOS counterpart files are now the `+tvOS` halves 010 created; `NowPlayingScreen` is unreachable on tvOS (this slice adds a Music-tab "Now Playing" button — see Section 3 and Section 6); `sampleAlbums` is 5; the tvOS bundle id is `mobi.jamie.mixtape-tv`.

## 5. Acceptance Criteria

- [x] `xcodebuild build` passes for both the `iOS` and `tvOS` schemes. Gate expected executed-test count per scheme: **156** (unchanged from 010 — this slice adds no test). Verified 2026-09-04 via `./scripts/gate.sh 156`.
- [x] `xcodebuild test` passes for both schemes with `-skip-testing:iOSUITests` (iOS) / `-skip-testing:tvOSUITests` (tvOS) — unit tests only, none skipped, none commented out. 156/156, 0 failed, 0 skipped on each scheme.
- [x] `./scripts/check-layer-imports.sh` exits 0.
- [x] `swiftformat --lint .` is clean.
- [x] On the Apple TV simulator, signed in: Home, Movies, Shows and Music tabs are all reachable and focus-navigable; Movies shows the two-item library via `MovieLibraryShelf`; Music shows the album shelf via `AlbumGrid`. *2026-09-04, driven as in 004 by a throwaway XCUITest in a scratch copy (`XCUIRemote`, screenshots attached to the result bundle):* Home, Movies, Shows, Music and Settings all reached from the top tab bar with the remote; Movies shows the two `posterShelf.cell.*` cards with the `.card` focus lift; Shows shows `libraryTab.emptyLabel.shows` (the test user has no TV library); Music shows the five `albumGrid.cell.*` cards under the library title. The first run's Music tab showed "No albums" because it resolved the orphaned "Empty Music" view — drift log, cleared by a server restart.
- [x] **AC6 replayed on tvOS**: the `mp4`/h264 Avatar item plays via `.directAVPlayer` with system transport controls; `./scripts/jf-probe.swift /Sessions` (decision 47) shows `PlayMethod: DirectPlay` and no `TranscodingInfo`. *2026-09-04:* AVKit's tvOS transport (scrubber, elapsed/remaining, audio menu) on screen; `/Sessions` for the Apple TV device: `Item=Avatar: Fire and Ash`, `Container=mov,mp4,m4a,3gp,3g2,mj2`, `PlayMethod=DirectPlay`, `TranscodingInfo` absent.
- [x] **AC7 replayed on tvOS**: the `mkv`/h264/aac F1 item plays via `.directVLC` with the Siri Remote overlay (play/pause on the remote's Play/Pause button, scrub on swipe); `./scripts/jf-probe.swift /Sessions` shows `PlayMethod: DirectPlay` and no `TranscodingInfo`. *2026-09-04:* `/Sessions`: `Item=F1`, `Container=mkv`, `PlayMethod=DirectPlay`, `TranscodingInfo` absent. The remote's Play/Pause paused VLC (overlay flipped to the play glyph, progress bar held at ≈10 %); two right presses then Play/Pause put the bar at ≈43 % ≈ 7 s later, so the swipe step moved the position forward by more than wall-clock. The first run left focus on the cover's Close button and neither command fired — fixed by the `@FocusState` row in Section 6. The server's `IsPaused` did not flip: Triage 11.
- [x] An album (`m4a`/`alac` tracks) plays on tvOS: the Music tab's focusable "Now Playing" button (drift (b) — the Siri Remote has no skip buttons) pushes `NowPlayingScreen`, whose focusable Next and Previous buttons advance to track 2 and step back to track 1, and `./scripts/jf-probe.swift /Sessions` shows a music session whose `NowPlayingItem` changes accordingly with `PlayMethod: DirectPlay` and no `TranscodingInfo`. *2026-09-04:* "Take Me Back To Eden" (Sleep Token, 12 `m4a` tracks) opened from the focused shelf card, Play pressed on `AlbumDetailScreen`; `/Sessions`: `Item=Chokehold`, `PlayMethod=DirectPlay`, `TranscodingInfo` absent. Menu back to the shelf, up-swipe onto `libraryTab.nowPlayingButton`, select → `nowPlaying.screen`; Next (walked by focus — Triage 8) → `Item=The Summoning`; Previous twice (the first restarts a track past 3 s, 009) → `Item=Chokehold`. Two earlier runs found the button unreachable by focus; fixed by the `focusSection()` row in Section 6.
- [x] AC3 (tvOS Quick Connect) is **not** re-demonstrated here — it was claimed in slice 004 and nothing about sign-in changes in this slice.

## 6. Decision Log

**Write the row before you implement the decision, not after.** This is the whole mechanism. A decision log filled in at close is reconstructed from memory, and the rejected alternatives — the part the next slice's pre-flight actually needs — are exactly what memory loses first.

| Date | Decision | Alternatives rejected | Why |
|---|---|---|---|
| 2026-09-03 | Five tvOS tabs (Home, Movies, Shows, Music, Settings), cited from `SPEC-DECISIONS.md` decision 26 | Four tabs, matching iOS's `RootTabScreen` | Decision 26 already settled this: engineering doc §9's "same information architecture" prose was the error, not the five-tab structure it described alongside it. Not re-argued here. |
| 2026-09-03 | `AlbumGrid` from 005/010 is reused unchanged as the tvOS music shelf; no new `AlbumLibraryShelf` type is added | Naming a new type `AlbumLibraryShelf` to match the `MovieLibraryShelf` / `SeriesLibraryShelf` pattern | `AlbumGrid` is already a `LazyVGrid` and slice 010 already made it tvOS-exclusive — there is no iOS variant left for it to diverge from, so a rename or a platform split would be a file for its own sake, not a behaviour difference. |
| 2026-09-03 | The `.directVLC` path gets a new tvOS-only overlay file rather than reusing 007's touch overlay as-is | Shipping 007's play/pause-scrub-close touch overlay unchanged on tvOS | A Siri Remote has no tap surface for a scrub bar or a close button; the touch affordances from 007 are not operable from the remote, so AC7 cannot be demonstrated on tvOS without a remote-driven counterpart. |
| 2026-09-03 | `SeriesDetailScreen`, `EpisodeRow`, `NowPlayingScreen` and `SettingsScreen` are left as single shared files, no `#if os(tvOS)` counterpart added | Pre-emptively splitting these into platform-specific files | Engineering doc §9's tvOS screen table names no divergence for any of the four, and they already build and behave correctly on the `tvOS` scheme from 005/009 — a split with no behaviour difference is speculative scope, not a fix for anything broken. |
| 2026-09-03 | `VideoPlayerScreen` needs no new code for the `.directAVPlayer` / `.transcodeHLS` paths on tvOS | Building tvOS-specific transport controls for the AVPlayer paths | Decision 18 already chose the AVKit `VideoPlayer` representable specifically because it supplies transport controls, Picture in Picture and platform-appropriate remote handling for free; reimplementing that here would contradict the reasoning decision 18 already recorded. |
| 2026-09-04 | One tvOS `LibraryTabScreen(kind:)` behind Movies, Shows and Music, hosting `LibraryDestination`; `MusicTabScreen+tvOS.swift` is deleted and `MusicTabScreen+iOS.swift` becomes `MusicTabScreen.swift` (iOS-only, like `WalletScreen`). | Three near-identical tab types (`MoviesTabScreen`, `ShowsTabScreen`, `MusicTabScreen`); keeping the tvOS `MusicTabScreen` beside two new ones. | The three tabs differ only in which `LibraryKind` they resolve; `LibraryDestination+tvOS` already maps kind to shelf. One type, one file. |
| 2026-09-04 | `PosterGrid+tvOS.swift` becomes `PosterShelf.swift` (tvOS-only): library title header, 5-up `LazyVGrid` of `PosterCard`s under `.buttonStyle(.card)`; `MovieLibraryShelf` and `SeriesLibraryShelf` wrap it exactly as the iOS grids wrap `PosterGrid`. `MovieLibraryGrid`, `SeriesLibraryGrid` and `PosterGrid+iOS.swift` (renamed `PosterGrid.swift`) become `#if os(iOS)`. | Inlining the shelf layout in both shelf types; leaving the shelves as thin aliases over the shared grid files. | Two shelves with the same layout rules (decision 26) share one helper, as the two iOS grids already do; the layout genuinely diverges from iOS (header, columns, focus style), so the shelf types are real, not renames. |
| 2026-09-04 | `AlbumGrid` gets `.buttonStyle(.card)` and the same shelf header; type, identifiers and call unchanged. | Reusing it byte-for-byte as 011's front matter planned. | `.plain` shows no focus effect on tvOS, so the album shelf was reachable but not visibly navigable — the acceptance criterion says focus-navigable. One style and one header line is the smallest honest fix; 011's `depends_on` note on 010 is corrected to say so. |
| 2026-09-04 | `MovieDetailScreen` splits into `+iOS` (the 005 body) and `+tvOS` (full-bleed backdrop, metadata block bottom-left); the metadata line moves to a shared `MediaItem.detailMetadata` in `Shared/`. | Duplicating the metadata builder in both files; one file branching on `#if os(tvOS)` inside the body. | Two-files rule; the metadata string is pure `MediaItem` formatting with no platform in it, so it is shared once rather than copied twice. |
| 2026-09-04 | 007's private `VLCPlayerView` overlay splits into `VLCPlayerView+iOS.swift` (the 007 overlay) and `VLCPlayerView+tvOS.swift` (Siri Remote: `onPlayPauseCommand` toggles, `onMoveCommand` left/right steps ±10 s, select on the focused button toggles), both in `MixtapeInfrastructure` beside the controller. `VLCVideoSurface` becomes internal so both can use it. | Keeping the overlay inside `VLCPlayerController.swift` with a second `#if os(tvOS)` branch; moving the overlay to Presentation. | Two-files rule; the overlay stays in Infrastructure because `VideoPlayerControlling.makeView()` hands Presentation an `AnyView` and Presentation may not see the controller's internals. |
| 2026-09-04 | A shared `platformCardButtonStyle()` modifier pair (`+iOS` → `.plain`, `+tvOS` → `.card`) for `HomeScreen`'s Continue Watching cards. | `#if os(tvOS)` inside `HomeScreen`'s body; splitting `HomeScreen` into two files for one button style. | The screen's layout is identical on both platforms; only the focus style differs, and `.card` does not exist on iOS. A named platform pair keeps the divergence in two files named for what they are. |
| 2026-09-04 | tvOS music scrubbing stays a read-only bar in `NowPlayingScreen`; only the VLC overlay gets remote scrubbing. | Adding `onMoveCommand` scrubbing to `NowPlayingScreen`. | 011's scope leaves `NowPlayingScreen` untouched and engineering doc §9's tvOS table names no divergence for it; 009's code comment pointing scrubbing at 011 is corrected to say so. Triage 7 (seek to the exact end stalls) is also a reason not to add a coarse remote scrub there this round. |
| 2026-09-04 | `RootTabIdentifiers` gains `moviesTab` and `showsTab`; `LibraryTabIdentifiers` and `PosterShelfIdentifiers` are new (decision 17). | Reusing `PosterGridIdentifiers` on the shelf. | Different view, different enum, so the deferred UI tests can tell the platforms apart. |
| 2026-09-04 | `VLCPlayerView+tvOS` claims focus for its play/pause button on appear (`@FocusState` + `.focused`), so the remote's Play/Pause and left/right reach `onPlayPauseCommand` / `onMoveCommand`. | Handling the commands in `VideoPlayerScreen`; a `.defaultFocus` scope on the overlay. | The first acceptance run left focus on `VideoPlayerScreen`'s Close button, which is not a descendant of the VLC view, so neither command fired and the remote did nothing. `VideoPlayerScreen` is Presentation and may not know which player it hosts; `defaultFocus` only ranks elements inside its own scope and the Close button sits outside it. |
| 2026-09-04 | `LibraryTabScreen` keeps "first library of its kind" — one music library per user is the tvOS assumption. The stale "Empty Music" view 010's acceptance run left on the dev server is removed on the server (a restart plus scan, see the drift log) rather than coded around. | A library picker per tab; a preference for the non-empty library. | Neither engineering doc §9 nor decision 26 gives a tvOS tab more than one library; a second music library is out of V1's product shape. 010's own page says the library was deleted afterwards, so removing the orphan restores the recorded state. Recorded in the drift log. |
| 2026-09-04 | The Music tab's "Now Playing" button is a top-trailing overlay in `LibraryTabScreen`'s body, not a `.toolbar` item. | `.toolbar { Button(…) }` on the tab's `NavigationStack`. | The shelves draw their own left-aligned title instead of the stack's centred `navigationTitle` (the Settings tab shows what that looks like on tvOS), so the tab has no bar of its own for a toolbar item to land in, and whether tvOS would render one there was not going to be checked by a driver round trip. An overlay at the shelf's own padding is visible and focusable regardless. The overlay row is a `focusSection()`: with five albums in six columns the button sits above no card, so an up-swipe from the row went to the tab bar instead (run 4); the full-width section catches it. |

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
- [x] Acceptance criteria met
- [x] Tests passing, in a target that exists (156 per scheme in the four existing SPM test targets; none added)
- [x] Every `covers:` requirement satisfied, or forked with a decision row (§1.5, §1.6, §1.8, §1.10, §1.12 demonstrated on tvOS above)
- [x] Decision log written as you went, not reconstructed
- [x] Pre-flight completed and drift resolved (four pre-flight items plus the "Empty Music" orphan found during acceptance, all in the drift log)
- [x] Master checklist row current
- [x] `next_slice`'s `depends_on` reflects what actually shipped, not what was planned (012's note on 011 names the shipped files and the VLC overlay's material fallback outside Presentation)
- [x] Both link directions checked: this page's `next_slice` is 012 and 012's `previous_slice` is 011

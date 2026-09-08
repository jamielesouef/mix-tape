---
slice_id: "010"
title: The Wallet
priority: P1
complexity: L
ladder: none
depends_on:
  - { id: "009", type: hard, note: "as shipped: MusicPlayerService (queue is one album, next/previous/finishedAlbumID/acknowledgeFinish) drives an injected AudioPlayerControlling; AlbumDetailScreen Play and each TrackRow call play(album:tracks:startingAt:); the plain AlbumGrid (from 005) is the Music tab root and the mini player docks via tabViewBottomAccessory. 010 replaces the grid with the wallet and wires the return-to-sleeve on finishedAlbumID; MusicPlayerService and AlbumDetailScreen Play are unchanged" }
previous_slice: "009"
next_slice: "011"
parent_slice: none
covers: ["§1.8", "§1.15", "§12.13a", "§12.13b", "§12.13c", "§12.13d", "§12.13e"]
created: 2026-09-03
---

# 010 — The Wallet

← [previous](009-music-playback.md) · [Master Checklist](MASTER-CHECKLIST.md) · [next](011-tvos-presentation.md) →

> **Status, owner and blockers live in the master checklist, not here.** Dependencies live in this page's front matter and nowhere else. Each fact has one home; if you find yourself writing it twice, one of the two copies is going to be wrong in a fortnight.

## 1. Objective

On iOS, the Music tab's root becomes the CD wallet: paged sleeves you pull a disc out of, play to the end, and watch slide home again — the surface §9.1 describes, replacing the plain grid slice 009 shipped as a stopgap. This is observable end to end without any unbuilt slice: pull a sleeve, play the album from 009's already-wired player, and see the wallet return to it unaided.

## 2. Business Value & Priority

P1, L. This is the product identity of the music half of the app — §1.1 calls the wallet metaphor "not a missing feature, it is the product" — but it was correctly deferred behind 009 so that queue behaviour, background audio and reporting could be proven against a plain grid first, without a matched-geometry transition and a paging layout also in flight. This slice is not a rung in a further ladder: nothing about the wallet is deferred past it, and 011 gives tvOS its own conventional grid rather than a second wallet.

## 3. Scope

**In scope:**
- `WalletScreen` — the Music tab's iOS root, replacing the plain `AlbumGrid` entry point from slice 005/009.
- `WalletPage` — a horizontally paged view of fixed-size album blocks, 2×2 on compact horizontal size class, 3×3 on regular (decision 20), with a page indicator; a partial last page keeps its remaining slots visible as empty sleeves.
- `AlbumSleeve` — album art in a rounded rect with a thin border and a single diagonal specular highlight; a flat bordered card under Reduce Transparency; a static (non-tracking) highlight under Reduce Motion.
- The pull-out transition: tapping a sleeve pushes `AlbumDetailScreen` via a single namespace and modifier pair — `matchedTransitionSource` on the sleeve, `navigationTransition(.zoom)` on the pushed detail (fork F5: `matchedGeometryEffect` does not animate across a navigation push). No bespoke transition.
- The return-to-sleeve sequence, triggered when `MusicPlayerService.finishedAlbumID` becomes non-nil: dismiss `NowPlayingScreen`, pop `AlbumDetailScreen`, scroll to the page holding that album, pulse its sleeve border for 0.4 s, call `acknowledgeFinish()`.
- The same return sequence run without animation on foreground, for the case where the last track finished while the app was backgrounded.
- A pure page-index function in `MixtapeDomain` — given an album id and the wallet's sort order, which page and slot it lives on, for both the 2×2 and 3×3 layouts. A pure rule with no I/O, so Domain is its home per §4, and `MixtapePresentation` may import `MixtapeDomain`.
- Empty wallet state (no albums, one line of copy, no spinner) and failed-load state (empty wallet plus retry), both driven by the same `LibraryService` load path 005 established.
- `AlbumGrid` becomes tvOS-only: its single file is wrapped in `#if os(tvOS)` (drift: it shipped as one shared file), its identifiers are unchanged, and it stops being reachable from any iOS screen. `MusicTabScreen` and `LibraryDestination`, the two shared views that reached it, split into `+iOS` / `+tvOS` files; both iOS files route music to the wallet.
- Accessibility identifiers for the wallet surface (`WalletIdentifiers.swift`, one enum per decision 17) covering page indicator, each sleeve, and the wallet's empty/retry controls.

**Out of scope** (name the slice it's deferred to):
- Tilt-following specular highlight (`CMMotionManager` / `DeviceAttitudeReader`) — not deferred to a later slice, cut outright. §7 and §9.1 both gate it on "skip if it costs more than an afternoon", a judgement an unattended run has no way to make; the static diagonal highlight already satisfies every acceptance criterion this slice claims. If a future round wants it, `DeviceAttitudeReading` is the seam §9.1 names for it.
- tvOS wallet — never built anywhere, per §1.1: "This applies to iOS only." tvOS's conventional album grid is slice 011's `AlbumGrid` shelf.
- Shuffle, repeat, add-to-queue, "play all", up-next, a global play button, or any control that could let a second album's tracks reach the queue — absent per §1.1 and §9.1, not merely hidden. Nothing in this slice adds one.
- `AC13f` (FLAC album, no transcode session) — not claimed here; slice 009 claimed it once the FLAC album landed (decision 35, Plan Fork 4), since the reporting path it exercises is 009's.
- XCUITest and CI — deferred this round only, per decision 4. No UI test is written or enabled.

**Plan requirements covered:**
- `§1.15` — The Wallet capability itself: `WalletScreen`, `WalletPage`, `AlbumSleeve` and the pull-out/return sequence, as above.
- `§12.13a` — reworded by decision 20: 3×3 on iPad and on regular-width iPhones in landscape, 2×2 on standard iPhones in both orientations, no mid-page reflow. Satisfied by keying `WalletPage`'s column count to `horizontalSizeClass` rather than device orientation.
- `§12.13b` — satisfied by the single matched zoom navigation transition (`matchedTransitionSource` / `navigationTransition(.zoom)`, fork F5) and its reverse on pop.
- `§12.13c` — satisfied by the return-to-sleeve sequence above, driven off `finishedAlbumID`.
- `§12.13d` — satisfied by running the same sequence, unanimated, on `scenePhase` returning to `.active` while `finishedAlbumID` is already set.
- `§12.13e` — satisfied by the absence list above; the final-track lock-screen disable itself was built in 009 and is re-verified here at the wallet level since it is now reachable through the wallet's own player entry point.

## 4. Pre-Flight Validation

Complete **before the first line of code**, not at close.

For **each id in `depends_on`**, in order — don't summarise, walk the list:

- [x] `009` — opened it. Confirmed 2026-09-04: `MusicPlayerService.finishedAlbumID`, `acknowledgeFinish()`, `AlbumDetailScreen` and `NowPlayingScreen` exist and match the shapes this slice assumed when drafted (§6 signature, §1.1 invariants suite passing).
- [x] `009` — not a spike; no fallback to check.
- [x] `009`'s state matches what this slice assumed when drafted: the plain `AlbumGrid` is iOS-reachable from the Music tab and album playback already reports to the server (decision 34) before this slice starts removing the grid.
- [x] Architecture standards doc re-read; nothing changed underneath this slice — in particular that `MixtapePresentation` still may not import `MixtapeData`, `MixtapeUseCase` or `MixtapeInfrastructure`, and still imports `MixtapeDomain`, where the page-index rule lives.

**Drift found:** `AlbumGrid` is one platform-shared file reached from shared `MusicTabScreen` and `LibraryDestination`, not the `#if os` pair this page assumed — logged in the master checklist drift log (2026-09-04) and resolved as described there.

## 5. Acceptance Criteria

- [x] AC13a (reworded by decision 20): the wallet shows a fixed 2×2 block on the iPhone 17 Pro simulator in both orientations ("Page 1 of 2" / "Page 2 of 2" with the fifth album alone on a partial page beside three empty sleeves), and a fixed 3×3 block on an iPad Pro 11-inch (M4) simulator created on the iOS 26.5 runtime ("Page 1 of 1", five albums and four empty sleeves). The iPad simulator was deleted after the check so the gate's first-simulator pick stays the iPhone. **Manual, 2026-09-04.** No iPad simulator exists on this machine at drafting time and there is no separate iPadOS runtime; the gate creates one first with `xcrun simctl create` using an iPad device type (for example `com.apple.CoreSimulator.SimDeviceType.iPad-Pro-11-inch-M4`) against the installed iOS 26.5 runtime (`com.apple.CoreSimulator.SimRuntime.iOS-26-5`), because a standard iPhone never reaches regular width and cannot demonstrate the 3×3 half on its own.
- [x] AC13b (fork F5): tapping the "King Of Terrors" sleeve zoomed it into `AlbumDetailScreen` (mid-transition frame captured); the pop zoomed the detail back into the same sleeve (frame 262 of the end-of-album recording shows the detail shrinking into the sleeve's frame). **Manual, 2026-09-04.**
- [x] AC13c: "King Of Terrors" played from the wallet's own `AlbumDetailScreen`, skipped to track 6 and scrubbed to 0.97; when the track ended the now-playing sheet dismissed, the detail popped, the wallet sat on page 1 and the sleeve pulsed. A 60 fps `simctl recordVideo` capture sampled at 20 fps shows the accent border on frames 272–277 (0.3 s visible, 13.55–13.8 s), nowhere else. **Manual, 2026-09-04.**
- [x] AC13d: same setup, Home pressed with 8 s of the final track left, app relaunched 12 s later: the sheet and detail were gone and the wallet showed page 1 with no pulse — a recording from before the relaunch to 3 s after it has accent-blue pixels in the sleeve region only on the home-screen frames. **Manual, 2026-09-04.**
- [x] AC13e: `grep -rniE "shuffle|repeat|addToQueue|append\(|upNext|playAll|autoplay"` over `MixtapePresentation` and `MixtapeServices/Music` finds only `GridItem(repeating:)` and `MovieDetailScreen`'s string `append` — no music control. `MusicPlayerService.start(index:)` still calls `setNextTrackEnabled(index + 1 < queue.count)` and the 009 `.service` suite still asserts it is false on the final track (156 tests green). **Audit, 2026-09-04.**
- [x] An empty music library ("Empty Music", created on the dev server for the check and deleted afterwards) showed four empty sleeves and `wallet.emptyLabel` with no spinner, reached from the Libraries tab. With `docker stop jellyfin` and a fresh launch, the Music tab showed four empty sleeves, the server-unreachable message and `wallet.retryButton`; after `docker start jellyfin`, Retry loaded the library. **Manual, 2026-09-04.**
- [x] `MixtapeDomainTests`, tagged `.domain`, covers the wallet's page-index function returning the correct page and slot for a given album id, for both the 2×2 and 3×3 column counts, including the first and last album in a partial final page.
- [x] `WalletScreen`'s `#Preview` covers full page and partial page (five sample albums: one full 2×2 page plus one partial), empty and failed, per §9.1 and the project's `{loaded, empty, failure}` preview convention.
- [x] Both `iOS` and `tvOS` schemes build; the tvOS scheme still builds `AlbumGrid` as its music surface, now iOS-unreachable. Gate expected executed-test count per scheme: **156** (152 from slice 009 plus 4 `WalletPosition` tests). Verified 2026-09-04 via `./scripts/gate.sh 156`; `./scripts/check-layer-imports.sh` exits 0; `swiftformat --lint .` is clean.

## 6. Decision Log

**Write the row before you implement the decision, not after.** This is the whole mechanism. A decision log filled in at close is reconstructed from memory, and the rejected alternatives — the part the next slice's pre-flight actually needs — are exactly what memory loses first.

| Date | Decision | Alternatives rejected | Why |
|---|---|---|---|
| 2026-09-03 | Wallet grid keyed to horizontal size class; AC13a reworded (`SPEC-DECISIONS.md` decision 20, cited not re-argued). | — | Already decided; see decision 20. |
| 2026-09-03 | Cut the tilt-following specular highlight entirely; `DeviceAttitudeReader` is not built this round. | Building `DeviceAttitudeReader` behind Reduce Motion per §9.1's "optional, if cheap" wording. | §9.1 and §7 both gate the feature on "skip if it costs more than an afternoon" — a call an unattended run cannot make for itself. The static diagonal highlight already satisfies every acceptance criterion claimed here; `DeviceAttitudeReading` is the seam a later round can build behind without touching `AlbumSleeve`. |
| 2026-09-03 | `AlbumGrid` stays as a real type, restricted to its tvOS `#if os(tvOS)` file; its iOS `#if os(iOS)` file is deleted rather than kept dormant. | Keeping the iOS `AlbumGrid` file in place, unreferenced, as a fallback. | A second reachable music root on iOS is exactly the kind of second entry point §1.1's invariants exist to prevent — even unreferenced, it is a future merge conflict waiting to be wired back in by mistake. Deleting it costs nothing `git` cannot restore. |
| 2026-09-03 | The wallet's page-index computation is a pure function in `MixtapeDomain`, called by `WalletPage`, tested in `MixtapeDomainTests` with the `.domain` tag. | Writing it as a private function inside the `WalletPage` view file; putting it in `MixtapeServices`; adding a `MixtapePresentationTests` target. | It is a pure rule with no I/O, which is what §4 says Domain holds; `MixtapeDomainTests` already exists; `MixtapePresentation` already imports `MixtapeDomain`. Not a fork. |
| 2026-09-04 | Pull-out uses `.matchedTransitionSource(id:in:)` on the sleeve and `.navigationTransition(.zoom(sourceID:in:))` on the pushed `AlbumDetailScreen` (fork F5). | `matchedGeometryEffect` as §9.1 names it; a bespoke ZStack overlay standing in for the push. | `matchedGeometryEffect` only animates between views inside one animated container; across a `NavigationStack` push the source and destination never coexist, so nothing moves. The zoom transition is the platform's matched-geometry push: one namespace, one modifier pair, no bespoke code, and `AlbumDetailScreen` stays untouched. |
| 2026-09-04 | The wallet pushes the detail with `navigationDestination(item:)` bound to `@State pulledAlbum: MediaItem?`; popping is `pulledAlbum = nil`. | `NavigationStack(path:)` owned by `WalletScreen`; `NavigationLink(value:)` through `MediaItemDestination`. | The wallet is both the Music tab's root and a pushed view from the Libraries tab, so it cannot own the stack; a `NavigationLink(value:)` would route through the shared `MediaItemDestination` and miss the zoom source. The item binding pops from either host and is the only state the return sequence needs. |
| 2026-09-04 | `MiniPlayer` dismisses its `NowPlayingScreen` sheet when `MusicPlayerService.isActive` turns false. | Keying the dismissal off `finishedAlbumID`; lifting the sheet state into `WalletScreen`. | `acknowledgeFinish()` clears `finishedAlbumID`, possibly in the same render pass, so an `onChange` on it could observe nil → nil and never fire; `status` stays `.idle` after a finish, so `isActive` is stable. Lifting the sheet state would couple the wallet to the tab shell for one boolean. |
| 2026-09-04 | The page indicator is a `Text` ("Page n of m") with its own identifier; the `TabView(.page)` dots are hidden. | The built-in `UIPageControl` dots. | The dots take no accessibility identifier and crowd past a dozen pages; a label reads correctly under VoiceOver and is the seam the deferred UI tests need (decision 4). |
| 2026-09-04 | `MusicTabScreen` and `LibraryDestination` split into `+iOS` / `+tvOS` files. | A `#if os(iOS)` inside each shared body; a pass-through `MusicLibraryDestination` platform pair. | `CLAUDE.md`: platform divergence is two files named for what they are, never one file branching inside a body. The pass-through pair is an extra type for a one-line divergence 011 replaces anyway. |
| 2026-09-04 | `MockLibraryRepository.sampleAlbums` grows from 2 to 5 albums. | Building a five-album page inline in the preview. | The `WalletScreen` preview needs a full 2×2 page plus a partial page; tests reference `sampleAlbums[0]` and `[1]` only, so growing the fixture breaks nothing and every album preview gets more realistic data. |
| 2026-09-04 | The pulse starts 0.6 s after the pop, via `Task.sleep`, rather than in the pop transaction's `withAnimation` completion. | Chaining on `withAnimation(completion:)` (first attempt); keying the pulse off a view-appearance hook. | The sheet dismissal and the navigation pop are UIKit transitions SwiftUI exposes no completion for; the transaction completion fired at once with nothing SwiftUI-animatable in it, so the 0.4 s pulse ran under the dismissing sheet and never reached the screen (a 20 fps frame scan found no accent border). The fixed delay is the one honest hook; the test-side "inject a clock, never sleep" rule is about tests. |
| 2026-09-04 | Each `WalletPage` is its own accessibility container (`.accessibilityElement(children: .contain)`) beneath its identifier. | Dropping the page identifier. | A bare identifier on a non-element container cascades onto every child, so every sleeve reported `wallet.page.0` instead of its own `wallet.sleeve.<id>` — exactly what the deferred UI tests would query. |

## 7. Sub-Slices

Not split — delivered as a single slice.

## 8. Testing Strategy

- **Unit / Integration / UI:** `MixtapeDomainTests` gets the wallet page-index pure function tested against both the 2×2 and 3×3 layouts, including a partial final page, tagged `.domain`. The `MusicPlayerService` §1.1 invariants suite from slices 008/009 already covers `finishedAlbumID` firing exactly once and `acknowledgeFinish()` clearing it — this slice consumes that trigger and does not duplicate its tests. No UI test is written (decision 4); AC13a–AC13e are demonstrated manually on the iPhone and iPad simulators per Section 5.
- **Test targets required:** `MixtapeDomainTests` (exists from slice 001; used here, not created).

## 9. Keeping this document true

This slice is done when the page describes what was actually built — not when the code works. The discipline is **ordering**: the write happens *before* the thing it describes, so it sits on the critical path instead of after it, where it gets skipped.

| Before you… | Write this first |
|---|---|
| implement a decision | the Section 6 row, including what you rejected |
| start work | flip status in the master checklist |
| stop on a blocker | the Active Blockers row |
| build on a spike | that spike's Result section |
| widen scope | Section 3, and `depends_on` on any slice that's now affected |

And in the same commit as the code, not a follow-up: **commit this file alongside it**, with the slice id in the commit subject (`010: add the wallet`).

Nothing checks any of this. That's the point of putting the writes first — a write you have to do to proceed is one you do; a write you're supposed to do afterwards is one you don't.

## 10. Definition of Done

- [x] Acceptance criteria met
- [x] Tests passing, in a target that exists
- [x] Every `covers:` requirement satisfied, or forked with a decision row (F5)
- [x] Decision log written as you went, not reconstructed
- [x] Pre-flight completed and drift resolved
- [x] Master checklist row current
- [x] `next_slice`'s `depends_on` reflects what actually shipped, not what was planned (011's note on 010 — `AlbumGrid` tvOS-only, reused unchanged — holds)
- [x] Both link directions checked: this page's `next_slice` and that page's `previous_slice`

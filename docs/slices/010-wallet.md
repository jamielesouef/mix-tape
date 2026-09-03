---
slice_id: "010"
title: The Wallet
priority: P1
complexity: L
ladder: none
depends_on:
  - { id: "009", type: hard, note: "needs MusicPlayerService.finishedAlbumID, AlbumDetailScreen, NowPlayingScreen and the mini player slot already wired" }
previous_slice: "009"
next_slice: "011"
parent_slice: none
covers: ["§1.15", "§12.13a", "§12.13b", "§12.13c", "§12.13d", "§12.13e"]
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
- The pull-out transition: tapping a sleeve pushes `AlbumDetailScreen` via a single `matchedGeometryEffect` namespace/modifier pair on the artwork — no bespoke transition.
- The return-to-sleeve sequence, triggered when `MusicPlayerService.finishedAlbumID` becomes non-nil: dismiss `NowPlayingScreen`, pop `AlbumDetailScreen`, scroll to the page holding that album, pulse its sleeve border for 0.4 s, call `acknowledgeFinish()`.
- The same return sequence run without animation on foreground, for the case where the last track finished while the app was backgrounded.
- A pure page-index function — given an album id and the wallet's sort order, which page and slot it lives on, for both the 2×2 and 3×3 layouts — placed in `MixtapeServices` so it is unit-testable without a `MixtapePresentation` test target.
- Empty wallet state (no albums, one line of copy, no spinner) and failed-load state (empty wallet plus retry), both driven by the same `LibraryService` load path 005 established.
- `AlbumGrid` becomes tvOS-only: its iOS `#if os(iOS)` file is deleted, its tvOS `#if os(tvOS)` file and identifiers are unchanged, and it stops being reachable from any iOS screen.
- Accessibility identifiers for the wallet surface (`WalletIdentifiers.swift`, one enum per decision 17) covering page indicator, each sleeve, and the wallet's empty/retry controls.

**Out of scope** (name the slice it's deferred to):
- Tilt-following specular highlight (`CMMotionManager` / `DeviceAttitudeReader`) — not deferred to a later slice, cut outright. §7 and §9.1 both gate it on "skip if it costs more than an afternoon", a judgement an unattended run has no way to make; the static diagonal highlight already satisfies every acceptance criterion this slice claims. If a future round wants it, `DeviceAttitudeReading` is the seam §9.1 names for it.
- tvOS wallet — never built anywhere, per §1.1: "This applies to iOS only." tvOS's conventional album grid is slice 011's `AlbumGrid` shelf.
- Shuffle, repeat, add-to-queue, "play all", up-next, a global play button, or any control that could let a second album's tracks reach the queue — absent per §1.1 and §9.1, not merely hidden. Nothing in this slice adds one.
- `AC13f` (FLAC album, no transcode session) — not claimed here. Decision 35 records that the library has no FLAC album yet; `MASTER-CHECKLIST.md` names slice 009 as the natural owner once one exists, since the reporting path it exercises is 009's.
- XCUITest and CI — deferred this round only, per decision 4. No UI test is written or enabled.

**Plan requirements covered:**
- `§1.15` — The Wallet capability itself: `WalletScreen`, `WalletPage`, `AlbumSleeve` and the pull-out/return sequence, as above.
- `§12.13a` — reworded by decision 20: 3×3 on iPad and on regular-width iPhones in landscape, 2×2 on standard iPhones in both orientations, no mid-page reflow. Satisfied by keying `WalletPage`'s column count to `horizontalSizeClass` rather than device orientation.
- `§12.13b` — satisfied by the single `matchedGeometryEffect` pull-out and its reverse on pop.
- `§12.13c` — satisfied by the return-to-sleeve sequence above, driven off `finishedAlbumID`.
- `§12.13d` — satisfied by running the same sequence, unanimated, on `scenePhase` returning to `.active` while `finishedAlbumID` is already set.
- `§12.13e` — satisfied by the absence list above; the final-track lock-screen disable itself was built in 009 and is re-verified here at the wallet level since it is now reachable through the wallet's own player entry point.

## 4. Pre-Flight Validation

Complete **before the first line of code**, not at close.

For **each id in `depends_on`**, in order — don't summarise, walk the list:

- [ ] `009` — opened it. Confirm `MusicPlayerService.finishedAlbumID`, `acknowledgeFinish()`, `AlbumDetailScreen` and `NowPlayingScreen` exist and match the shapes this slice assumed when drafted (§6 signature, §1.1 invariants suite passing).
- [ ] `009` — not a spike; no fallback to check.
- [ ] `009`'s state matches what this slice assumed when drafted: the plain `AlbumGrid` is iOS-reachable from the Music tab and album playback already reports to the server (decision 34) before this slice starts removing the grid.
- [ ] Architecture standards doc re-read; nothing changed underneath this slice — in particular that `MixtapePresentation` still may not import `MixtapeData`, `MixtapeUseCase` or `MixtapeInfrastructure`, which is why the page-index function goes in `MixtapeServices` rather than beside the view.

**Drift found:** `none`.

## 5. Acceptance Criteria

- [ ] AC13a (reworded by decision 20): the wallet shows a fixed 2×2 block on the iPhone 17 Pro simulator in both orientations, and a fixed 3×3 block on an iPad simulator, with no reflow mid-page in either case. No iPad simulator exists on this machine at drafting time; the gate creates one first with `xcrun simctl create` against an installed iPadOS 26 runtime (list with `xcrun simctl list runtimes`), because a standard iPhone never reaches regular width and cannot demonstrate the 3×3 half on its own.
- [ ] AC13b: tapping a sleeve lifts its artwork into `AlbumDetailScreen`'s header via `matchedGeometryEffect`; navigating back returns the artwork to the sleeve it came from.
- [ ] AC13c: playing an album to the end stops playback, dismisses `NowPlayingScreen`, pops `AlbumDetailScreen` if open, scrolls to the wallet page holding that album, and pulses its sleeve for 0.4 s.
- [ ] AC13d: the same sequence happens correctly, without the pulse animation, when the app was backgrounded for the final track and is foregrounded afterwards.
- [ ] AC13e: no shuffle, repeat, or add-to-queue control exists anywhere in the music UI, and the lock screen's next-track command is disabled on the final track.
- [ ] An empty library shows the wallet's empty state with no spinner; a failed load shows the wallet's empty state with a retry that re-triggers the load.
- [ ] `MixtapeServicesTests` covers the wallet's page-index function returning the correct page and slot for a given album id, for both the 2×2 and 3×3 column counts, including the first and last album in a partial final page.
- [ ] `WalletScreen`'s `#Preview` covers full page, partial page, empty and failed, per §9.1 and the project's `{loaded, empty, failure}` preview convention.
- [ ] Both `iOS` and `tvOS` schemes build; the tvOS scheme still builds `AlbumGrid` as its music surface, now iOS-untouched.

## 6. Decision Log

**Write the row before you implement the decision, not after.** This is the whole mechanism. A decision log filled in at close is reconstructed from memory, and the rejected alternatives — the part the next slice's pre-flight actually needs — are exactly what memory loses first.

| Date | Decision | Alternatives rejected | Why |
|---|---|---|---|
| 2026-09-03 | Wallet grid keyed to horizontal size class; AC13a reworded (`SPEC-DECISIONS.md` decision 20, cited not re-argued). | — | Already decided; see decision 20. |
| 2026-09-03 | Cut the tilt-following specular highlight entirely; `DeviceAttitudeReader` is not built this round. | Building `DeviceAttitudeReader` behind Reduce Motion per §9.1's "optional, if cheap" wording. | §9.1 and §7 both gate the feature on "skip if it costs more than an afternoon" — a call an unattended run cannot make for itself. The static diagonal highlight already satisfies every acceptance criterion claimed here; `DeviceAttitudeReading` is the seam a later round can build behind without touching `AlbumSleeve`. |
| 2026-09-03 | `AlbumGrid` stays as a real type, restricted to its tvOS `#if os(tvOS)` file; its iOS `#if os(iOS)` file is deleted rather than kept dormant. | Keeping the iOS `AlbumGrid` file in place, unreferenced, as a fallback. | A second reachable music root on iOS is exactly the kind of second entry point §1.1's invariants exist to prevent — even unreferenced, it is a future merge conflict waiting to be wired back in by mistake. Deleting it costs nothing `git` cannot restore. |
| 2026-09-03 | The wallet's page-index computation is a pure function in `MixtapeServices`, called by `WalletPage`, not a `MixtapePresentation`-local helper. | Writing it as a private function inside the `WalletPage` view file; adding a `MixtapePresentationTests` target to test it there. | No `MixtapePresentationTests` target exists in the §3 tree and slice 001 did not create one — inventing one is out of this slice's scope. `MixtapeServices` is already a dependency of `MixtapePresentation`, so the function is reachable from the view exactly as before, and it gets a `.service`-tagged test for free. |

## 7. Sub-Slices

Not split — delivered as a single slice.

## 8. Testing Strategy

- **Unit / Integration / UI:** `MixtapeServicesTests` gets the wallet page-index pure function tested against both the 2×2 and 3×3 layouts, including a partial final page. The `MusicPlayerService` §1.1 invariants suite from slices 008/009 already covers `finishedAlbumID` firing exactly once and `acknowledgeFinish()` clearing it — this slice consumes that trigger and does not duplicate its tests. No UI test is written (decision 4); AC13a–AC13e are demonstrated manually on the iPhone and iPad simulators per Section 5.
- **Test targets required:** `MixtapeServicesTests` (exists from slice 001; used here, not created).

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

- [ ] Acceptance criteria met
- [ ] Tests passing, in a target that exists
- [ ] Every `covers:` requirement satisfied, or forked with a decision row
- [ ] Decision log written as you went, not reconstructed
- [ ] Pre-flight completed and drift resolved
- [ ] Master checklist row current
- [ ] `next_slice`'s `depends_on` reflects what actually shipped, not what was planned
- [ ] Both link directions checked: this page's `next_slice` and that page's `previous_slice`

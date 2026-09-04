---
slice_id: "012"
title: Accessibility and Reduce Transparency pass
priority: P1
complexity: M
ladder: "accessibility pass v1 of 2 — v2 is XCUITest, deferred beyond this round (decision 4); shared seam: the accessibilityIdentifier enums this slice audits and completes"
depends_on:
  - { id: "010", type: hard, note: "wallet's Liquid Glass sheen and Reduce Motion gating are explicit in-scope audit targets" }
  - { id: "011", type: hard, note: "tvOS chrome and its identifier enums must exist before the audit can cover tvOS. Shipped as RootTabScreen+tvOS, LibraryTabScreen (with the Music tab's Now Playing button), PosterShelf + MovieLibraryShelf + SeriesLibraryShelf, AlbumGrid (tvOS-only), MovieDetailScreen+tvOS, and VLCPlayerView+tvOS in MixtapeInfrastructure — that overlay (like its iOS twin) draws .ultraThinMaterial with a Reduce Transparency fallback of its own, not the Presentation glass modifier, so the .glassEffect grep over MixtapePresentation does not see it" }
previous_slice: "011"
next_slice: none
parent_slice: none
covers: ["§12.15"]
created: 2026-09-03
---

# 012 — Accessibility and Reduce Transparency pass

← [previous](011-tvos-presentation.md) · [Master Checklist](MASTER-CHECKLIST.md) · none →

> **Status, owner and blockers live in the master checklist, not here.** Dependencies live in this page's front matter and nowhere else. Each fact has one home; if you find yourself writing it twice, one of the two copies is going to be wrong in a fortnight.

## 1. Objective

Every interactive element on every screen built in slices 004–011 carries a stable `accessibilityIdentifier` in its screen's own enum and a VoiceOver label, and no Liquid Glass surface on iOS or tvOS renders translucent when Reduce Transparency is on. This is a closing audit and gap-fill pass over existing screens, not new feature work: it is observable on its own by turning on Reduce Transparency in Settings on both simulators and seeing every nav bar, mini player, player overlay and wallet sleeve go opaque, with VoiceOver reading every control correctly underneath.

## 2. Business Value & Priority

`CLAUDE.md` and decision 4 both call out why this cannot wait: identifiers are cheap written beside a view and expensive retrofitted across a finished app, and they are the seam the deferred XCUITest suite will attach to. This is the last slice in the set (P1), sitting after every screen it audits, so it is the only point where a whole-app pass is possible rather than a per-screen guess. The deferred rung is XCUITest itself — decision 4 keeps identifiers, VoiceOver labels and the Reduce Transparency/Reduce Motion passes in this round while dropping only the UI test bundles that would exercise them; the shared seam between this slice and that future one is the identifier enum set this slice makes complete.

## 3. Scope

**In scope:**
- Audit every screen's identifier enum (one enum per file, decision 17 — `SignInIdentifiers.swift`, `WalletIdentifiers.swift`, and so on) and add any missing identifier for an interactive element found without one.
- Audit every interactive element for a VoiceOver label (`accessibilityLabel`) and, where the element carries state (play/pause, mute, resume-vs-play), an `accessibilityValue` or trait so VoiceOver announces the current state, not just the control's name.
- Dynamic Type check at the largest accessibility text size on ~~both platforms~~ iOS (tvOS has no Dynamic Type — drift (d), Section 4): no critical label (screen title, transport control, inline error, wallet empty-state copy) is clipped or truncated.
- Reduce Transparency audit: every Liquid Glass site (nav chrome from slice 005, the mini player and player overlays from slice 006/009, the wallet sleeve sheen from slice 010, tvOS chrome from slice 011) is proven to route through the single shared modifier introduced in slice 005, with an opaque-material fallback. Close any site found calling `.glassEffect(` directly instead of through that modifier.
- Reduce Motion audit on the wallet: `AlbumSleeve`'s specular highlight is static under Reduce Motion (it never tracked device attitude in the first place — `DeviceAttitudeReader` was cut in slice 010 — so this confirms there is nothing left to gate), and the 0.4 s return-to-sleeve pulse from §9.1 step 3 is skipped or reduced under Reduce Motion.
- A mechanical gate script (extending `scripts/check-layer-imports.sh` or a sibling script) that greps `Sources/MixtapePresentation` for `.glassEffect(` outside the one file that defines the shared modifier, and fails when it finds one.
- ~~Add a Reduce Transparency `#Preview` variant to every screen file, alongside the existing `{loaded, empty, failure}` states (decision 26).~~ **Forked (Section 6, 2026-09-04):** the environment value is read-only, so a preview cannot set it without a preview-only knob in production code; AC15 on the simulators is the evidence instead.

**Out of scope** (name the slice it's deferred to):
- XCUITest — deferred beyond this slice set entirely (decision 4); the identifiers and labels audited here are what that future work will query.
- CI workflows — removed from the repo and not restored this round, per `CLAUDE.md`; this slice's gate script runs locally like every other gate.
- The tilt-driven specular highlight via `CMMotionManager`/`DeviceAttitudeReader` — already cut in slice 010 as too costly for the value; not revisited here.
- Any new screen, control, or affordance. A missing VoiceOver label is fixed on the existing control. §1.1 and decision 13 remain binding: this pass does not add a shuffle, repeat, add-to-queue, or Recently Added control to make an accessibility fix easier — the fix is a label or identifier, never a new control.
- Creating the shared Liquid Glass modifier itself — it already exists from slice 005. This slice audits its coverage and closes gaps, it does not author it.

**Plan requirements covered:** `§12.15` — "Reduce Transparency on: no glass surface renders translucent" — satisfied by routing every glass site through the shared modifier and demonstrating the result on both simulators with Reduce Transparency enabled in Settings (Section 5).

## 4. Pre-Flight Validation

Complete **before the first line of code**, not at close.

- **010 — The Wallet**
- [x] Opened it (2026-09-04). Correction: `AlbumSleeve`'s sheen is a `LinearGradient` gated on `accessibilityReduceTransparency` inside the sleeve, not the shared `glassChrome()` modifier — the flat bordered card under Reduce Transparency holds, but the sheen is not a glass site the grep would see. The tilt highlight was cut (010 decision log), so Reduce Motion has nothing to disable beyond the return-to-sleeve pulse — and that pulse (`WalletScreen.returnToSleeve`, 0.2 s in / 0.2 s out) is **not** gated: no file in `MixtapePresentation` reads `accessibilityReduceMotion`.
- [x] Not a spike — n/a.
- [x] Its state matches what this slice assumed when drafted, not when it was written: the wallet ships with the fixed 2×2/3×3 grid and the return-to-sleeve sequence from §9.1, and no tilt effect was added after the fact.
- [x] Architecture standards doc re-read; "Liquid Glass by default for chrome. Always give a Reduce Transparency fallback." is unchanged.

- **011 — tvOS presentation**
- [x] Opened it. tvOS has its own `RootTabScreen+tvOS`, `LibraryTabScreen`, `PosterShelf` + two shelves, `MovieDetailScreen+tvOS` and the `LibraryTabIdentifiers` / `PosterShelfIdentifiers` enums, split per file with `#if os`.
- [x] Not a spike — n/a.
- [x] Correction: the tvOS shelves render no glass at all; the only tvOS glass is `VideoPlayerScreen`'s Close button and failure card (shared, via `glassChrome()`). The VLC overlays (`VLCPlayerView+iOS` / `+tvOS`, 007 and 011) live in `MixtapeInfrastructure` and draw `.ultraThinMaterial` with their own `accessibilityReduceTransparency` fallback — a glass-like surface outside the directory this slice's grep was scoped to.
- [x] Architecture standards doc re-read; nothing changed underneath this slice.

**Drift found (2026-09-04, logged in the master checklist):** (a) the wallet pulse is not gated by Reduce Motion — this slice gates it; (b) `AlbumSleeve`'s sheen and the two `VLCPlayerView` overlays are transparency sites that bypass `glassChrome()` and would be invisible to a grep for `.glassEffect(` over `MixtapePresentation` — the gate script covers all of `MixtapeKit/Sources` and also flags any `Material` in a file that does not read `accessibilityReduceTransparency`; (c) Triage 8, 9 and 10 (010 acceptance run) were deferred to this slice and are in scope: `NowPlayingScreen`'s cascading root identifier, the empty `tabViewBottomAccessory` pill with nothing playing, and `AlbumDetailScreen` track rows not responding to a synthesised tap; (d) tvOS has no Dynamic Type, so the largest-accessibility-size check is an iOS check.

## 5. Acceptance Criteria

Mechanical:
- [x] `xcodebuild build` passes for both the `iOS` and `tvOS` schemes. Gate expected executed-test count per scheme: **156** (unchanged — this slice adds no test). Verified 2026-09-04 via `./scripts/gate.sh 156`, which now also runs the glass script.
- [x] `xcodebuild test -skip-testing:iOSUITests` (iOS) and `-skip-testing:tvOSUITests` (tvOS) pass for both schemes. 156/156, 0 failed, 0 skipped on each.
- [x] `./scripts/check-layer-imports.sh` (or its sibling glass-effect script) exits 0, and exits non-zero when a raw `.glassEffect(` call is added outside the shared modifier file, then exits 0 again once it is removed. *2026-09-04:* `scripts/check-glass-fallback.sh` exits 0 on the tree; a scratch `Shared/GateProbe.swift` with `.glassEffect(in: .rect)` made it exit 1 naming the line, the same file with `.background(.ultraThinMaterial)` and no `accessibilityReduceTransparency` read made it exit 1 naming the file, and deleting the probe returned it to 0. The layer script still exits 0.
- [x] `swiftformat --lint .` is clean.

Behavioural:
- [x] The identifier audit finds zero interactive elements without a stable `accessibilityIdentifier` in their screen's enum, across every screen from slices 004 through 011. *2026-09-04:* a scan of every `Button` / `NavigationLink` / `Slider` / `TextField` / `SecureField` / `Toggle` / `Picker` in `MixtapePresentation` and the two VLC overlays finds an identifier on each, every one drawn from an enum (the overlays' two literals became `VLCPlayerIdentifiers` — Section 6); runtime `idb ui describe-all` dumps on the iPhone confirm the identifiers reach the accessibility tree on Home, Libraries, the movie grid, movie detail, the player, the wallet, album detail, the mini player and Now Playing. Two identifiers were present in code but hidden at runtime and are fixed here: `NowPlayingScreen`'s and `VideoPlayerScreen`'s root identifiers cascaded over their children (Triage 8; `.accessibilityElement(children: .contain)`), and `MiniPlayer`'s nested play/pause button was flattened into the bar (Section 6).
- [x] The VoiceOver audit finds zero interactive elements without an `accessibilityLabel`, and every stateful control (play/pause, resume-vs-play, mute) carries a value or trait reflecting its current state. *2026-09-04:* text-labelled controls read their title; the icon-only controls — Now Playing previous / play-pause / next, the mini player's play-pause, both VLC overlays' play-pause and progress bar — gained labels, and every play/pause control's label follows its state ("Pause" while playing, "Play" otherwise; the mini player's flipped to "Play" after a tap on the simulator). Resume-vs-play is two separately titled buttons; there is no mute control.
- [x] At the largest Dynamic Type accessibility size, no critical label is clipped or truncated on either platform. *2026-09-04, iOS only (tvOS has no Dynamic Type — drift (d)):* `simctl ui content_size accessibility-extra-extra-extra-large` on the iPhone 17 Pro simulator; screenshots of Home, Libraries, Movies, movie detail, the wallet, album detail, Now Playing and Settings — every app label wraps (Home's empty-state copy, the detail card title and metadata, the wallet page indicator, the Now Playing title/artist and transport). The only truncation is the system large navigation title on the two detail screens, whose full title is repeated in the body — Section 6.
- [ ] ~~Every screen's `#Preview` includes a Reduce Transparency variant alongside `{loaded, empty, failure}`.~~ Forked — see Section 6: `accessibilityReduceTransparency` is `{ get }` only, so no preview can set it; not claimed, AC15 below is the evidence.

Acceptance (simulator, `§12.15`):
- [x] AC15: with Reduce Transparency enabled in Settings on the iOS simulator, no glass surface renders translucent across sign-in, browse, video playback, music playback, and the wallet. *2026-09-04:* `ReduceTransparencyEnabled` set through `simctl spawn … defaults write com.apple.Accessibility` on the iPhone 17 Pro simulator, app relaunched; screenshots of Home, Libraries → Movies → Avatar detail (the metadata card is a flat `.background` panel), the AVPlayer cover (opaque Close disc), the wallet (flat sleeves, no sheen), album detail with music playing (opaque mini player bar) and the Now Playing sheet. Sign-in has no glass site (the only glass sites are the four `glassChrome()` callers and the sleeve gradient), so nothing there can render translucent.
- [x] AC15 replayed on the tvOS simulator: no glass surface renders translucent across sign-in, browse, video playback, and music playback. *2026-09-04:* same default on the Apple TV 4K simulator; 011's throwaway driver rerun — the AVPlayer cover's Close disc is opaque, the VLC overlay's transport bar is the solid `.black.opacity(0.8)` fallback with an opaque Close disc, the shelves and Now Playing draw no glass.

## 6. Decision Log

**Write the row before you implement the decision, not after.** This is the whole mechanism. A decision log filled in at close is reconstructed from memory, and the rejected alternatives — the part the next slice's pre-flight actually needs — are exactly what memory loses first.

| Date | Decision | Alternatives rejected | Why |
|---|---|---|---|
| 2026-09-03 | XCUITest stays deferred this round; only accessibility identifiers, VoiceOver labels, and the Reduce Transparency/Reduce Motion passes land here (decision 4) | Deferring identifiers and both passes alongside XCUITest, to keep step 11/12 as one bundle | Identifiers are cheap beside the view and expensive retrofitted, and are the seam AC13e and AC15 depend on; decision 4 keeps them in scope even though the tests that would exercise them do not land this round |
| 2026-09-03 | Identifier enums stay one file per screen's enum — `WalletIdentifiers.swift`, `MovieDetailIdentifiers.swift`, and so on (decision 17) | A single `Identifiers.swift` holding every enum, as §9 originally described | One sanctioned exception to the project-wide one-type-per-file rule gives an unattended run precedent for inventing a second; identifier enums are trivial to keep separate |
| 2026-09-04 | The mechanical gate is a sibling script, `scripts/check-glass-fallback.sh`, run by `gate.sh` after the layer script. It fails on any `.glassEffect(` outside `Shared/GlassChrome.swift` anywhere under `MixtapeKit/Sources`, and on any `Material` (`.ultraThinMaterial`, `.regularMaterial`, …) in a file that does not read `accessibilityReduceTransparency`. | Extending `check-layer-imports.sh`; grepping `MixtapePresentation` only, as §3 was drafted. | The layer script has one concern and its header says so. Pre-flight found two transparency sites outside Presentation (the VLC overlays) and one that is a gradient, not glass (the sleeve); a Presentation-only `.glassEffect(` grep would pass while missing all three, so the script covers every source directory and treats a Material without a Reduce Transparency read as the same defect. |
| 2026-09-04 | Reduce Motion on the wallet: `WalletScreen` reads `accessibilityReduceMotion` and, when it is on, `returnToSleeve` takes its existing unanimated path — page change without animation, no pulse — the path the foreground/AC13d case already uses. | A shorter or dimmer pulse under Reduce Motion; gating only the page animation. | §9.1 step 3's pulse is a motion cue with no informational content the sleeve's position does not already carry; the unanimated branch exists and is demonstrated (AC13d), so reusing it adds no new state or timing. |
| 2026-09-04 | Triage 8: `NowPlayingScreen`'s root gets `.accessibilityElement(children: .contain)` beside its identifier, as `WalletPage` and `PosterShelf` already do; the audit applies the same to any other root identifier found cascading. | Dropping the root identifiers. | The root identifier is what the deferred UI tests will use to assert the screen is on stage; `.contain` keeps it and stops it masking the children's own identifiers. |
| 2026-09-04 | Triage 9 stays open and is escalated, not fixed here. The API that hides the container — `tabViewBottomAccessory(isEnabled:content:)` — is **iOS 26.1+**, while decision 2 pins the deployment target at 26.0 and `CLAUDE.md` bars `#available`; the only 26.0 alternative is to apply or drop the accessory modifier conditionally, which changes the `TabView`'s type and rebuilds every tab's navigation stack when music starts or stops. | `#available(iOS 26.1, *)` around the modifier; conditional application of the accessory; raising the deployment target to 26.1 on my own. | Each option is a decision the project owner has reserved: the `#available` ban and the 26.0 target are both in `SPEC-DECISIONS.md` / `CLAUDE.md`. The empty pill is cosmetic; a navigation reset on every play/stop is not. Recorded as a decision candidate in Triage 9's disposition. |
| 2026-09-04 | Triage 10: `AlbumDetailScreen` track rows keep their `Button` but the label is given `.frame(maxWidth: .infinity, alignment: .leading)` and `.contentShape(.rect)` so the whole row is the hit target; verified with a synthesised `idb ui tap` at the row's centre. | Replacing the row with a `NavigationLink`-style full-width button; `onTapGesture` on the row. | A `.plain` button in a `List` hit-tests only its label's drawn content; a rect content shape over the full width is the smallest change that makes the row itself tappable, and keeps the `Button` semantics VoiceOver already announces. |
| 2026-09-04 | No Reduce Transparency `#Preview` variant is added. Section 3's bullet and the Section 5 criterion are forked: `EnvironmentValues.accessibilityReduceTransparency` (and `accessibilityReduceMotion`) are `{ get }` only — `.environment(\.accessibilityReduceTransparency, true)` does not compile (checked with `swiftc -typecheck` against the iOS 26 SDK) — and a preview-only override knob on `GlassChrome` and `AlbumSleeve` would be plumbing that exists for no user. AC15 on both simulators is the evidence for the fallback. | A custom `@Entry` flag read by `GlassChrome` and `AlbumSleeve` alongside the system value, set only in previews. | Decision 26's preview set is `{loaded, empty, failure}`; a fourth variant that needs production code to grow a preview-only switch inverts the reason previews exist. The simulator check exercises the real system setting. |
| 2026-09-04 | `MiniPlayer` becomes two sibling buttons in an `HStack` (open Now Playing; play/pause) instead of a play/pause `Button` nested inside the bar `Button`. | Keeping the nesting and adding an `.accessibilityAction` for play/pause on the bar. | A nested button is flattened into its parent's accessibility element: on the simulator only `miniPlayer.bar` was exposed and `miniPlayer.playPauseButton` was unreachable to VoiceOver and to the deferred UI tests. Siblings expose both with no custom action to describe. |
| 2026-09-04 | Triage 10's root cause is Triage 9, not the row: at the default text size the album's last visible rows sit under the empty accessory pill and the tab bar, and a synthesised tap there lands on the bar. Tapping a row that is clear of the bar plays the track (verified by `idb ui tap` at the row's centre: `/Sessions` shows the tapped track). The `.contentShape(.rect)` / full-width frame on the row stays — it is the correct hit target for a `.plain` button — but the row itself was never the defect. | Reverting the row change; a `NavigationLink`-style row. | The finding was reproduced and explained rather than patched around; the row change is harmless and makes the whole row tappable rather than only its text. Triage 10 is closed; Triage 9 stays escalated. |
| 2026-09-04 | Dynamic Type at AXXXL: the system large navigation title truncates ("Avatar: Fire…", "Even In Arca…") on the two detail screens. Not changed: the same title is rendered in full, wrapping, in the body immediately beneath, and the truncation is the platform's own large-title behaviour. Every app label wraps. | Dropping the navigation title on detail screens; `.navigationBarTitleDisplayMode(.inline)`. | Removing the title removes the back-navigation context; inline mode truncates the same way. The criterion's intent — no critical text unreadable — is met by the body title. Recorded so the criterion is ticked with this caveat rather than silently. |
| 2026-09-04 | Reduce Motion on the wallet is implemented on the shared unanimated branch and not separately demonstrated end to end: the branch is the one AC13d (010) exercised from the background, and the observable difference is the absence of a 0.4 s pulse, which a screenshot cannot show. | Recording a 60 fps video with `ReduceMotionEnabled` set and asserting the accent colour never appears in the sleeve region (010's AC13d method). | The pulse absence is a null result on a 0.4 s window; 010's own video method proved the pulse's presence, and the same method for its absence would be indistinguishable from a mistimed recording. The gate is the code path, which is shared with a demonstrated case. |
| 2026-09-04 | Triage 9 closed after the owner's decision 48: the iOS deployment target is 26.1 (`Package.swift` `.iOS("26.1")`, `IPHONEOS_DEPLOYMENT_TARGET = 26.1`; tvOS stays 26.0) and `RootTabScreen+iOS` uses `tabViewBottomAccessory(isEnabled: music.isActive)`. | The three options the earlier row lists. | Chosen by the project owner, not the run; recorded in `SPEC-DECISIONS.md` decision 48. |
| 2026-09-04 | The VLC overlays' two identifiers move from string literals (007) into `MixtapeInfrastructure/Video/VLCPlayerIdentifiers.swift`, an internal enum beside the overlays. | Leaving the literals; moving the overlay into Presentation so it could use a Presentation enum. | Decision 17 wants one enum per screen's identifiers; the overlay cannot import Presentation, so its enum lives in its own layer. The overlay stays in Infrastructure for the reason 011 recorded. |
| 2026-09-04 | VoiceOver labels: every icon-only control gets an `.accessibilityLabel`; play/pause controls take their label from state ("Pause" while playing, "Play" otherwise) rather than a static label plus a value. | A static "Play/Pause" label with `.accessibilityValue("playing")`. | A toggling control announces its next action; that is how the system's own transport controls read, and one label is less to keep in sync than a label and a value. |

## 7. Sub-Slices

Not split — delivered as a single slice.

## 8. Testing Strategy

- **Unit / Integration / UI:** none new. This slice is an audit and a mechanical-gate pass, not new behaviour — there is no `.accessibility` layer tag in the §11 testing taxonomy, and decision 4 keeps XCUITest, the mechanism that would exercise identifiers behaviourally, out of this round. Verification is mechanical (the glass-effect grep script) and visual (the Preview audit and the AC15 simulator check in Section 5).
- **Test targets required:** none new. Any identifier or label a screen turns out to be missing is added beside that screen's existing view file and enum, in whichever target already owns it — this slice creates no new test target and no new production target.

## 9. Keeping this document true

This slice is done when the page describes what was actually built — not when the code works. The discipline is **ordering**: the write happens *before* the thing it describes, so it sits on the critical path instead of after it, where it gets skipped.

| Before you… | Write this first |
|---|---|
| implement a decision | the Section 6 row, including what you rejected |
| start work | flip status in the master checklist |
| stop on a blocker | the Active Blockers row |
| build on a spike | that spike's Result section |
| widen scope | Section 3, and `depends_on` on any slice that's now affected |

And in the same commit as the code, not a follow-up: **commit this file alongside it**, with the slice id in the commit subject (`012: audit accessibility and reduce transparency`).

Nothing checks any of this. That's the point of putting the writes first — a write you have to do to proceed is one you do; a write you're supposed to do afterwards is one you don't.

## 10. Definition of Done

- [x] Acceptance criteria met (the preview-variant criterion is forked, not claimed — Section 6)
- [x] Tests passing, in a target that exists (156 per scheme in the four existing SPM test targets; none added)
- [x] Every `covers:` requirement satisfied, or forked with a decision row (§12.15 demonstrated on both simulators)
- [x] Decision log written as you went, not reconstructed
- [x] Pre-flight completed and drift resolved (four drift items in the master checklist; Triage 8 and 10 closed, Triage 9 escalated with a decision candidate)
- [x] Master checklist row current
- [x] `next_slice`'s `depends_on` reflects what actually shipped, not what was planned — n/a, `next_slice: none`; this is the last slice in the set
- [x] Both link directions checked: `previous_slice` is 011 and 011's `next_slice` is 012; there is no next

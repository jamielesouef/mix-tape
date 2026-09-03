---
slice_id: "012"
title: Accessibility and Reduce Transparency pass
priority: P1
complexity: M
ladder: "accessibility pass v1 of 2 — v2 is XCUITest, deferred beyond this round (decision 4); shared seam: the accessibilityIdentifier enums this slice audits and completes"
depends_on:
  - { id: "010", type: hard, note: "wallet's Liquid Glass sheen and Reduce Motion gating are explicit in-scope audit targets" }
  - { id: "011", type: hard, note: "tvOS chrome and its identifier enums must exist before the audit can cover tvOS" }
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
- Dynamic Type check at the largest accessibility text size on both platforms: no critical label (screen title, transport control, inline error, wallet empty-state copy) is clipped or truncated.
- Reduce Transparency audit: every Liquid Glass site (nav chrome from slice 005, the mini player and player overlays from slice 006/009, the wallet sleeve sheen from slice 010, tvOS chrome from slice 011) is proven to route through the single shared modifier introduced in slice 005, with an opaque-material fallback. Close any site found calling `.glassEffect(` directly instead of through that modifier.
- Reduce Motion audit on the wallet: `AlbumSleeve`'s specular highlight is static under Reduce Motion (it never tracked device attitude in the first place — `DeviceAttitudeReader` was cut in slice 010 — so this confirms there is nothing left to gate), and the 0.4 s return-to-sleeve pulse from §9.1 step 3 is skipped or reduced under Reduce Motion.
- A mechanical gate script (extending `scripts/check-layer-imports.sh` or a sibling script) that greps `Sources/MixtapePresentation` for `.glassEffect(` outside the one file that defines the shared modifier, and fails when it finds one.
- Add a Reduce Transparency `#Preview` variant to every screen file, alongside the existing `{loaded, empty, failure}` states (decision 26).

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
- [ ] Opened it. Its decision log still says what this slice assumed: `AlbumSleeve` renders its sheen through the shared Liquid Glass modifier with a flat-card fallback under Reduce Transparency, and the tilt highlight was cut rather than gated, so Reduce Motion has nothing to disable beyond the return-to-sleeve pulse.
- [ ] Not a spike — n/a.
- [ ] Its state matches what this slice assumed when drafted, not when it was written: the wallet ships with the fixed 2×2/3×3 grid and the return-to-sleeve sequence from §9.1, and no tilt effect was added after the fact.
- [ ] Architecture standards doc re-read; nothing changed underneath this slice.

- **011 — tvOS presentation**
- [ ] Opened it. Its decision log still says what this slice assumed: tvOS has its own `RootTabScreen`, shelves, and identifier enums for every signed-in surface, split from the iOS files with `#if os` per file rather than in-body branching.
- [ ] Not a spike — n/a.
- [ ] Its state matches what this slice assumed when drafted, not when it was written: tvOS chrome uses the same shared Liquid Glass modifier as iOS wherever it renders glass, so the mechanical grep applies to both platform files equally.
- [ ] Architecture standards doc re-read; nothing changed underneath this slice.

**Drift found:** `none`.

## 5. Acceptance Criteria

Mechanical:
- [ ] `xcodebuild build` passes for both the `iOS` and `tvOS` schemes.
- [ ] `xcodebuild test -skip-testing:iOSUITests` (iOS) and `-skip-testing:tvOSUITests` (tvOS) pass for both schemes.
- [ ] `./scripts/check-layer-imports.sh` (or its sibling glass-effect script) exits 0, and exits non-zero when a raw `.glassEffect(` call is added outside the shared modifier file, then exits 0 again once it is removed.
- [ ] `swiftformat --lint .` is clean.

Behavioural:
- [ ] The identifier audit finds zero interactive elements without a stable `accessibilityIdentifier` in their screen's enum, across every screen from slices 004 through 011.
- [ ] The VoiceOver audit finds zero interactive elements without an `accessibilityLabel`, and every stateful control (play/pause, resume-vs-play, mute) carries a value or trait reflecting its current state.
- [ ] At the largest Dynamic Type accessibility size, no critical label is clipped or truncated on either platform.
- [ ] Every screen's `#Preview` includes a Reduce Transparency variant alongside `{loaded, empty, failure}`.

Acceptance (simulator, `§12.15`):
- [ ] AC15: with Reduce Transparency enabled in Settings on the iOS simulator, no glass surface renders translucent across sign-in, browse, video playback, music playback, and the wallet.
- [ ] AC15 replayed on the tvOS simulator: no glass surface renders translucent across sign-in, browse, video playback, and music playback.

## 6. Decision Log

**Write the row before you implement the decision, not after.** This is the whole mechanism. A decision log filled in at close is reconstructed from memory, and the rejected alternatives — the part the next slice's pre-flight actually needs — are exactly what memory loses first.

| Date | Decision | Alternatives rejected | Why |
|---|---|---|---|
| 2026-09-03 | XCUITest stays deferred this round; only accessibility identifiers, VoiceOver labels, and the Reduce Transparency/Reduce Motion passes land here (decision 4) | Deferring identifiers and both passes alongside XCUITest, to keep step 11/12 as one bundle | Identifiers are cheap beside the view and expensive retrofitted, and are the seam AC13e and AC15 depend on; decision 4 keeps them in scope even though the tests that would exercise them do not land this round |
| 2026-09-03 | Identifier enums stay one file per screen's enum — `WalletIdentifiers.swift`, `MovieDetailIdentifiers.swift`, and so on (decision 17) | A single `Identifiers.swift` holding every enum, as §9 originally described | One sanctioned exception to the project-wide one-type-per-file rule gives an unattended run precedent for inventing a second; identifier enums are trivial to keep separate |

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

- [ ] Acceptance criteria met
- [ ] Tests passing, in a target that exists
- [ ] Every `covers:` requirement satisfied, or forked with a decision row
- [ ] Decision log written as you went, not reconstructed
- [ ] Pre-flight completed and drift resolved
- [ ] Master checklist row current
- [ ] `next_slice`'s `depends_on` reflects what actually shipped, not what was planned
- [ ] Both link directions checked: this page's `next_slice` and that page's `previous_slice`

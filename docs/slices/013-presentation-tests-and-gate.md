---
slice_id: "013"
title: Presentation test target and gate hardening
priority: P0
complexity: L
ladder: "verification v2 of 3 — v1 was the four SPM suites and the two grep scripts (slice 001); v3 is XCUITest, still deferred (decision 4). Shared seam: scripts/gate.sh, which every rung calls and which stays the one command a workflow runs"
depends_on:
  - { id: "012", type: hard, note: "the last slice of the V1 set — this slice hardens the gate that declared it done, so it must run after the thing it is auditing" }
  - { id: "S003", type: hard, note: "the one open site the hardened glass gate flags. An unanswered spike is a hard dependency: whether §12.15 needs code or only an annotation is exactly what S003 returns" }
previous_slice: "012"
next_slice: "014"
parent_slice: none
covers: []
created: 2026-09-04
---

# 013 — Presentation test target and gate hardening

← [previous](012-accessibility-and-reduce-transparency.md) · [Master Checklist](MASTER-CHECKLIST.md) · [next](014-video-reporting-completeness.md) →

> **Status, owner and blockers live in the master checklist, not here.** Dependencies live in this page's front matter and nowhere else. Each fact has one home; if you find yourself writing it twice, one of the two copies is going to be wrong in a fortnight.

## 1. Objective

`MixtapePresentation` gets a test target, and `scripts/gate.sh` stops taking the number it
asserts against as an argument. Observable on its own: delete a test and the gate fails
without anyone editing a command line; introduce an ungated Material and the glass script
names the line, not the file.

## 2. Business Value & Priority

This is P0 and first in the round because it is the slice that makes the rest of the round
verifiable. Slices 014 and 015 both fix defects that live in `MixtapePresentation` and in
service orchestration — the wallet's return sequence, the mini player's sheet, transport
routing. There is nowhere for a regression test on any of that to run today: the layer is
73 files with no target, and decision 4 correctly deferred XCUITest, which left the whole
UI unverified by anything except a prose record of a manual acceptance run.

The gate's own weaknesses compound it. `gate.sh:9` reads `expected=${1:?…}`, so the agent
running the gate supplies the number the gate checks — a regression that removes tests
passes by passing a smaller argument. Nothing in the repository records that any gate ever
ran, on which commit, with what result. "Every commit passed the full gate" is currently
unfalsifiable from the tree, which is a poor foundation for an unattended pipeline.

Ladder: this is v2 of three rungs of verification. v1 was slice 001's four SPM suites and
two grep scripts. v3 is XCUITest, which decision 4 defers past this round and which will
attach to the identifier enums slice 012 completed. The seam all three share is
`scripts/gate.sh` — each rung adds steps to the same script, and no caller changes.

## 3. Scope

**In scope:**

- A `MixtapePresentationTests` target in `MixtapeKit/Package.swift`, tagged `.presentation`
  alongside the existing `.domain` / `.useCase` / `.service` / `.repository` tags, and added
  to both shared schemes' testables so it runs in the gate on each platform.
- Seed it with tests for the logic the audit found untested and about to be changed:
  `WalletScreen`'s page resolution against a `MockLibraryService`, `MiniPlayer`'s active
  gating, and the `LoadState` → view-state mapping each screen switches on. Behaviour, not
  the mock's plumbing (§11).
- `gate.sh` derives the expected test count instead of accepting it. Count `@Test`
  declarations across `MixtapeKit/Tests` in the script, or read a committed
  `docs/slices/test-count.txt` that a failing gate tells you to update deliberately.
  Whichever, the number stops being a caller's assertion about itself.
- `gate.sh` asserts a per-suite count, not just per-suite presence. `:62-64` currently
  greps for each suite name, which passes if one test in it ran; tests can migrate between
  suites with the total unchanged.
- `gate.sh` leaves an artefact: append one line per run to a gitignored
  `.gate-log` — commit SHA, date, per-scheme totals, pass or fail — and stop deleting the
  result bundles at `:11` before the run that produced them has been read.
- `check-layer-imports.sh` scope widened from `MixtapeKit/Sources` to include `Apps/`, with
  the composition root (`Apps/Shared/AppContainer.swift`, §10) as the single named exception
  permitted to import all six layers. Today nothing enforces that only it does.
- The layer-import build phase added to the **tvOS** app target. It exists on iOS only
  (`pbxproj:180`), so a tvOS-only build never runs it.
- `Mock*` files moved behind `#if DEBUG` in `MixtapeServices/Mocks/` (9 files) and
  `MixtapeUseCase/Mocks/` (5 files). They currently link into both release apps. `#Preview`
  is debug-only, so nothing that uses them is lost.
- Resolve the one site the hardened glass gate flags, per S003's answer or its fallback.

**Out of scope** (name the slice it's deferred to):

- XCUITest, and any change to the two template stub files in `uiTests/`. Decision 4 stands;
  its rationale is the `objectVersion = 77` pin, which this slice must not disturb either.
- The three tautological test declarations the audit found
  (`QuickConnectUIStateTests`, `MixtapeErrorTests`, and `ReportPlaybackStartUseCaseTests`'s
  assertion-free case). They are real compile-time checks and rewriting them is not worth a
  gate change. Recorded here so the next audit does not re-raise them.
- Snapshot testing. A `MixtapePresentationTests` target is not a licence to add an image-diff
  dependency — VLCKit stays the only third-party dependency (`CLAUDE.md`).

**Plan requirements covered:** none. Like slices 001–003 this is foundation: it claims no
§1 capability and no §12 criterion, and is gated on builds, tests and the scripts alone.
It does, however, carry the resolution of the §12.15 site S003 measures — if S003 comes back
unfavourable, §12.15's coverage row gains 013 alongside 012 and this `covers:` list changes
with it.

## 4. Pre-Flight Validation

Complete **before the first line of code**, not at close.

- [x] **012** — opened. Its decision log still says the Reduce Transparency audit routed every
      app-drawn glass surface through `glassChrome()` and that the preview-variant idea was
      forked because the environment value is read-only. Confirm drift row (b) — the
      Infrastructure VLC overlays and the sleeve sheen sitting outside the Presentation grep —
      is still the shape this slice's per-site gate assumes.
- [x] **S003** — answered 2026-09-04, favourably: fallback not taken, Section 3's last bullet stays the annotation. Confirm this slice is built on the measured answer, not the hoped-for
      one. Note whether the fallback was taken; if it was, Section 3's last bullet becomes the
      safe-area-inset rework and complexity rises.
- [x] Architecture standards doc re-read. Confirm `CLAUDE.md`'s two hard constraints are
      unchanged: `MixTape.xcodeproj` stays at `objectVersion = 77` with
      `preferredProjectObjectVersion = 77`, and nothing newer than Swift 6.2 is written.
      **Adding a test target is the single highest-risk action in this round for the
      `objectVersion` pin** — prefer editing `Package.swift` and the scheme XML directly over
      any action that makes Xcode 27 rewrite the project file, and diff `pbxproj` before
      committing.
- [x] Confirm the count this slice will derive matches what the gate currently asserts:
      156 `@Test` declarations expanding to roughly 226 runtime cases. The gate compares
      against `totalTestCount` from `xcresulttool`; establish which of the two numbers that
      field reports *before* wiring the derivation, or the first hardened run fails for the
      wrong reason.

**Drift found:** three items, recorded in the checklist's Drift Log (2026-09-04, 013): the placeholders depend on the mocks, `#Preview`'s release behaviour was unmeasured, and the two platform-only screens mean presentation tests must be platform-shared.

## 5. Acceptance Criteria

- [x] `MixtapePresentationTests` exists, runs in both schemes, and its tests are tagged
      `.presentation`.
- [x] Deleting any one test and running `./scripts/gate.sh` with no arguments fails the gate.
- [x] Running `./scripts/gate.sh` with no arguments passes on a clean tree — the count is
      derived, and the usage line no longer demands one.
- [x] Moving a test from one suite to another, with the total unchanged, fails the gate.
- [x] Adding `.ultraThinMaterial` to any file, including one that already reads
      `accessibilityReduceTransparency` elsewhere, fails `check-glass-fallback.sh` and the
      failure names the line.
- [x] Adding `import MixtapeData` to a file under `Apps/` other than `AppContainer.swift`
      fails `check-layer-imports.sh`.
- [x] Building the tvOS scheme alone runs the layer-import phase.
- [x] A release build of both apps contains no `Mock*` type. Verify with `nm`/`strings` on the
      built binary, not by reading the source.
- [x] `.gate-log` gains a line per gate run, and the previous run's result bundle survives
      long enough to be read.
- [x] `git diff` on `MixTape.xcodeproj/project.pbxproj` shows `objectVersion = 77` and
      `preferredProjectObjectVersion = 77` unchanged.

**Evidence, 2026-09-04.** Every negative control was seen failing and then reverted: a test file removed (`MixtapeDomainTests declares 17 @Test but docs/slices/test-count.txt expects 20`, before any build), a test commented out (19 vs 20 — the count reads `^\s*@Test`, so a commented declaration does not count), a test file moved from `MixtapeDomainTests` to `MixtapeUseCaseTests` with the total unchanged (fails on the first suite that disagrees), `./scripts/gate.sh 156` (refused: the gate takes no arguments), `.ultraThinMaterial` added at `VLCPlayerView+iOS.swift:44` in a file that already reads `accessibilityReduceTransparency` (`MISS Material token … :44`, exit 1), `import MixtapeData` in `Apps/MixtapeiOS/MixtapeApp.swift` (`Apps must not import …`, exit 1), and `import MixtapeData` in `RootScreen.swift` under a tvOS-only build and an iOS-only build (both `** BUILD FAILED **` with the line named — after the `set -e` fix; before it, both built clean). Release builds of both apps: `nm` and `strings` on `iOS.app/iOS` and `tvOS.app/tvOS` report 0 lines containing `Mock` (the iOS baseline before this slice was 1087 and 40). Full gate: 167/0/0 on both schemes, five bundles each with its manifest count, `.gate-log` gained a `PASS` line after the three `FAIL` lines the controls wrote, and the previous run's bundles survive at `$TMPDIR/mixtape-gate.prev`. `objectVersion = 77` and `preferredProjectObjectVersion = 77` unchanged in the diff.

## 6. Decision Log

**Write the row before you implement the decision, not after.**

| Date | Decision | Alternatives rejected | Why |
|---|---|---|---|
| 2026-09-04 | Three pre-push fixes landed ahead of this slice, outside the round: tvOS `UIBackgroundModes`, the per-site rewrite of `check-glass-fallback.sh` with its `.barMaterial` regex bug fixed, and the tvOS Now Playing overlay moved outside the `NavigationStack`. Full gate re-run and passed (156/0/0 both schemes). | Holding all three for 013/014/016 | Two were one-line spec compliance and the third was a dead regex; carrying a known-wrong gate into the slice that hardens it would have meant writing 013's acceptance criteria against a script already known to be broken. The tvOS cover swap is unverified at runtime — 016 owns that check. |
| 2026-09-04 | S003 answered favourably: the system `tabViewBottomAccessory` container renders opaque on its own under Reduce Transparency (zero pixel shift in the container margins with content scrolling beneath, iOS 26.5 simulator). The one site the hardened glass gate flags is closed by its `// glass-fallback:` annotation, now stating the measured answer. | The Section 5 fallback — gating the accessory off under `accessibilityReduceTransparency` and rendering `MiniPlayer` in a `.safeAreaInset(edge: .bottom)` | The fallback exists to fix a defect the measurement shows is not there; taking it anyway would trade a verified system behaviour for a second, placement-divergent presentation and a runtime modifier switch with Triage 9 tab-reset risk. Scope and complexity of this slice unchanged. |
| 2026-09-04 | The expected test count is a committed per-suite manifest, `docs/slices/test-count.txt`, not a number derived in-script from `@Test` declarations. `gate.sh` checks the manifest twice: against the source tree's per-directory `@Test` count before any build (fail fast), and against each result bundle's per-`Unit test bundle` `Test Case` node count after the run. A failing check names the file to update deliberately. | Deriving the count in-script by grepping `@Test`; asserting the total only | A grep-derived count cannot satisfy the "moving a test between suites with the total unchanged fails" criterion: the move shifts the source count and the run count identically, so grep-versus-xcresult passes. Only a committed number catches it — and a committed number is reviewed in a diff, which is the property the caller-supplied argument lacked. Pre-flight settled which number `xcresulttool` reports: `totalTestCount` is 156, the `@Test` declarations; the 79 `Arguments` children of parameterised cases are not counted, and the per-bundle counts (20/41/53/42) equal the per-directory greps exactly. |
| 2026-09-04 | The `Mock*` wrap lands with a release branch in each `+Placeholder.swift`: `#if DEBUG` keeps the mock factory, `#else` builds the same service over inert conformers of the five `MixtapeUseCase` protocols (`Placeholder*Repository`, `PlaceholderSessionStore`, `PlaceholderImageURLBuilder`) and a silent `PlaceholderAudioPlayerController`; `VideoPlaybackService`'s release placeholder passes `makeController: { _ in nil }`. | (a) Leaving the mocks in release and dropping the `nm` criterion; (b) building the release placeholders over the real `AudioPlayerController()` to save a type | The pre-flight found the placeholders are release code that depends on the mocks (drift row). (a) scales the contract down, which is not the slice's call. (b) was rejected because `AudioPlayerController.init` registers `MPRemoteCommandCenter` targets — a placeholder that wires the lock screen to a service nothing owns is a footgun, and the inert class is twelve lines. |
| 2026-09-04 | Presentation tests test pure helpers extracted from the views — `WalletPager` (page resolution over a `LoadState<Page<MediaItem>>`), `ContentPhase` (the `LoadState` → view-state mapping), and `MiniPlayer.dockedTrack(in:)` (the active gating) — in platform-shared files, so the new suite compiles identically on both schemes and one manifest serves both. No view is rendered in a test. | Rendering views under a hosting controller; a snapshot dependency; a ViewModel layer to hold the logic | Rendering is XCUITest's job and decision 4 defers it; a snapshot library breaks the single-dependency rule; a ViewModel breaks MV. Small value-type helpers are the seam MV allows, and 015's single-owner and off-page tests need exactly this seam. The platform-shared rule exists because `WalletScreen` is iOS-only and `LibraryTabScreen` tvOS-only — a test that compiles on one scheme would split the counts. |
| 2026-09-04 | Every `#Preview` block in `MixtapeKit/Sources` and `Apps` (41 files) goes under `#if DEBUG` alongside the mocks. | Leaving the previews as they were; a preview-only module for the mocks | Measured, not assumed: with only the 14 `Mock*` files wrapped, a Release build of either app fails at the first preview — `ContinueWatchingCard.swift:38: cannot find 'MockMedia' in scope` — so `#Preview` bodies are compiled in Release and the slice's "`#Preview` is debug-only" premise was false. A separate module would move the problem, not remove it: the previews would still reference it from release code. The wrap is mechanical, and `swiftformat` owns the indentation. |
| 2026-09-04 | The tvOS layer-import build phase is a second `PBXShellScriptBuildPhase` object with its own identifier, referenced from the tvOS target, and the project file is edited by hand and validated with `plutil -lint` and `xcodebuild -list`. | Referencing the iOS phase's object from both targets' `buildPhases`; letting Xcode add the phase | A build phase object shared by two targets is not a shape Xcode writes and is not one to rely on it reading. Opening Xcode 27 rewrites `objectVersion` to 90. |
| 2026-09-04 | Both layer-import build phases run `set -e` before the script, are marked always-out-of-date, and the tvOS target sets `ENABLE_USER_SCRIPT_SANDBOXING = NO` as the iOS target already did. | Leaving the phases as the iOS one was written; declaring the script and every source file as sandbox inputs | The negative control found the phase had never been able to fail a build: `/bin/sh` runs `check-layer-imports.sh` then `touch`, and without `set -e` the `touch`'s exit code is the phase's, so a forbidden import built clean on iOS too. The control also found that Xcode's SPM integration lets `MixtapePresentation` import `MixtapeData` without a declared dependency — decision 1's "the compiler rejects the import outright" does not hold under Xcode, so the script is the only guard and the phase must fail. Always-out-of-date because a phase with an output stamp and no inputs is skipped on every incremental build; the check is a grep and costs nothing. Sandboxing off on tvOS because the script reads the whole source tree, which cannot be enumerated as inputs. |

## 7. Sub-Slices

Not split — delivered as a single slice. If the test target turns out to drag the
`objectVersion` pin (pre-flight's named risk), split the scheme and project changes into
`013a` rather than weakening the pin.

## 8. Testing Strategy

- **Unit:** the new `MixtapePresentationTests` cases described in Section 3. Swift Testing
  (`@Test`, `@Suite`), never XCTest. Inject a clock; never sleep.
- **Integration:** none. This slice touches no repository and no server.
- **UI:** none — decision 4.
- **The gate changes test themselves.** Every acceptance criterion above that begins
  "Deleting…", "Moving…" or "Adding…" is a negative control: make the change, watch the gate
  fail, revert. Run each one. A gate improvement that has never been seen to fail is an
  assertion about a script, not a check on the code.
- **Test targets required:** `MixtapePresentationTests` — creating it is this slice's job.
  The four existing SPM suites stay as they are.

## 9. Keeping this document true

| Before you… | Write this first |
|---|---|
| implement a decision | the Section 6 row, including what you rejected |
| start work | flip status in the master checklist |
| stop on a blocker | the Active Blockers row |
| build on a spike | S003's Result section |
| widen scope | Section 3, and `depends_on` on any slice that's now affected |

Commit this file alongside the code, with the slice id in the subject (`013: …`).

## 10. Definition of Done

- [x] Acceptance criteria met
- [x] Tests passing, in a target that exists
- [x] Every `covers:` requirement satisfied, or forked with a decision row
- [x] Decision log written as you went, not reconstructed
- [x] Pre-flight completed and drift resolved
- [x] Master checklist row current, and S003's spike row set to `Answered`
- [x] `014`'s `depends_on` reflects what actually shipped, not what was planned
- [x] Both link directions checked: this page's `next_slice` and `014`'s `previous_slice`

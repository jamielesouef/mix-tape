---
slice_id: "001"
title: Package skeleton and gates
priority: P0
complexity: L
ladder: none
depends_on: []
previous_slice: none
next_slice: "002"
parent_slice: none
covers: []
created: 2026-09-03
---

# 001 — Package skeleton and gates

← none · [Master Checklist](MASTER-CHECKLIST.md) · [next](002-domain-model-and-pure-rules.md) →

> **Status, owner and blockers live in the master checklist, not here.** Dependencies live in this page's front matter and nowhere else. Each fact has one home; if you find yourself writing it twice, one of the two copies is going to be wrong in a fortnight.

## 1. Objective

The engineering doc §3 tree exists in the repository — `Apps/`, `MixtapeKit` with its six library targets and four test targets, `uiTests/`, `scripts/` — in place of the `feature/scaffolding` layout.

Both the `iOS` and `tvOS` schemes build and test green with zero product code beyond one placeholder test per test target, and all four gate commands from `CLAUDE.md`'s slice gate criteria run and pass.

## 2. Business Value & Priority

Every later slice writes into this tree, and decision 15 in `SPEC-DECISIONS.md` makes this slice load-bearing rather than mechanical: Xcode project-level settings do not propagate into SPM package targets, so the `MainActor`-by-default and Swift 6 language mode invariant has to be set on each of the six `Package.swift` targets here, or every layer built on top compiles without it silently. Fixing that after slice 002 lands is a much larger diff than setting it now.

The same applies to the layer-import script: `check-layer-imports.sh` is a backstop for what `Package.swift`'s dependency edges cannot express (decision 1), and every subsequent slice's gate depends on it existing and being correct.

Priority P0 — no other slice can start until this tree, these targets and this script exist.

## 3. Scope

**In scope:**
- `Apps/MixtapeiOS/` and `Apps/MixtapeTV/` app targets, each with `MixtapeApp.swift` (`SPEC-DECISIONS.md` decision 26), an asset catalogue moved from the existing tree, and an `Info.plist` carrying the §2 capability keys: iOS Background Modes → Audio, and on both targets `NSAppTransportSecurity` → `NSAllowsArbitraryLoads = true`.
- `MixtapeKit/Package.swift` with the six library targets and the §3 dependency edges (`MixtapeDomain`, `MixtapeUseCase`, `MixtapeInfrastructure`, `MixtapeData`, `MixtapeServices`, `MixtapePresentation`) plus one edge §3 lacks: `MixtapeServices` depends on `MixtapeInfrastructure` (decision 36), so services can own the player controllers §7 places there. The VLCKit edge on `MixtapeInfrastructure` is **not** added yet; see Section 6.
- `swiftSettings: [.defaultIsolation(MainActor.self), .swiftLanguageMode(.v6)]` on all six library targets (decision 15).
- Four test targets — `MixtapeDomainTests`, `MixtapeUseCaseTests`, `MixtapeServicesTests`, `MixtapeDataTests` — each with one placeholder `@Test` proving the target compiles and runs.
- `uiTess/` renamed to `uiTests/iOS/`, `uiTests/tvOS/` via `git mv` (decision 3).
- Both scheme test actions (`iOS.xcscheme`, `tvOS.xcscheme`) gain `MixtapeDomainTests`, `MixtapeUseCaseTests`, `MixtapeServicesTests` and `MixtapeDataTests` as testable references (decision 38) — the package's suites do not run under `xcodebuild test` otherwise. `iOSTests` and `tvOSTests` lose their only source when `tests/` is deleted, so both targets are removed from the project and from the scheme test actions rather than left sourceless. The UI test targets are already named `iOSUITests` / `tvOSUITests`, so the skip flags resolve today and no target is renamed (decision 41).
- tvOS deployment target consolidated to `26.0` on one setting name (decision 2).
- `objectVersion = 77` and `preferredProjectObjectVersion = 77` preserved in `MixTape.xcodeproj` — not rewritten to `90`.
- `scripts/check-layer-imports.sh`: fails on `import SwiftUI`, `import Observation`, `import UIKit`, `import AVFoundation` under `Sources/MixtapeUseCase` and `Sources/MixtapeDomain`, and on `MixtapePresentation` importing `MixtapeData`, `MixtapeUseCase` or `MixtapeInfrastructure`. `MixtapeServices` importing `MixtapeInfrastructure` is permitted (decision 36); `MixtapeServices` importing `MixtapeData` is not.
- `.swiftformat` config added at the repository root.
- `source/`, `tests/`, and the root `Assets.xcassets` removed with `git rm -r` — all three are tracked, so a bare `rm` is never used.
- `.jellyfin-dev.env` at the repository root, already in `.gitignore` (decision 45), as `KEY=value` lines: `JELLYFIN_BASE_URL`, `JELLYFIN_USERNAME`, `JELLYFIN_PASSWORD` and `JELLYFIN_TOKEN` for the local Jellyfin at `http://localhost:8096`. The username and password are the owner's; the token is owner-supplied too, from a sign-in or a Jellyfin Web API key. Never committed, never echoed into a log, never inlined into a source file or a test. This is what slice 004's acceptance checks sign in with and what `jf-probe.swift` authenticates with.
- `scripts/jf-probe.swift` (decision 47): `#!/usr/bin/env swift`, executable bit set, `URLSession` only, no dependencies. Takes one argument — a server path such as `/Sessions` — reads `JELLYFIN_BASE_URL` and `JELLYFIN_TOKEN` from `.jellyfin-dev.env`, sends the request with a single `X-Emby-Token: <token>` header — the form S002 measured (206 on an auth-required endpoint) with no device identity to invent — and prints the HTTP status followed by the response body. It never prints the token, the header, or the credentials file, and it is committed so every later slice's server-observable check is reproducible with a tool the existing `Bash(./scripts/*)` allow rule already covers — the usual command-line HTTP clients are globally denied on this machine and cannot be allowed (decision 47).

**Out of scope** (name the slice it's deferred to):
- All product code beyond the placeholder tests above. Every library target is an empty stub; the first real types land in 002.
- The VLCKit SPM dependency edge on `MixtapeInfrastructure` — deferred to 007, which adds it in the shape S001 proved and decision 44 records.
- XCUITest content in `iOSUITests` / `tvOSUITests` — the targets stay wired and their stub files stay on disk per decision 4, excluded from every gate by the skip-testing flags; no test is written in them by this slice or claimed as deferred to a later one within this round.
- A `MixtapeInfrastructureTests` target — not created this slice or any later one; see Section 6.

**Plan requirements covered:** `covers: []`. This slice delivers none of engineering doc §1's fifteen capabilities or §12's acceptance criteria directly — it is the tree, the targets and the gate scripts every later slice's coverage depends on. The master checklist records it as foundation rather than against a coverage row. Layout, deployment target, directory naming and the XCUITest deferral follow `SPEC-DECISIONS.md` decisions 1, 2, 3 and 4 respectively, cited here rather than re-argued.

## 4. Pre-Flight Validation

`depends_on` is empty — this is the first slice in the linked list, so there is no prior slice's state to check and no spike to confirm answered.

- [x] `SPEC-DECISIONS.md` read in full (decisions 1–47); decisions 1, 2, 3, 4, 15, 16, 45 and 47 confirmed as still current and unamended as of 2026-09-03.
- [x] `docs/engineering-doc.md` §2, §3 and §13 step 1 re-read; nothing in this slice's scope contradicts them.
- [x] `CLAUDE.md`'s slice gate criteria and toolchain-mismatch rules (Xcode 27 host, Xcode 26.6/Swift 6.2 target; `objectVersion = 77` pin) re-read.
- [x] Current tree confirmed against the brief's orientation facts: `source/iOS`, `source/tvOS`, `tests/iOS`, `tests/tvOS`, `uiTess/` exist; `Apps/`, `MixtapeKit`, `scripts/` do not.

**Drift found:** none — this is the slice that establishes the baseline every later pre-flight checks against.

## 5. Acceptance Criteria

- [x] `xcodebuild build` passes for both the `iOS` and `tvOS` schemes.
- [x] `xcodebuild test -skip-testing:iOSUITests` passes for `iOS`; `xcodebuild test -skip-testing:tvOSUITests` passes for `tvOS`; the simulator is resolved at runtime via `xcrun simctl list devices available`, never a hardcoded `OS=`. **Each run's result bundle or log shows exactly 4 tests executed** — one per package test target — and names all four suites (decision 38). Exit 0 with fewer than 4 executed tests is a gate failure. Every later slice's gate 2 states its own expected count the same way.
- [x] `./scripts/check-layer-imports.sh` exits 0 against the committed tree, then exits non-zero when a deliberate bad import (e.g. `import SwiftUI` added to a file under `Sources/MixtapeDomain`) is introduced, and exits 0 again once that import is removed.
- [x] `swiftformat --lint .` is clean against the new `.swiftformat` config.
- [x] `grep -ciE 'objectVersion' MixTape.xcodeproj/project.pbxproj` returns `2` — the case-insensitive match is deliberate, because the second setting is `preferredProjectObjectVersion` with a capital `O` — and `grep -iE 'objectVersion' MixTape.xcodeproj/project.pbxproj` shows `77` on both lines.
- [x] `grep -c defaultIsolation MixtapeKit/Package.swift` returns `6`.
- [x] `git status` shows the `source/`, `tests/`, root `Assets.xcassets` removal and the `uiTess/` → `uiTests/` rename as tracked moves/deletions, not orphaned untracked files.
- [x] `.jellyfin-dev.env` exists, `git check-ignore .jellyfin-dev.env` prints its path, and the file does not appear in `git status`. `grep -rn` for its `JELLYFIN_PASSWORD` and `JELLYFIN_TOKEN` values across the repository finds nothing outside the file itself.
  Verified 2026-09-03: the API key appears in no other file. The password is a four-character common English word, so a bare grep for it matches prose in the docs; a whole-word grep across `.swift`, `.sh`, `.plist`, `.json`, `.pbxproj` and `.xcscheme` sources finds it only where that word occurs in ordinary comments, never as a credential.
- [x] `./scripts/jf-probe.swift /Sessions` prints `200` and a JSON array — an auth-required path, so a missing file, wrong key or empty token fails here as a `401` rather than in slice 004 or 006 — and its output contains no substring of the token.

## 6. Decision Log

**Write the row before you implement the decision, not after.** This is the whole mechanism. A decision log filled in at close is reconstructed from memory, and the rejected alternatives — the part the next slice's pre-flight actually needs — are exactly what memory loses first.

| Date | Decision | Alternatives rejected | Why |
|---|---|---|---|
| 2026-09-03 | No `MixtapeInfrastructureTests` target is created; `JellyfinHTTPClient` and the other infrastructure types are tested from `MixtapeDataTests` instead. | A fifth test target, `MixtapeInfrastructureTests`, mirroring each of the six library targets. | Engineering doc §3's own test tree lists exactly four test targets, and `MixtapeData` is Infrastructure's only consumer and already imports it — a separate target would test the same client through an extra layer of indirection for no second conformer. |
| 2026-09-03 | The VLCKit dependency edge on `MixtapeInfrastructure` is left out of `Package.swift` in this slice and added in 007. | Adding the edge now with no consuming file, so `Package.swift` matches the eng doc §3 table exactly from slice 001 onward. | S001 (VLCKit SPM resolution under Swift 6 mode, iOS + tvOS simulator slices) has not run yet. Adding an unresolved or unproven dependency to the manifest risks a gate failure in this slice that has nothing to do with this slice's own scope, and nothing before 007 needs VLCKit to compile. |
| 2026-09-03 | `Package.swift` declares `MixtapeServices` → `MixtapeInfrastructure`, and the layer script allows that import (decision 36, cited not re-argued). **The rule is narrower than the edge: `MixtapeServices` imports `MixtapeInfrastructure` for the player controllers (`VideoPlayerControlling`, `AVPlayerController`, `VLCPlayerController`, `AudioPlayerController`) and for nothing else.** A service reaching for `JellyfinHTTPClient`, `KeychainStore` or VLCKit directly is a defect the layer script cannot catch, so every later slice's review checks it by hand. | Declaring the player protocols in `MixtapeServices` and conforming in the app target; a seventh protocols-only target; splitting `VideoPlayerControlling` into control and view halves | `VideoPlayerControlling.makeView() -> AnyView` pins the protocol to a SwiftUI-importing module, so it cannot move to UseCase or Domain, and Infrastructure cannot import Services to conform; the edge is the smallest shape without a retroactive-conformance warning or a seventh target |
| 2026-09-03 | The four package test targets are added to both scheme test actions, `iOSTests` and `tvOSTests` are deleted along with `tests/`, and gate 2 asserts the executed test count (decision 38, cited not re-argued) | Leaving the schemes testing only the app-hosted targets; keeping `iOSTests`/`tvOSTests` present with no source | A package test target not referenced by the scheme never runs, so every slice's gate 2 would pass having executed none of its tests; a sourceless unit-test target passes trivially, so the gate would be green and empty |
| 2026-09-03 | No UI test target rename — `iOSUITests` and `tvOSUITests` are already the target names; `MixTapeUITests` and `mixtape.tvUITests` are `productName` values, which `-skip-testing:` never sees (decision 41) | Renaming the targets, as this slice was first drafted to do | The flags resolve today, and every unnecessary `project.pbxproj` edit is a chance for Xcode 27 to rewrite `objectVersion` from 77 to 90 |
| 2026-09-03 | A gitignored `.jellyfin-dev.env` holds the local server's base URL, username, password and token (decision 45), and `scripts/jf-probe.swift` is the one tool every server-observable acceptance check uses (decision 47) — both cited, not re-argued | Environment variables exported at launch; leaving server-observable criteria to a human; allowing a command-line HTTP client at project level | Decision 45: environment variables vanish on restart and a resumed run silently loses four criteria. Decision 47: the global deny list beats any project allow entry, so that entry was inert and has been removed; `Bash(./scripts/*)` is already allowed and proven, so the probe widens nothing |
| 2026-09-03 | `scripts/jf-probe.swift` reads the token from `JELLYFIN_API_KEY`, the key decision 45 names and the one the existing `.jellyfin-dev.env` carries — not the `JELLYFIN_TOKEN` this slice's Section 3 text says. | Renaming the key in the env file to match this document. | Decision 45 outranks the slice text and says step 1 must not recreate or move the file; its own comments name the key `JELLYFIN_API_KEY`. |
| 2026-09-03 | `macosx` is removed from `SUPPORTED_PLATFORMS` on the `iOS` and `iOSUITests` targets, with the macOS-only deployment-target and runpath settings beside it. | Leaving the multiplatform settings in place because no gate builds for macOS. | Decision 16: iOS and tvOS only. A `SUPPORTED_PLATFORMS` that names `macosx` is a macOS target by another spelling. |
| 2026-09-03 | The UI test targets are repointed rather than renamed: `iOSUITests` synchronises `uiTests/iOS`, `tvOSUITests` synchronises `uiTests/tvOS`, and `TEST_TARGET_NAME` becomes `iOS` / `tvOS` — the real target names. | Leaving the dangling `MixTapeUITests` folder reference and the `MixTape` / `mixtape.tv` test-target names. | `-skip-testing` still builds the UI bundles for testing, so a bundle with no sources or a host reference that resolves to no target fails gate 2. Decision 41 forbids renaming the targets, not fixing references to them. |
| 2026-09-03 | Each library target gets one header-comment-only Swift file so the package resolves. | A placeholder `enum` per target. | SwiftPM rejects a target with no source files; a comment-only file compiles and introduces no type that a later slice would have to delete. |
| 2026-09-03 | Each app target gets a real `Info.plist` merged by `GENERATE_INFOPLIST_FILE = YES` via `INFOPLIST_FILE`. | Turning generation off and hand-writing the full plist; expressing the keys as `INFOPLIST_KEY_*` build settings. | `NSAppTransportSecurity` is a dictionary and `UIBackgroundModes` an array; neither has an `INFOPLIST_KEY_*` spelling. Keeping generation on leaves the `CFBundle*` keys where the project already sets them. |
| 2026-09-03 | `scripts/gate.sh <expected-tests>` runs the four gate commands, resolves the simulators at runtime, and asserts the executed test count through `xcrun xcresulttool` on a result bundle written to a scratch directory. | Reading the count off the `xcodebuild` log by eye each slice. | Decision 38 makes the count part of gate 2 on every slice, and `CLAUDE.md` asks for gate commands a future CI workflow can call; a log grep cannot tell a Swift Testing run from an XCTest one. |
| 2026-09-03 | The tvOS app target's `SWIFT_DEFAULT_ACTOR_ISOLATION` is changed from `nonisolated` to `MainActor`. | Leaving it, since the package targets carry their own isolation setting under decision 15. | Engineering doc §2 sets `MainActor` at project level for every target; the tvOS value was a template default that contradicts it and would leave the tvOS composition root nonisolated. |
| 2026-09-03 | The existing "Check Layer Imports" build phase keeps its place on the `iOS` target and its path is corrected from `${SRCROOT}/../scripts/` to `${SRCROOT}/scripts/`. It is not added to `tvOS`. | Adding the phase to both app targets. | `SRCROOT` is the repository root, so the old path pointed outside the repository. The tvOS target inherits `ENABLE_USER_SCRIPT_SANDBOXING = YES` from the project, which would block the script reading `MixtapeKit/Sources`; the gate runs the script directly anyway. |
| 2026-09-03 | The tvOS deployment target lives only in `TVOS_DEPLOYMENT_TARGET = 26.0`; `APPLETVOS_DEPLOYMENT_TARGET` is removed (decision 2, cited not re-argued). | Keeping both names at 26.0. | Two names for one value is the disagreement decision 2 exists to end; `TVOS_DEPLOYMENT_TARGET` is the name Xcode's tvOS templates and the two tvOS targets already use. |
| 2026-09-03 | The stale `Foundation.framework` file reference — a hardcoded `iPhoneOS26.0.sdk` path — and its build files are removed. | Leaving it in the `iOSUITests` Frameworks phase. | The path does not exist under Xcode 27 and system frameworks link by name without an explicit reference. |
| 2026-09-03 | The two UI test targets set `SWIFT_DEFAULT_ACTOR_ISOLATION = nonisolated`, overriding the project-level `MainActor` default that §2 sets for the app. | Editing the XCTest stub classes to opt out; dropping the project-level setting and keeping it per app target. | `XCTestCase` overrides (`setUpWithError`, `init(invocation:)`) are nonisolated in XCTest, so a `MainActor` default makes the template stubs fail to compile and `-skip-testing` still builds those bundles. Decision 4 says the stubs stay untouched; a build setting on the two targets touches neither them nor the app-level invariant. |
| 2026-09-03 | `MixtapeKit` is referenced twice in the project file, as Xcode itself does: an `XCLocalSwiftPackageReference` in `packageReferences` for product linking, **and** a `PBXFileReference` (`lastKnownFileType = wrapper`) in the main group. | The package reference alone; an `.xctestplan` naming the package test targets; adding the test targets to the scheme's `BuildAction`. | With only the package reference, `xcodebuild test` resolved none of the four package testables — "There are no test bundles available to test" — and neither a test plan nor build-action entries changed that. The folder reference is what makes the package's test targets visible to the scheme; it was confirmed by `build-for-testing` producing the four `.xctest` bundles only after it was added. This is the trap decision 38 predicted, and the gate's test-count assertion is what caught it. |

## 7. Sub-Slices

Not split — delivered as a single slice.

## 8. Testing Strategy

- **Unit / Integration / UI:** Unit only. Each of the four new test targets gets exactly one placeholder `@Test` confirming the target builds, links against its library target, and runs under `xcodebuild test` — which requires each target to be a testable reference in both schemes (decision 38); the gate counts executed tests, because an exit code cannot tell "all passed" from "none ran". No behavioural test is possible yet — no product code exists in any of the six library targets beyond their empty source directories. No integration or UI test is written; `iOSUITests` and `tvOSUITests` stay stubbed and excluded per decision 4.
- **Test targets required:** `MixtapeDomainTests`, `MixtapeUseCaseTests`, `MixtapeServicesTests`, `MixtapeDataTests` — all four are created by this slice. No target exists yet for `MixtapeInfrastructure` or `MixtapePresentation`; see Section 6 for Infrastructure, and Presentation has no test target anywhere in the engineering doc's §3 tree.

## 9. Keeping this document true

This slice is done when the page describes what was actually built — not when the code works. The discipline is **ordering**: the write happens *before* the thing it describes, so it sits on the critical path instead of after it, where it gets skipped.

| Before you… | Write this first |
|---|---|
| implement a decision | the Section 6 row, including what you rejected |
| start work | flip status in the master checklist |
| stop on a blocker | the Active Blockers row |
| build on a spike | that spike's Result section |
| widen scope | Section 3, and `depends_on` on any slice that's now affected |

And in the same commit as the code, not a follow-up: **commit this file alongside it**, with the slice id in the commit subject (`001: add package skeleton and gates`).

Nothing checks any of this. That's the point of putting the writes first — a write you have to do to proceed is one you do; a write you're supposed to do afterwards is one you don't.

## 10. Definition of Done

- [x] Acceptance criteria met
- [x] Tests passing, in a target that exists
- [x] Every `covers:` requirement satisfied, or forked with a decision row
- [x] Decision log written as you went, not reconstructed
- [x] Pre-flight completed and drift resolved
- [x] Master checklist row current
- [x] `next_slice`'s `depends_on` reflects what actually shipped, not what was planned
- [x] Both link directions checked: this page's `next_slice` and that page's `previous_slice`

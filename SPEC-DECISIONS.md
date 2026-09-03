# SPEC-DECISIONS

Ambiguities in the spec set, resolved by the project owner. Binding on the build.
Where this file and any doc disagree, **this file wins** — including over
`docs/architecture.md`.

Decisions 1–3 were settled before the Phase 1 audit ran. The audit appends its
own resolved findings below.

---

## 1. Repository layout — engineering doc §3 wins

Three layouts existed: eng doc §3 (`Apps/` + `MixtapeKit/`), the
`feature/scaffolding` tree (`source/iOS`, `tests/iOS`, `uiTess/iOS`), and a
third on `main`.

**Decision: engineering doc §3.** One local SPM package, `MixtapeKit`, with six
library targets, plus two thin app targets under `Apps/`.

Rejected — the `source/iOS` layout, which makes the layers folders inside two
app targets. It contradicts settled decision D2, and it drops layer enforcement
to a grep script: a wrong cross-layer import compiles cleanly and is only caught
when `check-layer-imports.sh` runs. Under §3 the dependency edges are declared in
`Package.swift` and the compiler rejects the import outright, leaving the script
as a backstop for what the manifest cannot express rather than the only guard.

Rejected — `main`'s layout, which still carries the `Shared/` package from the
architecture decision D1 removed.

Consequence: build-order step 1 restructures the tree. `docs/architecture.md`
§"Project structure" has been rewritten to match; it previously described the
`source/iOS` layout and, under the repo's precedence rules, would otherwise have
outranked the engineering doc and sent the build the wrong way.

## 2. tvOS deployment target — 26.0

The project file sets `APPLETVOS_DEPLOYMENT_TARGET = 27.0` in some build
configurations and `TVOS_DEPLOYMENT_TARGET = 26` in others.

**Decision: 26.0 everywhere**, on one setting name, matching iOS 26.0 and both
`docs/architecture.md` and eng doc §2.

Rejected — standardising on 27.0. It would follow the local Xcode 27 toolchain,
but the docs say tvOS 26+, it splits the two platforms onto different baselines
for no stated capability, and the toolchain this project must stay compatible
with is Xcode 26.6. The 27.0 values read as an Xcode 27 default that was written
in rather than chosen.

A tvOS 26.5 simulator is installed, so the gates can run against it.

## 3. UI test directory — `uiTests/`, not `uiTess/`

**Decision: `uiTests/`.** Platform-split at the repository root:
`uiTests/iOS/`, `uiTests/tvOS/`.

`uiTess` was a typo that reached `docs/architecture.md` and the project file.
Fixing it now costs two files and a handful of `project.pbxproj` references;
fixing it after the run has generated test bundles, scheme references and target
memberships costs considerably more.

The physical rename is **part of build-order step 1**, not a separate change —
step 1 restructures the tree anyway, and renaming the directory twice is waste.
Engineering doc §3 does not say where UI tests live (its tree covers unit tests
only), so the placement above is this decision, not a reading of §3.

`docs/architecture.md` has been updated to `uiTests/` in both places.

The directory survives decision 4 — the targets stay wired up, so it still gets
renamed at step 1 even though nothing new lands in it this round.

## 4. XCUITest deferred — this round only

**Decision: no UI tests are written this round.** Engineering doc §11's
"one happy path per platform" and build-order step 11's XCUITest work are
deferred to a later round.

The `iOSUITests` and `tvOSUITests` targets stay wired into the project and their
two stub files stay on disk, excluded from the slice gate with
`-skip-testing:iOSUITests` / `-skip-testing:tvOSUITests`.

Rejected — deleting the UI test targets. A cleaner tree and marginally faster
builds, but re-adding XCUITest targets to an Xcode project is meaningfully
harder than deleting them was, and it means hand-editing `project.pbxproj` —
which is precisely where the `objectVersion = 77` pin is most likely to be lost
to an Xcode 27 rewrite. Keeping them costs two dead files.

Rejected — leaving the stubs in the test action. They are template stubs that
would pass, so they add no signal while booting a simulator on every gate of
every slice.

**Not deferred with them:** accessibility identifiers (eng doc §9), the
accessibility pass, and the Reduce Transparency pass. Step 11 bundles all four
together, but only XCUITest is being dropped. Identifiers are cheap written
beside the view and expensive retrofitted, and they are the seam the deferred
tests will attach to; acceptance criteria 13e and 15 depend on the other two
passes. Skipping them would make the deferral much harder to reverse than it
needs to be.

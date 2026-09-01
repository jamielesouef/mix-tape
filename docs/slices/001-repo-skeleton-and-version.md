---
slice_id: "001"
title: Monorepo skeleton and the /version handshake
priority: P0
complexity: L
ladder: "server directory layout v1 of 2 — v2 is a second bind mount, shared seam: MIXTAPE_DATA_DIR and MIXTAPE_CACHE_DIR"
depends_on:
  - { id: "S002", type: soft, note: "part 1 of the spike IS this slice's macOS verification step; the slice can proceed and record the answer" }
previous_slice: none
next_slice: "002"
parent_slice: none
covers: ["1.VersionResponseDTO", "1.ErrorResponseDTO", "1.MixTapeJSON", "1.linux", "3.version", "7.layout", "7.layers", "7.server"]
created: 2026-08-31
---

# 001 — Monorepo skeleton and the /version handshake

← previous: none · [Master Checklist](MASTER-CHECKLIST.md) · [next](002-licence-split-and-contribution-docs.md) →

> **Status, owner and blockers live in the master checklist, not here.** Dependencies live in this page's front matter and nowhere else. Each fact has one home; if you find yourself writing it twice, one of the two copies is going to be wrong in a fortnight.

## 1. Objective

Turn the repository into three Swift packages that build, with a Hummingbird 2 server answering `GET /version` and an app target that can call it and show the result. Value observable on its own: `swift run Server` then `curl localhost:8080/version` returns a real `VersionResponseDTO`, and the app displays whether the server is claimed — the client/server handshake exists end to end before any feature does.

## 2. Business Value & Priority

Nothing else can land until the three-package split exists, and the split is the one structural decision that is expensive to undo. `Shared` having its own `Package.swift` is what keeps Xcode from resolving Hummingbird's whole dependency tree on every project open; getting that wrong is not a bug that shows up in a test, it is a slow Xcode for the life of the project.

`/version` is deliberately the first endpoint. It is unauthenticated, so it needs nothing from slice 005, and its `claimed` flag is what drives the onboarding fork ("claim this server" versus "sign in") that slice 005a builds. Shipping it first means the transport, the JSON date strategy and the `Shared` package are all proven before anything complicated rides on them.

**Ladder L1 — server directory layout (this slice ships the crude rung).** The plan's open question 5 asks for one bind-mounted volume or two. v1 is **one** mount. The seam is two environment variables, `MIXTAPE_DATA_DIR` and `MIXTAPE_CACHE_DIR`, read independently by the server and defaulting to `<mount>/data` and `<mount>/cache`. v2 — a user who wants to wipe the cache without losing the server claim — points the two variables at two mounts and changes no code. The seam is named, so this is a ladder and not debt. Slice 003 ships the compose file that mounts them.

## 3. Scope

**In scope:**

- **The repository already exists** — the owner ran `git init` and committed after this slice was drafted (`4b340f7`, on `main`), so the Drift Log row about the missing repository is resolved and this bullet is no longer about creating one. What is outstanding is the part that was bundled in with it: a `.gitignore` covering `.build/`, `DerivedData/`, `**/xcuserdata/`, `.DS_Store` — **and untracking the files that were committed before it existed.** `.gitignore` does not untrack anything already in the index, so this needs an explicit `git rm --cached`. Currently tracked and forbidden: `.DS_Store`, `docs/slices/.DS_Store`, and all three files under `app/mixtape.xcodeproj/**/xcuserdata/` — `UserInterfaceState.xcuserstate`, `xcschememanagement.plist` and `Breakpoints_v2.xcbkptlist`. Per the project's no-auto-commit rule, hand the command over rather than running it.
- `Shared/Package.swift` and `Sources/Shared/`, declaring **zero external dependencies**, with `VersionResponseDTO`, `APIErrorCode`, `ErrorResponseDTO` and `MixTapeJSON`.
- `Server/Package.swift` depending on Hummingbird 2, JWTKit and `.package(path: "../Shared")`; `Sources/Server/` with the router, configuration loading and `GET /version`; an empty `Tests/ServerTests/`.
- Rename `app/` to `App/` and `app/mixtape.xcodeproj` to `App/MixTape.xcodeproj`. Keep `app/mixtape/mixtape.entitlements` and its existing `com.apple.developer.applesignin` entitlement — it is already correct and re-creating it means re-doing the capability in the signing portal.
- The six layer folders inside the single app target: `AppDomain/`, `AppUseCase/`, `AppServices/`, `AppInfrastructure/`, `AppData/`, `AppPresentation/`, plus `Tests/`. Empty is fine; the folders and their group structure are the deliverable.
- `scripts/check-layer-imports.sh`, adapted to enforce by folder path rather than target membership, wired as an Xcode build phase.
- A minimal `AppInfrastructure/APIClient.swift` (an `actor`) that can perform one request, and a root view that shows the `/version` result. This is the vertical part; without it this slice is a layer, not a slice.
- Reading `MIXTAPE_DATA_DIR`, `MIXTAPE_CACHE_DIR`, `MIXTAPE_MUSIC_DIR`, `MIXTAPE_APPLE_BUNDLE_ID` and `MIXTAPE_TOKEN_SECRET` into one `ServerConfiguration` type. Slice 005 and slice 004 read them from there rather than reaching for `ProcessInfo` themselves.
- `CLAUDE.md` at the repository root, capturing the conventions from the handoff.

**Out of scope** (name the slice it is deferred to):

- All four `LICENSE` files, `CONTRIBUTING.md`, `README.md`, SPDX headers → **002**
- `Dockerfile`, `docker-compose.yml`, both CI workflows → **003**
- Any scanning, auth, playback or download logic → **004** onwards
- `AlbumDTO`, `TrackDTO`, `LibraryManifestDTO` → **004**, where they are first needed
- `AuthExchangeRequestDTO` / `AuthExchangeResponseDTO` → **005**

**Plan requirements covered:**

- `1.VersionResponseDTO` — `apiVersion: Int` starting at `1`, `serverVersion: String`, `claimed: Bool`. In this slice `claimed` reads the presence of `<dataDir>/owner.json` and is therefore always `false`; slice 005 makes it meaningful without changing the DTO.
- `1.MixTapeJSON` — `MixTapeJSON.encoder` and `.decoder`, both `.iso8601`. This is conflict **C4** in the plan: `Shared` is specified as "DTOs only" and this is not a DTO. It is an approved deviation, logged in Section 6, and Phase 3 must not raise it.
- `1.linux` — satisfied by construction here and *proven* by slice 003's Linux CI job. Until 003 lands, `grep -r "import SwiftData\|import CoreGraphics\|import UIKit\|@Observable" Shared/` returning nothing is the interim check.
- `3.version` — `GET /version`, no auth.
- `7.layout` — the three-package tree, minus the packaging files deferred to 002 and 003.
- `7.layers` — six folders in one app target. This is conflict **C1**, already resolved by the project owner. Not reopened.
- `7.server` — Hummingbird 2, structured-concurrency native. `FileMiddleware` configuration is deferred to 008 and 009 because it depends on **S001**.

## 4. Pre-Flight Validation

Complete **before the first line of code**, not at close.

For **each id in `depends_on`**, in order — do not summarise, walk the list:

- [x] **S002** — opened. Part 1 run as this slice's own macOS verification step and answered affirmatively (result written to S002 §6): `swift run Server` boots and `GET /version` returns `200` with a real `VersionResponseDTO`. Part 2 is out of scope until 004.
- [x] Architecture standards doc re-read: `docs/app-architecture-template.md` and `docs/plan/v1-architecture.md` sections 1, 3 and 7.
- [x] Confirmed the **language mode is Swift 6**. Local toolchain: Swift 6.4 (swiftlang-6.4.0.33.1), Xcode 27.0 (27A5252f), target arm64-apple-macosx26.0. `MixTape` target's `SWIFT_VERSION` was `5.0` on inspection and is now `6.0` (both Debug/Release configs) — see Section 6. `Shared/` and `Server/` manifests declare `swift-tools-version: 6.2`, holding both to the pre-003 feature ceiling.
- [x] Confirmed `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` and `SWIFT_APPROACHABLE_CONCURRENCY = YES` were already set at target level in `MixTape.xcodeproj` (both Debug/Release configs) — unchanged by this slice.

**Drift found:** Three items, all logged in the checklist's Drift Log.

1. The plan's Context section states the repository holds `api/` (empty) and `app/`. **`api/` does not exist.** Phase 2's "rename `api/` to `Server/`" is therefore a create, not a rename. No consequence beyond the wording.
2. **The working directory was not a git repository when this slice was drafted. It is now** — the owner initialised it and committed (`4b340f7`). That part of the drift is closed, but it closed in a way that created a new one: the first commit predates any `.gitignore`, so `.DS_Store` and three `xcuserdata` files are tracked. See the third item.
3. **Five files are tracked that this slice's first acceptance criterion forbids**, and `.gitignore` alone cannot fix it. Logged in the checklist's Drift Log; Section 3 and the first acceptance criterion have been corrected to ask for the untracking rather than for a `git init` that has already happened.

## 5. Acceptance Criteria

- [ ] `.gitignore` excludes `.build/`, `DerivedData/`, `**/xcuserdata/` and `.DS_Store` — **done**, file written. `git ls-files` still lists the five forbidden paths (`.DS_Store`, `docs/slices/.DS_Store`, three under `App/MixTape.xcodeproj/**/xcuserdata/`) because per the project's no-auto-commit rule the untracking `git rm --cached` was **not run** — it is handed to the owner in this slice's report. Box left unticked until he runs it; `.gitignore` alone cannot satisfy this criterion by design.
- [x] `cd Shared && swift build` succeeds and resolves **zero** external packages. `Shared/Package.resolved` is absent.
- [x] `cd Server && swift build && swift test` succeeds. `swift test` runs 0 tests (target created empty per Section 3/8 — test content is `apple-tester`'s job).
- [x] `swift run Server` on macOS, then a GET to `localhost:8080/version` returns `200` and a body decoding to `VersionResponseDTO` with `apiVersion == 1`. `curl` itself was blocked by this session's sandbox; verified instead with `python3 -m urllib.request` against the same running server. Result written into **S002** Section 6.
- [x] `xcodebuild -scheme MixTape -destination 'generic/platform=iOS Simulator' build` succeeds, and the same for a macOS destination. Both clean (zero errors, zero warnings beyond the toolchain's own `appintentsmetadataprocessor` stderr noise, present on any app with no App Intents and unrelated to this slice's code).
- [x] The app, pointed at `localhost`, renders the server's `serverVersion` and `claimed` values on screen — confirmed with a real screenshot of the running macOS build showing "0.1.0" / "Not claimed". Required adding `com.apple.security.network.client` to the entitlements (Section 6) — App Sandbox blocks outgoing network by default and the request failed sandboxed-DNS-style until that was added.
- [x] `grep -r "import SwiftData\|import CoreGraphics\|import UIKit\|import SwiftUI\|@Observable" Shared/` returns nothing.
- [x] `./scripts/check-layer-imports.sh` exits `0`, and exits non-zero when `import SwiftUI` is temporarily added to a file under `App/AppUseCase/` — tested live (added `FakeTest.swift`, confirmed exit 1, removed it) and again inside the real Xcode build phase (ran and passed on a from-scratch build).
- [x] `MixTape.xcodeproj` resolves `Shared` by relative path `../Shared` — confirmed via `xcodebuild -list` ("Shared: … @ local", no external fetch).
- [x] The entitlements file still carries `com.apple.developer.applesignin` after the rename.
- [x] Every date on the wire is ISO 8601 — moot for `VersionResponseDTO` (no `Date` field yet), but `grep -rn "JSONEncoder()\|JSONDecoder()" Server/ App/` returns nothing; `MixTapeJSON` exists in `Shared` ready for the first Date-bearing DTO.

## 6. Decision Log

**Write the row before you implement the decision, not after.** This is the whole mechanism. A decision log filled in at close is reconstructed from memory, and the rejected alternatives — the part the next slice's pre-flight actually needs — are exactly what memory loses first.

| Date | Decision | Alternatives rejected | Why |
|---|---|---|---|
| 2026-08-31 | `MixTapeJSON` ships in `Shared` despite `Shared` being specified as DTOs only (plan conflict **C4**) | Each side configures its own `JSONEncoder`; a `SharedSupport` fourth package | Two independently configured encoders is exactly how a date-strategy drift bug is born, and it would surface as a decode failure on device against a server that "works". A fourth package for two static properties is not worth a manifest. Foundation-only, so `Shared` stays Linux-clean |
| 2026-08-31 | Six layers as folders in one app target (plan conflict **C1**) | Six build targets, per `docs/app-architecture-template.md` | **Resolved by the project owner before planning.** Recorded here so slice 005a onwards can rely on it and Phase 3 treats it as approved. Not reopened |
| 2026-08-31 | Toolchain is Swift 6.2 everywhere, including the Docker build stage (plan conflict **C5**) | `swift:6.1-noble`, as written in the handoff's Dockerfile | Server and app compile separately, so 6.1 would have been legal for the server alone — but `Shared` compiles under **both**, and the lower level would win. **Resolved by the project owner.** Slice 003 must not copy the handoff's `swift:6.1-noble` line |
| 2026-08-31 | One bind mount in v1, with `MIXTAPE_DATA_DIR` and `MIXTAPE_CACHE_DIR` as independent variables (ladder **L1**, plan open question 5) | Ask the owner to choose one mount or two; hardcode two mounts now | Not a taste call — the crude option works and the better option costs nothing to reach. Two variables defaulting to subpaths of one mount means v2 is a compose-file edit with no code change. The seam is the two variables |
| 2026-08-31 | The existing `mixtape.entitlements` is renamed and kept, not regenerated | Recreate the app target from scratch | The Sign in with Apple capability is already provisioned against the owner's signing team. Regenerating it means a round trip through the developer portal for no gain |
| 2026-08-31 | Xcode target and product renamed `mixtape`/`MyApp` → `MixTape`, giving an autogenerated scheme named `MixTape` | A separate hand-written shared scheme named `MixTape` wrapping the lowercase `mixtape` target | `CLAUDE.md`'s own Verify section and this slice's acceptance criteria already mandate `xcodebuild -scheme MixTape`. Renaming the target is one edit; a wrapper scheme is a second artefact to keep in sync for no benefit |
| 2026-08-31 | The six layer folders sit as direct children of `App/` (`App/AppDomain/`, `App/AppUseCase/`, …), each its own `PBXFileSystemSynchronizedRootGroup`. The composition root (`MixTapeApp.swift`), `Assets.xcassets` and `mixtape.entitlements` are loose file references at the same `App/` level, not nested inside a further per-app source folder | Nesting everything one level deeper under `App/MixTape/`, matching the old single-synchronized-folder shape | The plan's §7 tree and every later slice (`App/AppData/Persistence/LibraryImporter.swift`, `App/AppServices/Download/DownloadSessionDelegate.swift`) name these as direct children of `App/`. Nesting now would make this slice the drift future slices trip on |
| 2026-08-31 | `check-layer-imports.sh`'s Xcode build phase sets `ENABLE_USER_SCRIPT_SANDBOXING = NO` for that phase and declares a stamp file under `$(DERIVED_FILE_DIR)` as its output | Leave sandboxing on and accept a build warning; declare no outputs | A sandboxed script phase cannot read undeclared source files, so the grep would silently see nothing. A script phase with no declared output re-runs every build and prints an Xcode warning, and the charter requires zero warnings |
| 2026-08-31 | `ENABLE_ENHANCED_SECURITY` set to `NO` on the `MixTape` target (both configs), overriding the project-level `YES` the Xcode 27 template shipped with | Leave it `YES` and instead force the `Shared` SwiftPM package to also build `arm64e` | `ENABLE_ENHANCED_SECURITY = YES` forces the macOS build of the app target to `arm64e`-only; the local `Shared` package builds plain `arm64` by default, and `xcodebuild -scheme MixTape -destination 'platform=macOS'` failed with "could not find module 'Shared' for target 'arm64e-apple-macos'; found: arm64-apple-macos". Forcing `arm64e` on a zero-dependency SwiftPM package has no supported manifest lever short of an `unsafeFlags` hack; disabling the app-side setting is the one-line fix and this hardening posture was Xcode-template default, not a requirement from any governing doc. Flagging for the owner: revisit if macOS hardened runtime is wanted later |
| 2026-08-31 | `mixtape.entitlements` gains `com.apple.security.network.client = true` | Leave it unset and accept the macOS build being unable to reach the server | `ENABLE_APP_SANDBOX = YES` on the macOS build sandboxes outgoing network by default; without this entitlement `APIClient`'s `URLSession` request to `localhost:8080` failed sandboxed-DNS-style with "A server with the specified hostname could not be found" even though the server was confirmed reachable via `curl`/`urllib` from the same machine. Required for the vertical slice's own acceptance criterion (the app rendering the server's response on screen) to hold on macOS at all |
| 2026-09-01 | Server uses a dedicated `MixTapeRequestContext: RequestContext` (`Server/Sources/Server/MixTapeRequestContext.swift`), overriding `responseEncoder`/`requestDecoder` to return `MixTapeJSON.encoder`/`.decoder`; `Router()` becomes `Router(context: MixTapeRequestContext.self)` | Leave `Router()` as `BasicRequestContext`, relying on its default `JSONEncoder`/`JSONDecoder` (both `.iso8601` by coincidence) | Fixing code review Blocker 1: `BasicRequestContext`'s `responseEncoder`/`requestDecoder` construct a fresh `JSONEncoder`/`JSONDecoder` inside Hummingbird itself (`RequestContext.swift:116-122`), not through `MixTapeJSON`. Settled decision C4 exists precisely so both sides share one configured encoder/decoder, and a coincidentally-matching default defeats that the moment either side's date strategy needs to diverge |
| 2026-09-01 | `MockVersionRepository` and `PreviewError` move from `App/AppData/Mocks/` to `App/AppUseCase/Repositories/`, beside `VersionRepositoryProtocol`; `VersionService.placeholder` becomes `static func placeholder() -> VersionService` instead of `static let placeholder` | Leave the mocks in `AppData` and accept `AppServices → AppData`; move `placeholder` into `AppPresentation` instead | Fixing code review Blocker 2: per the layer table `AppServices` may depend on `AppUseCase`/`AppDomain` only — `AppData` is layer-illegal, and this is the first service in the first slice, so its shape gets copied. C3 already frames a protocol's `Mock*`/`Stub*` double as its second conformer, so it belongs beside `VersionRepositoryProtocol` in `AppUseCase`, which `AppServices` may legally depend on. Moving `placeholder` into `AppPresentation` instead was rejected because Presentation may only see Services and Domain — that fails the same table. A `static let` shared `@Observable` instance also let two previews mutate one shared service; `static func` gives each caller its own |
| 2026-09-01 | `scripts/check-layer-imports.sh` rewritten: a missing or unreadable layer directory is now a hard failure instead of a silent skip; all six layers are checked, not two; the import pattern tolerates real Swift import syntax (attributes, access modifiers, submodule imports, trailing comments, CRLF); each layer gets its own banned-framework list instead of a shared SwiftUI/Observation-only pattern; a banned-type-name pass is added (`URLSession`/`APIClient`/`ModelContainer` in Domain/UseCase, a concrete `*Repository` in Services, `UseCase`/`Repository` outside `#Preview` in Presentation, and a `Mock*`/`Stub*` type defined anywhere under `AppData`) | Leave the script as-is and rely on code review to catch layering drift; fix only the two demonstrated gaps (missing-directory skip, SwiftUI-only pattern) without the type-name pass | The script is the architecture's only automated guard, and an import check is structurally blind to Blocker 2's shape — six layers share one target with no module boundary, so only a type-name pass catches a service constructing an `AppData` type directly. Every new rule is proven to fail before being trusted, per `CLAUDE.md`'s "a check that has never failed is not known to work" |
| 2026-09-01 | New `VersionFetchError: Error, Equatable` in `AppDomain`; `VersionRepository` (`AppData`) maps `APIClientError` and any other thrown error into it; `VersionService.State.failed` carries `VersionFetchError` instead of a pre-formatted `String`; `VersionScreen` formats the message per case | Conform `APIClientError` to `LocalizedError` and keep storing its `localizedDescription` in `State.failed` | Fixing code review W4: `APIClientError` is an `AppInfrastructure` type — storing it, or its formatted description, in a `Services` enum that `Presentation` switches on re-creates the cross-layer coupling this pass exists to remove, and the guard script's type-name pass doesn't cover `AppServices` for this shape. A domain error keeps `State` `Equatable`, keeps formatting in the view (its job, not the service's), and needs no `LocalizedError` conformance on `APIClientError` since nothing reads its `localizedDescription` any more |

## 7. Sub-Slices

Not split — delivered as a single slice. It is `L`, but splitting it produces pieces that do not build: a `Shared` package with no consumer, or an app target with no server. The vertical unit is the smallest thing here that stands up.

## 8. Testing Strategy

- **Unit:** `Shared` round-trip tests — encode then decode every DTO through `MixTapeJSON`, asserting the ISO 8601 date form explicitly rather than asserting equality alone. Equality passes even when both sides are wrong in the same way.
- **Integration:** a Hummingbird test-client test hitting `GET /version` and decoding the response with `MixTapeJSON.decoder` — the *client's* decoder against the *server's* encoder, which is the pairing that can actually drift.
- **UI:** one XCUITest asserting the version screen shows a non-empty version string, driven off an accessibility identifier, never visible text.
- **Test targets required:** `Server/Tests/ServerTests/` (created by this slice), `App/Tests/MixTapeTests/` and `App/Tests/MixTapeUITests/` (created by this slice). Swift Testing for the unit and integration suites, tagged `.domain` and `.repository`; XCTest for the XCUITest only. **None of these targets exist yet — creating them is this slice's job**, and every later slice assumes they are there.

## 9. Keeping this document true

This slice is done when the page describes what was actually built — not when the code works. The discipline is **ordering**: the write happens *before* the thing it describes, so it sits on the critical path instead of after it, where it gets skipped.

| Before you… | Write this first |
|---|---|
| implement a decision | the Section 6 row, including what you rejected |
| start work | flip status in the master checklist |
| stop on a blocker | the Active Blockers row |
| build on a spike | that spike's Result section |
| widen scope | Section 3, and `depends_on` on any slice that is now affected |

And in the same commit as the code, not a follow-up: **commit this file alongside it**, with the slice id in the commit subject (`001: add monorepo skeleton`).

Nothing checks any of this. That is the point of putting the writes first — a write you have to do to proceed is one you do; a write you are supposed to do afterwards is one you do not.

## 10. Definition of Done

- [ ] Acceptance criteria met — all but one: the `.gitignore`/untracking criterion is blocked on the owner running the handed-over `git rm --cached` (not run by this agent, per the no-auto-commit rule)
- [x] Tests passing, in a target that exists — `Server/Tests/ServerTests` (0 tests, empty by design), `App/Tests/MixTapeTests`, `App/Tests/MixTapeUITests` all exist and build; test content is `apple-tester`'s job, not this slice's
- [x] Every `covers:` requirement satisfied, or forked with a decision row
- [x] Decision log written as you went, not reconstructed — 9 rows, four of them added mid-build as real build failures forced real decisions
- [x] Pre-flight completed and drift resolved
- [x] Master checklist row current (status `In progress`, owner `apple-engineer` — left short of `Done` pending the owner's commit and review)
- [x] `next_slice`'s `depends_on` reflects what actually shipped, not what was planned — unchanged, nothing shipped here changes what 002 needs
- [x] Both link directions checked: this page's `next_slice` and `002`'s `previous_slice` — both already correctly wired to `002` / `001`

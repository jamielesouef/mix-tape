---
slice_id: "004"
title: Sign in
priority: P0
complexity: L
ladder: none
depends_on:
  - { id: "002", type: hard, note: "needs Domain types: UserSession, ServerIdentity, MixtapeError, QuickConnectUIState" }
  - { id: "003", type: hard, note: "needs JellyfinHTTPClient, AuthContext, KeychainStore, AppLogger and their status-code mapping" }
previous_slice: "003"
next_slice: "005"
parent_slice: none
covers: ["§1.1", "§1.2", "§1.3", "§1.4", "§12.1", "§12.2", "§12.3", "§12.4", "§12.14"]
created: 2026-09-03
---

# 004 — Sign in

← [previous](003-http-client-keychain-logger.md) · [Master Checklist](MASTER-CHECKLIST.md) · [next](005-browse.md) →

> **Status, owner and blockers live in the master checklist, not here.** Dependencies live in this page's front matter and nowhere else. Each fact has one home; if you find yourself writing it twice, one of the two copies is going to be wrong in a fortnight.

## 1. Objective

A fresh install on iOS and tvOS reaches a signed-in state by password or Quick Connect against a live Jellyfin server, survives a relaunch, and signs out cleanly. This is the checkpoint: you can sign in.

## 2. Business Value & Priority

Nothing downstream is demonstrable without a session. Browsing, playback and reporting all take `UserSession` as an input, so this slice is the gate every later slice's acceptance criteria walk through. P0, complexity L: two auth mechanisms, a polling state machine, and the app's first composition root and screens all land here at once.

Not a rung on a version ladder — there is no deferred v2 of sign-in in this spec.

## 3. Scope

**In scope:**
- `JellyfinAuthRepository` plus its DTOs and mappers in `MixtapeData`. A `/System/Info/Public` response missing `Id`, `ServerName` or `Version` throws `.notAJellyfinServer` (decision 31).
- Quick Connect start uses `POST /QuickConnect/Initiate` (decision 5); the `Authorization` header is sent on `/QuickConnect/Enabled` as on every other call (decision 26).
- `KeychainSessionStore` in `MixtapeData`, implementing `SessionStoreProtocol` on top of 003's `KeychainStore`. It also owns the stable `DeviceId` UUID — generated once, persisted alongside the token, and read by every request's `Authorization` header for the lifetime of the install.
- Use cases in `MixtapeUseCase`: `ValidateServerUseCase` (normalises the scheme and trailing slash, tries `https` then `http`), `SignInWithPasswordUseCase`, `StartQuickConnectUseCase`, `PollQuickConnectUseCase` (polls `GET /QuickConnect/Connect`, then exchanges via `POST /Users/AuthenticateWithQuickConnect` itself — decision 21), `RestoreSessionUseCase`, `SignOutUseCase`.
- `SessionService` in `MixtapeServices`, per engineering doc §6, with `quickConnect: QuickConnectUIState` non-optional (decisions 24, 28) — `.idle`, `.waiting(code:)`, `.failed(MixtapeError)`. A `Task` polls every 5 seconds for at most 5 minutes, driven by an injected clock; on expiry it sets `.failed(.quickConnectExpired)` (decision 29). Any use case throwing `.sessionExpired` returns the service to `.signedOut` and clears the Keychain — the single place session expiry is handled.
- Composition root: `AppContainer` in each app target, constructing the client, repository, use cases and services in order; one `@Entry` per service. `RootScreen` switches on `sessionService.state`: `.loading` → a splash view, `.signedOut` → `ServerEntryScreen` → `SignInScreen` / `QuickConnectScreen`.
- Screens in `MixtapePresentation`: `SplashScreen`, `ServerEntryScreen`, `SignInScreen`, `QuickConnectScreen`, `SettingsScreen` (server name, user, Sign Out). tvOS presents `QuickConnectScreen` first with password sign-in as the secondary action (engineering doc §9, tvOS table).
- Accessibility identifier enums, one file per screen's enum, named for the enum (decision 17) — `ServerEntryIdentifiers.swift`, `SignInIdentifiers.swift`, `QuickConnectIdentifiers.swift`, `SettingsIdentifiers.swift`.
- `Mock*` implementations of every service touched here, for previews. Every view file's `#Preview` covers `{loaded, empty, failure}` states (decision 26).

**Out of scope** (name the slice it's deferred to):
- `RootTabScreen` and every browse screen — 005.
- Video and music playback, and their report use cases — 006 through 009.
- The wallet — 010.
- tvOS's own chrome for the signed-in surfaces beyond the sign-in flow's ordering above — 011.

**Plan requirements covered:**
- `§1.1` Connect to one Jellyfin server by URL, validate it — `ValidateServerUseCase` plus `JellyfinAuthRepository.serverIdentity(at:)`.
- `§1.2` Sign in with username + password — `SignInWithPasswordUseCase`.
- `§1.3` Sign in with Quick Connect (code + poll) — `StartQuickConnectUseCase` plus `PollQuickConnectUseCase`.
- `§1.4` Persist session in Keychain, restore on launch, sign out — `KeychainSessionStore`, `RestoreSessionUseCase`, `SignOutUseCase`.
- `§12.1` AC1 — `localhost:8096` with no scheme resolves and connects.
- `§12.2` AC2 — wrong password shows an inline error and keeps the username field.
- `§12.3` AC3 — tvOS Quick Connect code shown, approval in Jellyfin Web signs in within 10 s.
- `§12.4` AC4 — force-quit and relaunch lands signed in with no sign-in prompt.
- `§12.14` AC14 — sign out clears the Keychain; relaunch shows the server entry screen.

No requirement in this list is being built differently from how the engineering doc and `SPEC-DECISIONS.md` describe it, so Section 6 records citations and one slice-local sequencing decision, not forks.

## 4. Pre-Flight Validation

Complete **before the first line of code**, not at close.

**`002` — domain model and pure rules:**
- [x] Opened `002-domain-model-and-pure-rules.md`. Its decision log still says what this slice assumed.
- [x] Not a spike — n/a.
- [x] Its state matches what this slice assumed when drafted: `UserSession`, `ServerIdentity` (non-optional `id`/`name`/`version`/`baseURL` per decision 31), `MixtapeError` (no `.forbidden`, per decision 9), and `QuickConnectUIState` (`.idle` / `.waiting(code:)` / `.failed(MixtapeError)`, per decisions 24 and 28) all exist as specified.
- [x] Architecture standards doc re-read; nothing changed underneath this slice.

**`003` — HTTP client, keychain, logger:**
- [x] Opened `003-http-client-keychain-logger.md`. Its decision log still says what this slice assumed.
- [x] Not a spike — n/a.
- [x] Its state matches what this slice assumed when drafted: `JellyfinHTTPClient`, `AuthContext`, `KeychainStore` and `AppLogger` exist in `MixtapeInfrastructure`, and the status mapping — 401 → `.invalidCredentials` on auth endpoints, `.quickConnectUnavailable` on `/QuickConnect/Enabled` and `/QuickConnect/Initiate` (decision 10), `.sessionExpired` elsewhere; unmapped 4xx → `.transport` (decision 9) — is proven by `MixtapeDataTests`.
- [x] Architecture standards doc re-read; nothing changed underneath this slice.

**`001` — credentials file (decision 45):**
- [x] `.jellyfin-dev.env` exists at the repository root, is untracked, and `git check-ignore` confirms it is ignored. Its `JELLYFIN_USERNAME` and `JELLYFIN_PASSWORD` are what AC1, AC2, AC4 and AC14 below sign in with. They are typed into the simulator, never inlined into a source file, a test, a fixture or a log.

**Drift found:** none.

## 5. Acceptance Criteria

Mechanical:
- [x] `xcodebuild build` passes for both the `iOS` and `tvOS` schemes.
- [x] `xcodebuild test -skip-testing:iOSUITests` passes for `iOS`; `xcodebuild test -skip-testing:tvOSUITests` passes for `tvOS`. Gate 2 expected executed-test count per scheme: **62** — 15 Domain, 19 Data (11 client + 8 auth repository), 15 UseCase, 13 Services; parameterised tests count once. Verified 2026-09-03 via `./scripts/gate.sh 62`.
- [x] `./scripts/check-layer-imports.sh` exits 0.
- [x] `swiftformat --lint .` is clean.

Behavioural:
- [x] `.useCase` tests in `MixtapeUseCaseTests` for all six use cases — success, `.sessionExpired`, `.serverUnreachable` — against `Mock*` repositories.
- [x] `.service` tests in `MixtapeServicesTests` for `SessionService`: restore, sign-in and expiry transitions, plus Quick Connect success, cancel and timeout, all against an injected clock — no test sleeps.
- [x] `.repository` tests in `MixtapeDataTests` for `JellyfinAuthRepository` against a stubbed `URLProtocol`, including the decision-31 null-identity case that must throw `.notAJellyfinServer`.

Acceptance, against `http://localhost:8096` and the iOS/tvOS simulators, signing in with `JELLYFIN_USERNAME` and `JELLYFIN_PASSWORD` from `.jellyfin-dev.env` (decision 45) — the values are entered in the simulator and appear in no source file, test, fixture or log:
- [x] AC1 — entering `localhost:8096` with no scheme resolves and connects.
- [x] AC2 — a wrong password shows an inline error and does not clear the username field.
- [x] AC3 — on the tvOS simulator, the Quick Connect code appears; approving it in Jellyfin Web signs the app in within 10 s.
- [x] AC4 — force-quitting and relaunching the app lands directly on the signed-in root (`SettingsScreen`, see Section 6) with no sign-in prompt.
- [x] AC14 — signing out clears the Keychain; relaunching shows `ServerEntryScreen`.

Verified 2026-09-03 on the iPhone 17 Pro (iOS 26.5) simulator through `idb`, reading each screen by accessibility identifier: AC1 landed on `signIn.*` with the server name "mixtape" after the https→http fallback; AC2 showed `signIn.errorLabel` "Wrong username or password." with `signIn.userNameField` still holding the username; AC4 relaunched straight onto `settings.*`; AC14 showed `serverEntry.*` after sign-out and again after relaunch. AC3 verified on a clone of the Apple TV 4K (tvOS 26.5) simulator by the scratch-copy XCUITest driver described in Section 6 — code shown, approved by API, signed-in root within 10 s (approval `POST /QuickConnect/Authorize` returned 200; the signed-in root appeared 4.1 s after approval, against the 10 s limit).

## 6. Decision Log

**Write the row before you implement the decision, not after.** This is the whole mechanism. A decision log filled in at close is reconstructed from memory, and the rejected alternatives — the part the next slice's pre-flight actually needs — are exactly what memory loses first.

| Date | Decision | Alternatives rejected | Why |
|---|---|---|---|
| 2026-09-03 | `.signedIn` routes to `SettingsScreen` until 005 delivers `RootTabScreen`, so AC14 is demonstrable in this slice | A placeholder `RootTabScreen` built here and thrown away in 005 | `RootTabScreen` and the browse screens are 005's scope; building a stub tab shell here duplicates work 005 does properly, and `SettingsScreen` already exists in this slice's scope regardless |
| 2026-09-03 | `POST /QuickConnect/Initiate`, per decision 5 | see decision 5 | already resolved in `SPEC-DECISIONS.md`; cited here because `StartQuickConnectUseCase` calls this endpoint |
| 2026-09-03 | 401 on `/QuickConnect/Initiate` maps to `.quickConnectUnavailable`, per decision 10 | see decision 10 | already resolved; cited because `JellyfinAuthRepository` relies on 003's status mapping for this exception |
| 2026-09-03 | `.notAJellyfinServer` fires when `/System/Info/Public` returns without `Id`, `ServerName` or `Version`, per decision 31 | see decision 31 | already resolved; cited because `ValidateServerUseCase` and the non-optional `ServerIdentity` mapper implement it |
| 2026-09-03 | `PollQuickConnectUseCase` performs the token exchange itself rather than returning only a poll result, per decision 21 | see decision 21 | already resolved; cited because this slice writes that use case |
| 2026-09-03 | `QuickConnectUIState` is `.idle` / `.waiting(code:)` / `.failed(MixtapeError)`, and `SessionService.quickConnect` is non-optional, per decisions 24 and 28 | see decisions 24 and 28 | already resolved; cited because `SessionService` is typed this way in this slice |
| 2026-09-03 | Quick Connect expiry sets `quickConnect = .failed(.quickConnectExpired)`, per decision 29 | see decision 29 | already resolved; cited because `SessionService`'s 5-minute timer implements it |
| 2026-09-03 | The `Authorization` header is sent on `/QuickConnect/Enabled` even though the call is unauthenticated, per decision 26 | see decision 26 | already resolved; cited because `JellyfinAuthRepository.isQuickConnectEnabled` sends it |
| 2026-09-03 | Accessibility identifiers: one enum per file, named for the enum, per decision 17 | see decision 17 | already resolved; cited because this slice writes the first identifier enums |
| 2026-09-03 | AC1, AC2, AC4 and AC14 sign in with the credentials in the gitignored `.jellyfin-dev.env` that slice 001 created, per decision 45 | see decision 45 | already resolved; cited because this is the first slice that needs a real username and password, and the spike run's leaked-token failure is the one this rule prevents |
| 2026-09-03 | `ValidateServerUseCase` decides "no scheme" by the absence of `://` and, when none was given, tries `https://` first and falls back to `http://` on **any** error from the `https` attempt. With an explicit scheme there is no fallback. | Keying on `URL(string:).scheme == nil`; falling back only on `.serverUnreachable`. | `URL(string: "localhost:8096")?.scheme` is `"localhost"`, so the scheme check would misfire on AC1's exact input. A TLS handshake against Jellyfin's plain-HTTP port fails with `URLError.secureConnectionFailed`, which 003 maps to `.transport`, so a fallback limited to `.serverUnreachable` never reaches `http`. |
| 2026-09-03 | `Mock*` repositories and the mock session store live in `MixtapeUseCase/Mocks/`, beside the protocols they conform to, using Foundation only (`NSLock` for the store's state). `MockSessionService` in `MixtapeServices/Mocks/` is an `enum` of static factories returning real `SessionService` instances wired to those mocks. | Mocks in `MixtapeServices`; a `MockSessionService` subclass; `Synchronization.Mutex`. | `MixtapeUseCaseTests` may only import UseCase and Domain, and §11 wants use-case tests against `Mock*`, so the mocks have to sit at or below UseCase. `SessionService` is `final` so it cannot be subclassed, and Presentation may not construct use cases, so the only way a `#Preview` can show a state is a factory in Services that returns the real class pre-configured. `Mutex` is fine in 6.2 but pulls a second module into a layer that is meant to be Foundation-only. |
| 2026-09-03 | `SessionService.init` takes an `initialState`, `serverIdentity`, `quickConnect` and `error` alongside the use cases and clock, all defaulting to the launch values, so previews and tests can start from any state. | Making the state `var`s settable; a separate preview-only initialiser in a `#if DEBUG`. | The state stays `public private(set)`, so only construction can set it, and one initialiser serves production, previews and tests. |
| 2026-09-03 | `SessionService` exposes `public func handleSessionExpiry()` — clears the store and returns the state to `.signedOut` — and calls it itself whenever a use case throws `.sessionExpired`. | A protocol later services conform to; each service clearing the store itself. | §6 makes `SessionService` the single place expiry is handled; 005's services need one method to call, not a protocol with one conformer. |
| 2026-09-03 | The stable `DeviceId` is read from `KeychainSessionStore.deviceID()` at composition time and injected into `JellyfinAuthRepository.init(client:deviceID:appVersion:)`; the same value is written into every `UserSession`. `SessionStoreProtocol` keeps §5's three methods. | Adding `deviceID()` to `SessionStoreProtocol`; generating the id inside the repository. | `/QuickConnect/Initiate` needs the `DeviceId` header before any session exists (§8), so it must exist at construction. The composition root already sees the concrete store, so the protocol does not need to grow; a repository is a stateless struct and must not own generation. |
| 2026-09-03 | Sign-in flow is platform-split as two files defining the same type, `SignInFlow`, under `#if os(iOS)` (`SignInFlow+iOS.swift`: server entry → password sign-in, Quick Connect as the secondary action) and `#if os(tvOS)` (`SignInFlow+tvOS.swift`: server entry → Quick Connect first, password as the secondary action). `RootScreen` is shared and switches on `sessionService.state` only. | Two differently named flows with an `#if os` inside `RootScreen`'s body; one flow with a branch in the body. | The rule is two files and no branch inside a body; a shared type name is what lets `RootScreen` stay branch-free, and it is the same pattern 003 used for `DeviceName`. The screens themselves are shared — only their order differs. |
| 2026-09-03 | `StartQuickConnectUseCase` checks `isQuickConnectEnabled` before `initiateQuickConnect` and throws `.quickConnectUnavailable` when the server says `false`. `SignInScreen` always offers "Use Quick Connect"; an unavailable server surfaces as `QuickConnectUIState.failed(.quickConnectUnavailable)` on `QuickConnectScreen`. | A separate enabled-check use case feeding a `SignInScreen` toggle. | §5 lists no such use case, and §9's "when enabled" is satisfied with one fewer state to keep in sync: the user learns Quick Connect is off at the moment they ask for it. |
| 2026-09-03 | `scripts/jf-probe.swift` gains an optional leading HTTP method argument (`./scripts/jf-probe.swift POST /QuickConnect/Authorize?code=…&userId=…`); the one-argument form stays a GET. | A second script; approving the code in Jellyfin Web by hand. | AC3 needs the Quick Connect code approved with nobody at a browser; decision 47 makes the probe the one server tool, and one optional argument keeps it so. |
| 2026-09-03 | `AppContainer.swift` lives once in `Apps/Shared/`, a synchronised folder added to both app targets; each target keeps its own `MixtapeApp.swift`. | Two copies of `AppContainer`, one per target, as §10's "both share this shape" reads. | Slices 005–011 each add services to the container; two copies is two chances per slice to diverge. The folder costs two lines in the project file, checked afterwards for `objectVersion = 77`. |
| 2026-09-03 | Credentials reach the simulator through `scripts/sim-type.sh <ENV_KEY>`, which reads the value from `.jellyfin-dev.env` itself and types it through `idb`; the literal never appears in a command line you type, a tool argument or a log. AC2's wrong password is a plain literal. | Typing the values directly through the simulator input tool. | Decision 46 already treats a conversation transcript as a leak surface; a tool argument is a transcript. |
| 2026-09-03 | Acceptance checks drive the simulators with `idb` (Facebook's `idb_companion` via Homebrew, `fb-idb` via `uv`), installed during this slice: `idb ui tap`, `idb ui text`, `idb ui describe-all`. `scripts/sim-type.sh` types through it. | AppleScript keystrokes and clicks into Simulator.app; waiting for a person at the terminal. | The Mac's screen locked mid-run and AppleScript then saw zero Simulator windows, so window-server automation is unavailable to an unattended run. `idb` talks to CoreSimulator directly, works with the screen locked, and exposes every `accessibilityIdentifier` — which is also what the installed xclaude plugin's tap and type tools require. |
| 2026-09-03 | AC3 is driven by a throwaway XCUITest in a scratch **copy** of the repository (outside the worktree, never committed): it launches the installed tvOS app, presses select, types the address, reads `quickConnect.codeLabel`, approves the code through `POST /QuickConnect/Authorize` with the API key read from the env file, and asserts the signed-in root appears in under 10 s. The repository's `tvOSUITests` stub is untouched and no gate runs it. | Writing the driver into the repository's `tvOSUITests` target; waiting for a person to unlock the Mac and type on the Simulator's remote. | On Xcode 27's CoreSimulator, `idb` reports "Keyboard HID is suppressed … use the DTUHID transport" for tvOS (facebook/idb issue #941, no fix), and tvOS has no touch surface, so `idb` cannot enter the address. XCUITest uses the transport CoreSimulator now requires. Decision 4 defers UI *tests* from the deliverable and forbids enabling the repo's targets to check something; a driver in a scratch copy adds nothing to the deliverable and runs in no gate. |
| 2026-09-03 | `EmptyBody` (a `public struct: Encodable` with no fields) moves from the test target into `MixtapeInfrastructure`, used for `POST /QuickConnect/Initiate`, which has no request body. | A fourth client method that posts without a body; a duplicate empty struct in `MixtapeData`. | §7's client contract is three methods and 003 shipped it; an empty JSON object is what the endpoint receives and ignores. |

## 7. Sub-Slices

Not split — delivered as a single slice.

## 8. Testing Strategy

- **Unit / Integration / UI:** unit tests only. `.useCase` suite against `Mock*` repositories, `.service` suite against `Mock*` use cases with an injected clock, `.repository` suite against a stubbed `URLProtocol`. No XCUITest and no CI this round (decision 4).
- **Test targets required:** `MixtapeUseCaseTests`, `MixtapeServicesTests`, `MixtapeDataTests` — all created in slice 001; no new target needed.

## 9. Keeping this document true

This slice is done when the page describes what was actually built — not when the code works. The discipline is **ordering**: the write happens *before* the thing it describes, so it sits on the critical path instead of after it, where it gets skipped.

| Before you… | Write this first |
|---|---|
| implement a decision | the Section 6 row, including what you rejected |
| start work | flip status in the master checklist |
| stop on a blocker | the Active Blockers row |
| build on a spike | that spike's Result section |
| widen scope | Section 3, and `depends_on` on any slice that's now affected |

And in the same commit as the code, not a follow-up: **commit this file alongside it**, with the slice id in the commit subject (`004: add sign-in flow`).

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

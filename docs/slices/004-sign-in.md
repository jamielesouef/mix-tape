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
- [ ] Opened `002-domain-model-and-pure-rules.md`. Its decision log still says what this slice assumed.
- [ ] Not a spike — n/a.
- [ ] Its state matches what this slice assumed when drafted: `UserSession`, `ServerIdentity` (non-optional `id`/`name`/`version`/`baseURL` per decision 31), `MixtapeError` (no `.forbidden`, per decision 9), and `QuickConnectUIState` (`.idle` / `.waiting(code:)` / `.failed(MixtapeError)`, per decisions 24 and 28) all exist as specified.
- [ ] Architecture standards doc re-read; nothing changed underneath this slice.

**`003` — HTTP client, keychain, logger:**
- [ ] Opened `003-http-client-keychain-logger.md`. Its decision log still says what this slice assumed.
- [ ] Not a spike — n/a.
- [ ] Its state matches what this slice assumed when drafted: `JellyfinHTTPClient`, `AuthContext`, `KeychainStore` and `AppLogger` exist in `MixtapeInfrastructure`, and the status mapping — 401 → `.invalidCredentials` on auth endpoints, `.quickConnectUnavailable` on `/QuickConnect/Enabled` and `/QuickConnect/Initiate` (decision 10), `.sessionExpired` elsewhere; unmapped 4xx → `.transport` (decision 9) — is proven by `MixtapeDataTests`.
- [ ] Architecture standards doc re-read; nothing changed underneath this slice.

**`001` — credentials file (decision 45):**
- [ ] `.jellyfin-dev.env` exists at the repository root, is untracked, and `git check-ignore` confirms it is ignored. Its `JELLYFIN_USERNAME` and `JELLYFIN_PASSWORD` are what AC1, AC2, AC4 and AC14 below sign in with. They are typed into the simulator, never inlined into a source file, a test, a fixture or a log.

**Drift found:** none.

## 5. Acceptance Criteria

Mechanical:
- [ ] `xcodebuild build` passes for both the `iOS` and `tvOS` schemes.
- [ ] `xcodebuild test -skip-testing:iOSUITests` passes for `iOS`; `xcodebuild test -skip-testing:tvOSUITests` passes for `tvOS`.
- [ ] `./scripts/check-layer-imports.sh` exits 0.
- [ ] `swiftformat --lint .` is clean.

Behavioural:
- [ ] `.useCase` tests in `MixtapeUseCaseTests` for all six use cases — success, `.sessionExpired`, `.serverUnreachable` — against `Mock*` repositories.
- [ ] `.service` tests in `MixtapeServicesTests` for `SessionService`: restore, sign-in and expiry transitions, plus Quick Connect success, cancel and timeout, all against an injected clock — no test sleeps.
- [ ] `.repository` tests in `MixtapeDataTests` for `JellyfinAuthRepository` against a stubbed `URLProtocol`, including the decision-31 null-identity case that must throw `.notAJellyfinServer`.

Acceptance, against `http://localhost:8096` and the iOS/tvOS simulators, signing in with `JELLYFIN_USERNAME` and `JELLYFIN_PASSWORD` from `.jellyfin-dev.env` (decision 45) — the values are entered in the simulator and appear in no source file, test, fixture or log:
- [ ] AC1 — entering `localhost:8096` with no scheme resolves and connects.
- [ ] AC2 — a wrong password shows an inline error and does not clear the username field.
- [ ] AC3 — on the tvOS simulator, the Quick Connect code appears; approving it in Jellyfin Web signs the app in within 10 s.
- [ ] AC4 — force-quitting and relaunching the app lands directly on the signed-in root (`SettingsScreen`, see Section 6) with no sign-in prompt.
- [ ] AC14 — signing out clears the Keychain; relaunching shows `ServerEntryScreen`.

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
- [ ] Acceptance criteria met
- [ ] Tests passing, in a target that exists
- [ ] Every `covers:` requirement satisfied, or forked with a decision row
- [ ] Decision log written as you went, not reconstructed
- [ ] Pre-flight completed and drift resolved
- [ ] Master checklist row current
- [ ] `next_slice`'s `depends_on` reflects what actually shipped, not what was planned
- [ ] Both link directions checked: this page's `next_slice` and that page's `previous_slice`

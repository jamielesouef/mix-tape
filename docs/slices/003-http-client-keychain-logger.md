---
slice_id: "003"
title: HTTP Client, Keychain and Logger
priority: P0
complexity: M
ladder: none
depends_on:
  - { id: "001", type: hard, note: "MixtapeInfrastructure and MixtapeDataTests targets, Package.swift concurrency settings, and check-layer-imports.sh must already exist" }
  - { id: "002", type: hard, note: "MixtapeError cases and the Duration/ticks conversion this slice's mapping and test fixtures build on" }
previous_slice: "002"
next_slice: "004"
parent_slice: none
covers: []
created: 2026-09-03
---

# 003 — HTTP Client, Keychain and Logger

← [previous](002-domain-model-and-pure-rules.md) · [Master Checklist](MASTER-CHECKLIST.md) · [next](004-sign-in.md) →

> **Status, owner and blockers live in the master checklist, not here.** Dependencies live in this page's front matter and nowhere else. Each fact has one home; if you find yourself writing it twice, one of the two copies is going to be wrong in a fortnight.

## 1. Objective

Build `JellyfinHTTPClient`, `AuthContext`, `KeychainStore` and `AppLogger` in `MixtapeInfrastructure`, so every later slice's networking sits on a status-code mapping that is already proven, not discovered while debugging sign-in.

There is no UI yet to make this observable in the running app, but the observable value stands on its own: a stubbed-`URLProtocol` test suite proves, before a single repository exists, that every 4xx/5xx/`URLError` case this app will ever see resolves to the right `MixtapeError`.

## 2. Business Value & Priority

P0. Slice 004 cannot write a testable `JellyfinAuthRepository` until this client's contract exists, and every later repository (005, 006, 008, 009) calls through the same client. Getting the status-code table wrong here means re-deriving it inside every repository's tests instead of once.

Not a version rung — there is no deferred "v2" of this client. `ladder: none`.

## 3. Scope

**In scope:**
- `JellyfinHTTPClient`: `struct`, `Sendable`, wrapping `URLSession`, with the three-method contract from engineering doc §7 — `get<T: Decodable & Sendable>`, `post<Body, T>`, and a fire-and-forget `post<Body>`.
- `AuthContext`: the header inputs (base URL, device ID, app version, optional token), living in `MixtapeInfrastructure` beside the client, not in Domain — a transport concern per engineering doc §4.
- Header assembly, sent on **every** request, authenticated or not: `Authorization: MediaBrowser Client="mixtape", Device="<device name>", DeviceId="<stable UUID>", Version="<CFBundleShortVersionString>", Token="<access token>"`. The `Token` component is omitted entirely — not sent empty — when `AuthContext.token` is `nil`. Never `X-Emby-Authorization`; Jellyfin is removing it.
- The device name half of the header as two platform files, each wrapped in its own top-level `#if os`, named for what they are — `DeviceName+iOS.swift` (`UIDevice.current.name`) and `DeviceName+tvOS.swift` (`"Apple TV"`) — never one file branching inside a function body.
- The status-code → `MixtapeError` mapping table below, implemented once inside `JellyfinHTTPClient` so no repository re-derives it.
- The JSON decoder configuration: no `keyDecodingStrategy` set, ever. Jellyfin returns PascalCase and every DTO supplies its own explicit `CodingKeys` from slice 004 onward; this client must not paper over a missing one with `.convertFromSnakeCase` or any other automatic strategy.
- `KeychainStore`: `struct`, `Sendable`, generic `Data` get/set/delete for one service+account pair. No session-shaped API yet — that is `KeychainSessionStore`, built on top of this in slice 004.
- `AppLogger`: `struct` over `os.Logger`, one subsystem, categories `network`, `playback`, `auth`.

Status-code mapping:

| Status / condition | `MixtapeError` |
|---|---|
| 401 on `/Users/AuthenticateByName`, `/Users/AuthenticateWithQuickConnect` | `.invalidCredentials` |
| 401 on `/QuickConnect/Enabled` | `.quickConnectUnavailable` (decision 10) |
| 401 on `/QuickConnect/Initiate` | `.quickConnectUnavailable` (decision 10) |
| 401 elsewhere | `.sessionExpired` |
| 404 | `.transport` |
| 5xx (500, 503, …) | `.transport` |
| any other 4xx (400, 403, 405, 415, …) | `.transport` (decision 9 catch-all) |
| `URLError.cannotFindHost` / `.cannotConnectToHost` / `.timedOut` | `.serverUnreachable` |
| JSON decode failure | `.decoding` |

**Out of scope** (name the slice it's deferred to):
- `KeychainSessionStore` (the `SessionStoreProtocol` implementation) and the stable `DeviceId` UUID it generates and persists — slice 004.
- `JellyfinAuthRepository` and every other repository — slices 004, 005, 006, 008, 009.
- Real DTOs and their `CodingKeys` — slice 004 onward; this slice's decode test uses a small test-only `Decodable` fixture to prove the rule, since no production DTO exists yet.
- Keychain correctness at the unit-test level. A simulator's Keychain entitlement makes this flaky to assert directly in a unit test; it is proven instead by AC4 (relaunch stays signed in) and AC14 (sign out clears it) in slice 004, once there is a session to persist.
- Quick Connect, sign-in and every other endpoint call — slice 004.

**Plan requirements covered:** none. This is foundation infrastructure with no user-observable capability of its own; it is recorded in the master checklist as foundation, the same convention slice 001 uses, and the first `§1`/`§12` rows are claimed starting at slice 004.

## 4. Pre-Flight Validation

Complete **before the first line of code**, not at close.

- [ ] Opened `001-package-skeleton-and-gates.md`. Its decision log still says what this slice assumed: `MixtapeInfrastructure` exists as a `Package.swift` target with `.defaultIsolation(MainActor.self)` and `.swiftLanguageMode(.v6)`, `MixtapeDataTests` exists (this slice's tests live there, not in a new `MixtapeInfrastructureTests` target — see Section 6), and `check-layer-imports.sh` runs as part of the gate.
- [ ] 001 is not a spike — n/a.
- [ ] 001's state matches what this slice assumed when drafted, not when 001 was written.
- [ ] Architecture standards doc re-read; nothing changed underneath this slice.
- [ ] Opened `002-domain-model-and-pure-rules.md`. Its decision log still says what this slice assumed: `MixtapeError` has exactly the cases in engineering doc §4 with no `.forbidden` case (decision 9), and the type compiles standalone in `MixtapeDomain` with no dependency this client needs to route around.
- [ ] 002 is not a spike — n/a.
- [ ] 002's state matches what this slice assumed when drafted, not when 002 was written.
- [ ] Architecture standards doc re-read; nothing changed underneath this slice.

**Drift found:** none.

## 5. Acceptance Criteria

- [ ] Both `iOS` and `tvOS` schemes build.
- [ ] `MixtapeDataTests`' `JellyfinHTTPClientTests` suite, tagged `.repository`, passes against a stubbed `URLProtocol` — no live server call anywhere in the suite.
- [ ] Every row of the status-code mapping table above is exercised, including 400, 403, 405, 415 and 503 all resolving to `.transport`, and both `/QuickConnect/Enabled` and `/QuickConnect/Initiate` resolving their 401 to `.quickConnectUnavailable` rather than `.invalidCredentials`.
- [ ] The header is asserted byte-for-byte with a token present and with `AuthContext.token == nil`, confirming the `Token` component is omitted, not sent empty, in the latter case.
- [ ] A PascalCase fixture decodes correctly through a test-only `Decodable` type with explicit `CodingKeys`, proving the client's `JSONDecoder` carries no key-decoding strategy of its own.
- [ ] `./scripts/check-layer-imports.sh` exits 0.
- [ ] `swiftformat --lint .` is clean.

## 6. Decision Log

**Write the row before you implement the decision, not after.** This is the whole mechanism. A decision log filled in at close is reconstructed from memory, and the rejected alternatives — the part the next slice's pre-flight actually needs — are exactly what memory loses first.

| Date | Decision | Alternatives rejected | Why |
|---|---|---|---|
| 2026-09-03 | Adopt `SPEC-DECISIONS.md` decision 9: any unmapped 4xx status maps to `.transport`, with no dedicated `.forbidden` case. | A distinct `.forbidden` case for 403. | Already settled in decision 9 — no second conformer, no test data, and the retry affordance from AC16 covers it either way. Not re-argued here. |
| 2026-09-03 | Adopt `SPEC-DECISIONS.md` decision 10: 401 on `/QuickConnect/Initiate` maps to `.quickConnectUnavailable`, matching the existing `/QuickConnect/Enabled` carve-out, not the blanket auth-endpoint rule. | Leaving the blanket "401 on an auth endpoint → `.invalidCredentials`" rule exception-free. | Already settled in decision 10 — on tvOS, where Quick Connect is the primary sign-in path, a credentials error over a server-configuration problem the user never entered credentials for would be actively misleading. Not re-argued here. |
| 2026-09-03 | This slice's tests live in `MixtapeDataTests`, tagged `.repository`. No `MixtapeInfrastructureTests` target is created. | A dedicated `MixtapeInfrastructureTests` target mirroring the other three layer test targets one-for-one. | `MixtapeData` is the only consumer of `JellyfinHTTPClient` and already imports `MixtapeInfrastructure` per the §3 dependency table, so a fifth test target would exist to hold tests for exactly one type, with no other Infrastructure type gaining tests this round. Recorded here as well as in 001 because it is this slice's own testing strategy, not just 001's target list. |

## 7. Sub-Slices

Not split — delivered as a single slice.

## 8. Testing Strategy

- **Unit / Integration / UI:** Unit only, against a stubbed `URLProtocol`. No live server call in any test — `http://localhost:8096` is for manual acceptance checks, never for an automated one. No XCUITest, no CI (decision 4).
- **Test targets required:** `MixtapeDataTests`, already scaffolded in slice 001 with a placeholder `@Test`. This slice replaces that placeholder with the real `JellyfinHTTPClientTests` suite, tagged `.repository`.

## 9. Keeping this document true

This slice is done when the page describes what was actually built — not when the code works. The discipline is **ordering**: the write happens *before* the thing it describes, so it sits on the critical path instead of after it, where it gets skipped.

| Before you… | Write this first |
|---|---|
| implement a decision | the Section 6 row, including what you rejected |
| start work | flip status in the master checklist |
| stop on a blocker | the Active Blockers row |
| build on a spike | that spike's Result section |
| widen scope | Section 3, and `depends_on` on any slice that's now affected |

And in the same commit as the code, not a follow-up: **commit this file alongside it**, with the slice id in the commit subject (`003: add HTTP client status mapping`).

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

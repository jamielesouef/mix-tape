---
slice_id: "020"
title: Session-owned teardown and cache invalidation
priority: P0
complexity: M
ladder: none
depends_on:
  - { id: "019", type: hard, note: "019's evidence paragraph recorded the defect live: the mini player kept playing 'In the Name of the Father' through sign-out and two sign-ins. This slice fixes exactly that observation" }
previous_slice: "019"
next_slice: "021"
parent_slice: none
covers: []
created: 2026-09-07
---

# 020 — Session-owned teardown and cache invalidation

← [previous](019-codex-review-bounded-fixes.md) · [Master Checklist](MASTER-CHECKLIST.md) · [next](021-playback-operation-generations.md) →

> **Status, owner and blockers live in the master checklist, not here.** Dependencies live in this page's front matter and nowhere else. Each fact has one home; if you find yourself writing it twice, one of the two copies is going to be wrong in a fortnight.

## 1. Objective

`SessionService` becomes the single owner of what happens to every other service when a session ends — sign-out, expiry, or a fresh sign-in replacing an old one. Observable on its own: sign out while an album is playing and the mini player stops immediately and silently, sign back in as a different user and Home shows that user's libraries with nothing left over from the first.

## 2. Business Value & Priority

Codex High #1: `SessionService` clears its own credentials but nothing else, so `LibraryService`, `SeriesService`, `MusicPlayerService` and `VideoPlaybackService` keep whatever they were holding — cached pages, a playing album, an open video session — across a sign-out. 019's evidence paragraph reproduced it: the mini player played through a sign-out and two subsequent sign-ins. P0 because this is a live disclosure and control-loss path in the ordinary sign-out flow, not an edge case, and every later slice in the round (021's generations, 023's refresh invalidation) needs a named teardown owner to sit beside.

## 3. Scope

**In scope:**

- **Codex High #1** — every session-scoped service stops holding session N's state once `SessionService` ends session N. `LibraryService`, `SeriesService`: caches return to `.idle` (not `.failed` — screens only refetch from idle, per the codex recommendation). `MusicPlayerService`, `VideoPlaybackService`: the active player stops synchronously and a best-effort stopped report is sent for the track or item that was live, using the session that just ended.
- **Testing — no cross-user/session cache isolation tests** — `MixtapeServicesTests` gains a test that signs in as user A, loads a library page, signs out, signs in as user B, and asserts `LibraryService.pages` is empty and `libraries` is `.idle`, not `.failed` or carrying A's data.
- **The re-entrancy hazard this slice's own fan-out creates** — `SessionService.handleSessionExpiry()` is already called *from inside* `LibraryService`'s and `SeriesService`'s own `catch` blocks (via `handle(_:)`). A synchronous, unguarded fan-out that clears `pages` and then returns control to that same catch block, which then writes `pages[id] = .failed(...)`, would repopulate a cache this slice just cleared — one of codex's "smaller correctness concerns" ("refresh does not invalidate in-flight requests"), for the sign-out case specifically. Guarded here per the decision log; the general refresh case (a refresh racing an in-flight load with no sign-out involved) is 023's.

**Out of scope** (name the slice it's deferred to):

- Generalised stale-completion protection for playback operations (rapid play/next/stop racing each other with no session change involved) — codex High #2 → 021. This slice's players guard only the session-ending write; 021 owns the operation-generation mechanism the players use for every other race.
- `ImageService` — recorded, not changed, by decision row below.
- Refresh invalidating in-flight requests in the general case (no sign-out) → 023.
- Request coalescing for tracks/series → 023.

**Plan requirements covered:** none. Defect work, gated on builds, tests and the scripts, plus the demonstration below.

## 4. Pre-Flight Validation

- [x] **019** — open it; confirm the evidence paragraph's observation (mini player survives sign-out and two sign-ins) still reproduces before this slice's fix, so the acceptance run has a documented "before" to contrast with "after".
- [x] Confirm `UserSession` (`MixtapeDomain/UserSession.swift`) is `Equatable` — the sign-out guard below compares a captured session against `SessionService`'s current one by value, not identity.
- [x] Confirm `AppContainer` (`Apps/Shared/AppContainer.swift`) is still the only place all six services are visible — the fan-out this slice adds is wired there, not inside `SessionService`.
- [x] Architecture standards doc re-read; nothing changed underneath this slice.

**Drift found:** none.

## 5. Acceptance Criteria

- [x] **AC20a** — `MixtapeServicesTests`: sign in as user A (`SessionService.state = .signedIn(A)`), call `LibraryService.loadLibrary(id:)`, assert `pages[id]` is `.loaded`. Call `SessionService.signOut()`. Assert `libraryService.pages` is empty and `libraryService.libraries == .idle` (not `.failed`).
- [x] **AC20b** — same test, continued: sign in as user B, assert `LibraryService.loadHome()` fetches fresh data (the stub repository's call count for user B is 1, not 0) — the idle state actually triggers a refetch rather than being mistaken for "already loaded".
- [x] **AC20c** — `MixtapeServicesTests`: with `MusicPlayerService` mid-album (`status == .playing`), call `SessionService.signOut()`. Assert synchronously after the call: `status == .idle`, `album == nil`, `queue.isEmpty`. Assert the stub audio controller's `stop()` was called before any reporting stub method returns (ordering, not just eventual state).
- [x] **AC20d** — same shape for `VideoPlaybackService`: mid-playback, `SessionService.handleSessionExpiry()` is called (the `.sessionExpired` path, not just explicit sign-out); assert `status == .idle` and the stub video controller's `teardown()` was called.
- [x] **AC20e** — `MixtapeServicesTests`: reproduces the re-entrancy hazard directly, two ways. (i) The general case — `LibraryService.loadLibrary(id:)` is in flight against a stub repository held open on a `Gate`; while it is in flight, `SessionService.handleSessionExpiry()` fires *externally*; the gate is then opened and the stub's (now-stale) response arrives. Assert `pages[id]` stays absent (or `.idle`), never `.failed` with the stale error and never `.loaded` with the stale page. (ii) The narrower, own-catch-block case bullet 3 names — the stub repository's `fetchLibraryItems` itself `throw`s `.sessionExpired` (no external `Gate`, no separate trigger), so `handle(error)` is invoked synchronously from inside `loadLibrary`'s own `catch` clause and fires the fan-out from there. Assert `pages[id]` never receives the stale `.failed` write in this exact control flow — a fix that only passes case (i) does not necessarily pass case (ii).
- [x] **AC20f** — iOS simulator, `localhost:8096`: play an album, confirm `/Sessions` shows the app's session with `NowPlayingItem` via `jf-probe.swift`, sign out, and within 2 s `/Sessions` shows no `NowPlayingItem` for the app's device and the mini player is gone from every tab. Sign in as a second test account (or the same account twice) and confirm Home loads fresh rather than showing a stale spinner state.
- [x] `xcodebuild build` and `test` pass for both schemes; layer, glass and swiftformat clean.

**Evidence, 2026-09-07, iPhone 17 Pro simulator (iOS 26.5) against `localhost:8096`, read through `scripts/jf-probe.swift /Sessions` and `idb ui describe-all`.** Gate: `.gate-log` 14:01:59, 192/0/0 on both schemes (five new `MixtapeServicesTests`, AC20a–e). Pre-flight: `UserSession` is `Equatable` (`MixtapeDomain/UserSession.swift:9`); `AppContainer` is still the only holder of all six services; the 019 observation reproduced before the fix. *AC20f* — "King Of Terrors" playing, `/Sessions` showing `NowPlayingItem` "In the Name of the Father" at 6 s; `settings.signOutButton`; the next screen was `serverEntry.urlField` with no `miniPlayer.*` element, and `/Sessions` read within 2 s showed the app's device with no `NowPlayingItem`. Signing in again landed on Home and the Libraries tab listed Movies and Music from a fresh fetch. Choices recorded by the implementer: the fan-out is a closure `SessionService.onSessionEnded` set once by `AppContainer` (sign-out is called from `SettingsScreen`, so a return value would never reach the root); only `signOut()` and `handleSessionExpiry()` fire it, because no code path replaces a live session without signing out first. Input for 021, not fixed here: `VideoPlaybackService.play()`'s `catch` still writes `.failed(.sessionExpired)` after `handle(error)` has already ended the session — the generation guard 021 adds to that `catch` closes it. Input for 023: with `onSessionEnded` unwired (tests, previews) an expiry leaves a cache at `.loading`; production always wires it.

## 6. Decision Log

**Write the row before you implement the decision, not after.**

| Date | Decision | Alternatives rejected | Why |
|---|---|---|---|
| 2026-09-07 | `SessionService` owns ending a session but does not hold references to the other five services. Each session-scoped service (`LibraryService`, `SeriesService`, `MusicPlayerService`, `VideoPlaybackService`) gains one method, `endSession()`, that synchronously stops/clears everything session N held. `AppContainer` — the composition root, already the one place that sees all six layers — wires the fan-out: `SessionService`'s sign-out and expiry paths return the session that just ended, and `AppContainer` (or a small closure it hands to `SessionService` at construction) calls `endSession()` on each dependent service in turn. | (a) A new `SessionLifecycleCoordinator` type that holds all five services and is the thing `AppContainer` builds instead of wiring them itself — codex's own recommendation, read literally. (b) Each dependent service uses `withObservationTracking` on `sessionService.state` to notice a sign-out on its own. (c) Inject the five dependent services into `SessionService.init` so it can call `endSession()` directly. | (a) is one more type with one implementation and no seam anything else will ever plug into — `AppContainer` already is the coordinator; CLAUDE.md bars a service locator and this would be one wearing a different name. (b) has no defined ordering between five independent observation callbacks and reintroduces the exact race this slice exists to close. (c) is a dependency cycle: `LibraryService` already takes `sessionService` as a constructor argument, so `SessionService` cannot also take `LibraryService` — the six-target dependency graph in CLAUDE.md has `MixtapeServices` types depend on each other in one direction, never back. |
| 2026-09-07 | `endSession()` on `LibraryService` and `SeriesService` resets every cache to its `.idle`/empty starting value — `libraries = .idle`, `continueWatching = .idle`, `pages = [:]`, `details = [:]`, `tracks = [:]` (or `seasons`/`episodes` for `SeriesService`) — never `.failed`. | Setting every `LoadState` to `.failed(.sessionExpired)` so a screen shows an explicit "session ended" message. | Every load method in both services (`loadHome`, `loadLibrary`, `loadTracks`, …) treats `.loaded` as "skip, already cached" and treats anything else as "fetch" — but only from `.idle`: `HomeScreen.swift:56`, `LibraryListScreen.swift:50`, and `LibraryTabScreen.swift:54` all gate their `.task` refetch on `if case .idle`, never on `.failed`. A `.failed` state shows a `RetryView` requiring an explicit manual tap and never auto-refetches, so resetting to `.failed` would leave the next screen stuck on a stale failure/retry view indefinitely, not just flash one briefly. `.idle` fetches with no visible failure flash — codex's own recommendation is "cancel work and clear every user-scoped cache", which reads as "as if nothing had ever loaded", not "as if the load had errored". |
| 2026-09-07 | `MusicPlayerService.endSession()` and `VideoPlaybackService.endSession()` are synchronous with respect to the player: `controller.stop()` / `controller.teardown()` and the observable `status = .idle` transition happen before the method returns. The stopped report for whatever was playing is sent from a plain `Task { ... }` (not `Task.detached` — nothing in `MixtapeServices` uses `Task.detached` today; `reportOnce`/`trackDidEnd` already fire-and-forget the same way and already inherit `@MainActor` isolation under `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`, which this report keeps too) using the `UserSession` the method was handed (the one that just ended), not `self.session` (which is already `nil` by the time the report use case runs, since `SessionService.state` flips before or during the fan-out). | (a) Skip the stopped report entirely on session end — simplest, but it means Jellyfin's own session list keeps showing the app "playing" until its own timeout, which is the same class of drift codex flagged for §1.13. (b) Make the report synchronous too, i.e. `endSession()` becomes `async` and blocks the sign-out UI on a network round trip. (c) `Task.detached` instead of a plain `Task` — drops `@MainActor` isolation for no reason and is inconsistent with every other fire-and-forget report in this codebase. | (a) trades a real defect for one Jellyfin already tolerates (a stale `/Sessions` entry that times out); still not free, but strictly better than leaving the local player running, which is this slice's actual objective. (b) reintroduces exactly the network-sized UI gap codex High #2 describes for the ordinary next/stop path — sign-out must not wait on it. (c) has no isolation reason to exist here and risks an isolation-mismatch bug if implemented literally. This is the first "report fired off the transport path" in the codebase; 021's pre-flight must read this row before generalising the pattern rather than inventing a second one — and once 021 lands its serialised `reportTask` chain, this report is folded into that same chain rather than staying a second, unordered fire-and-forget path (021 §6 row 4). |
| 2026-09-07 | The re-entrancy hazard (`handleSessionExpiry()` invoked mid-fetch from inside `LibraryService.handle(_:)`'s own catch block) is closed with a session-identity guard at every write site that follows an `await`, evaluated in this exact order: **first** call `handle(error)` (which may itself trigger the `endSession()` fan-out as a side effect), **then** re-read `session` fresh, **then** compare it against the `epoch` captured before the `await`, **then** conditionally write. A guard checked *before* `handle(error)` runs is not sufficient — `session == epoch` still holds at that point (the fan-out hasn't fired yet), `handle(error)` then clears `pages` as a side effect inside the branch that is about to write, and the write executes anyway, repopulating the cache `endSession()` just cleared. Each load method captures `let epoch = session` before its `await fetchX(...)`, and after the `await` returns — success or `catch` — writes to `pages`/`details`/`tracks`/`libraries`/`continueWatching` only `if session == epoch`, checked after any error-handling side effect that call produces. `UserSession` is already `Equatable`, so this needs no new type. | (a) A dedicated generation counter bumped on every `endSession()`, checked instead of session equality. (b) A lock/queue that serialises `endSession()` against any in-flight load. (c) Checking the guard before calling `handle(error)`, then writing unconditionally inside the true branch. | (a) is exactly the mechanism 021 is building for playback; introducing it here for two read-only caches, one slice early, means two competing generation schemes by the time 021 lands. Session equality is free (the type already exists, already flows through every method signature) and sufficient because the only way `session` changes value here is a sign-out, sign-in or expiry — the three events this slice cares about. (b) adds ordering machinery for a case that resolves with a value comparison. (c) is the reentrancy bug itself: it passes the guard, then lets `handle(error)`'s own fan-out fire before the (now stale) write lands. |
| 2026-09-07 | `endSession()` does not clear `inFlight` on `LibraryService`/`SeriesService`. | Clearing `inFlight` alongside `pages`/`libraries`/etc. | `exhausted` self-heals (`loadLibrary` removes an id before every load) and `refresh()` itself never clears `inFlight` either, so no existing precedent is broken. A narrow edge case remains: a stale in-flight request for library id X that outlives the ended session leaves `inFlight.contains(id)` true, so a same-id `loadLibrary` call from the *next* session silently no-ops via the existing `guard inFlight.contains(id) == false` until the stale request completes and removes it. Accepted here as a documented, bounded risk (one request's worth of delay, self-clearing) rather than fixed, since fixing it needs the same after-`await` re-check this row's neighbour already adds for `pages` et al., and `inFlight` membership is set before the `await`, not after — a difference worth its own pass rather than a same-commit tack-on. |
| 2026-09-07 | `ImageService`'s cache is left unchanged by this slice — no `endSession()`, no clearing on sign-out. | Clearing the `NSCache` on every session end, matching the other four services. | Image URLs carry no auth (decision 25) and are keyed by a URL that embeds the server host, item id and image tag — never a user id or access token. Two different users on the same server see the same cached poster for the same item, correctly; there is no cross-user leak to close, only a cache that would be dropped for no reason. If a future multi-server session model changes what a cache key means, that is a decision for whoever builds it, not a silent scope-widening here. |

## 7. Sub-Slices

Not split — delivered as a single slice.

## 8. Testing Strategy

- **Unit:** `MixtapeServicesTests` (`.service`) — AC20a–AC20e above, using the existing `StubAudioPlayerController`, `StubVideoPlayerController` and `Gate` (the latch already used elsewhere in this suite for holding a stubbed call in flight). No new test-helper type is required. **Gap this leaves:** `AppContainer` (`Apps/Shared/AppContainer.swift`) is outside `MixtapeKit`, and `MixtapeServicesTests`' target dependencies (`MixtapeServices`, `MixtapeInfrastructure`, `MixtapeDomain` only) cannot construct or exercise it — AC20a–e prove each service's `endSession()` behaves correctly once invoked directly, not that `SessionService`'s sign-out/expiry paths genuinely trigger all four services' `endSession()` in the shipped `AppContainer` wiring. Only AC20f (the simulator demonstration) verifies that composition-root wiring for real; the unit suite does not and cannot.
- **Demonstration:** AC20f, iOS simulator against `localhost:8096`, read through `scripts/jf-probe.swift`.
- **Test targets required:** `MixtapeServicesTests` (exists). `docs/slices/test-count.txt` changes in the same commit as the new tests.

## 9. Keeping this document true

| Before you… | Write this first |
|---|---|
| implement a decision | the Section 6 row, including what you rejected |
| start work | flip status in the master checklist |
| stop on a blocker | the Active Blockers row |
| widen scope | Section 3, and `depends_on` on any slice that's now affected |

Commit this file alongside the code, with the slice id in the subject (`020: …`).

## 10. Definition of Done

- [x] Acceptance criteria met
- [x] Tests passing, in a target that exists
- [x] Decision log written as you went, not reconstructed
- [x] Pre-flight completed and drift resolved
- [x] Master checklist row current
- [x] `next_slice`'s `depends_on` reflects what actually shipped, not what was planned
- [x] Both link directions checked: this page's `next_slice` and that page's `previous_slice`

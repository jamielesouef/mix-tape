---
slice_id: "021"
title: Playback operation generations and off-path reporting
priority: P0
complexity: L
ladder: none
depends_on:
  - { id: "020", type: hard, note: "020 names the teardown owner (AppContainer's fan-out, triggered from SessionService's sign-out/expiry paths, calling endSession() on each of the four dependent services: LibraryService, SeriesService, MusicPlayerService, VideoPlaybackService) and the off-path-report pattern (a plain Task, session captured before the await). This slice's generation token must respect that owner rather than add a second one, and its serialised reports follow the same off-path shape 020 introduced first" }
previous_slice: "020"
next_slice: "022"
parent_slice: none
covers: []
created: 2026-09-07
---

# 021 — Playback operation generations and off-path reporting

← [previous](020-session-owned-teardown.md) · [Master Checklist](MASTER-CHECKLIST.md) · [next](022-direct-stream-url.md) →

> **Status, owner and blockers live in the master checklist, not here.** Dependencies live in this page's front matter and nowhere else. Each fact has one home; if you find yourself writing it twice, one of the two copies is going to be wrong in a fortnight.

## 1. Objective

Rapid play/next/previous/stop on either player can no longer let a stale network completion, a stale controller callback, or a stale progress task touch a track or item that has since been replaced. Local transport transitions are immediate; reporting happens off that path. Observable on its own: hammer Next on the wallet or double-tap a video's replay control on the simulator, and the displayed track/item and the `/Sessions` state on the server never show a mismatch, even under an artificially slowed network.

## 2. Business Value & Priority

Codex High #2, in full: `MusicPlayerService.next()`, `.previous()`, `trackDidEnd()` and `.stop()` all `await reportStoppedForCurrent()` before the local transition happens, so a slow (up to the configured 15 s) stopped report delays the next track's start or leaves audio running after `stop()` is called. There is no operation-generation token, so a stale artwork request, report, or progress tick can update a newer track. `VideoPlaybackService.play()` has a related but distinct family: a stale `resolveVideo` failure can stomp a newer `.playing` state, the same-item-replay case passes the existing item-ID-only guard, controller callbacks are not tied to the operation that installed them, and a progress task can fire after the operation it was started for has ended. P0 because this is the mechanism behind an already-observed defect (Triage 25's flaky test is this exact race surfacing in the test suite itself) and because 020 built its teardown on a session-identity guard that this slice must not duplicate with a second, incompatible scheme.

## 3. Scope

**In scope:**

- **Codex High #2, video half** — `VideoPlaybackService` gains an `OperationGeneration` (a small `Equatable` value type, `MixtapeServices`, UUID-backed) minted at the top of `play()` **and at the top of `stop()`**. It is captured by every closure `play()` installs on the controller (`onPositionChange`, `onTransportEvent`, `onEnded`, `onFailure`) and checked — alongside the existing `status == .preparing` check, not instead of it — before any of them mutate service state: `guard status == .preparing, generation == self.currentGeneration else { return }`. This replaces only the `self.item?.id == item.id` half of the guard at `VideoPlaybackService.swift:93`; the `status == .preparing` half stays, because it is what protects the post-`stop()` case (see the next bullet). The same generation check guards the `catch` at `VideoPlaybackService.swift:113` (`status = .failed(handle(error))`), which has no guard at all today, so a stale resolution *failure* can no longer stomp a newer or stopped state with `.failed`. `startProgressReporting()`'s loop also checks the generation, not only `status == .playing`, before sending a report.
- **Codex High #2, video local-transition-first half** — `stop()` already tears the controller down before awaiting the stopped report (confirmed unaffected by this slice) and now also mints a fresh `OperationGeneration` before doing so, so any completion or failure still in flight from the operation `stop()` just ended can never match `self.currentGeneration` again, however long it takes to arrive. The generation guard — combined with the `status == .preparing` check it now sits alongside — is what stops a stale `resolveVideo` completion from resurrecting a `.playing` state after `stop()` has moved on.
- **Codex High #2, music half** — `MusicPlayerService` gains the same `OperationGeneration`, minted in `start(index:)`. `next()`, `previous()` and `trackDidEnd()` no longer `await reportStoppedForCurrent()` before calling `start(index:)` or `finish()`: the local transition (`controller.load`/`play`, `status`, `currentIndex`) happens first, and the stopped report for the *track being left* is sent off that path — a detached `Task`, generation-guarded, snapshotting the track, position and session at the moment of the transition, in the same off-path shape 020 introduced for session-ending reports. `stop()` gets the same treatment: `controller.stop()` and the observable `.idle` transition happen before the stopped report is awaited, not after.
- **Codex High #2, "a replacement play does not first stop and report the previous track"** — `play(album:tracks:startingAt:)` now sends a stopped report for whatever track was current before the new album replaces the queue, using the same off-path, generation-guarded report path as `next()`/`previous()`.
- **Serialised, not detached, off-path reports** — the off-path reports for a single player are chained through one `Task` reference per service (a report `Task` awaits the previous one, if any, before running), so a rapid double-skip cannot deliver "started track 3" to the server before "stopped track 1" — order at the server matches order on screen. This is stronger than 020's one-shot session-ending report, which has nothing after it to race.
- **Testing — no delayed-collaborator race tests** — `MixtapeServicesTests` gains tests for: rapid play→next→next on `MusicPlayerService` with a `Gate`-held stub report call, asserting the final displayed track matches the final server-visible report and no intermediate track's report lands after a later one's; rapid play→stop and same-item replay on `VideoPlaybackService` with a `Gate`-held stub `resolveVideo`, asserting a stale resolution never sets `.playing` or `.failed` on top of a newer or stopped state.
- **Triage 25** — `VideoPlaybackServiceTests`'s "progress fires once per interval while playing" is rewritten to be deterministic (see §6 row and §8).

**Out of scope** (name the slice it's deferred to):

- Direct-stream URL construction and player routing for direct-stream-only sources — codex High #4 → 022.
- Audio-session interruptions/route changes, video's `.playback` category, `ImageService`, `LibraryService`/`SeriesService` pagination and coalescing, and the general (non-sign-out) refresh-invalidation case, which reuses this slice's generation → 023.
- Any change to what a report contains, or to the §1.1 invariants. The queue is the album; this slice changes *when* a report is sent, never what triggers one.

**Plan requirements covered:** none. Defect work, gated on builds, tests and the scripts, plus the demonstration below.

## 4. Pre-Flight Validation

- [ ] **020** — opened. Confirm `AppContainer`'s `endSession()` fan-out (`LibraryService`, `SeriesService`, `MusicPlayerService`, `VideoPlaybackService`) and its off-path report shape (a plain `Task`, session captured before the `await`, per 020 §6) still match what this slice assumes; this slice's `OperationGeneration` is a *different* mechanism (which playback operation is current) from 020's session-identity guard (which session is current), not a replacement for it. `LibraryService`/`SeriesService` keep the session-equality guard from 020 unchanged by this slice — this slice mints no generation for either of them. 023 later gives them a generation too, for the general (non-sign-out) refresh-invalidation case; per row 1 below, `OperationGeneration` is named for what it guards, not for the player, precisely so that reuse does not need a second type. The two guards on `LibraryService`/`SeriesService` will then be additive at each write site (session-identity for the sign-out/expiry case, generation for the same-session refresh case), not competing — see 023 §6 for the row that states this once both slices exist.
- [ ] Read `MixtapeServicesTests/Gate.swift`, `ReportLog.swift`, `Recorder.swift`, `Counter.swift` before writing a new test helper — `Gate` is already the latch that holds one stubbed call in flight while a test drives another, and is the primitive the race tests in this slice need; do not add a second one.
- [ ] Architecture standards doc re-read.

**Drift found:** none.

## 5. Acceptance Criteria

- [ ] **AC21a** — `MixtapeServicesTests`: `VideoPlaybackServiceTests` — start `play(item: A)` against a stub repository held on a `Gate`; before it resolves, call `play(item: B)` (a different item) to completion. Open the gate. Assert the service's `item`/`plan`/`status` reflect B, never A, and the stub controller installed for A's (now-late) callbacks never fires against B's state.
- [ ] **AC21b** — same shape, same item: `play(item: A)` twice in a row, the first held on the gate. Assert the second `play(item: A)` is the one that ends up live — the item-ID-only guard this replaces would have let the first (stale) completion pass the `self.item?.id == item.id` check and overwrite the second's `plan`.
- [ ] **AC21c** — `MixtapeServicesTests`: `MusicPlayerServiceTests` — `play(album:tracks:startingAt: 0)`, then immediately `next()`, then immediately `next()` again, with the reporting stub held on a `Gate` so all three stopped/start reports are pending at once. Open the gate. Assert `ReportLog.entries` shows the reports in call order (track 0 stopped before track 1 started before track 1 stopped before track 2 started) — the serialisation criterion — and that `music.current` is track 2 throughout, never reverting to an earlier track once a later report drains.
- [ ] **AC21d** — `MixtapeServicesTests`: `MusicPlayerServiceTests` — `next()` on a stub controller whose `stop()`/report path is slow (via `Gate`) completes the local transition (`currentIndex`, `status`, the stub's `load`/`play` calls) before the gate opens, proving the local transition no longer awaits the network report.
- [ ] **AC21e** — `MixtapeServicesTests`: `MusicPlayerServiceTests` — `play(album: X)` while album `Y` is current and playing; assert a stopped report for `Y`'s current track is sent (present in `ReportLog.entries`) before `X`'s first track's start report.
- [ ] **AC21f** — Triage 25 closed: `VideoPlaybackServiceTests`'s progress-cadence test no longer calls `eventually` to poll `ReportLog`; it awaits the report directly (see §6/§8), and three consecutive `xcodebuild test` runs of `MixtapeServicesTests` on the tvOS scheme pass with no flake, logged in `.gate-log`.
- [ ] **AC21h** — `MixtapeServicesTests`: `VideoPlaybackServiceTests` — `play(item: A)` held on a `Gate` mid-`resolveVideo`; call `stop()`; open the gate twice, once resolving to success and once (a separate run) to a thrown error. Assert in both cases: `status == .idle`, `item == nil`, and no controller was installed — the stale completion (success or failure) never resurrects a `.playing` or `.failed` state on top of the stopped one. This is the play→stop race §3's own testing bullet promises and AC21a/AC21b (both play-then-play, no stop) do not cover.
- [ ] **AC21g** — iOS simulator, `localhost:8096`: rapid-tap Next on the wallet's Now Playing three times inside 2 s; `jf-probe.swift` against `/Sessions` shows the final `NowPlayingItem` matching the on-screen track, with no report for an earlier track observed after a later one's timestamp.
- [ ] `xcodebuild build` and `test` pass for both schemes; layer, glass and swiftformat clean.

## 6. Decision Log

**Write the row before you implement the decision, not after.**

| Date | Decision | Alternatives rejected | Why |
|---|---|---|---|
| 2026-09-07 | A new value type, `OperationGeneration` (`MixtapeServices`, `Sendable`, `Equatable`, backed by a `UUID`), one instance per service (`MusicPlayerService`, `VideoPlaybackService`), minted at the top of the method that starts a new operation (`start(index:)`, `play(item:startAt:)`) and captured by every closure and detached report `Task` that method installs. Named for what it guards — a playback operation — not for the player, so 023 can reuse the same type on `LibraryService.refresh()` without the name implying playback. | (a) Reuse 020's session-identity (`UserSession ==`) guard for this too. (b) A monotonically increasing `Int` counter instead of a UUID. | (a) is the wrong epoch: a session can stay identical across ten rapid `next()` calls, so session equality cannot distinguish operation 3 from operation 4 within the same session — it is 020's tool for a different problem (has the *session* changed), not this slice's (has the *operation* changed). (b) works equally well but a UUID needs no shared mutable counter to protect with its own lock across the detached report tasks this slice adds; equality is the only operation either type needs, so there is no reason to prefer the counter's ordering, which nothing here uses. |
| 2026-09-07 | `VideoPlaybackService.swift:93`'s guard becomes `guard status == .preparing, generation == self.currentGeneration else { return }`, dropping only the `self.item?.id == item.id` half, keeping the `status == .preparing` half. The same generation check is added to the `catch` block at `VideoPlaybackService.swift:113`, which today has no guard at all. | (a) Keeping the item-ID check alongside the generation check, belt-and-braces. (b) Dropping both the item-ID check and the `status == .preparing` check, leaving only the generation check. | (a) The item-ID check is what let a same-item replay's stale completion through in the first place (AC21b) — a second `play(item: A)` shares A's id with the first, so the check that is supposed to catch staleness agrees with the stale call. Keeping it adds no protection the generation does not already provide and keeps a foothold for the exact bug this slice closes. (b) was this row's own first draft, and it reopens a *different* bug rather than closing one: `stop()` sets `status = .idle` and `item = nil` but, before the neighbouring row's fix, did not mint a new generation, so a stale `resolveVideo` completion for the operation `stop()` just ended could still carry `generation == self.currentGeneration` and resurrect a `.playing` state after the user stopped playback. Keeping `status == .preparing` closes that hole immediately (`.idle != .preparing`); the neighbouring row's generation-on-`stop()` fix closes it independently too, and both together are cheaper than reasoning about which one alone is sufficient. |
| 2026-09-07 | `stop()` mints a fresh `OperationGeneration` before tearing the controller down, in addition to `play(item:startAt:)` minting one at the top of a new operation. | Leaving `stop()` out of the set of methods that mint a generation, relying on the `status == .preparing` guard alone to block a stale post-`stop()` completion. | Relying on `status == .preparing` alone is exactly today's guard, and it is what this slice exists to strengthen, not lean on unchanged — a future guard change that drops the status half (the mistake the row above documents making once already) would silently reopen the post-`stop()` resurrection case with nothing left to catch it. Minting a fresh generation on `stop()` too means the post-`stop()` case is closed by two independent mechanisms, matching the belt-and-braces reasoning the row above already accepts for the item-ID check. |
| 2026-09-07 | Off-path reports for a single player are serialised through one `Task<Void, Never>?` reference the service holds (`reportTask`), chained: each new off-path report is `Task { await previousReportTask?.value; <send this report> }`, and the reference is updated to the new task before the old one is awaited. | (a) Fire each off-path report as its own detached `Task` with no ordering between them. (b) A `Gate`-style single-slot latch that only ever holds the most recent report, dropping an in-flight one if a newer one arrives. | (a) is what 020 does for the one-shot session-ending report, which is safe there because nothing follows it in the same session — here, three reports for three rapid transitions racing the network could arrive at the server in any order, so `/Sessions` could show track 3 started, then track 1 stopped, landing last and clobbering the display with stale state (AC21g's failure mode). (b) drops a report instead of reordering it, which under-reports to Jellyfin (a stopped report that never arrives leaves a phantom "still playing" entry) rather than reordering — worse for the server-side session list than a short queue of pending POSTs. |
| 2026-09-07 | `MusicPlayerService.endSession()`/`VideoPlaybackService.endSession()` (020) route their off-path stopped report through the same serialised `reportTask` chain this slice introduces, by calling the same private teardown helper `stop()` uses (mint fresh generation, tear down controller, `.idle`, enqueue the stopped report on `reportTask`) rather than staying a separate plain `Task` outside the chain. | Leaving `endSession()`'s report as a second, independent plain `Task`, unordered against `reportTask`. | 020's justification for a plain `Task` there — "safe because nothing follows it in the same session" — stops holding the moment this slice adds a chain that *can* follow it: a rapid `next()` mid-flight when a sign-out fires could let 021's chained "track 2 started" report land at the server after 020's session-ending "stopped" report was already in flight but unlanded, reordering server state exactly the way AC21g exists to prevent. Routing both through one chained helper also answers "how do the two teardown paths (`stop()`, `endSession()`) interact if both fire close together" — they are the same path, so there is nothing to interact; whichever runs first tears down and enqueues, the second finds the controller already `nil` and the chain already carrying its report. |
| 2026-09-07 | Triage 25's flaky test stops polling with `eventually` and instead awaits a `Recorder`/`ReportLog`-style continuation that the stub repository's report method resumes once its call actually lands — the test drives the `ManualClock` forward with `clock.tick()` and then `await` on that continuation rather than yielding up to 2000 times hoping the report arrived. | Reducing `eventually`'s yield budget, or adding a fixed `Task.sleep` before asserting. | `eventually` is a poll against scheduler timing, which is precisely the class of race codex named for the service itself (§ "Testing assessment"); a poll can still lose under load, which is what the one observed failure was. A continuation that the production code itself resumes has no timing window to lose — the test cannot proceed until the call it is asserting on has actually happened. A longer sleep only makes the flake rarer, not impossible, and CLAUDE.md's testing rules already forbid sleeping instead of using the injected clock. |

## 7. Sub-Slices

Not split — delivered as a single slice. The video half and the music half share one new type and one new report-serialisation shape; splitting them would mean writing that shape's decision row twice.

## 8. Testing Strategy

- **Unit:** `MixtapeServicesTests` (`.service`) — AC21a–AC21f and AC21h, using `ManualClock`, `Gate`, `ReportLog`, `StubAudioPlayerController`, `StubVideoPlayerController`, all of which already exist in this target; no new test double is required beyond whatever `Recorder`/`ReportLog` addition Triage 25's rewrite needs for the awaited continuation (a small addition to `ReportLog`, not a new file, if the existing shape does not already support it).
- **Demonstration:** AC21g, iOS simulator against `localhost:8096`, read through `scripts/jf-probe.swift`.
- **Test targets required:** `MixtapeServicesTests` (exists). `docs/slices/test-count.txt` changes in the same commit as the new tests.

## 9. Keeping this document true

| Before you… | Write this first |
|---|---|
| implement a decision | the Section 6 row, including what you rejected |
| start work | flip status in the master checklist |
| stop on a blocker | the Active Blockers row |
| widen scope | Section 3, and `depends_on` on any slice that's now affected |

Commit this file alongside the code, with the slice id in the subject (`021: …`).

## 10. Definition of Done

- [ ] Acceptance criteria met
- [ ] Tests passing, in a target that exists
- [ ] Triage 25 closed in the master checklist
- [ ] Decision log written as you went, not reconstructed
- [ ] Pre-flight completed and drift resolved
- [ ] Master checklist row current
- [ ] `next_slice`'s `depends_on` reflects what actually shipped, not what was planned
- [ ] Both link directions checked: this page's `next_slice` and that page's `previous_slice`

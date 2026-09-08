---
slice_id: "014"
title: Video playback reporting completeness
priority: P0
complexity: M
ladder: none
depends_on:
  - { id: "013", type: hard, note: "the pause/resume reporting this slice fixes lives in VideoPlaybackService and is driven from MixtapePresentation. 013 creates the only target a regression test for it can run in" }
  - { id: "006", type: hard, note: "AVPlayerController and the AVKit VideoPlayer presentation this slice reroutes; ReportPlaybackStartUseCase (decision 37)" }
  - { id: "007", type: hard, note: "VLCPlayerController and its overlay, which calls controller.toggle() and controller.scrub(to:) directly — the VLC half of the same defect (Triage 11)" }
  - { id: "008", type: hard, note: "ReportPlaybackProgressUseCase and ReportPlaybackStoppedUseCase, and the 10 s heartbeat this slice makes pause-aware" }
  - { id: "009", type: soft, note: "MusicPlayerService's MPNowPlayingInfoCenter refresh cadence is the same §6 clause and is fixed here, but the video half does not depend on it" }
previous_slice: "013"
next_slice: "015"
parent_slice: none
covers: ["§1.13"]
created: 2026-09-04
---

# 014 — Video playback reporting completeness

← [previous](013-presentation-tests-and-gate.md) · [Master Checklist](MASTER-CHECKLIST.md) · [next](015-wallet-finish-ownership.md) →

> **Status, owner and blockers live in the master checklist, not here.** Dependencies live in this page's front matter and nowhere else. Each fact has one home; if you find yourself writing it twice, one of the two copies is going to be wrong in a fortnight.

## 1. Objective

Pausing or seeking a video reaches the server. Observable on its own: pause any movie on
either player and `GET /Sessions` shows `IsPaused: true` at the position you paused at;
resume and it goes back.

## 2. Business Value & Priority

§6 requires `VideoPlaybackService` to report "on pause, on seek completion". The methods
exist and are correct — `VideoPlaybackService.swift:120-122` pauses, sets `.paused`, and
calls `reportOnce(isPaused: true)`. **Nothing calls them.** A grep of all of
`MixtapePresentation` for `videoPlaybackService.` returns only `.playerView`, `.status`,
`.isActive`, `.item`, `.play(...)` and `.stop()`.

Both players route around the service:

- The AVPlayer path presents AVKit's `VideoPlayer` (`AVPlayerController.swift:82`), whose
  transport controls drive the underlying `AVPlayer` directly.
- The VLC overlay calls `controller.toggle()` and `controller.scrub(to:)` directly
  (`VLCPlayerView+iOS.swift:27,36`), because the overlay lives in `MixtapeInfrastructure`
  and cannot see the service.

The consequence is worse than a missing report. While the user is paused, the 10 s
heartbeat's `guard status == .playing` still passes, because `status` never left
`.playing` — so the server is actively told `IsPaused: false` with a frozen position for
the entire pause. Jellyfin's session list is wrong for as long as the user is stopped.

This is P0 and the highest-severity finding in the reconciliation. Triage 11 records only
the VLC half and defers it to "a 007 follow-up"; the AVKit half — the primary path for
AC6 and AC8 on **both** platforms — was recorded nowhere until the audit. This slice
closes both halves together, because they are one defect with two symptoms and fixing one
leaves the heartbeat bug live on the other.

Not a ladder. There is no crude version worth shipping: a fix that covers one player still
reports `IsPaused: false` through every pause on the other.

## 3. Scope

**In scope:**

- Add a status callback to `VideoPlayerControlling` beside the existing `onPositionChange`,
  so a controller can tell the service it changed state. This is the seam Triage 11 named;
  it is what lets the Infrastructure-resident VLC overlay reach `VideoPlaybackService`
  without importing it, and it keeps the §3 dependency edges intact.
- `VLCPlayerController` fires that callback from `toggle()` and from `scrub(to:)`.
- `AVPlayerController` fires it too. AVKit's `VideoPlayer` drives the `AVPlayer` directly,
  so observe `AVPlayer.timeControlStatus` (and the seek completion) and translate to the
  callback rather than trying to intercept the system transport UI.
- `VideoPlaybackService` observes the callback, moves `status` to `.paused` / `.playing`,
  and sends the pause and resume reports it already knows how to send.
- The 10 s heartbeat stops reporting `IsPaused: false` while paused. Either it pauses with
  the player or it reports the true `isPaused`; the first is simpler and matches §6's
  "progress" semantics.
- `MPNowPlayingInfoCenter` refreshed every 5 s during music playback, per §6. It is
  currently refreshed on track change, pause, resume and seek only
  (`MusicPlayerService.swift:165`); the periodic task at `:211-226` is the 10 s **report**
  loop and never touches now-playing. AC12 passes today because the lock screen extrapolates
  from `MPNowPlayingInfoPropertyPlaybackRate`, so this is spec compliance rather than a
  visible defect — it is here because it is the same §6 clause and the same loop.

**Out of scope** (name the slice it's deferred to):

- Any change to what a report *contains*. `PlayMethod` sourcing (decisions 11 and 40),
  `ApiKey` on stream URLs (decision 42) and the dropped `maxStreamingBitrate` (decision 43)
  are all settled and stay untouched.
- Scrubber UI on either player. This slice changes what reaches the server when the user
  scrubs, not how they scrub.
- The music player's exact-end seek stall (Triage 7) — that is slice 015, where the finish
  event is already being reworked.
- Reporting on track change within an album. `MusicPlayerService` already does this
  correctly (decision 34, all three use cases called).

**Plan requirements covered:**

- **§1.13** "Report playback start / progress / stop to the server" — currently claimed by
  slices 006, 008 and 009 and satisfied for start, periodic progress and stop. This slice
  completes the pause and seek half of "progress" that §6 spells out and the coverage table
  never separated. The §1.13 coverage row gains 014.

Nothing here is a fork: §6 already describes the behaviour being built, and no decision
authorised its absence.

## 4. Pre-Flight Validation

- [x] **013** — opened. `MixtapePresentationTests` exists and is in both schemes; the gate
      derives its own count, so adding this slice's tests does not need a command-line change.
- [x] **006** — opened. Decision 18 (`VideoPlayer`, not `AVPlayerLayer`) and decision 37
      (start report lands in 006) still hold. Confirm `AVPlayerController` still presents
      AVKit's `VideoPlayer` — if slice 011's tvOS work changed the presentation, the
      `timeControlStatus` approach changes with it.
- [x] **007** — opened. Confirm the VLC overlay still calls `controller.toggle()` directly
      and that Triage 11 is still open and unclaimed by any other slice.
- [x] **008** — opened. Confirm the heartbeat is still 10 s and still guards on
      `status == .playing`, and that the `MinResumeDurationSeconds = 300` finding in the drift
      log has not been changed on the dev server — this slice's AC needs a pause observable in
      `/Sessions`, which is unaffected by the resume floor, but the same probe is used.
- [x] **009** (soft) — opened, for the `MPNowPlayingInfoCenter` clause only.
- [x] Architecture standards doc re-read. Confirm §3's edges: `MixtapeInfrastructure` still
      may not import `MixtapeServices`, so the callback must stay a closure or protocol
      declared on the Infrastructure side.

**Drift found:** `none`. `AVPlayerController` still presents AVKit's `VideoPlayer`; the VLC overlay still calls `controller.toggle()` and `controller.scrub(to:)` directly; the heartbeat is still 10 s guarded on `status == .playing`; `MinResumeDurationSeconds` on the dev server is not read by this slice's checks. `MixtapePresentationTests` exists from 013 and the gate reads its counts from `docs/slices/test-count.txt`.

## 5. Acceptance Criteria

- [x] **AC14a** — Play a movie on the AVPlayer path, pause with the system transport, wait
      15 s. `GET /Sessions` shows `IsPaused: true` and a position that does not advance.
      Resume: `IsPaused: false` and the position advances again.
- [x] **AC14b** — The same on the VLC path, paused from the overlay's play/pause button.
      This is the case Triage 11 recorded as broken: `/Sessions` currently keeps
      `IsPaused: false` while VLC is paused.
- [x] **AC14c** — Seek on either player; a progress report carrying the post-seek position
      is sent at seek completion, not only at the next 10 s tick.
- [x] **AC14d** — During a pause, no progress report claims `IsPaused: false`. Verify from the
      report stream, not from the final `/Sessions` state — the defect is what is sent during
      the pause, and a correct end state can hide it.
- [x] **AC14e** — Play an album; `MPNowPlayingInfoCenter`'s elapsed time is refreshed at
      5 s intervals, not extrapolated from the playback rate alone.
- [x] Unit tests in `MixtapeServicesTests`: the service moves to `.paused` on the callback and
      sends exactly one pause report; the heartbeat sends nothing while paused; resume sends
      exactly one resume report. Inject a clock — never sleep.
- [x] `xcodebuild build` and `test` pass for both schemes, layer, glass and swiftformat clean,
      per `CLAUDE.md` gate criteria.

**Evidence, 2026-09-04, iPhone 17 Pro simulator (iOS 26.5) against `localhost:8096`, read through `scripts/jf-probe.swift /Sessions`.** *AC14a* — Avatar (mp4, AVPlayer path, 20.8 s): after the AVKit pause, `IsPaused: true` with `PositionTicks` frozen at 2 s across four samples over 16 s and `LastPlaybackCheckIn` unchanged at 07:34:43.8 (the pause report) throughout — no heartbeat claimed `IsPaused: false` during the pause, which is *AC14d* read from the check-in stream rather than the end state. Resume: `IsPaused: false`, position 3 → 8 → 12 s, check-in at 07:35:15.8 (resume report) then 07:35:23.2 (heartbeat back). *AC14b* — F1 (mkv, VLC path): pause from the overlay button, `IsPaused: true`, position frozen at 4 s across four samples over 18 s, check-in constant at 07:36:08.7; resume `IsPaused: false`, position advancing. *AC14c* — VLC: dragging the overlay scrubber from 50 % to 75 % produced a check-in at 07:37:06.55, within two seconds of the drag and off the 10 s heartbeat grid, with the reported position jumping from 24 s to 38 s; AVKit: dragging the system "Current position" slider to 70 % produced a check-in at 07:38:00.2 (start was 07:37:55.2, so not a heartbeat) with the position jumping from 3 s to 16 s. *AC14e* — verified by the `ManualClock` test (`now playing refreshes every five seconds and progress reports every ten`), not observed on a lock screen: the simulator offers no way to read `MPNowPlayingInfoCenter`'s elapsed time from outside the process. Unit tests: five new cases in `MixtapeServicesTests` (58 in the suite), including the heartbeat sending nothing across two 10 s ticks while paused. `PlayMethod` was not used as a gate anywhere, per the drift-log note.

## 6. Decision Log

**Write the row before you implement the decision, not after.**

| Date | Decision | Alternatives rejected | Why |
|---|---|---|---|
| 2026-09-04 | Both halves of the defect are fixed in one slice rather than splitting the AVKit half from Triage 11's VLC half | A 007 follow-up for VLC only, as Triage 11 proposed, with AVKit deferred | They are one defect: the heartbeat reports `IsPaused: false` through any pause on either player. Fixing one player leaves the same wrong data flowing from the other, and the seam — a status callback on `VideoPlayerControlling` — is shared. Two slices would build it twice or leave the second half depending on the first's shape anyway. |
| 2026-09-04 | The controller is the single source of transport events. `VideoPlayerControlling` gains `onTransportEvent: ((VideoTransportEvent) -> Void)?` with `.paused`, `.resumed` and `.seeked(Duration)`; `VideoPlaybackService` moves `status` and sends its one report only from that callback, and its own `togglePlayPause()` / `seek(to:)` merely forward to the controller. The service's handler is idempotent (`.paused` while already paused is ignored), so a controller may report the same transition twice without a second report going out. | (a) Keeping the service's methods as the reporting path and having the controllers suppress the echo of their own calls; (b) two callbacks, one for state and one for seeks | (a) needs every controller to tell its own seek apart from AVKit's or the overlay's — a flag per call path — and gets the two players out of step the first time one forgets. One path means one place to test: the `Stub*` controller emits the event a real player would, and the existing "each discrete event reports exactly once" test keeps its meaning. (b) is the same seam split in two for no caller that wants only half of it. |
| 2026-09-04 | `AVPlayerController` observes `AVPlayer.timeControlStatus` for pause and resume and `AVPlayerItem.timeJumpedNotification` for seek completion, ignoring the jump its own `startAt` seek causes and the `.paused` the player reports when the item plays to its end. | Intercepting AVKit's transport UI; polling the rate from the one-second time observer | AVKit's `VideoPlayer` offers no transport hooks (decision 18 chose it for exactly the system controls that make the hooks unreachable). `timeControlStatus` is the player's own account of playing versus paused and `timeJumped` is its only seek signal; both cover a scrub in the system UI as well as a call from the service. The end-of-item `.paused` is skipped because `onEnded` follows it and a pause report at the final frame would be a fourth report for a stop. |
| 2026-09-04 | `MusicPlayerService`'s periodic task ticks every 5 s: every tick refreshes `MPNowPlayingInfoCenter`, every second tick sends the 10 s progress report. `progressInterval` stays 10 s and gains a `nowPlayingInterval` of 5 s beside it. | A second task for now-playing; a `Timer` | One loop, one clock, one cancellation — and the injected `ManualClock` drives both cadences in the same test. A second task is a second thing to cancel in `finish()`, `stop()` and `deinit`. |
| 2026-09-04 | The `ManualClock` tests wait on the observable condition (`eventually { … }`, yields only, never a sleep) after each tick instead of asserting straight after `tick()` returns. Applied to the new cadence tests and to 008's `progress fires once per interval while playing`, whose assertions are unchanged. | Leaving the fixed-yield `settle()` pattern | The first full gate run failed both tests while the same suite passed three times alone: `tick()` resumes the sleeper and yields once, but the loop body runs on its own task, and under the load of a full run (and a second `xcodebuild` on the machine) one yield was not enough. A fixed yield count is a sleep in disguise; waiting for the state the assertion needs is what "inject a clock, never sleep" means in practice. |

## 7. Sub-Slices

Not split — delivered as a single slice.

## 8. Testing Strategy

- **Unit:** `MixtapeServicesTests`, tagged `.service`. The callback→status→report chain with
  a `MockVideoPlayerController` and an injected clock. Test behaviour — that a pause produces
  one report with `isPaused: true` — not that the mock recorded a call.
- **Integration:** none against the live server in an automated test. `CLAUDE.md` is explicit:
  a test that needs the dev server running is a broken test.
- **UI:** none — decision 4.
- **Acceptance:** AC14a–AC14e are manual runs against `localhost:8096`, read through
  `scripts/jf-probe.swift` (decision 47; `curl` is denied on this machine). Note the drift-log
  finding that `/Sessions` `PlayState.PlayMethod` is unreliable on 10.11.11 — gate on
  `IsPaused` and `PositionTicks`, not on `PlayMethod`.
- **Test targets required:** `MixtapeServicesTests` (exists). `MixtapePresentationTests` from
  013 if the AVKit rerouting puts any logic in the player screen.

## 9. Keeping this document true

| Before you… | Write this first |
|---|---|
| implement a decision | the Section 6 row, including what you rejected |
| start work | flip status in the master checklist |
| stop on a blocker | the Active Blockers row |
| widen scope | Section 3, and `depends_on` on any slice that's now affected |

Commit this file alongside the code, with the slice id in the subject (`014: …`).

## 10. Definition of Done

- [x] Acceptance criteria met
- [x] Tests passing, in a target that exists
- [x] §1.13 satisfied for pause and seek, and the coverage table row updated to name 014
- [x] Triage 11 closed in the master checklist, with the fix named
- [x] Decision log written as you went, not reconstructed
- [x] Pre-flight completed and drift resolved
- [x] Master checklist row current
- [x] `015`'s `depends_on` reflects what actually shipped
- [x] Both link directions checked: this page's `next_slice` and `015`'s `previous_slice`

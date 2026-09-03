---
slice_id: "008"
title: Playback Reporting and Resume
priority: P0
complexity: M
ladder: none
depends_on:
  - { id: "006", type: hard, note: "needs PlaybackPlan.playMethod, ResolveVideoPlaybackUseCase and VideoPlaybackService's play/stop lifecycle to hang reporting off" }
  - { id: "007", type: hard, note: "AC9 is demonstrated on the F1 mkv, which only plays via the .directVLC branch 007 wires in" }
previous_slice: "007"
next_slice: "009"
parent_slice: none
covers: ["§1.11", "§1.13", "§12.9", "§12.10"]
created: 2026-09-03
---

# 008 — Playback Reporting and Resume

← [previous](007-video-vlc.md) · [Master Checklist](MASTER-CHECKLIST.md) · [next](009-music-playback.md) →

> **Status, owner and blockers live in the master checklist, not here.** Dependencies live in this page's front matter and nowhere else. Each fact has one home; if you find yourself writing it twice, one of the two copies is going to be wrong in a fortnight.

## 1. Objective

Every video session the app plays shows up correctly in Jellyfin's own session list while it plays, resume points round-trip through the server, and finishing a movie marks it watched — observable without any later slice, on the two video items the library already has.

## 2. Business Value & Priority

Capability 11 (resume, watched-at-90%) and the video half of capability 13 (report start/progress/stop) are both P0: acceptance criteria 5, 9 and 10 depend on them, and criterion 5 was only partly demonstrable in 005 because nothing in the app had reported a position yet. This is not a rung on a version ladder — the music half of capability 13 is a separate, later wiring (decision 34, slice 009) against the same three use cases this slice builds, not a v2 of this slice's own scope.

## 3. Scope

**In scope:**
- `ReportPlaybackStartUseCase`, `ReportPlaybackProgressUseCase`, `ReportPlaybackStoppedUseCase` (decision 19) — three thin types, one `MixtapeUseCase` file each, each posting the shared §8 body (`ItemId`, `MediaSourceId`, `PlaySessionId`, `PositionTicks`, `IsPaused`, `CanSeek: true`, `PlayMethod`) through `PlaybackRepositoryProtocol`'s `reportStart`/`reportProgress`/`reportStopped`.
- `PlayMethod` on every report comes from `PlaybackPlan.playMethod` (decision 11), never derived again from `PlaybackMethod` — the plan already carries the wire value from whichever of `supportsDirectPlay`/`supportsDirectStream` was true at resolve time.
- Report failures are logged on the `network` category (003) and swallowed at the use-case boundary — a dropped heartbeat never becomes a `MixtapeError` the player surfaces.
- `VideoPlaybackService` (006/007) gains the reporting cadence: on `play` start, every 10 s while playing, on pause, on seek completion, and on `stop` — never more often, regardless of how many of those events land close together.
- Local `isWatched` is computed once, on `stop()`, from `position / duration >= 0.9` (decision 8) and folded into the stopped report's implied state; this is the only place in the app that rule runs. List and detail mapping (005) already sets `PlaybackState.isWatched` from `UserData.Played` verbatim and is untouched here — decision 8 is explicit that these are two different moments, not two sources for one field.
- `play(item:)`'s `startAt` comes from the item's mapped `PlaybackState.position` — the same resume point 005 already surfaces via `hasResumePoint` — so Play and Resume are one entry point with no separate "resume" code path to drift from it.
- `MovieDetailScreen` (005) shows a Resume affordance in place of Play when `hasResumePoint` is true; wiring only, no new screen.
- `LibraryService.refresh()` (005) is called after `stop()` completes so Home's Continue Watching row reflects the just-finished session on return, without a manual pull-to-refresh.

**Out of scope** (name the slice it's deferred to):
- Music playback reporting — decision 34 assigns this to 009, once `MusicPlayerService` exists to call the same three use cases.
- Series/season/episode resume — the library has 0 episodes; nothing exists to report against, and nothing here changes that gap (the same data gap decision 14 records against criterion 11).
- Any change to how `.directAVPlayer`/`.directVLC`/`.transcodeHLS` is chosen — that logic belongs to 006 and 007; this slice only reports on whichever `PlaybackPlan` they already produced.
- The wallet's return-to-sleeve sequence on `finishedAlbumID` — that trigger is music-only and lands in 010.

**Plan requirements covered:**
- `§1.11` — resume from last position and mark-watched-at-≥90% are both delivered: resume via `startAt`/`hasResumePoint`, watched via the stop-time threshold rule.
- `§1.13` — delivered for its video half only. The music half is decision 34's territory and is claimed by 009, not here.
- `§12.9` — AC9 (watch ~30 s, exit, Resume offered, `GET /UserItems/Resume` agrees) is demonstrated on the F1 mkv, the only item long enough at 48.4 s.
- `§12.10` — AC10 (finish a movie, `UserData.Played` true) is demonstrated on Avatar, the only item short enough at 20.8 s to finish inside a manual check.

No fork: every departure from the engineering doc's plain reading here (three use-case types, the `isWatched` split, `PlayMethod` sourcing) is already resolved in `SPEC-DECISIONS.md` and cited in Section 6, not re-argued or reinvented.

## 4. Pre-Flight Validation

Complete **before the first line of code**, not at close.

**006** — Video: AVPlayer direct and HLS
- [ ] Opened it. Its decision log still says what this slice assumed: `PlaybackPlan` carries a `playMethod: PlayMethod` field set at resolve time (decision 11), and `VideoPlaybackService` exposes `play(item:)`, `togglePlayPause()`, `seek(to:)` and `stop()` with no reporting wired in yet.
- [ ] N/A — 006 is a slice, not a spike.
- [ ] Its state matches what this slice assumed when drafted: no report call fires anywhere in `VideoPlaybackService` before this slice adds one.
- [ ] Architecture standards doc re-read; nothing changed underneath this slice.

**007** — Video: VLC direct
- [ ] Opened it. Its decision log still says what this slice assumed: the `.directVLC` branch is wired into the same `VideoPlaybackService.play`/`stop` lifecycle 006 built, so this slice's cadence hooks fire identically regardless of which `VideoPlayerControlling` is active underneath.
- [ ] N/A — 007 is a slice, not a spike.
- [ ] Its state matches what this slice assumed when drafted: `stop()` on a VLC-backed session raises the same completion point 006's AVPlayer path does.
- [ ] Architecture standards doc re-read; nothing changed underneath this slice.

**Drift found:** none.

## 5. Acceptance Criteria

Mechanical:
- [ ] `xcodebuild build` passes for the `iOS` and `tvOS` schemes.
- [ ] `xcodebuild test` passes for both schemes with `-skip-testing:iOSUITests` (iOS) / `-skip-testing:tvOSUITests` (tvOS); no unit test skipped or commented out.
- [ ] `./scripts/check-layer-imports.sh` exits 0.
- [ ] `swiftformat --lint .` is clean.

Behavioural:
- [ ] `MixtapeUseCaseTests`, tagged `.useCase`: one suite per report use case, each covering a successful call and a swallowed failure that never reaches the caller as a thrown error.
- [ ] `MixtapeServicesTests`, tagged `.service`: a `VideoPlaybackService` reporting suite, driven by an injected clock (never a real sleep), proving the cadence is exactly start / every 10 s while playing / on pause / on seek completion / on stop, across a run that includes a pause-then-resume and a mid-track seek, with no extra report anywhere in that sequence.
- [ ] `MixtapeServicesTests`: a case proving `isWatched` is `true` on stop when position is ≥ 90% of the F1 mkv's 48.4 s runtime, and `false` below that threshold, at 89.9 %/90.0 %/90.1 % boundaries.

Acceptance (server-observable against `http://localhost:8096`):
- [ ] AC9 — play F1 (mkv, 48.4 s) to roughly 30 s, exit the player. `MovieDetailScreen` offers Resume at ≈30 s. `GET /UserItems/Resume?userId={uid}` lists the item with `PlaybackPositionTicks` matching the app's last progress report.
- [ ] AC10 — play Avatar (mp4, 20.8 s) to completion. `GET /Items/{itemId}?userId={uid}` (or Jellyfin Web) shows `UserData.Played: true`.
- [ ] AC6 and AC7 completed — while Avatar plays and while F1 plays, `GET /Sessions` shows this device's session with `NowPlayingItem` set and `PlayMethod: DirectPlay`; slices 006 and 007 could only check for the absence of `TranscodingInfo`, because `PlayMethod` reaches the session through the start report this slice wires.
- [ ] AC5 re-verified — using the resume point this slice's own reporting created (not the one seeded via Jellyfin Web in 005), Home's Continue Watching row shows a progress bar matching that position after `LibraryService.refresh()` runs.

## 6. Decision Log

**Write the row before you implement the decision, not after.** This is the whole mechanism. A decision log filled in at close is reconstructed from memory, and the rejected alternatives — the part the next slice's pre-flight actually needs — are exactly what memory loses first.

| Date | Decision | Alternatives rejected | Why |
|---|---|---|---|
| 2026-09-03 | Reporting is three use case types — `ReportPlaybackStartUseCase`, `ReportPlaybackProgressUseCase`, `ReportPlaybackStoppedUseCase` (SPEC-DECISIONS #19) | A single `ReportPlaybackUseCase` with an `action:` parameter | Three thin structs sharing one repository cost almost nothing and each gets its own test; one type with a switch collapses three different payload shapes into one signature and satisfies the one-type-per-use-case rule only on paper |
| 2026-09-03 | `isWatched` runs the `>= 0.9` rule only at stop time, during active local playback (SPEC-DECISIONS #8) | Computing `isWatched` from position/duration on every mapped list and detail response too | `PlayedPercentage` never arrives from this server, so a mapper doing that would compute from `nil`; the two rules apply at different moments and 005 already handles the at-rest case from `UserData.Played` |
| 2026-09-03 | Every report's `PlayMethod` is read from `PlaybackPlan.playMethod`, set at resolve time (SPEC-DECISIONS #11) | Reporting `DirectPlay` unconditionally for any non-transcode path | AC6/AC7/AC8 are verified by reading the Jellyfin session dashboard; reporting an untrue `PlayMethod` degrades the very check those criteria depend on |
| 2026-09-03 | Progress and stopped report failures — including a 503 with `Retry-After` — are logged and swallowed, never surfaced as a playback error (SPEC-DECISIONS #9, #26) | Retrying on 503, or raising the failure into `VideoPlaybackService.status` | `Retry-After` is not honoured in V1; a dropped heartbeat must never interrupt playback, per §8 of the engineering doc |

## 7. Sub-Slices

Not split — delivered as a single slice.

## 8. Testing Strategy
- **Unit / Integration / UI:** unit only. `.useCase`-tagged tests for the three report use cases against a `Stub` `PlaybackRepositoryProtocol` (success and swallowed-failure cases). `.service`-tagged tests for `VideoPlaybackService`'s reporting cadence and the stop-time `isWatched` rule, against a stub `VideoPlayerControlling` and an injected clock. No XCUITest — deferred per decision 4. No CI gate is added or restored.
- **Test targets required:** `MixtapeUseCaseTests` and `MixtapeServicesTests`, both already created in 001; no new target needed.

## 9. Keeping this document true

This slice is done when the page describes what was actually built — not when the code works. The discipline is **ordering**: the write happens *before* the thing it describes, so it sits on the critical path instead of after it, where it gets skipped.

| Before you… | Write this first |
|---|---|
| implement a decision | the Section 6 row, including what you rejected |
| start work | flip status in the master checklist |
| stop on a blocker | the Active Blockers row |
| build on a spike | that spike's Result section |
| widen scope | Section 3, and `depends_on` on any slice that's now affected |

And in the same commit as the code, not a follow-up: **commit this file alongside it**, with the slice id in the commit subject (`008: add playback reporting and resume`).

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

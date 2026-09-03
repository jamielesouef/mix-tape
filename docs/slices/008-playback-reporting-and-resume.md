---
slice_id: "008"
title: Playback Reporting and Resume
priority: P0
complexity: M
ladder: none
depends_on:
  - { id: "006", type: hard, note: "needs PlaybackPlan.playMethod, ResolveVideoPlaybackUseCase and VideoPlaybackService's play/stop lifecycle to hang reporting off" }
  - { id: "007", type: hard, note: "as shipped: VLCPlayerController conforms to VideoPlayerControlling and is selected by AppContainer for .directVLC; VideoPlaybackService drives both players through the same interface and already sends the start report on play (decision 37). 008 adds progress/stopped reports and resume; note the 006 Drift Log finding that /Sessions PlayState.PlayMethod reads DirectPlay even during transcode on 10.11.11, so gate on TranscodingInfo, not PlayMethod" }
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

Every video session the app plays keeps Jellyfin's session list current while it plays and closes it cleanly on stop, resume points round-trip through the server, and finishing a movie marks it watched — observable without any later slice, on the two video items the library already has. The start report already exists from 006 (decision 37); this slice adds progress and stopped.

## 2. Business Value & Priority

Capability 11 (resume, watched-at-90%) and the video half of capability 13 (report start/progress/stop) are both P0: acceptance criteria 5, 9 and 10 depend on them, and criterion 5 was only partly demonstrable in 005 because nothing in the app had reported a position yet. This is not a rung on a version ladder — the music half of capability 13 is a separate, later wiring (decision 34, slice 009) against the same three use cases this slice builds, not a v2 of this slice's own scope.

## 3. Scope

**In scope:**
- `ReportPlaybackProgressUseCase` and `ReportPlaybackStoppedUseCase` (decision 19) — two thin types, one `MixtapeUseCase` file each, each posting the shared §8 body (`ItemId`, `MediaSourceId`, `PlaySessionId`, `PositionTicks`, `IsPaused`, `CanSeek: true`, `PlayMethod`) through `PlaybackRepositoryProtocol`'s `reportProgress`/`reportStopped`. `ReportPlaybackStartUseCase` and `reportStart` already exist from 006 (decision 37) and are reused unchanged.
- `PlayMethod` on every report comes from `PlaybackPlan.playMethod` (decision 11), never derived again from `PlaybackMethod` — the plan already carries the wire value from whichever of `supportsDirectPlay`/`supportsDirectStream` was true at resolve time.
- Report failures are logged on the `network` category (003) and swallowed at the use-case boundary — a dropped heartbeat never becomes a `MixtapeError` the player surfaces.
- `VideoPlaybackService` (006/007) gains the rest of the reporting cadence: it already reports on `play` start (006); this slice adds every 10 s while playing, on pause, on seek completion, and on `stop` — never more often, regardless of how many of those events land close together.
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
- [x] Opened it. Its decision log still says what this slice assumed: `PlaybackPlan` carries a `playMethod: PlayMethod` field set at resolve time (decision 11), and `VideoPlaybackService` exposes `play(item:)`, `togglePlayPause()`, `seek(to:)` and `stop()` with no reporting wired in yet.
- [x] N/A — 006 is a slice, not a spike.
- [x] Its state matches what this slice assumed when drafted: no report call fires anywhere in `VideoPlaybackService` before this slice adds one.
- [x] Architecture standards doc re-read; nothing changed underneath this slice.

**007** — Video: VLC direct
- [x] Opened it. Its decision log still says what this slice assumed: the `.directVLC` branch is wired into the same `VideoPlaybackService.play`/`stop` lifecycle 006 built, so this slice's cadence hooks fire identically regardless of which `VideoPlayerControlling` is active underneath.
- [x] N/A — 007 is a slice, not a spike.
- [x] Its state matches what this slice assumed when drafted: `stop()` on a VLC-backed session raises the same completion point 006's AVPlayer path does.
- [x] Architecture standards doc re-read; nothing changed underneath this slice.

**Drift found:** none blocking. The 006 Drift Log finding carries here: on 10.11.11 `/Sessions` `PlayState.PlayMethod` reads `DirectPlay` even during a transcode, so this slice never gates on `PlayMethod`. The 005 env-file drift also carries: AC9/AC10 read `/UserItems/Resume` and `/Items/{id}` for the user the app signs in as, whose id is read from `/Sessions`, not from `JELLYFIN_USER_ID`.

## 5. Acceptance Criteria

Mechanical:
- [x] `xcodebuild build` passes for the `iOS` and `tvOS` schemes.
- [x] `xcodebuild test` passes for both schemes with the UI bundles skipped; no unit test skipped or commented out. Gate expected executed-test count per scheme: **138** (131 from slice 007 plus 7: 4 progress/stopped use-case cases and 3 `VideoPlaybackService` reporting cases — discrete-event cadence, per-interval progress, and the parameterised watched-at-stop). Verified 2026-09-03 via `./scripts/gate.sh 138`.
- [x] `./scripts/check-layer-imports.sh` exits 0.
- [x] `swiftformat --lint .` is clean.

Behavioural:
- [x] `MixtapeUseCaseTests` (`.useCase`): `ReportPlaybackProgressUseCase` and `ReportPlaybackStoppedUseCase` each covering a successful call and a swallowed failure. The start use case's suite is from 006.
- [x] `MixtapeServicesTests` (`.service`): a reporting-cadence suite on an injected `ManualClock` (never a real sleep) proving the sequence is exactly start / every 10 s while playing / on pause / on seek / on stop, across a pause-then-resume and a mid-track seek, with no extra report — and a per-interval progress test driving the clock two ticks.
- [x] `MixtapeServicesTests`: a parameterised case proving the stop-time watched rule at 89.9% / 90.0% / 90.1% of F1's 48.4 s runtime — at or past 90% the stopped report carries the full duration (Jellyfin marks it played), below it the actual resume point.

Acceptance (server-observable against `http://localhost:8096`, via `./scripts/jf-probe.swift`; the session and user are matched via `/Sessions`, not the env file's user id — 005 Drift Log; `PlayMethod` is never gated on — 006 Drift Log):
- [x] AC9 — played F1 (mkv, 48.4 s) to ~22 s and closed. `/UserItems/Resume` listed F1 with `PlaybackPositionTicks` at 21.6 s, and `MovieDetailScreen` then showed the Resume affordance (both Play and Resume). Requires the server's `MinResumeDurationSeconds` lowered to admit the short clip — see the Section 6 row. **Manual, 2026-09-03.**
- [x] AC10 — played Avatar (mp4, 20.8 s) to completion; the player auto-dismissed on end and `/Items/{itemId}` showed `UserData.Played: true`. **Manual, 2026-09-03.**
- [x] After `stop()`, `/Sessions` showed this device's `NowPlayingItem` cleared — the stopped report closed what 006's start report opened. Observed repeatedly across the AC9/AC10 runs. **Manual, 2026-09-03.**
- [x] AC5 re-verified — using the resume point this slice's own reporting created (not the 005 Jellyfin-Web seed), Home's Continue Watching row showed F1 with a progress bar reading 73%, matching the server's 35.5 s of 48.4 s exactly, after `LibraryService.refresh()` ran on stop. **Manual, 2026-09-03.**

## 6. Decision Log

**Write the row before you implement the decision, not after.** This is the whole mechanism. A decision log filled in at close is reconstructed from memory, and the rejected alternatives — the part the next slice's pre-flight actually needs — are exactly what memory loses first.

| Date | Decision | Alternatives rejected | Why |
|---|---|---|---|
| 2026-09-03 | Reporting is three use case types — `ReportPlaybackStartUseCase` (006, decision 37), `ReportPlaybackProgressUseCase` and `ReportPlaybackStoppedUseCase` (here) (SPEC-DECISIONS #19) | A single `ReportPlaybackUseCase` with an `action:` parameter | Three thin structs sharing one repository cost almost nothing and each gets its own test; one type with a switch collapses three different payload shapes into one signature and satisfies the one-type-per-use-case rule only on paper |
| 2026-09-03 | `isWatched` runs the `>= 0.9` rule only at stop time, during active local playback (SPEC-DECISIONS #8) | Computing `isWatched` from position/duration on every mapped list and detail response too | `PlayedPercentage` never arrives from this server, so a mapper doing that would compute from `nil`; the two rules apply at different moments and 005 already handles the at-rest case from `UserData.Played` |
| 2026-09-03 | Every report's `PlayMethod` is read from `PlaybackPlan.playMethod`, set at resolve time (SPEC-DECISIONS #11) | Reporting `DirectPlay` unconditionally for any non-transcode path | AC6/AC7/AC8 are verified by reading the Jellyfin session dashboard; reporting an untrue `PlayMethod` degrades the very check those criteria depend on |
| 2026-09-03 | Progress and stopped report failures — including a 503 with `Retry-After` — are logged and swallowed, never surfaced as a playback error (SPEC-DECISIONS #9, #26) | Retrying on 503, or raising the failure into `VideoPlaybackService.status` | `Retry-After` is not honoured in V1; a dropped heartbeat must never interrupt playback, per §8 of the engineering doc |
| 2026-09-03 | AC9 (app-created resume) and AC5 (re-verify) are demonstrated with the dev server's `MinResumeDurationSeconds` temporarily lowered from **300 to 10**, then restored. On the default config a `PlaybackStopped` report for any item under 300 s creates **no** resume point — Jellyfin discards the position — and both video items the library has (Avatar 20.8 s, F1 48.4 s) are far below that. | Claiming AC9 against the default config (unverifiable — no resume point is ever saved for these clips); leaving the criterion for a human | The app side is proven independently: a live `/Sessions` poll showed the app's progress reports carrying accurate positions (2, 4, 7, 9, 10, 13 s) and the start/stopped reports opening and closing the session. The only blocker is a server policy that excludes short test clips, the same class of data/config gap decision 14 records and decision 35 resolves by changing the server. With the floor at 10 s, F1's app-created stopped report produced a `/UserItems/Resume` entry at 21.6 s, `MovieDetailScreen` showed Resume, and Home showed F1 at 73% (35.5 s of 48.4 s) matching the server exactly. The config was restored to 300 afterwards; the created resume `UserData` persists. Recorded in the Drift Log. |

## 7. Sub-Slices

Not split — delivered as a single slice.

## 8. Testing Strategy
- **Unit / Integration / UI:** unit only. `.useCase`-tagged tests for the progress and stopped report use cases against a `Stub` `PlaybackRepositoryProtocol` (success and swallowed-failure cases); the start use case is tested in 006. `.service`-tagged tests for `VideoPlaybackService`'s reporting cadence and the stop-time `isWatched` rule, against a stub `VideoPlayerControlling` and an injected clock. No XCUITest — deferred per decision 4. No CI gate is added or restored.
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

- [x] Acceptance criteria met (AC9/AC5 demonstrated with the dev server's resume floor lowered then restored — Section 6 row)
- [x] Tests passing, in a target that exists
- [x] Every `covers:` requirement satisfied, or forked with a decision row (§1.13 video half here; music half is 009)
- [x] Decision log written as you went, not reconstructed
- [x] Pre-flight completed and drift resolved
- [x] Master checklist row current
- [x] `next_slice` `depends_on` reflects what actually shipped, not what was planned
- [x] Both link directions checked: this page `next_slice` and that page `previous_slice`

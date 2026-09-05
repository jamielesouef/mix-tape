---
slice_id: "018"
title: Audio end-of-track failure (Triage 7 v2)
priority: P2
complexity: M
ladder: "exact-end seek handling v2 of 2 — v1 (slice 015) clamps the seek to runtime − 1 s behind MusicPlayerService.seek(to:); v2 root-causes the failure and deletes the clamp. Shared seam: MusicPlayerService.seek(to:)"
depends_on:
  - { id: "015", type: hard, note: "v1 of the ladder and the measurement this slice starts from: on 'King Of Terrors' (FLAC) a seek to runtime − 1 s makes AVPlayerItem fail with FigFilePlayer err=-12864 — status .failed, no onEnded — while the ALAC albums end cleanly" }
  - { id: "013", type: hard, note: "MixtapeServicesTests and MixtapePresentationTests, and the gate that reads docs/slices/test-count.txt" }
previous_slice: "017"
next_slice: none
parent_slice: none
covers: []
created: 2026-09-05
---

# 018 — Audio end-of-track failure (Triage 7 v2)

← [previous](017-spec-document-reconciliation.md) · [Master Checklist](MASTER-CHECKLIST.md) · none →

> **Status, owner and blockers live in the master checklist, not here.** Dependencies live in this page's front matter and nowhere else. Each fact has one home; if you find yourself writing it twice, one of the two copies is going to be wrong in a fortnight.

## 1. Objective

Seeking any track to any position ends the track normally. Observable on its own: drag the Now Playing scrubber to its end on a FLAC track and the album finishes, exactly as it does on an ALAC track today.

## 2. Business Value & Priority

Triage 7 recorded a "stall" at the exact end of a track. Slice 015 measured it and found something different: on "King Of Terrors" (FLAC, served by `/Audio/{id}/universal`), a seek that lands one second before the end makes `AVPlayerItem` fail — `FigFilePlayer err=-12864`, `onFailure` fires, `status` becomes `.failed`, and `onEnded` never comes — where the four ALAC albums end cleanly from the same gesture. So v1's clamp (`MusicPlayerService.endSeekMargin`) is a margin around a decode failure, not around a seek race, and the margin that is safe for FLAC is unknown.

**Second observation, 2026-09-05 (016's tvOS acceptance run):** it is not only seeks. On the Apple TV simulator the FLAC track "In the Name of the Father" (King Of Terrors, 3:47) was left to play from the start; `/Sessions` then showed the Apple TV session stuck on that track with `PositionTicks` 2271608163 — the full runtime — re-reported every 10 s for the next quarter of an hour, through a sign-out and a Quick Connect sign-in, while the album's remaining tracks never started and the queue never finished. So the natural end of a FLAC track fails the same way the seek-to-end did, the report loop keeps running on the failed item, and the failure survives sign-out. Reproduce with the album playing untouched, not only with the scrubber; and check what `stop()` on sign-out should do to the report loop.

P2 because the natural end of every track is unaffected and the gesture is a deliberate drag to the end; it is a slice rather than a deferral because AC17i does not allow an open triage item without an owner. This is the second rung of the ladder 015 opened; the shared seam is `MusicPlayerService.seek(to:)`, and the deliverable of this rung is to delete the clamp there and change nothing else.

## 3. Scope

**In scope:**

- Reproduce the failure against the dev server with `scripts/jf-probe.swift` reading `/Sessions`, and capture the server's response for the last bytes of the FLAC stream (`/Audio/{id}/universal` with `container=flac,…`) — whether the container/codec the server picks for FLAC is one AVPlayer can seek to within its final second.
- Decide, with a decision row, whether the fix is client-side (the `universal` container list or `transcodingContainer`, `BuildAudioStreamURLUseCase`) or a server finding recorded in the drift log with the clamp kept.
- If client-side: delete `endSeekMargin` from `MusicPlayerService.seek(to:)`, update the `MixtapeServicesTests` seek test, and demonstrate the drag-to-end on the FLAC album.

**Out of scope** (name the slice it's deferred to):

- Any change to what a report contains, or to the §1.1 invariants. The queue is the album.
- Anything on tvOS beyond confirming the fix there: 016's tvOS checks closed on 2026-09-05 (`scripts/tv-remote.sh`), and the see-through Now Playing cover is Triage 23, a separate owner.

**Plan requirements covered:** none. This is a defect rung, gated on builds, tests and the scripts, plus the demonstration above.

## 4. Pre-Flight Validation

- [ ] **015** — opened. Confirm `endSeekMargin` is still 1 s behind `seek(to:)` and that the evidence paragraph's FLAC finding still reads as recorded.
- [ ] **013** — opened. `docs/slices/test-count.txt` is the count the gate reads; this slice changes it deliberately if it changes a test.
- [ ] Dev server: "King Of Terrors" still present as FLAC, and only once — 016 removed its "Music 2" copy on 2026-09-05 (`/Library/VirtualFolders` and `/UserViews` list Movies and Music only); confirm that still holds so the duplicate is not the one measured.
- [ ] Architecture standards doc re-read.

**Drift found:** `none` — or what changed, plus a row in the checklist's Drift Log.

## 5. Acceptance Criteria

- [ ] **AC18a** — On a FLAC track, dragging the scrubber to its end ends the track and the album finishes; `music.status` never reaches `.failed`.
- [ ] **AC18b** — The same on an ALAC track, unchanged from 015.
- [ ] **AC18c** — `endSeekMargin` is gone, or a decision row says why it stays and what bounds it.
- [ ] `xcodebuild build` and `test` pass for both schemes; layer, glass and swiftformat clean.

## 6. Decision Log

**Write the row before you implement the decision, not after.**

| Date | Decision | Alternatives rejected | Why |
|---|---|---|---|

## 7. Sub-Slices

Not split.

## 8. Testing Strategy

- **Unit:** `MixtapeServicesTests` (`.service`): the seek path with and without the clamp; a stub controller that reports failure near the end if the fix is client-side.
- **Integration:** none against the live server in an automated test.
- **UI:** none — decision 4.
- **Acceptance:** AC18a and AC18b on the iOS simulator against `localhost:8096`, read through `scripts/jf-probe.swift`.
- **Test targets required:** `MixtapeServicesTests` (exists).

## 9. Keeping this document true

| Before you… | Write this first |
|---|---|
| implement a decision | the Section 6 row, including what you rejected |
| start work | flip status in the master checklist |
| stop on a blocker | the Active Blockers row |
| widen scope | Section 3, and `depends_on` on any slice that's now affected |

Commit this file alongside the code, with the slice id in the subject (`018: …`).

## 10. Definition of Done

- [ ] Acceptance criteria met
- [ ] Tests passing, in a target that exists
- [ ] Triage 7 closed in the master checklist, v2 included
- [ ] Decision log written as you went, not reconstructed
- [ ] Pre-flight completed and drift resolved
- [ ] Master checklist row current

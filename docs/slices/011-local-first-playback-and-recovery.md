---
slice_id: "011"
title: Local-first playback and download recovery
priority: P0
complexity: M
ladder: "orphan cleanup v1 of 2 — v2 is a sweep of Downloads/ for directories with no row, shared seam: DeleteDownloadUseCase and the Downloads root path helper"
depends_on:
  - { id: "010", type: hard, note: "needs downloaded files and rows to prefer" }
  - { id: "009", type: hard, note: "needs PlaybackService and the streaming path to fall back to" }
previous_slice: "010"
next_slice: none
parent_slice: none
covers: ["6.localFirst"]
created: 2026-08-31
---

# 011 — Local-first playback and download recovery

← [previous](010-album-download-offline.md) · [Master Checklist](MASTER-CHECKLIST.md) · next: none

> **Status, owner and blockers live in the master checklist, not here.** Dependencies live in this page's front matter and nowhere else. Each fact has one home; if you find yourself writing it twice, one of the two copies is going to be wrong in a fortnight.

## 1. Objective

Make `PlaybackService.load(album:)` prefer a downloaded file over the server, and recover gracefully when the file it expected is gone. Value observable on its own: put the phone in aeroplane mode and a downloaded album still plays. That is the whole point of slice 010, and until this lands, slice 010 has downloaded files that nothing uses.

## 2. Business Value & Priority

This is the payoff slice and the last one in v1. It is separate from 010 for one reason: 010 is shippable and testable on its own — files on disk, rows in the store, a downloads list — and mixing the playback-selection change into it would mean 010's tests could not distinguish "the download worked" from "playback picked the right source".

The detail that earns this slice its own document is the third step. **A SwiftData row saying `completed` is not proof the bytes are still there.** iOS can evict files. The plan is explicit about this, and the check is one line — but without it, the app hands `AVPlayerItem` a URL to a file that does not exist and gets a failure that looks like a corrupt download rather than an evicted one.

## 3. Scope

**In scope:**

- `PlaybackService.load(album:)` selecting a source per track:
  1. Look for a `DownloadedTrack` with that `id` in state `completed`
  2. If found **and the file exists on disk**, use `AVPlayerItem(url: <local file URL>)`
  3. Otherwise use the server audio URL from `AudioURLProvider`
- A missing file flips the row to `failed`, so the UI can offer a re-download
- The album's state recomputes to `failed` off that flip, per slice 010's rule
- A re-download affordance wherever a `failed` album appears
- An offline indicator: a downloaded album is playable with no network; one that is not downloaded says so rather than failing at play time
- The downloads list distinguishing `completed` from `failed` clearly enough to act on
- A "delete all downloads" action — this is fork **F4**'s v1 escape hatch and is the only way to reclaim orphaned bytes in v1

**Out of scope** (name the slice it is deferred to):

- A background sweep for orphaned files → ladder **L9** v2
- Automatic re-download of an evicted file without the user asking → out of scope for v1; a silent background fetch on a metered connection is a worse failure than a visible one
- Storage usage reporting → out of scope for v1
- Partial-album playback where some tracks are local and others stream → **in scope and automatic**, because the choice is made per track. Named here because it reads like an omission

**Plan requirements covered:**

- `6.localFirst` — the three-step selection, the disk-existence check, and the flip to `failed` on a miss.
- **One accepted limitation, F4, recorded in Section 6.** Track ids are path-derived. Moving a file on the NAS — not retagging it, moving it — mints a **new** track id. The `DownloadedTrack` keeps the old id, so `load(album:)` looks up the new id, finds nothing, and streams. The downloaded bytes are then never used and never deleted: invisible orphans that grow every time the owner reorganises their folders. v1 accepts this with "delete all downloads" as the escape hatch, because a correct sweep needs care and this is the last slice of v1.

**Verification note carried into implementation:** whether `FileManager.fileExists` is sufficient to detect an evicted file, and the exact eviction semantics for files in Application Support marked excluded from backup, were **not re-verified against Apple's documentation during planning, because the documentation tool was not available in that session.** Check against `apple-docs` before implementing — if eviction leaves a zero-length placeholder rather than removing the file, an existence check passes and playback fails anyway, and the check must become a size check.

## 4. Pre-Flight Validation

Complete **before the first line of code**, not at close.

For **each id in `depends_on`**, in order — do not summarise, walk the list:

- [ ] **010** — opened. Its decision log still says only relative paths are stored, and `DownloadedAlbum.state` is recomputed from track states. This slice writes a track to `failed` and relies on that recompute firing.
- [ ] **010** — confirm the relative-path resolution helper exists and is the single place a `Downloads/` file URL is built. If there are two, this slice creates a third and ladder **L9**'s seam is already gone.
- [ ] **009** — opened. Its decision log still says `AudioURLProvider` is the **only** place an audio URL is constructed. This slice adds a second source for a player item; it must not add a second URL construction site.
- [ ] **009** — confirm the "next on the final track stops" behaviour and its comment are still present. This slice rebuilds queue construction and it is the easiest thing to lose in a refactor.
- [ ] Re-read the Apple documentation for the eviction behaviour named in Section 3.
- [ ] Architecture standards doc re-read: `docs/plan/v1-architecture.md` section 6, playback selection.

**Drift found:** `none` — or what changed, plus a row in the checklist's Drift Log.

## 5. Acceptance Criteria

- [ ] A fully downloaded album plays **in aeroplane mode**. This is the acceptance criterion the last three slices were building towards.
- [ ] Playing a downloaded album makes **no network request for audio**. Verified by watching traffic, not by it working.
- [ ] An album that is not downloaded still streams, unchanged from slice 009.
- [ ] An album where only some tracks completed plays the local ones locally and streams the rest, per track, in one continuous album.
- [ ] **Deleting a downloaded file from disk behind the app's back, then playing:** the track streams, and its row flips to `failed`. Both halves checked — a fallback that does not flip the row leaves the user with no way to notice or fix it.
- [ ] That flip recomputes the album to `failed`, and a re-download affordance appears.
- [ ] Re-downloading a `failed` album returns it to `completed` and to local playback.
- [ ] A `completed` row whose file is missing **never** causes a hard playback failure. It always falls back.
- [ ] Playing a downloaded album whose album is no longer in the server's manifest works, offline and online. This is the retag/removal case from slice 010's fork **F3**, now proven at playback.
- [ ] "Delete all downloads" removes every file under `Downloads/` and every `Downloaded*` row, and the app is left in a consistent state — verified by a relaunch afterwards.
- [ ] The queue is still the album, and next on the final track still stops. **Re-tested here**, because this slice rewrites queue construction.
- [ ] No second audio-URL construction site. Grep confirms one.
- [ ] Swift 6 strict concurrency clean.
- [ ] `#Preview`s updated for the `failed` and re-download states.
- [ ] Runs on iOS, iPadOS and macOS.

## 6. Decision Log

**Write the row before you implement the decision, not after.** This is the whole mechanism. A decision log filled in at close is reconstructed from memory, and the rejected alternatives — the part the next slice's pre-flight actually needs — are exactly what memory loses first.

| Date | Decision | Alternatives rejected | Why |
|---|---|---|---|
| 2026-08-31 | The disk-existence check runs on every load, not once at launch | Trust the `completed` state; verify all downloads at launch | iOS can evict a file at any time, so a launch-time sweep is stale by the time it is used, and on a large downloads set it costs a launch-time filesystem walk. The check is one call at the moment it matters |
| 2026-08-31 | A missing file falls back to streaming **and** flips the row to `failed` | Fall back silently; fail the track outright | Silent fallback means the user is streaming on cellular believing they are offline-safe, and the download never gets repaired. Failing outright turns a recoverable situation into a broken album. Fall back so it plays, flip the row so it can be fixed |
| 2026-08-31 | No automatic re-download of an evicted file | Re-download in the background on detection | A silent background fetch of an album on a metered connection is a worse failure than a visible `failed` badge. The user asked for this album once; they can ask again knowing the cost |
| 2026-08-31 | **F4 — orphaned bytes after a NAS file move are accepted in v1, with "delete all downloads" as the escape hatch (ladder **L9**)** | A sweep of `Downloads/` for directories with no matching row; reconcile by path instead of id; make track ids tag-derived | Track ids are path-derived by design (slice 004), which is what stops a **retag** from orphaning a download — the more common case. The cost is that a **move** orphans one instead. A correct sweep must not delete a directory belonging to an in-flight download, and this is the last slice of v1. The seam is `DeleteDownloadUseCase` plus the single `Downloads/` root helper; v2 adds a sweep behind them |
| 2026-08-31 | Mixed local and streamed tracks within one album are allowed | Require a fully downloaded album before playing any of it locally | The choice is per track and costs nothing. Requiring all-or-nothing would mean a single failed track forces the whole album to stream, which is worse on every axis |

## 7. Sub-Slices

Not split — delivered as a single slice.

## 8. Testing Strategy

- **Unit:** the source-selection function as pure logic — given a track id, an optional `DownloadedTrack` with a state, and a file-existence result, which source is chosen and is the row flipped? Six cases: no row; row `queued`; row `failed`; row `completed` with the file present; row `completed` with the file **absent**; and row `completed` with a zero-length file, in case the documentation check in Section 3 changes the test to a size check. The absent case is the one this slice exists for.
- **Unit:** the album-state recompute firing off a flip to `failed`, reusing slice 010's rule rather than reimplementing it.
- **Integration:** against an in-memory container and a real temporary directory — write a file, select, delete the file, select again, assert both the fallback and the flip.
- **UI:** one XCUITest — with a seeded downloaded album and a stubbed server that refuses all audio, assert playback starts. That is aeroplane mode, expressed as a test.
- **Manual, and required, on a real device:** aeroplane mode with a downloaded album; a partially downloaded album online; "delete all downloads" followed by a relaunch. Record in the commit.
- **Test targets required:** `App/Tests/MixTapeTests/` and `App/Tests/MixTapeUITests/`, created by slice 001. Swift Testing tagged `.service`.

## 9. Keeping this document true

This slice is done when the page describes what was actually built — not when the code works. The discipline is **ordering**: the write happens *before* the thing it describes, so it sits on the critical path instead of after it, where it gets skipped.

| Before you… | Write this first |
|---|---|
| implement a decision | the Section 6 row, including what you rejected |
| start work | flip status in the master checklist |
| stop on a blocker | the Active Blockers row |
| build on a spike | that spike's Result section |
| widen scope | Section 3, and `depends_on` on any slice that is now affected |

And in the same commit as the code, not a follow-up: **commit this file alongside it**, with the slice id in the commit subject (`011: prefer local files at playback`).

Nothing checks any of this. That is the point of putting the writes first — a write you have to do to proceed is one you do; a write you are supposed to do afterwards is one you do not.

## 10. Definition of Done

- [ ] Acceptance criteria met
- [ ] Tests passing, in a target that exists
- [ ] Every `covers:` requirement satisfied, or forked with a decision row — **F4 is an accepted limitation and has one**
- [ ] Decision log written as you went, not reconstructed
- [ ] Pre-flight completed and drift resolved, **including the Apple-documentation check named in Section 3**
- [ ] Master checklist row current
- [ ] `next_slice` is `none` — this is the last slice of v1. Confirm the Plan Coverage table has no uncovered rows before closing it
- [ ] Both link directions checked: `010`'s `next_slice` points here and this page's `previous_slice` points back

---
slice_id: "010"
title: Downloading an album for offline use
priority: P0
complexity: L
ladder: "download granularity v1 of 2 — v2 is per-track selection and user-facing pause, shared seam: DownloadService.enqueue(album:) over per-track DownloadedTrack rows that already exist"
depends_on:
  - { id: "009", type: hard, note: "needs the /audio route the downloads fetch from" }
  - { id: "007", type: hard, note: "needs the Downloaded* models, defined there and unused until now" }
  - { id: "005a", type: hard, note: "needs the token readable while the device is locked" }
previous_slice: "009"
next_slice: "011"
parent_slice: none
covers: ["2.downloads", "6.states", "6.storage", "6.session", "6.delegate", "6.resume"]
created: 2026-08-31
---

# 010 — Downloading an album for offline use

← [previous](009-album-playback-streaming.md) · [Master Checklist](MASTER-CHECKLIST.md) · [next](011-local-first-playback-and-recovery.md) →

> **Status, owner and blockers live in the master checklist, not here.** Dependencies live in this page's front matter and nowhere else. Each fact has one home; if you find yourself writing it twice, one of the two copies is going to be wrong in a fortnight.

## 1. Objective

Download a whole album to the device with a background `URLSession`, survive an app relaunch, and list what is downloaded. Value observable on its own: tap download, background the app, come back, and the album is on the phone with its bytes on disk and its rows in SwiftData.

## 2. Business Value & Priority

Offline playback is the reason to own this rather than stream from a NAS you are not at home with. It is on the handoff's v1 list.

It is also, in the handoff's own words, **the concurrency friction point**. Delegate callbacks fire off-main and can arrive after an app relaunch, so `DownloadService` cannot be cleanly `@MainActor`. This slice contains the one `nonisolated` shim in the codebase, and the justification is written in the file — not in a commit message, in the file. Every other service is `@MainActor @Observable` and stays that way.

The detail that makes it all work is small and easy to miss: **`taskDescription = trackID`**. That string survives an app relaunch, so mapping a system-resumed task back to a track needs no shared dictionary and no state that could be lost. Any design that reaches for a dictionary here has misunderstood the problem.

The ten-year token from slice 005 pays off here too. A download queued days ago and resumed after a relaunch still authenticates, with no user present and possibly a locked device.

**Ladder L8 — download granularity (this slice ships the crude rung).** v1 downloads a whole album, with no user-facing pause. The seam is `DownloadService.enqueue(album:)` sitting over per-track `DownloadedTrack` rows that already carry their own `state` and `resumeData`. v2 — per-track selection, or a pause button — is built from rows that already exist. Named seam, so this is a ladder.

## 3. Scope

**In scope:**

- `DownloadState: String` in `AppDomain/` — `queued`, `downloading`, `completed`, `failed`
- Per-track state on `DownloadedTrack`; `DownloadedAlbum.state` **recomputed and stored** whenever a track changes, so the grid can query it directly: any `failed` → `failed`; any `downloading` → `downloading`; all `completed` → `completed`; otherwise `queued`
- Files at `Application Support/MixTape/Downloads/<albumID>/<trackID>.<ext>` and `.../artwork.jpg`
- `Downloads` marked `isExcludedFromBackupKey = true`
- **Only** the path relative to `Downloads/` stored in SwiftData, never an absolute one — the app container path changes between launches and updates, and a stored absolute path is a guaranteed bug
- One `URLSession` created once and owned by `DownloadService`: `background(withIdentifier: "io.mixtape.downloads")`, `isDiscretionary = false`, `sessionSendsLaunchEvents = true`, `Authorization: Bearer <token>` per `URLRequest`
- `taskDescription = trackID` on every task
- `DownloadSessionDelegate` at `App/AppServices/Download/DownloadSessionDelegate.swift` — `final class NSObject, URLSessionDownloadDelegate`, `nonisolated`. `didFinishDownloadingTo` moves the file **synchronously on the delegate thread**, because the temporary URL is valid only for the duration of the callback, and only then hops to the main actor. **No `@unchecked Sendable`, no `DispatchQueue`**, and the justification comment is in the file
- `.backgroundTask(.urlSession("io.mixtape.downloads"))` on the scene
- Relaunch reconciliation: `session.getAllTasks()` compared against SwiftData; any row in `downloading` or `queued` with no live task is marked `failed` and re-enqueued, using `resumeData` where present
- A download button on `AlbumDetailScreen` and progress on the album tile, driven by `bytesReceived`/`bytesExpected`
- A downloads list showing what is on the device
- **Deleting a download**, including one whose album is no longer in the manifest — see fork **F3**
- `DownloadAlbumUseCase` and `DeleteDownloadUseCase` in `AppUseCase/`; `DownloadRepository` in `AppData/`

**Out of scope** (name the slice it is deferred to):

- Choosing the local file at playback time → **011**. Downloading does not change what plays yet
- Per-track download, or a user-facing pause → ladder **L8** v2
- A storage-usage screen, or an automatic eviction policy → out of scope for v1
- Downloading over cellular versus Wi-Fi preferences → out of scope for v1; `isDiscretionary = false` and the system's own settings apply
- Sweeping orphaned files left by a NAS-side file move → **011**, fork **F4**

**Plan requirements covered:**

- `2.downloads` — `DownloadedAlbum` and `DownloadedTrack` given their lifecycle. The models themselves were defined in slice 007.
- `6.states`, `6.storage`, `6.session`, `6.delegate`, `6.resume` — as specified.
- **One deliberate fork, F3, recorded in Section 6.** The plan establishes that a downloaded album survives a rescan that removes it from the manifest — *"it simply stops appearing in the 'on server' list and keeps appearing in the 'downloaded' list"*. It never says how the user gets rid of it. Because album ids are tag-derived, **retagging an album on the NAS mints a new album id**: the old download stays downloaded forever under an id the server no longer knows, and the retagged album appears as a new album with no download. The user now sees the same album twice and cannot delete the stale copy from anywhere that reaches the server. Deletion must therefore be driven from the downloads list, off local rows alone, never from the manifest.

**Verification note carried into implementation:** the plan's claims about background `URLSession` behaviour — the temporary file URL's lifetime in `didFinishDownloadingTo`, `sessionSendsLaunchEvents`, delegate replay after relaunch, and `.backgroundTask(.urlSession(_:))` semantics — were **not re-verified against Apple's documentation during planning, because the documentation tool was not available in that session.** Check each against `apple-docs` before implementing. This is the slice where a wrong assumption about lifecycle costs the most, because the failures only appear after a real termination on a real device.

## 4. Pre-Flight Validation

Complete **before the first line of code**, not at close.

For **each id in `depends_on`**, in order — do not summarise, walk the list:

- [ ] **009** — opened. Its decision log still says `/audio` accepts a **bearer header** as well as `?token=`. This slice uses the header, and if 009 shipped query-parameter-only, this slice cannot authenticate a background task cleanly. That would be a blocker, not a workaround.
- [ ] **009** — confirm fork **F5** landed. Downloads request the same paths playback does; if hazardous filenames `404` on stream, they `404` on download too, and the failure will be attributed to the download code.
- [ ] **007** — opened. Its decision log still says `DownloadedAlbum` and `DownloadedTrack` are defined with **no relationship to the cache models**, and that `DownloadedAlbum` carries a self-sufficient copy of its render-and-play fields. Confirm the survives-a-replacement test from 007 is still green **before** adding anything here.
- [ ] **005a** — opened. Confirm the Keychain item was written with `kSecAttrAccessibleAfterFirstUnlock`. If it was not, a background download on a locked device fails with something that reads as a network error. Fixing it means re-pairing every install, so check now, not after.
- [ ] Confirm the background modes capability is enabled on the app target for both audio and background processing.
- [ ] Re-read the Apple documentation for the four behaviours named in Section 3.
- [ ] Architecture standards doc re-read: `docs/plan/v1-architecture.md` section 6; `docs/app-architecture-template.md` on `@concurrent`, actor isolation and the no-`@unchecked Sendable` rule.

**Drift found:** `none` — or what changed, plus a row in the checklist's Drift Log.

## 5. Acceptance Criteria

- [ ] Tapping download on an album fetches every track and lands the bytes at the specified paths.
- [ ] Album artwork is downloaded to `<albumID>/artwork.jpg`.
- [ ] Progress updates on the tile as bytes arrive, from `bytesReceived`/`bytesExpected`.
- [ ] `DownloadedAlbum.state` matches the recompute rule at every point. Test each transition, including one failed track among completed ones producing `failed`.
- [ ] **Backgrounding the app mid-download and returning later shows it completed.** Real device, real backgrounding.
- [ ] **Force-quitting the app mid-download, then relaunching, resumes or re-enqueues.** No row is left in `downloading` with no task. This is the reconciliation path and it is the one that rots silently.
- [ ] Downloading with the **device locked** succeeds. This is what `kSecAttrAccessibleAfterFirstUnlock` is for and it is proven here.
- [ ] Killing the network mid-download marks tracks `failed` and stores `resumeData` where the system provides it; retrying resumes rather than restarting. Compare the bytes transferred.
- [ ] **No absolute path is stored in SwiftData.** Grep the store; every `relativePath` is relative to `Downloads/`.
- [ ] Reinstalling the app in a way that changes the container path leaves stored paths still resolvable, given the same `Downloads/` root.
- [ ] `Downloads/` has `isExcludedFromBackupKey == true`. Read the attribute back, do not trust the write.
- [ ] **A downloaded album still present after a full manifest replacement.** Re-run slice 007's test with real downloads rather than hand-inserted rows.
- [ ] **F3 — an album deleted from the server, then rescanned, remains in the downloads list, remains playable, and can be deleted from there.** The delete removes both the rows and the files.
- [ ] **F3 — the retag case.** Retag an album on the NAS so its album id changes, rescan, and confirm: the old download still appears in the downloads list, the retagged album appears in the grid as new, and the user can delete the old one. Awkward, and it is exactly what will happen the first time someone tidies their tags.
- [ ] Deleting a download removes the files from disk, not just the rows. Check the directory.
- [ ] `DownloadSessionDelegate` is the only `nonisolated` type in `AppServices/`, and its justification comment is present in the file.
- [ ] No `@unchecked Sendable`, no `nonisolated(unsafe)` and no `DispatchQueue` anywhere in this slice.
- [ ] Swift 6 strict concurrency clean, no warnings.
- [ ] The downloads list and the download button have `#Preview`s covering queued, downloading, completed, failed and empty.

## 6. Decision Log

**Write the row before you implement the decision, not after.** This is the whole mechanism. A decision log filled in at close is reconstructed from memory, and the rejected alternatives — the part the next slice's pre-flight actually needs — are exactly what memory loses first.

| Date | Decision | Alternatives rejected | Why |
|---|---|---|---|
| 2026-08-31 | **F3 — deletion is driven from the downloads list off local rows alone, never from the manifest. A fork; the plan does not cover it** | Delete only from the album detail screen, which needs a manifest entry; automatically delete downloads that vanish from the manifest | Album ids are tag-derived, so retagging on the NAS mints a new id and strands the old download under an id the server no longer knows. If deletion needed a manifest entry, that album could never be removed. Auto-deleting was rejected outright — it is precisely the "a rescan wiped my downloads" failure the whole cache/download split exists to prevent |
| 2026-08-31 | `taskDescription = trackID` is the task-to-track mapping | A dictionary on `DownloadService`; a mapping table in SwiftData; matching on the URL | It is the only mapping that survives an app relaunch without state that could be lost. The system hands back a task; the task carries its own identity. Recorded because a dictionary is the obvious first instinct and is wrong here |
| 2026-08-31 | `DownloadSessionDelegate` is `nonisolated` and moves the file **synchronously on the delegate thread** before hopping to the main actor | Make the delegate `@MainActor`; hop first and move the file after; copy to a second temporary location | The temporary URL is valid only for the duration of the callback. Hopping first means the file is gone by the time the hop lands — an intermittent failure that reproduces on a slow device and not on a fast one. This is the one justified `nonisolated` shim in the codebase and the justification lives in the file |
| 2026-08-31 | `DownloadedAlbum.state` is stored and recomputed, not derived on read | Compute it from the tracks at read time; a SwiftData computed property | The grid queries album state directly for every visible tile. Deriving it means loading every track of every album to draw one screen. The cost is one recompute per track change, which is bounded and rare |
| 2026-08-31 | Whole-album downloads, no user-facing pause in v1 (ladder **L8**) | Per-track selection; a pause button; a queue-management screen | The album is the unit — that is the product. The seam is `enqueue(album:)` over per-track rows that already carry `state` and `resumeData`, so v2 needs no schema change |
| 2026-08-31 | Only paths relative to `Downloads/` are stored | Absolute URLs; bookmark data | The container path changes between launches and updates. The plan calls a stored absolute path "a guaranteed bug" and it is right. Bookmark data would work but is heavier than a string for a directory we own and control |

## 7. Sub-Slices

Not split — delivered as a single slice. The tempting split is session-then-UI, but the background session's real behaviour only shows under a real relaunch driven from a real UI, so the split would defer every interesting test into the second half.

## 8. Testing Strategy

- **Unit:** the `DownloadedAlbum.state` recompute rule, as a pure function over track states. All five combinations, including the empty one.
- **Unit:** relative-path construction and resolution, including a simulated container path change between the write and the read. This is the "guaranteed bug" made into a test.
- **Unit:** reconciliation logic as a pure function — given a set of live task descriptions and a set of stored rows, which rows are marked `failed` and re-enqueued? Testable without a real session, and it is the logic most likely to be wrong.
- **Integration:** `DownloadRepository` and the SwiftData writes against an in-memory container, including the manifest-replacement survival case with real download rows.
- **Integration:** the **F3** delete path — an album with no manifest entry deletes cleanly, rows and files.
- **UI:** one XCUITest — download an album from a stubbed server, assert it appears in the downloads list.
- **Manual, and required, on a real device:** background mid-download and return; force-quit mid-download and relaunch; download with the device locked; kill the network mid-download and retry. **None of these are trustworthy in the simulator**, and they are the four failures this slice exists to get right. Record the results in the commit.
- **Test targets required:** `App/Tests/MixTapeTests/` and `App/Tests/MixTapeUITests/`, created by slice 001. Swift Testing tagged `.service` and `.repository`.

## 9. Keeping this document true

This slice is done when the page describes what was actually built — not when the code works. The discipline is **ordering**: the write happens *before* the thing it describes, so it sits on the critical path instead of after it, where it gets skipped.

| Before you… | Write this first |
|---|---|
| implement a decision | the Section 6 row, including what you rejected |
| start work | flip status in the master checklist |
| stop on a blocker | the Active Blockers row |
| build on a spike | that spike's Result section |
| widen scope | Section 3, and `depends_on` on any slice that is now affected |

And in the same commit as the code, not a follow-up: **commit this file alongside it**, with the slice id in the commit subject (`010: add offline album download`).

Nothing checks any of this. That is the point of putting the writes first — a write you have to do to proceed is one you do; a write you are supposed to do afterwards is one you do not.

## 10. Definition of Done

- [ ] Acceptance criteria met
- [ ] Tests passing, in a target that exists
- [ ] Every `covers:` requirement satisfied, or forked with a decision row — **F3 is a fork and has one**
- [ ] Decision log written as you went, not reconstructed
- [ ] Pre-flight completed and drift resolved, **including the Apple-documentation check named in Section 3**
- [ ] Master checklist row current
- [ ] `next_slice`'s `depends_on` reflects what actually shipped, not what was planned
- [ ] Both link directions checked: this page's `next_slice` and `011`'s `previous_slice`

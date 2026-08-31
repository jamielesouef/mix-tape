---
slice_id: "006"
title: The library manifest endpoint and manual rescan
priority: P0
complexity: M
ladder: none
depends_on:
  - { id: "005a", type: hard, note: "delivery order; the server half it actually needs is 005" }
  - { id: "005", type: hard, note: "needs the bearer middleware to sit behind" }
  - { id: "004", type: hard, note: "needs LibraryIndex, the manifest and the revision" }
previous_slice: "005a"
next_slice: "007"
parent_slice: none
covers: ["3.library", "3.rescan"]
created: 2026-08-31
---

# 006 — The library manifest endpoint and manual rescan

← [previous](005a-app-sign-in-and-token-storage.md) · [Master Checklist](MASTER-CHECKLIST.md) · [next](007-album-grid-from-cache.md) →

> **Status, owner and blockers live in the master checklist, not here.** Dependencies live in this page's front matter and nowhere else. Each fact has one home; if you find yourself writing it twice, one of the two copies is going to be wrong in a fortnight.

## 1. Objective

Serve the manifest over HTTP: `GET /library` with gzip and `ETag`/`If-None-Match`, and `POST /library/rescan` that returns immediately. Value observable on its own: an authenticated `curl` returns your whole library as JSON, a second `curl` with the `ETag` returns `304`, and hitting rescan after adding an album makes the `ETag` change.

## 2. Business Value & Priority

This is the join between the two halves built so far — slice 004's manifest and slice 005's middleware — and it is the last server slice before the app has something to draw.

The `ETag` is not an optimisation, it is the sync design. There is no incremental sync in this product: the client either gets the whole manifest or gets `304` and keeps what it has. A launch against an unchanged library costs one conditional request, which is the entire reason a 5 MB payload is acceptable. If the `ETag` is wrong in either direction the product breaks in a way that looks like something else — a stale `ETag` shows a library that never updates, an over-eager one re-downloads 5 MB on every launch and drains a battery.

`POST /library/rescan` returning `202` immediately, with the client discovering completion through a changed `ETag`, is what makes a minutes-long scan cost **zero new DTOs and zero new state**. There is no job id, no progress endpoint and no polling protocol — the `ETag` already carries the answer.

## 3. Scope

**In scope:**

- `GET /library`, bearer-authed, returning `LibraryManifestDTO` with `ETag: <revision>`
- `304 Not Modified` when `If-None-Match` matches, with no body
- gzip content encoding when the client asks for it
- `POST /library/rescan`, bearer-authed, returning `202` with an empty body, scanning in the background
- `409` with `APIErrorCode.scanInProgress` when a scan is already running
- Replacing the `LibraryIndex` contents and the `library.json` snapshot atomically at the end of a scan — a request mid-scan sees the old manifest or the new one, never a mixture
- Deleting slice 005's protected test route, now that a real protected route exists
- **A defined response for `GET /library` before the first scan has ever completed** — see fork **F2** in Section 6

**Out of scope** (name the slice it is deferred to):

- Any client-side fetching, caching or display → **007**
- `GET /artwork` → **008**; `GET /audio` → **009**
- Scan progress reporting, a job id, or a percentage → out of scope for v1; the `ETag` is the completion signal
- Partial or paged manifests → out of scope; the plan's design is one manifest, whole
- A filesystem watch → ladder **L3** v2, in slice 004

**Plan requirements covered:**

- `3.library` — `GET /library`, bearer, `LibraryManifestDTO`, `ETag`, `304` on `If-None-Match`.
- `3.rescan` — `POST /library/rescan`, bearer, `202`, `409` `scanInProgress`.
- **One deliberate fork, F2, recorded in Section 6.** The plan defines boot-with-no-snapshot as "scan, then serve" and never says what `GET /library` returns *during* that first scan. On a large library that is a multi-minute window on the very first run — the first thing a new user ever experiences. Undefined behaviour there is an empty grid the user reads as "my library is broken".

## 4. Pre-Flight Validation

Complete **before the first line of code**, not at close.

For **each id in `depends_on`**, in order — do not summarise, walk the list:

- [ ] **005a** — opened. Delivery-order dependency only; the server needs nothing from the client. If 005a slipped, this slice can proceed, but 007 cannot.
- [ ] **005** — opened. Its decision log still says the bearer middleware verifies HS256 and checks `sub` against the owner, with no per-request I/O. Confirm the protected test route still exists so it can be deleted here rather than left behind.
- [ ] **004** — opened. Its decision log still says `actor LibraryIndex` holds the manifest and is replaced wholesale, and that **fork F1** landed so `revision` includes `hasArtwork`. If F1 did not land, this endpoint will serve `304` to a client that is missing artwork it should have — the fault will present in slice 008 and be diagnosed here.
- [ ] **004** — check the recorded manifest size for a large fixture library. If it came out far above the plan's ~5 MB estimate, the gzip and `ETag` design needs re-examining before this slice, not after.
- [ ] Neither dependency is a spike; no fallback to check.
- [ ] Architecture standards doc re-read: `docs/plan/v1-architecture.md` section 3.

**Drift found:** `none` — or what changed, plus a row in the checklist's Drift Log.

## 5. Acceptance Criteria

- [ ] `GET /library` with a valid bearer token returns `200`, a body decoding to `LibraryManifestDTO`, and an `ETag` equal to `revision`.
- [ ] `GET /library` with no token, or a bad one, returns `401` with `APIErrorCode.unauthorized`. **This criterion is why this slice comes after 005.**
- [ ] `GET /library` with `If-None-Match: <that ETag>` returns `304` and **no body**.
- [ ] After adding an album and rescanning, the same `If-None-Match` returns `200` with a new `ETag`.
- [ ] After adding a `cover.jpg` to an existing album and rescanning, the `ETag` **changes**. This is fork **F1** from slice 004, and this is where its absence would be felt.
- [ ] `Accept-Encoding: gzip` yields a gzipped body, and the compressed size of a large fixture library is recorded in the commit message.
- [ ] `POST /library/rescan` returns `202` **immediately** — measured, under a second, on a library that takes minutes to scan.
- [ ] A second `POST /library/rescan` while the first is running returns `409` with `APIErrorCode.scanInProgress`.
- [ ] `GET /library` **during** a rescan returns the previous manifest with the previous `ETag`, in full, never a partial one.
- [ ] `GET /library` on a first boot with no snapshot, while the initial scan runs, returns `503` with `APIErrorCode.scanInProgress` and a `Retry-After` header. This is fork **F2**.
- [ ] Killing the server mid-scan and restarting leaves a valid `library.json` or none — never a truncated one that fails to parse on boot.
- [ ] Slice 005's protected test route is gone.

## 6. Decision Log

**Write the row before you implement the decision, not after.** This is the whole mechanism. A decision log filled in at close is reconstructed from memory, and the rejected alternatives — the part the next slice's pre-flight actually needs — are exactly what memory loses first.

| Date | Decision | Alternatives rejected | Why |
|---|---|---|---|
| 2026-08-31 | **F2 — `GET /library` during the very first scan returns `503` with `APIErrorCode.scanInProgress` and `Retry-After`. A fork; the plan leaves this undefined** | An empty manifest with a real `ETag`; blocking the request until the scan finishes; `404` | An empty manifest is indistinguishable from an empty library, and worse, the client would cache it against an `ETag` and stop asking. Blocking holds a connection open for minutes and times out. `503` with `Retry-After` is the honest answer and reuses an `APIErrorCode` case that already exists, so it costs no DTO change. `scanInProgress` on `/library` is a `503` while on `/rescan` it is a `409` — different meanings, correctly: one is "not ready", the other is "already doing that" |
| 2026-08-31 | Rescan returns `202` with no job id; completion is discovered through the `ETag` | A job id plus a status endpoint; a progress percentage; a WebSocket | The `ETag` already changes exactly when the scan lands, so a job id would be a second source of truth for the same fact. Zero new DTOs, per the plan. The cost is no progress bar during a rescan, which is acceptable for an action taken a handful of times a year |
| 2026-08-31 | The index is replaced wholesale, under the actor, at the end of a scan | Incremental updates as the scan progresses; a read-write lock over a mutable index | A request must never see half a scan. Wholesale replacement inside `actor LibraryIndex` makes that structural rather than something to remember. It is also what ladder **L4**'s seam depends on |
| 2026-08-31 | gzip is applied by the framework's response encoding, not by hand | Pre-compressing `library.json` and serving the bytes; no compression | Pre-compressed bytes go stale against the in-memory index and add a second artefact to keep consistent. 5 MB of JSON compresses heavily, so the saving is real, but not worth a cache-invalidation problem |

## 7. Sub-Slices

Not split — delivered as a single slice. `/library` and `/library/rescan` share the `LibraryIndex` and the scan-in-progress state; splitting them means shipping a rescan whose result nothing can observe.

## 8. Testing Strategy

- **Integration:** the conditional-request matrix against a fixture index — no `If-None-Match`, matching, non-matching, and malformed. The `304` case must assert an **empty body**, not just the status; a `304` with a body is a spec violation clients handle inconsistently.
- **Integration:** auth rejection on both routes, all four cases from slice 005's middleware.
- **Integration:** `409` on a concurrent rescan, by holding a fake scan open with a continuation rather than by scanning a real library. The test must not take minutes.
- **Integration:** the **F2** first-boot path — no snapshot, scan in flight, assert `503` and `Retry-After`.
- **Integration:** a request during a rescan returns the *complete previous* manifest. Assert the full album count, not just a `200`.
- **Test targets required:** `Server/Tests/ServerTests/`, created by slice 001. Swift Testing, tagged `.repository`.

## 9. Keeping this document true

This slice is done when the page describes what was actually built — not when the code works. The discipline is **ordering**: the write happens *before* the thing it describes, so it sits on the critical path instead of after it, where it gets skipped.

| Before you… | Write this first |
|---|---|
| implement a decision | the Section 6 row, including what you rejected |
| start work | flip status in the master checklist |
| stop on a blocker | the Active Blockers row |
| build on a spike | that spike's Result section |
| widen scope | Section 3, and `depends_on` on any slice that is now affected |

And in the same commit as the code, not a follow-up: **commit this file alongside it**, with the slice id in the commit subject (`006: add library endpoint and rescan`).

Nothing checks any of this. That is the point of putting the writes first — a write you have to do to proceed is one you do; a write you are supposed to do afterwards is one you do not.

## 10. Definition of Done

- [ ] Acceptance criteria met
- [ ] Tests passing, in a target that exists
- [ ] Every `covers:` requirement satisfied, or forked with a decision row — **F2 is a fork and has one**
- [ ] Decision log written as you went, not reconstructed
- [ ] Pre-flight completed and drift resolved
- [ ] Master checklist row current
- [ ] `next_slice`'s `depends_on` reflects what actually shipped, not what was planned
- [ ] Both link directions checked: this page's `next_slice` and `007`'s `previous_slice`

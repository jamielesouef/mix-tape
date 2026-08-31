---
spike_id: "S001"
title: Can two FileMiddleware instances on two roots under two path prefixes coexist in Hummingbird 2?
timebox: 3 hours
unblocks: ["003", "008", "009"]
created: 2026-08-31
---

# S001 — Two FileMiddleware instances, two roots, two prefixes

[Master Checklist](MASTER-CHECKLIST.md) · Unblocks: [003-docker-image-and-ci](003-docker-image-and-ci.md), [008-album-detail-and-artwork](008-album-detail-and-artwork.md), [009-album-playback-streaming](009-album-playback-streaming.md)

> **Status, owner and the answer summary live in the master checklist, not here.** This page holds the question, the method, the fallback and the evidence. One fact, one home.

## 1. Question

Can two `FileMiddleware` instances — one rooted at the artwork cache directory and mounted under `/artwork`, one rooted at the music directory and mounted under `/audio` — coexist in a single Hummingbird 2 application, each passing through to the next handler on a miss rather than terminating the request with a `404`?

The answer is a yes/no plus one concrete detail: **on a miss, does the middleware call `next` or does it respond?**

## 2. Why this blocks

The plan's section 3 mounts both `/artwork/{albumID}` and `/audio/**` on `FileMiddleware`, on two different filesystem roots. `FileMiddleware` is what gives us correct HTTP `Range` handling — including multi-range and `If-Range` — which the handoff forbids hand-rolling. If two instances cannot coexist, three things change:

- **Slice 008** and **slice 009** lose their serving mechanism and need the fallback layout.
- **Slice 003** changes: `docker-compose.yml` must bind-mount the music directory *underneath* the cache root rather than beside it, which changes the documented quickstart and the volume layout that ladder **L1** ships.
- The `MIXTAPE_MUSIC_DIR` / `MIXTAPE_CACHE_DIR` relationship stops being independent, which weakens ladder **L1**'s seam.

If the middleware responds `404` on a miss instead of passing through, every route registered *after* it under the same prefix becomes unreachable — that is a routing bug that would surface late and look like a caching problem.

## 3. Cheapest experiment that answers it

A throwaway package outside this repository. Do not touch `Server/`.

- [ ] `mkdir /tmp/hb-spike && cd /tmp/hb-spike && swift package init --type executable`
- [ ] Add `hummingbird` (2.x) to `Package.swift`, matching the version slice 001 pins.
- [ ] Create two directories with one file each: `/tmp/hb-spike/cache/artwork/a.jpg` and `/tmp/hb-spike/music/Artist/Album/b.flac` (any bytes will do; `head -c 200000 /dev/urandom > …`).
- [ ] Build a router with, in order: `FileMiddleware("/tmp/hb-spike/cache", urlBasePath: "/artwork")`, `FileMiddleware("/tmp/hb-spike/music", urlBasePath: "/audio")`, then a plain `GET /health` route returning `"ok"`.
- [ ] `swift run` and check each case with `curl -i`:
  - `curl -i localhost:8080/artwork/artwork/a.jpg` → `200`
  - `curl -i localhost:8080/audio/Artist/Album/b.flac` → `200`
  - `curl -i -H 'Range: bytes=0-99' localhost:8080/audio/Artist/Album/b.flac` → `206` with `Content-Range`
  - `curl -i localhost:8080/health` → `200 ok` — **this is the pass-through test**; a `404` here is the unfavourable answer
  - `curl -i localhost:8080/audio/nope.flac` → `404`
  - `curl -i 'localhost:8080/audio/../../etc/passwd'` and the percent-encoded `%2e%2e%2f` form → `404`, never a file
- [ ] Record the exact `urlBasePath` spelling that worked, and whether the base path is stripped before the root is joined. Slice 008 and slice 009 both need that detail verbatim.

**Explicitly not doing:** no auth, no DTOs, no `Shared` dependency, no Docker, no wildcard-route design beyond what `/audio/**` needs to answer the question. This spike produces a `curl` transcript, not code that ships.

## 4. Timebox

`3 hours`. On expiry: stop, record what you learned, and take the fallback in Section 5. An overrunning spike is itself an answer — the thing is harder than the design assumed.

## 5. Fallback if the answer is unfavourable

Decided **before** running the experiment, so the result does not get argued with.

> **If two instances cannot coexist, or the middleware terminates on a miss:** a single `FileMiddleware` rooted at the cache directory, with the music directory bind-mounted beneath it at `<cacheDir>/music`. `/artwork/…` and `/audio/…` become two subtrees of one root, served by one instance mounted at `/`. Every other route is registered *before* it so the catch-all sits last.
>
> Consequences to apply immediately, not later: slice 003's compose file mounts music at `<cache>/music`; slice 008 and slice 009 build their URLs against the single root; ladder **L1**'s seam is recorded as weakened, because `MIXTAPE_MUSIC_DIR` can no longer point anywhere outside `MIXTAPE_CACHE_DIR`.

## 6. Result

| | |
|---|---|
| **Answer** | |
| **Evidence** | command output, error, doc link — not "it seemed to work" |
| **Date** | |

## 7. Consequences

- [ ] Decision recorded in the decision log of: `008-album-detail-and-artwork.md` and `009-album-playback-streaming.md`
- [ ] Affected slices updated (scope, dependencies, acceptance criteria): 003, 008, 009
- [ ] Master checklist spike row set to `Answered`, with the one-line answer
- [ ] Throwaway code deleted from `/tmp/hb-spike`, or moved somewhere clearly marked as a spike artefact
- [ ] If the answer invalidated a prior decision: Architecture Drift Log updated, and ladder **L1**'s seam re-described in `003-docker-image-and-ci.md`

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
| **Answer** | **Yes, and the pass-through concern was the wrong way round.** Two `FileMiddleware` instances on two roots under two prefixes coexist in Hummingbird 2.26.0 with no interference. `FileMiddleware` **calls `next` first and only serves a file if the downstream handler threw or returned `404`** — it is a fallback, not an interceptor. So a route can never be shadowed by a file middleware, regardless of registration order, and the "every route registered after it becomes unreachable" failure this spike was written to catch is unreachable by construction |
| **Mechanism, read from the source** | `Sources/Hummingbird/Middleware/FileMiddleware.swift:168-185` (Hummingbird 2.26.0). `handle` calls `try await next(request, context)` on its **first line**; the file lookup happens only in the `catch` for an `HTTPResponseError` whose status is `.notFound`, or when `serveOnNotFoundResponse` is set and the response came back `404`. Any other thrown error is rethrown untouched. On a prefix that does not match, on a non-`GET`/`HEAD` method, or on a file that is not there, it returns `fallbackResult` — the downstream result — rather than responding itself |
| **`urlBasePath` spelling and stripping** | `FileMiddleware("<root>", urlBasePath: "/artwork")` — leading slash, **no** trailing slash (a trailing one is stripped by `dropSuffix("/")` at line 116). The prefix is removed from the request path before the root is joined: `path.dropFirst(urlBasePath.count)` at line 209. A prefix that matches only part of a folder name is rejected — after stripping, the remainder must start with `/` or be empty, otherwise the middleware passes through (lines 210-217). So the on-disk path served for `GET /artwork/artwork/a.jpg` is `<root>/artwork/a.jpg`, **not** `<root>/artwork/artwork/a.jpg` |
| **Evidence — the runtime matrix** | Throwaway executable, Hummingbird pinned `exact: "2.26.0"` to match `Server/Package.resolved`. Two middlewares added in order (`cache` under `/artwork`, `music` under `/audio`), then `router.get("/health")`. `curl` to localhost is blocked by this session's sandbox, so the probe is `http.client`; status and headers are verbatim: <br>`/artwork/artwork/a.jpg` → **200**, `Content-Length: 200000`, `Content-Type: image/jpeg`, `Accept-Ranges: bytes` <br>`/audio/Artist/Album/b.flac` → **200**, `Content-Length: 200000`, `Accept-Ranges: bytes` <br>`Range: bytes=0-99` on the same path → **206**, `Content-Range: bytes 0-99/200000`, `Content-Length: 100` <br>`/health` → **200**, body `ok` — **the pass-through proof** <br>`/audio/nope.flac` → **404** · `/artwork/nope.jpg` → **404** · `/nothing-here` → **404** <br>`/audio/../../etc/passwd` → **400** · `/audio/%2e%2e%2f%2e%2e%2fetc/passwd` → **400** |
| **One divergence from this page's expectation, and it is the safe direction** | Section 3 predicted `404` for both traversal forms. Hummingbird answers **`400 Bad Request`**, because the check is `guard !path.contains("..")` *after* percent-decoding (lines 197-201) and rejects the request outright rather than looking for a file. Both encodings are caught by the one decoded check. No file is served either way, which is what the criterion was protecting — recorded rather than treated as a failure |
| **One finding this spike was not looking for, and slice 009 needs it** | The `.flac` response carried **no `Content-Type` header at all** — Hummingbird's default media-type map has no entry for it, and the header is simply omitted. `Range` still works, so this does not change the answer, but slice 009 streams `.flac` to `AVPlayer` and an absent `Content-Type` is exactly the class of thing that behaves differently on device from in `curl`. `FileMiddleware`'s init takes a `mediaTypeFileExtensionMap` parameter, which is where an entry would go. Carried into 009 as a decision row and a verification step, not fixed here |
| **Date** | 2026-09-01 |

## 7. Consequences

- [x] Decision recorded in the decision log of: `008-album-detail-and-artwork.md` and `009-album-playback-streaming.md`
- [x] Affected slices updated (scope, dependencies, acceptance criteria): **003 needs no change** — the favourable answer is the one its volume layout already assumed, so `MIXTAPE_MUSIC_DIR` and `MIXTAPE_CACHE_DIR` stay independent and ladder **L1**'s seam is unweakened. 008 and 009 each gain a decision row; 009 also gains the `.flac` `Content-Type` finding as a verification step
- [x] Master checklist spike row set to `Answered`, with the one-line answer
- [x] Throwaway code deleted. It lived in the session scratchpad (`…/scratchpad/hb-spike`), not `/tmp/hb-spike` — the spike package, its two 200 KB random-byte fixtures and the probe script are all gone. The `Package.swift` pin, the middleware order and the probe matrix are reproduced in Section 6 above, which is the part worth keeping
- [x] If the answer invalidated a prior decision: **nothing invalidated.** No Drift Log row, and ladder **L1**'s seam in `003-docker-image-and-ci.md` is unchanged — a favourable spike confirms a decision rather than departing from one

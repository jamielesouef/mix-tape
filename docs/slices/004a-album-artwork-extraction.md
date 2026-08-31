---
slice_id: "004a"
title: Album artwork extraction
priority: P1
complexity: M
ladder: "artwork sources v1 of 2 — v1 is local sources only, which S003 measured at 13% of album directories; v2 is an external fetch (Cover Art Archive or MusicBrainz), shared seam: the album-level source-selection function"
depends_on:
  - { id: "004", type: hard, note: "needs the album grouping and album ids the scan produces" }
  - { id: "S003", type: hard, note: "answered — FLAC embedded artwork works, mp3 has none at all, and 87% of album directories have no source of any kind" }
previous_slice: "004"
next_slice: "005"
parent_slice: "004"
covers: ["4.artwork"]
created: 2026-08-31
---

# 004a — Album artwork extraction

← [previous](004-library-scan-to-manifest.md) · [Master Checklist](MASTER-CHECKLIST.md) · [next](005-server-pairing-and-owner-claim.md) →

> **Status, owner and blockers live in the master checklist, not here.** Dependencies live in this page's front matter and nowhere else. Each fact has one home; if you find yourself writing it twice, one of the two copies is going to be wrong in a fortnight.

## 1. Objective

Extract one artwork image per album into `<cacheDir>/artwork/<albumID>.jpg` during the scan, and set `AlbumDTO.hasArtwork` accordingly. Value observable on its own: after a scan, the artwork cache directory holds a correct image per album, openable in any image viewer — no endpoint and no client needed to check it.

## 2. Business Value & Priority

**This slice's premise was rewritten by S003, and the honest version is uncomfortable.** The original sentence here read "an album-centric app whose grid is a wall of grey squares has lost its entire premise". Measured against the owner's real library, the v1 grid **is** mostly grey squares: **25 of 196 album directories have an embedded picture, 171 do not**, and exactly **3** `cover.jpg`/`folder.jpg`/`front.jpg` files exist on the whole disk. mp3 is the worst case and it is absolute — **0 of 340 files carry any picture stream at all**. m4a manages 82 of 728.

So this slice serves roughly **13%** of the owner's albums, and no amount of source reordering changes that, because for mp3 there is no source to reorder. What it does serve, it serves perfectly: **FLAC is 107/107**, which is the inversion of what the plan feared and kills the contingency S003 carried for it.

That does not demote the slice — the 25 directories it covers are the only colour in the wallet, and the work is a stream copy either way. It relocates the product problem: **in v1 the wallet's visual identity rests on the no-artwork placeholder, not on artwork.** That is why blocker **B3** was re-ranked off the back of this spike, and why ladder **L11** is registered here rather than left as a vague "maybe MusicBrainz one day" — at 13% coverage, an external artwork source is the obvious v2, and it deserves a named seam now.

The reason it is a **sub-slice** rather than scope inside 004 is that it is the only part of the scan that shells out to `ffmpeg` rather than `ffprobe`, and it is the only part that writes image files. Slice 004 can produce a fully correct, inspectable manifest with `hasArtwork` computed and no image written. Splitting keeps 004's acceptance criteria about grouping — the expensive-to-get-wrong part — rather than mixing them with file-extraction failures.

The constraint that shapes everything here: **no image processing on the server.** Linux has no Core Graphics. Nothing is decoded, resized or recompressed. A stream copy, or a byte-for-byte file copy, and nothing else. The client downsamples with ImageIO in slice 008. This removes an entire dependency class from the server and makes `/artwork` a plain static-file route.

## 3. Scope

**In scope:**

- **One album-level source-selection function** — album in, chosen source out, no I/O of its own. This is ladder **L11**'s seam and the unit under test in Section 8; v2 adds an external source to its ordered list and nothing else in this slice changes
- Preferred source, embedded: the first track in the album with a stream where `disposition.attached_pic == 1`, extracted once per album with `ffmpeg -i <file> -an -c:v copy -f image2 <cacheDir>/artwork/<albumID>.jpg`. **Embedded-first stands for every container** — S003 confirmed FLAC surfaces `attached_pic` on 107/107, so the source reordering its fallback held in reserve is not needed
- Fallback source: `cover.jpg`, `folder.jpg` or `front.jpg` in the album's directory, tried in that order, **copied as-is** with no re-encode. On the owner's library this fires at most 3 times; it is kept because it costs a directory listing already in hand
- `AlbumDTO.hasArtwork` set to whether an image landed in the cache
- Artwork extraction runs inside the same bounded task group as the scan, at the same concurrency cap — it must not double the process count
- Stale artwork removal: a rescan deletes cached artwork files whose album id is no longer in the manifest, so a renamed album does not leave an orphan image forever
- `scan-report.json` gains an artwork section: albums where both sources failed, and the reason. **Plus a per-album count of the image files present in the directory under any name.** S003 counted only the three canonical names and found three files on the whole disk; nobody has counted differently-named images, and that is the difference between "this library genuinely has no artwork" and "the artwork is there under a name we did not look for". A report field answers it from the first real scan — cheaper than a second spike, and it is the same move that made `scan-report.json` permanent scope in the first place

**Out of scope** (name the slice it is deferred to):

- `GET /artwork/{albumID}` and its `FileMiddleware` mount → **008**
- Client-side downsampling, caching and display → **008**
- The no-artwork placeholder design → **008**, and it is gated on blocker **B3**
- Resizing, thumbnailing or format conversion on the server → out of scope permanently; this is the no-Core-Graphics constraint, not a deferral
- Fetching artwork from MusicBrainz or Cover Art Archive → out of scope for v1

**Plan requirements covered:**

- `4.artwork` — embedded-first with the directory-file fallback, stream copy only, never a re-encode. Two additions the plan does not name, both recorded in Section 6: stale-artwork removal on rescan, and the artwork section of `scan-report.json`.

## 4. Pre-Flight Validation

Complete **before the first line of code**, not at close.

For **each id in `depends_on`**, in order — do not summarise, walk the list:

- [ ] **004** — opened. Its decision log still says album ids are tag-derived and computed the way this slice's filenames assume. If 004 forked on id derivation, every cached filename here changes.
- [ ] **004** — confirm fork **F1** landed: `revision` includes `hasArtwork`. If it did not, this slice's output is invisible to any client, because the `ETag` will not change when artwork appears. That would make **F1** a blocker on this slice rather than a nicety.
- [ ] **S003** — spike, question 4. **Answered on 2026-08-31; the fallback was not taken and its FLAC branch is dead.** Three facts to carry into the code rather than re-derive:
  - **FLAC 107/107 surface `attached_pic`, codec mjpeg.** Embedded-first for every container, exactly as the plan says. Do not implement the per-container source reordering S003 held in reserve.
  - **mp3 0/340 have any picture stream at all**, and m4a only 82/728. Expect the extraction path to be skipped far more often than it runs — a low artwork count is the correct result here, not a bug to chase.
  - **171 of 196 album directories have no source of any kind.** Confirm blocker **B3**'s re-ranked row before assuming the placeholder is somebody else's problem: it is the state 87% of tiles will be in.
- [ ] Confirm `ffmpeg` (not just `ffprobe`) is present in the runtime image and discoverable from a `Process`. Slice 003's runtime stage installs the `ffmpeg` package, which supplies both — verify rather than assume.
- [ ] Architecture standards doc re-read: `docs/plan/v1-architecture.md` section 4, Artwork.

**Drift found:** `none` — or what changed, plus a row in the checklist's Drift Log.

## 5. Acceptance Criteria

- [ ] An album whose first track carries embedded artwork produces `<cacheDir>/artwork/<albumID>.jpg`, and that file opens as an image.
- [ ] The extracted bytes are **identical** to the embedded stream. Verified by comparing the extracted file against the stream dumped by a separate `ffmpeg` invocation — a re-encode would silently pass a "the file is an image" check, so check the bytes.
- [ ] An album with no embedded artwork but a `cover.jpg` in its directory produces a byte-identical copy of that `cover.jpg`. `cmp` returns equal.
- [ ] Source precedence is `cover.jpg`, then `folder.jpg`, then `front.jpg`. An album with all three gets `cover.jpg`.
- [ ] An album with neither source sets `hasArtwork == false`, writes no file, and appears in `scan-report.json` **with the count of image files present in its directory under any name**.
- [ ] **A `.flac` album produces artwork from its embedded picture.** S003 measured 107/107 coverage, so a FLAC album failing to yield artwork is a defect in this slice and not a property of the library. Run against the real FLAC sample S003 captured.
- [ ] **An `.mp3` album with no directory image sets `hasArtwork == false` and completes without an error.** Zero of 340 mp3s in the owner's library carry a picture stream, so this is the common path, not the exception, and it must not log at error level or it will drown the report.
- [ ] Scanning the owner's library shape — roughly 13% of albums with a source — completes with `hasArtwork` true on those and false on the rest, and **no album claims artwork it does not have**. A low true count is a pass.
- [ ] `hasArtwork` in `library.json` matches the presence of the file on disk for every album. No album claims artwork it does not have — this is what slice 008 relies on to avoid a request that always 404s.
- [ ] A rescan after renaming an album directory removes the artwork file for the vanished album id. The cache does not grow monotonically.
- [ ] A file whose embedded picture is malformed enough to make `ffmpeg` fail is skipped, logged and reported. **The scan completes.**
- [ ] Artwork extraction does not raise the peak process count above the scan's concurrency cap.
- [ ] No image library, no Core Graphics, no ImageMagick is added to the server package or the runtime image. `Server/Package.swift` still declares only Hummingbird and JWTKit.

## 6. Decision Log

**Write the row before you implement the decision, not after.** This is the whole mechanism. A decision log filled in at close is reconstructed from memory, and the rejected alternatives — the part the next slice's pre-flight actually needs — are exactly what memory loses first.

| Date | Decision | Alternatives rejected | Why |
|---|---|---|---|
| 2026-08-31 | Stream copy or byte copy only; never a decode, resize or re-encode | Server-side thumbnailing; generating multiple sizes; converting everything to JPEG | Linux has no Core Graphics, and adding an image library pulls in a dependency class the handoff explicitly removes. The client downsamples with ImageIO in slice 008. It also keeps `/artwork` a plain static-file route, which is what lets `FileMiddleware` serve it |
| 2026-08-31 | Cached artwork is always written as `.jpg` regardless of the embedded picture's real format | Preserve the source extension; sniff and name accordingly | `/artwork/{albumID}` derives its path from the id alone, so a variable extension means a directory lookup per request. The extension is a filename, not a content type; slice 008's route sets `Content-Type` from a sniff of the leading bytes if it matters. Recorded because it looks wrong and will otherwise be "fixed" |
| 2026-08-31 | Stale artwork is removed on rescan — an addition to the plan | Leave orphans; a separate cleanup command; never clean | The cache is on a NAS and grows every time an album is retagged or renamed. Deleting files whose album id is absent from the new manifest is a set difference computed while the manifest is already in hand. Doing it later means writing a second scan |
| 2026-08-31 | Artwork extraction shares the scan's task group and concurrency cap | A second, separate pass; unbounded extraction | The cap exists because each unit is a process. A second unbounded pass doubles the process count on a NAS with a weak CPU, which is exactly the hardware this runs on |
| 2026-08-31 | **Embedded-first for every container, unchanged. S003's per-container reordering fallback is not implemented** | Directory files first for `.flac`, embedded first for everything else — the fallback this slice's pre-flight held in reserve | **S003 question 4 came back the opposite way to the plan's fear: FLAC is 107/107 with `attached_pic`, codec mjpeg.** The reordering existed only for a FLAC failure that does not occur. Recorded rather than silently dropped, because the pre-flight instructed a branch and the next reader needs to know which branch was taken and why |
| 2026-08-31 | **Ladder L11 — v1 uses local artwork sources only, at a measured 13% of album directories. The seam is the album-level source-selection function** | Ship local-only with no seam and no recorded v2; add an external fetch in v1; treat 87% coverage-free as acceptable without saying so | The handoff puts MusicBrainz and Cover Art Archive out of scope for v1, and that stands — an external fetch means a network dependency, a rate limit, a cache and a licence question, none of which belong in the first shippable server. But **S003 turned "local only" from a scoping preference into a measured 13% ceiling**, and a ceiling that low needs its escape route named now rather than rediscovered. The seam is the function that picks an album's source: v2 appends an external source to its ordered list, and the extraction, caching, `hasArtwork` and stale-removal paths are untouched because they already take bytes from wherever the selection points |
| 2026-08-31 | **The report records how many image files each artwork-less directory holds under any name** | Widen the fallback to "any single image file in the directory"; run a second spike to count them; do nothing | S003 counted only `cover.jpg`, `folder.jpg` and `front.jpg` and found three on the entire disk — but it never counted images under other names, so "this library has no artwork" and "the artwork is named something else" are still indistinguishable. Widening the fallback now would be guessing at a rule with a real failure mode: an "any single image" rule happily picks up a band photo or a scanned receipt and shows it as the album cover. Counting first costs a directory listing that is already in hand and answers the question from the first real scan |

## 7. Sub-Slices

This *is* a sub-slice of [004](004-library-scan-to-manifest.md). Not split further.

## 8. Testing Strategy

- **Unit:** source selection — given a fixture album's ffprobe JSON and a fixture directory listing, which source is chosen? Covers embedded-present, embedded-absent-with-`cover.jpg`, all-three-directory-files, and neither. This is pure logic, needs no `ffmpeg`, and is **ladder L11's seam**, so keep it a function that takes an album and returns a source rather than one that also does the extraction.
- **Unit:** the FLAC case against the real sample S003 captured — embedded `attached_pic`, codec mjpeg — rather than a synthetic one. The plan predicted this would fail and it does not; a fixture from real data is what stops that prediction being reintroduced.
- **Integration:** extraction against a tiny real fixture album with a real embedded picture, asserting byte equality with a separately dumped stream. This is the only test that catches a re-encode, and a re-encode is the failure that would otherwise ship unnoticed.
- **Integration:** rescan-after-rename, asserting the orphan artwork file is gone.
- **Test targets required:** `Server/Tests/ServerTests/`, created by slice 001. Swift Testing, tagged `.repository`. The fixture album with embedded artwork is committed to the repository — keep it a few kilobytes.

## 9. Keeping this document true

This slice is done when the page describes what was actually built — not when the code works. The discipline is **ordering**: the write happens *before* the thing it describes, so it sits on the critical path instead of after it, where it gets skipped.

| Before you… | Write this first |
|---|---|
| implement a decision | the Section 6 row, including what you rejected |
| start work | flip status in the master checklist |
| stop on a blocker | the Active Blockers row |
| build on a spike | that spike's Result section |
| widen scope | Section 3, and `depends_on` on any slice that is now affected |

And in the same commit as the code, not a follow-up: **commit this file alongside it**, with the slice id in the commit subject (`004a: add artwork extraction`).

Nothing checks any of this. That is the point of putting the writes first — a write you have to do to proceed is one you do; a write you are supposed to do afterwards is one you do not.

## 10. Definition of Done

- [ ] Acceptance criteria met
- [ ] Tests passing, in a target that exists
- [ ] Every `covers:` requirement satisfied, or forked with a decision row
- [ ] Decision log written as you went, not reconstructed
- [ ] Pre-flight completed and drift resolved
- [ ] Master checklist row current
- [ ] `next_slice`'s `depends_on` reflects what actually shipped, not what was planned
- [ ] Both link directions checked: this page's `next_slice` and `005`'s `previous_slice`

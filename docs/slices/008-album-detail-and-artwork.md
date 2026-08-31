---
slice_id: "008"
title: Album detail and artwork, end to end
priority: P0
complexity: M
ladder: "artwork caching v1 of 2 — v2 is a disk-backed downsampled cache, shared seam: the ArtworkLoaderProtocol in AppInfrastructure"
depends_on:
  - { id: "007", type: hard, note: "needs the grid and the cache models to hang artwork and detail off" }
  - { id: "004a", type: hard, note: "needs artwork actually extracted into the cache directory" }
  - { id: "S001", type: hard, note: "decides whether /artwork can be its own FileMiddleware root" }
previous_slice: "007"
next_slice: "009"
parent_slice: none
covers: ["3.artwork"]
created: 2026-08-31
---

# 008 — Album detail and artwork, end to end

← [previous](007-album-grid-from-cache.md) · [Master Checklist](MASTER-CHECKLIST.md) · [next](009-album-playback-streaming.md) →

> **Status, owner and blockers live in the master checklist, not here.** Dependencies live in this page's front matter and nowhere else. Each fact has one home; if you find yourself writing it twice, one of the two copies is going to be wrong in a fortnight.

## 1. Objective

Serve `GET /artwork/{albumID}` and consume it: real album covers in the grid, and an album detail screen listing the tracks. Value observable on its own: the wallet stops being grey squares and starts being your record collection.

## 2. Business Value & Priority

Mix Tape's entire premise is the nostalgia of pulling an album out of a CD wallet. Without covers there is no wallet — the grid is a list of text in a box shape, and the concept the whole product is organised around is not present. This is the slice where the design idea either lands or does not.

It is also the first place the plan's **no-image-processing-on-the-server** decision pays off. The server hands over original bytes with a long-lived immutable cache header and does no work at all; the client downsamples with ImageIO. That is what keeps Core Graphics — and an entire dependency class — off the Linux side.

The cache header is doing real work: **`Cache-Control: max-age=31536000, immutable`** is safe precisely because the artwork URL is derived from the album id, and the album id is derived from the tags. Retag an album and you get a different id, which is a different URL. Nothing is ever mutated in place, so nothing can be stale.

**Ladder L6 — artwork caching (this slice ships the crude rung).** v1 downsamples with ImageIO and relies on `URLCache` for the bytes. The seam is `ArtworkLoaderProtocol` in `AppInfrastructure` — one type that every artwork request goes through. v2, if the grid ever feels slow on a large library, puts a disk-backed cache of already-downsampled images behind that same protocol, and no view changes. Named seam, so this is a ladder.

## 3. Scope

**In scope:**

- `GET /artwork/{albumID}`, bearer-authed, served by `FileMiddleware` from the artwork cache directory, with `ETag` and `Cache-Control: max-age=31536000, immutable`
- `404` for an album id with no cached artwork
- `ArtworkLoaderProtocol` and its v1 implementation in `AppInfrastructure/` — fetch, downsample with ImageIO to the display size, hand back an image
- Downsampling **at decode time** with `CGImageSourceCreateThumbnailAtIndex` and `kCGImageSourceThumbnailMaxPixelSize`, never by decoding a full-size image and then resizing. A wall of 3000×3000 covers decoded at full size on a phone is a memory problem, not a performance one
- Real artwork in the album tile, using `AlbumDTO.hasArtwork` (via `CachedAlbum`) to decide whether to request at all
- The no-artwork placeholder — **the v2 rung of ladder L12**, replacing the plain tile 007 shipped as `AlbumArtworkPlaceholder`. Gated on **B3**, and **S003 makes this the most visible design work in the slice**: 171 of the owner's 196 album directories have no artwork source, so this view is what roughly 87% of the grid looks like. It is one component to swap, but it is not a small decision
- `AlbumDetailScreen` in `AppPresentation/Screens/Library/`, showing the cover, album artist, title, year, track count, total duration, and the track list with per-track title, track artist and duration
- "Disc 2 of 2" labelling from `discCount` where it is present
- Track artist shown per track, distinct from the album artist — this is where the split becomes visible to a user, on a compilation

**Out of scope** (name the slice it is deferred to):

- Playing anything. Tapping a track does nothing yet → **009**
- The download button → **010**
- A full-screen artwork viewer, or zoom → out of scope for v1
- Server-side thumbnails or multiple sizes → out of scope permanently; the no-Core-Graphics constraint
- Fetching missing artwork from an external service → out of scope for v1

**Plan requirements covered:**

- `3.artwork` — `GET /artwork/{albumID}`, bearer, original embedded image bytes, `ETag`, `Cache-Control: max-age=31536000, immutable`, served by `FileMiddleware`.

**Verification note carried into implementation:** the ImageIO downsampling approach and the exact `CGImageSourceCreateThumbnailAtIndex` option keys were **not re-verified against Apple's documentation during planning, because the documentation tool was not available in that session.** Check them against `apple-docs` before implementing. Getting the option keys subtly wrong produces working code that quietly decodes at full size — the failure is invisible until a device runs out of memory.

## 4. Pre-Flight Validation

Complete **before the first line of code**, not at close.

For **each id in `depends_on`**, in order — do not summarise, walk the list:

- [ ] **007** — opened. Its decision log still says the grid reads through `@Query` and `CachedAlbum` carries `hasArtwork`. Confirm **B3** (the placeholder) is answered; the grid currently ships 007's plain `AlbumArtworkPlaceholder`, which is ladder **L12**'s seam and the one view this slice replaces. **007 is allowed to be Done with B3 still open — this slice is not.**
- [ ] **004a** — opened. Its decision log still says artwork is written to `<cacheDir>/artwork/<albumID>.jpg`, always with a `.jpg` name regardless of the real format. **This route must therefore not infer `Content-Type` from the extension** — 004a recorded that explicitly, and this is the slice it was recorded for.
- [ ] **004a** — the S003 question-4 outcome is **answered, and it is not the outcome this bullet used to anticipate**. FLAC embedded artwork works perfectly (107/107), so no source reordering was taken — but coverage is far lower than assumed anyway, for a different reason: mp3 carries no embedded picture at all (0 of 340), m4a manages 82 of 728, and **171 of 196 album directories have no artwork source of any kind**. Two consequences to carry in: **B3**'s placeholder is the dominant visual of the grid rather than an edge case, and the `hasArtwork` gate below is doing far more work than it looks like it is.
- [ ] **S001** — spike. It is answered, and **the answer, not the hoped-for answer**, is what this route is built on. Note whether the fallback was taken.
  - Favourable: `FileMiddleware` rooted at the artwork cache directory, mounted at `/artwork`.
  - **Fallback taken:** a single `FileMiddleware` at the cache root serving both subtrees. This route's URL construction changes, and so does slice 009's. Record it as a decision row here.
  - Take the exact `urlBasePath` spelling and base-path-stripping behaviour S001 recorded. That detail is why the spike was asked to record it.
- [ ] Confirm **fork F1** from slice 004 landed, so a newly appearing cover changes the `revision` and reaches the client at all.
- [ ] Re-read the Apple documentation for the ImageIO downsampling keys named in Section 3.
- [ ] Architecture standards doc re-read: `docs/plan/v1-architecture.md` sections 3 and 4.

**Drift found:** `none` — or what changed, plus a row in the checklist's Drift Log.

## 5. Acceptance Criteria

- [ ] `GET /artwork/{albumID}` with a valid token returns the image bytes, **byte-identical** to the file in the cache directory.
- [ ] Without a token it returns `401`. With a token but an unknown album id, `404`.
- [ ] The response carries `ETag` and `Cache-Control: max-age=31536000, immutable`.
- [ ] A conditional request with `If-None-Match` returns `304`.
- [ ] `Content-Type` is correct for a PNG stored under a `.jpg` filename. This is the concrete case 004a's naming decision creates, and it must be checked with a real PNG-in-`.jpg` fixture.
- [ ] **A path-traversal attempt on `/artwork` returns `404` and never a file.** Test `../`, the percent-encoded `%2e%2e%2f` form, and a doubly-encoded form.
- [ ] The grid shows real covers for albums with artwork.
- [ ] The grid shows the agreed placeholder for albums without, and requests nothing for them — verified by watching for network requests, not by looking at the screen.
- [ ] Scrolling a 2000-album grid stays smooth, and memory stays flat. **Profile it.** A grid that decodes full-size covers scrolls acceptably for the first hundred and then does not.
- [ ] A cover that is genuinely 3000×3000 does not spike memory. Include one in the fixture library deliberately.
- [ ] `AlbumDetailScreen` shows cover, album artist, title, year, track count and total duration, and lists every track with its own title, track artist and duration.
- [ ] **On a compilation, the album artist reads "Various Artists" while each track shows its own artist.** This is the album-artist/track-artist split made visible, and it is the acceptance criterion that proves the schema decision was worth it.
- [ ] A multi-disc album shows its disc label where `discCount` is present.
- [ ] Both screens have `#Preview`s covering their states, **including nil artwork, empty track list and a failed image load**.
- [ ] Runs on iOS, iPadOS and macOS.

## 6. Decision Log

**Write the row before you implement the decision, not after.** This is the whole mechanism. A decision log filled in at close is reconstructed from memory, and the rejected alternatives — the part the next slice's pre-flight actually needs — are exactly what memory loses first.

| Date | Decision | Alternatives rejected | Why |
|---|---|---|---|
| 2026-08-31 | Downsample at decode time with `CGImageSourceCreateThumbnailAtIndex` | `Image(uiImage:)` with a `.resizable()` modifier; decode then resize; `AsyncImage` alone | SwiftUI's resizing happens after a full-size decode. A grid of 3000×3000 covers is hundreds of megabytes of decoded bitmap. Downsampling at decode time never materialises the full image. This is the whole reason the server is allowed to do no image work |
| 2026-08-31 | `Cache-Control: max-age=31536000, immutable` on artwork | A short max-age; `no-cache` with `ETag` revalidation | Safe **because** the URL derives from the album id, which derives from the tags. Retagging changes the id, so it changes the URL. Nothing is mutated in place, so nothing can go stale. Recorded because a year-long immutable cache looks reckless without that reasoning |
| 2026-08-31 | `hasArtwork` gates the request; the client never requests artwork it has been told is absent | Always request and treat `404` as the placeholder signal | **S003 has since measured it, and this decision is worth more than it looked**: 171 of 196 album directories have no artwork, so the always-request approach would `404` on roughly 87% of tiles — hundreds of pointless round trips on every grid scroll, against a NAS. `hasArtwork` is already in the DTO for exactly this |
| 2026-08-31 | `ArtworkLoaderProtocol` exists from the start (ladder **L6**) | Call `URLSession` from the view; add the protocol when a cache is needed | The seam has to exist before v2 can use it, and it is one protocol with two conformers on day one — the real loader and the preview mock. Satisfies plan conflict **C3** the same way the repository protocols do |
| 2026-08-31 | `Content-Type` is determined by sniffing the leading bytes, not by the `.jpg` extension | Trust the extension; store the real extension | 004a always names the cached file `.jpg` so the route can derive the path from the id alone. That decision moves the content-type problem here, which is where it was always going to be cheapest to solve |
| | **S001 outcome.** Row to be written when the spike lands, recording whether the fallback was taken and what it changed | | |
| | **B3 — no-artwork placeholder.** Row to be written when the owner answers | | |

## 7. Sub-Slices

Not split — delivered as a single slice. Artwork and the detail screen both hang off the same fetch-and-render path, and a detail screen with no cover is not a shippable increment of a CD-wallet app.

## 8. Testing Strategy

- **Integration (server):** the artwork route — happy path with byte equality, `401`, `404`, `304`, and the three path-traversal forms. The traversal tests are the ones that matter; the others would be noticed immediately in use.
- **Integration (server):** `Content-Type` sniffing, against a PNG fixture stored with a `.jpg` name.
- **Unit (app):** the downsampler, asserting the returned image's **pixel dimensions** match the requested maximum. This is the only test that catches the failure where the option keys are wrong and the full image is decoded anyway — asserting "an image came back" would pass.
- **Unit (app):** `hasArtwork == false` results in **no** request. Against a mock loader that records calls.
- **UI:** one XCUITest navigating grid to detail and asserting the track count, driven off accessibility identifiers.
- **Manual, and required:** an Instruments memory profile of a scroll through a large grid including at least one 3000×3000 cover. Recorded in the commit. A memory claim nobody measured is a memory claim that is wrong.
- **Test targets required:** `Server/Tests/ServerTests/`, `App/Tests/MixTapeTests/`, `App/Tests/MixTapeUITests/` — all created by slice 001.

## 9. Keeping this document true

This slice is done when the page describes what was actually built — not when the code works. The discipline is **ordering**: the write happens *before* the thing it describes, so it sits on the critical path instead of after it, where it gets skipped.

| Before you… | Write this first |
|---|---|
| implement a decision | the Section 6 row, including what you rejected |
| start work | flip status in the master checklist |
| stop on a blocker | the Active Blockers row |
| build on a spike | that spike's Result section |
| widen scope | Section 3, and `depends_on` on any slice that is now affected |

And in the same commit as the code, not a follow-up: **commit this file alongside it**, with the slice id in the commit subject (`008: add artwork and album detail`).

Nothing checks any of this. That is the point of putting the writes first — a write you have to do to proceed is one you do; a write you are supposed to do afterwards is one you do not.

## 10. Definition of Done

- [ ] Acceptance criteria met
- [ ] Tests passing, in a target that exists
- [ ] Every `covers:` requirement satisfied, or forked with a decision row
- [ ] Decision log written as you went, not reconstructed, **including the S001 outcome row**
- [ ] Pre-flight completed and drift resolved, **including the Apple-documentation check named in Section 3**
- [ ] Master checklist row current, and **B3 closed**
- [ ] `next_slice`'s `depends_on` reflects what actually shipped, not what was planned
- [ ] Both link directions checked: this page's `next_slice` and `009`'s `previous_slice`

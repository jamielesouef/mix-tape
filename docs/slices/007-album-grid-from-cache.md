---
slice_id: "007"
title: The album grid, backed by the SwiftData cache
priority: P0
complexity: L
ladder: "release grouping v1 of 2 — v2 is a server-supplied releaseID on AlbumDTO, shared seam: ReleaseGrouper and ReleaseKey in AppDomain; and no-artwork placeholder v1 of 2 — v2 is the design B3 resolves to, landing in 008, shared seam: AlbumArtworkPlaceholder"
depends_on:
  - { id: "006", type: hard, note: "needs GET /library and its ETag" }
  - { id: "005a", type: hard, note: "needs a stored token to authenticate the fetch" }
  - { id: "004", type: hard, note: "needs fork F6's title stripping and discCount reconciliation, or discs will not group" }
previous_slice: "006"
next_slice: "008"
parent_slice: none
covers: ["2.cache", "2.replacement", "2.modelActor", "OA1.releaseGrouping", "OA2.discSetType"]
created: 2026-08-31
---

# 007 — The album grid, backed by the SwiftData cache

← [previous](006-library-manifest-endpoint.md) · [Master Checklist](MASTER-CHECKLIST.md) · [next](008-album-detail-and-artwork.md) →

> **Status, owner and blockers live in the master checklist, not here.** Dependencies live in this page's front matter and nowhere else. Each fact has one home; if you find yourself writing it twice, one of the two copies is going to be wrong in a fortnight.

## 1. Objective

Fetch the manifest, import it into SwiftData through a `ModelActor`, and render the album grid from `@Query`. Value observable on its own: open the app and see your CD wallet — every album, in a grid, from a local store that survives a relaunch with no network.

## 2. Business Value & Priority

This is the product becoming visible. Everything before it is infrastructure with a `curl` transcript for evidence; this is the first slice a user would recognise as Mix Tape.

It also lays the SwiftData schema, and the schema is the thing with a migration cost attached. **Both model groups are defined here — including the `Downloaded*` models, which nothing in this slice uses.** That looks wrong and is deliberate: defining them now means slice 010 adds behaviour rather than a schema, and the absence of a relationship between the two groups — the boundary the whole download design rests on — is established before anything can accidentally add one. A relationship added in slice 010 to a schema shipped in slice 007 is a migration.

The rule the schema encodes: **library data is a cache, downloads are local truth.** A changed manifest replaces the cache wholesale, with no incremental sync logic anywhere. That is only safe because no SwiftData relationship crosses between the groups, so no cascade delete can reach a download. If a rescan on the NAS wiped downloaded albums off the phone, the app would feel broken — and it would be a data-loss bug, not a display bug.

**Ladder L10 — release grouping (this slice ships the crude rung).** Resolving **B1** the owner chose one tile per disc, with two conditions: discs of one release must always sit adjacent, and the disc-set shape must be a **type**, not something inferred at render time. Both are satisfied entirely in the app, with **no DTO change and no server change**, because `(albumArtist, title)` and `discCount` are already in `AlbumDTO`. The seam is `ReleaseGrouper` plus `ReleaseKey` — one derivation point. If grouping ever needs to come from the server, v2 adds a `releaseID` to `AlbumDTO` and `ReleaseGrouper` reads it instead of computing it; no view and no cache model changes. Named seam, so this is a ladder.

The adjacency guarantee is deliberately **structural, not a sort rule**. The grid iterates `[Release]`, and a release owns its discs. It is therefore impossible for an unrelated album to land between disc 1 and disc 2 — not merely unlikely under the default ordering, but unrepresentable. A sort-based guarantee would silently break the first time anyone added a sort control.

## 3. Scope

**In scope:**

- `CachedAlbum` and `CachedTrack`, with the cascade relationship between them, exactly as the plan's section 2 specifies
- `DownloadedAlbum` and `DownloadedTrack` **defined but unused**, with **no relationship of any kind to the cache models**
- One `ModelContainer` at `App/AppData/Persistence/`, holding both schema groups
- `@ModelActor actor LibraryImporter` at `App/AppData/Persistence/LibraryImporter.swift`. Note `final` is not written — actors cannot be declared `final`
- `replaceLibrary(with:)` doing exactly four things: delete all `CachedTrack`, delete all `CachedAlbum`, insert from the manifest, save. It never names a `Downloaded*` type
- `FetchLibraryUseCase` and `LibraryRepositoryProtocol` in `AppUseCase/`
- `LibraryRepository` in `AppData/` — a stateless `Sendable` struct over `APIClient`
- `LibraryService` — `@MainActor @Observable final class`, holding sync state (`idle`, `syncing`, `failed(String)`) and the current `revision` **only**. It does not mirror the library in memory
- Storing the last-seen `revision` and sending it as `If-None-Match`; a `304` means do nothing at all
- **`ReleaseKey`** in `AppDomain/` — a `Hashable, Sendable` value type of `albumArtist` and `title`, both normalised with the **same** rules the server's grouping key uses: trimmed, internal whitespace collapsed, casefolded for comparison
- **`DiscSet`** in `AppDomain/` — the disc-set type the owner asked for. `case single` and `case multiDisc(discsPresent: Int, discsExpected: Int?)`. `discsExpected` is the reconciled `discCount` where the tags supply it and `nil` where they do not, so the type answers three questions at once: is this a set, is the set complete, and what does the "of N" label say
- **`Release`** in `AppDomain/` — `id: ReleaseKey`, `discSet: DiscSet`, and `albums: [Album]` ordered by `discNumber`. This is what the grid iterates
- **`ReleaseGrouper`** in `AppDomain/` — the single derivation point from `[Album]` to `[Release]`, and ladder **L10**'s seam
- **Release ordering** — the default, and the only, order: `albumArtist` then `year` ascending with unknown years last, then `title`, with `ReleaseKey` as the final tiebreak. Applied to `[Release]`, not to `[Album]`. Discs within a release are ordered by `discNumber`. This is **B2**'s resolution and it lives in exactly one place, the sort over `ReleaseGrouper`'s output
- **A release's sort year** is the **minimum non-nil `year` across its discs**, and `nil` only when every disc is `nil`. `albumArtist` and `title` are equal across a release by construction — they are the key — but `year` is not: disc 1 tagged `1979` and disc 2 tagged `1980`, or disc 2 untagged, is ordinary ripper output. Without this rule the comparator sorts on a field `Release` does not have, and the choice gets made silently at the keyboard
- `AlbumGridScreen` in `AppPresentation/Screens/Library/`, reading through `@Query` and rendering `[Release]`
- An album tile component in `AppPresentation/Components/Cards/`, rendering one disc, with the disc label supplied by its `Release`'s `DiscSet`
- **`AlbumArtworkPlaceholder`** in `AppPresentation/Components/`, and ladder **L12**'s seam — the crude rung is a plain neutral tile carrying the album title, and 008 replaces this one view with whatever **B3** resolves to. It is a named component rather than an inline `Rectangle` in the tile precisely because S003 measured it as the state of roughly 87% of tiles; the thing the grid mostly is deserves its own file
- Pull-to-refresh calling `POST /library/rescan`, then re-fetching
- Empty, syncing and failed states on the grid

**Out of scope** (name the slice it is deferred to):

- Artwork display — tiles show the placeholder until **008** lands
- `AlbumDetailScreen` → **008**
- Playback → **009**; downloads → **010**
- Search, filtering or a sort control → out of scope for v1. The plan is explicit: exactly one default ordering and no control
- Incremental or partial sync → does not exist by design

**Plan requirements covered:**

- `2.cache` — `CachedAlbum` and `CachedTrack` as specified.
- `2.replacement` — `replaceLibrary(with:)`'s four steps, and the proof that downloads survive it.
- `2.modelActor` — `LibraryImporter`, at the specified path, with `LibraryManifestDTO` crossing the boundary as the `Sendable` type and **no `@Model` object ever crossing one**.
- `2.downloads` is **not** claimed here even though the models are defined — the models without their lifecycle are not the requirement. Slice 010 covers it.

**Owner decisions.** **B1** and **B2** are both resolved — their decision rows are in Section 6 and their resolutions are in the checklist. **B3**, the no-artwork placeholder, is the only one still open, and **S003 promoted it from a detail to the thing the grid mostly looks like**: 171 of the owner's 196 album directories have no artwork source of any kind, so roughly **87% of tiles show the placeholder**. It is still not a blocker, because ladder **L12** puts the crude rung behind a seam — this slice ships `AlbumArtworkPlaceholder` as a plain neutral tile and **008** swaps that one view for the agreed design. But it is no longer true that this "changes how a tile looks and nothing else"; at 87% it is the wallet's visual identity in v1.

**Verification note carried into implementation:** the plan asserts SwiftData behaviours this slice depends on — that `try context.delete(model:)` inside a `@ModelActor` deletes by type without loading objects, and that `@Query` in a view observes writes made on that actor. **These were not re-verified against Apple's documentation during planning, because the documentation tool was not available in that session.** Check both against `apple-docs` before implementing, and log any correction as a decision row plus a Drift Log entry.

## 4. Pre-Flight Validation

Complete **before the first line of code**, not at close.

For **each id in `depends_on`**, in order — do not summarise, walk the list:

- [ ] **006** — opened. Its decision log still says `GET /library` returns the manifest with `ETag: <revision>` and `304` on a match, and that fork **F2** returns `503` `scanInProgress` on a first boot. The grid must handle that `503` as "your server is still scanning", not as a failure — check the fork landed as written.
- [ ] **005a** — opened. Its decision log still says the token is in the Keychain and `APIClient` attaches it per request. Confirm the server base URL is readable from wherever 005a put it.
- [ ] **004** — opened. Confirm all three grouping decisions it records still stand: **B1** resolved to one tile per disc, so the album key `(albumArtist, title, discNumber)` is unchanged and the cache schema mirrors the DTO shape; fork **F6** strips a trailing disc marker from the title into `discNumber`; `discCount` is reconciled to the maximum across a release. `ReleaseGrouper` needs all three — without **F6**, `The Wall (Disc 1)` and `The Wall (Disc 2)` produce two different `ReleaseKey`s and the discs do not group at all.
- [ ] **B1, B2 and B3 status checked.** **B1** and **B2** are resolved; confirm this slice's Section 6 rows match the checklist before writing either the models or the sort. **B3** is still open and blocks only the tile's appearance — ship the plain placeholder.
- [ ] Re-read the Apple documentation for the two SwiftData behaviours named in Section 3.
- [ ] Architecture standards doc re-read: `docs/app-architecture-template.md` on services, `@Entry` wiring and the persistence exception; `docs/plan/v1-architecture.md` section 2.

**Drift found:** `none` — or what changed, plus a row in the checklist's Drift Log.

## 5. Acceptance Criteria

- [ ] A first launch against a populated server shows every album in the grid.
- [ ] Force-quit, go offline, relaunch — **the grid still shows every album**. It is a cache, and this is what makes it one.
- [ ] A second launch with an unchanged library sends `If-None-Match`, receives `304`, and performs **no** SwiftData write. Verified by observing the store's modification time, not by a log line.
- [ ] Adding an album on the server, rescanning, then refreshing shows the new album.
- [ ] Removing an album on the server and rescanning removes it from the grid.
- [ ] **Downloads survive a full manifest replacement.** Insert three `DownloadedAlbum` rows by hand in a test, run `replaceLibrary(with:)` with a manifest containing none of them, and assert all three rows and their tracks are still present. **This is the single most important test in the slice** — the plan's claim that no cascade can reach a download is an argument, and this turns it into evidence.
- [ ] `replaceLibrary(with:)` contains no reference to any `Downloaded*` type. Verified by grep, and the grep is recorded.
- [ ] No `@Model` type appears in any signature crossing an isolation boundary. `LibraryManifestDTO` goes in; nothing comes out.
- [ ] Importing a 2000-album manifest completes without blocking the main thread — the grid stays scrollable throughout. Timed and recorded.
- [ ] The grid shows a distinguishable state for each of: syncing on first run, empty library, fetch failed, and server-still-scanning (`503`).
- [ ] **The discs of a release are adjacent and in `discNumber` order**, asserted against a fixture built so the default ordering would separate them if adjacency depended on the sort — a second release whose sort position falls between disc 1 and disc 2. The assertion is on the rendered `[Release]` sequence, not on a sort descriptor.
- [ ] A two-disc release renders two tiles, each labelled from its `Release`'s `DiscSet` — `.multiDisc(discsPresent: 2, discsExpected: 2)` gives "Disc 1 of 2" and "Disc 2 of 2"; with `discsExpected == nil` the label drops the "of N" rather than guessing.
- [ ] Release ordering is `albumArtist`, then `year` with unknown years last, then `title`, then `ReleaseKey`. Asserted by a unit test over a fixture containing a nil year, two releases by one artist, two artists differing only in casing and spacing, and **a two-disc release whose discs carry different years** — it sorts on the earlier one.
- [ ] `LibraryService` holds no array of albums. Grep its properties; sync state and `revision` only.
- [ ] `./scripts/check-layer-imports.sh` passes.
- [ ] No repository or use case type appears in a view's signature.
- [ ] `AlbumGridScreen` and the album tile each have a `#Preview` covering their states, **including empty, nil artwork and failure**.
- [ ] Runs on iOS, iPadOS and macOS destinations. The grid adapts; it is not a phone layout stretched.

## 6. Decision Log

**Write the row before you implement the decision, not after.** This is the whole mechanism. A decision log filled in at close is reconstructed from memory, and the rejected alternatives — the part the next slice's pre-flight actually needs — are exactly what memory loses first.

| Date | Decision | Alternatives rejected | Why |
|---|---|---|---|
| 2026-08-31 | Both model groups ship in this slice, with the `Downloaded*` models defined but unused | Define `Downloaded*` in slice 010, when they are first needed | Adding models to a shipped schema in slice 010 is a migration; defining them now is free. It also fixes the no-relationship boundary before any code exists that might add one. Deliberately violating "do not build what you do not need" because the alternative has a migration attached |
| 2026-08-31 | No SwiftData relationship between the cache group and the download group; they associate by matching `id` strings, joined in memory at read time | A relationship with a nullify delete rule; a single unified model with an `isDownloaded` flag | The absence of the relationship **is** the boundary. A nullify rule still couples the graphs and relies on getting a rule right; a unified model makes a manifest replacement destroy downloads by construction. The cost is an in-memory join at read time, which for a personal library is nothing |
| 2026-08-31 | `DownloadedAlbum` carries a self-sufficient copy of every field it needs to render and play | Read the fields from `CachedAlbum` by id | A downloaded album must stay fully usable after a rescan removes it from the manifest. If it read from the cache, a rescan would leave a playable album with no title. Duplication is the correct answer here and is recorded so it is not normalised away later |
| 2026-08-31 | `LibraryService` holds sync state and `revision` only; views read the store through `@Query` | Service holds `[Album]` and views read the service | Mirroring the library in memory means two sources of truth and a 2000-element array on the main actor. `@Query` observes the store directly. This is the template's MV pattern working as intended |
| 2026-08-31 | `APIClient` is the actor, `LibraryRepository` is a stateless struct, `LibraryService` holds no private actor (plan conflict **C2**) | The handoff's "`LibraryService` with a `private actor` fetcher" | The template puts networking in `AppInfrastructure` and `AppData`. The handoff's intent — network work off the main actor behind an actor boundary — is fully preserved. Resolved in the plan; recorded so Phase 3 does not raise it |
| 2026-08-31 | **B1 resolved — one tile per disc, discs always adjacent, and the disc-set shape carried as a type.** `ReleaseKey`, `DiscSet`, `Release` and `ReleaseGrouper` land in `AppDomain`; the grid iterates `[Release]` and a release owns its discs (ladder **L10**) | Group discs under one album and key tracks on `(discNumber, trackNumber)`; one tile per disc with adjacency guaranteed by a sort rule; infer the disc-set shape at render time from `discCount` | **The project owner's call**, verbatim: *"1, but they must always be grouped. They should be a separate type, eg single disc, double disc type"*. Grouping discs under one album is a schema change and a migration. A sort-based adjacency guarantee holds only while the sort holds and breaks silently the first time a sort control is added; iterating `[Release]` makes an unrelated album between disc 1 and disc 2 **unrepresentable**, not merely unlikely. Inferring the shape at render time spreads the same `if discCount > 1` across every view, so `DiscSet` gives it one home. **No DTO and no server change** — `(albumArtist, title)` and `discCount` are already in `AlbumDTO`, the latter reconciled across a release by slice 004 |
| 2026-08-31 | **B2 resolved — releases are ordered by `albumArtist`, then `year` ascending with unknown years last, then `title`, with `ReleaseKey` as the final tiebreak.** A release's sort year is the **minimum non-nil `year` across its discs**, `nil` only when every disc is `nil`. Discs inside a release stay ordered by `discNumber` | Album artist then title; recently added; the first disc's year as the release year; putting the choice back to the owner | Ordering now applies to **releases**, not albums, so no ordering can separate the discs of a release — B1's adjacency guarantee is structural and survives any sort. "Recently added" is eliminated on fact rather than taste: `AlbumDTO` carries no added-at field, so it needs a DTO change and a cache-schema change, which puts it beyond v1. Between the two survivors, artist-then-year is the shelf a collector actually builds and matches the CD-wallet metaphor in the handoff; title order splits a discography by first letter. `albumArtist` is compared with the **same** normalisation `ReleaseKey` uses — trimmed, whitespace-collapsed, casefolded — so grouping and ordering cannot disagree about who an artist is. The `ReleaseKey` tiebreak makes the order total, so the grid does not reshuffle between launches. Minimum-non-nil is the year rule because the discs of one release routinely disagree — taking disc 1's year makes the order depend on which disc happened to be tagged. **Not laddered:** with recently-added removed there is no crude rung and a better one, only two equivalents behind the same sort descriptor — changing it later is one line and no migration |
| 2026-08-31 | **B3 does not block this slice. It ships `AlbumArtworkPlaceholder` as a plain neutral tile behind ladder L12, and B3's own decision row is written in 008, where the swap happens** | Wait for B3 before building the grid; inline the placeholder as a `Rectangle` in the tile; write B3's decision row here as well as in 008 | **S003 changed the stakes without changing the blocking**: 171 of 196 album directories have no artwork source, so the placeholder is what roughly 87% of tiles look like, and that is a real design decision the owner should make properly rather than quickly. L12 is what lets both be true — the crude rung is one named component, so the answer arriving late costs one view's body and nothing else. It is a named component rather than an inline shape precisely *because* it is 87% of the grid. The decision row lives in 008 alone because 008 owns the swap, and a row in both files is two facts that will disagree |

## 7. Sub-Slices

Not split — delivered as a single slice. It is `L`, and the tempting split is schema-then-grid, which produces a schema with nothing observing it. The vertical unit is manifest to pixels.

## 8. Testing Strategy

- **Unit:** DTO-to-model mapping in `AppData`, field by field, including the nullable ones. A field silently dropped in mapping is invisible until a user notices a missing year.
- **Unit:** `ReleaseGrouper`, in `AppDomain` and with no store involved — `[Album]` in, `[Release]` out. Cases: a single-disc album yields `.single`; two discs of one release yield one `Release` with `.multiDisc(discsPresent: 2, discsExpected: 2)`; a release missing disc 2 yields `discsPresent: 1, discsExpected: 2`; no `discCount` anywhere yields `discsExpected: nil`; and two albums whose artist or title differ only in casing or spacing group into **one** release, using the same normalisation as the server's key.
- **Unit:** the release ordering, as a table of unordered input to expected order, including a nil year and a casing-only artist difference. The disc-adjacency criterion is asserted here too, on the sequence rather than on the comparator.
- **Unit:** `LibraryService` state transitions against `StubLibraryRepository` — idle, syncing, success, `304`, failure, `503` scanning. Six states, and the `304` case must assert **no import ran**.
- **Integration:** `LibraryImporter.replaceLibrary(with:)` against an in-memory `ModelContainer`. Two cases: a replacement produces the right cache contents, and **a replacement leaves pre-inserted `Downloaded*` rows untouched**. The second is the criterion this slice exists to protect.
- **Integration:** replace twice with the same manifest; assert no duplicate rows. The `.unique` attribute is doing work here and should be shown to.
- **UI:** one XCUITest — launch with a seeded store, assert the grid shows the expected album count. Driven off accessibility identifiers, never visible text.
- **Test targets required:** `App/Tests/MixTapeTests/` and `App/Tests/MixTapeUITests/`, created by slice 001. Swift Testing tagged `.service` and `.repository`; XCTest for the XCUITest only. The `ModelContainer` under test is in-memory — never the app's real store.

## 9. Keeping this document true

This slice is done when the page describes what was actually built — not when the code works. The discipline is **ordering**: the write happens *before* the thing it describes, so it sits on the critical path instead of after it, where it gets skipped.

| Before you… | Write this first |
|---|---|
| implement a decision | the Section 6 row, including what you rejected |
| start work | flip status in the master checklist |
| stop on a blocker | the Active Blockers row |
| build on a spike | that spike's Result section |
| widen scope | Section 3, and `depends_on` on any slice that is now affected |

And in the same commit as the code, not a follow-up: **commit this file alongside it**, with the slice id in the commit subject (`007: add album grid and cache`).

Nothing checks any of this. That is the point of putting the writes first — a write you have to do to proceed is one you do; a write you are supposed to do afterwards is one you do not.

## 10. Definition of Done

- [ ] Acceptance criteria met
- [ ] Tests passing, in a target that exists
- [ ] Every `covers:` requirement satisfied, or forked with a decision row
- [ ] Decision log written as you went, not reconstructed
- [ ] Pre-flight completed and drift resolved, **including the Apple-documentation check named in Section 3**
- [ ] Master checklist row current. **B1 and B2 are already resolved** — confirm this page's decision rows match the checklist's resolutions. **B3 does not need to be closed for this slice to be done** — that is ladder **L12**'s entire purpose; confirm B3's checklist row still says so, and ship `AlbumArtworkPlaceholder`. 008 closes B3
- [ ] `next_slice`'s `depends_on` reflects what actually shipped, not what was planned
- [ ] Both link directions checked: this page's `next_slice` and `008`'s `previous_slice`

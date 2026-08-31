---
title: Master Slice Checklist
---

# Master Checklist — Mix Tape v1

**This file is the only home for status, owner and blockers.** Slice documents don't carry them. Dependencies are the reverse: they live in each slice's `depends_on` front matter and are not repeated here.

That split is deliberate. Every fact duplicated across two files becomes two facts that disagree — which is how a slice ends up declaring no dependencies while its own pre-flight and this checklist each say something different.

Derived from [`docs/plan/v1-architecture.md`](../plan/v1-architecture.md). Where a slice departs from that plan, the departure is a numbered fork (**F1**–**F6**) with a decision row in the owning slice — see [Plan Forks](#6-plan-forks).

## 1. Slices

Ordered by delivery sequence — the same order as the linked list.

| # | Slice | Priority | Cx | Owner | Status | Link |
|---|---|---|---|---|---|---|
| 001 | Monorepo skeleton and the /version handshake | P0 | L | | Not started | [001-repo-skeleton-and-version.md](001-repo-skeleton-and-version.md) |
| 002 | Licence split, DCO and the quickstart | P0 | S | | Not started | [002-licence-split-and-contribution-docs.md](002-licence-split-and-contribution-docs.md) |
| 003 | Docker image, compose quickstart and CI pipelines | P0 | M | | Not started | [003-docker-image-and-ci.md](003-docker-image-and-ci.md) |
| 004 | Library scan to a manifest on disk | P0 | L | | Not started | [004-library-scan-to-manifest.md](004-library-scan-to-manifest.md) |
| 004a | Album artwork extraction | P1 | M | | Not started | [004a-album-artwork-extraction.md](004a-album-artwork-extraction.md) |
| 005 | Server pairing, the owner claim and the bearer middleware | P0 | L | | Not started | [005-server-pairing-and-owner-claim.md](005-server-pairing-and-owner-claim.md) |
| 005a | App sign-in, token storage and the onboarding fork | P0 | M | | Not started | [005a-app-sign-in-and-token-storage.md](005a-app-sign-in-and-token-storage.md) |
| 006 | The library manifest endpoint and manual rescan | P0 | M | | Not started | [006-library-manifest-endpoint.md](006-library-manifest-endpoint.md) |
| 007 | The album grid, backed by the SwiftData cache | P0 | L | | Not started | [007-album-grid-from-cache.md](007-album-grid-from-cache.md) |
| 008 | Album detail and artwork, end to end | P0 | M | | Not started | [008-album-detail-and-artwork.md](008-album-detail-and-artwork.md) |
| 009 | Album playback, streamed from the server | P0 | L | | Not started | [009-album-playback-streaming.md](009-album-playback-streaming.md) |
| 010 | Downloading an album for offline use | P0 | L | | Not started | [010-album-download-offline.md](010-album-download-offline.md) |
| 011 | Local-first playback and download recovery | P0 | M | | Not started | [011-local-first-playback-and-recovery.md](011-local-first-playback-and-recovery.md) |

Status: `Not started` · `In progress` · `Blocked` · `In review` · `Done`

## 2. Spikes

Spikes are not deliverables and are not in the linked list, so they get their own table.

| # | Question | Timebox | Unblocks | Status | Answer |
|---|---|---|---|---|---|
| S001 | Can two `FileMiddleware` instances on two roots under two path prefixes coexist in Hummingbird 2, and pass through on a miss? | 3h | 003, 008, 009 | Not started | — |
| S002 | Does `swift run Server` serve a local music folder on macOS with no container, and are `ffprobe`/`ffmpeg` reachable from a `Process`? | 2h | 001, 004 | Not started | — |
| S003 | Does the plan's tag-mapping table match real `ffprobe` output across the owner's actual library? | 4h | 004, 004a | **Answered** | **No, in two places that matter.** 1175 files. The table is missing **`TPA`**, the ID3v2.2 disc-number frame, on 122 mp3s that would otherwise all become disc 1. And question 4 inverted: FLAC embedded artwork is perfect (107/107), mp3 has none at all (0/340), and **171 of 196 album directories have no artwork source of any kind**. Also: album-artist coverage is 40.8%, `discCount` is always populated so 004's reconciliation never fires, disc markers in titles are rare and the one real case defeats **F6**, and the `compilation` tag is wrong in 57 of 196 directories |

Status: `Not started` · `In progress` · `Answered` · `Abandoned`

**S003 was assigned to the project owner**, because it needed their library. It was still a spike, not a question — they ran commands and pasted output; they were not asked to make a design decision. **It ran on 2026-08-31 and is answered**; its five questions and the tested-negative on the `compilation` tag are written up in [S003 §6](S003-ffprobe-tag-shapes.md#6-result), and its consequences landed in 004, 004a, 007, blocker **B3**, two Drift Log rows and two new ladders.

**S003's evidence is preserved, small and deliberate.** [`S003-evidence/`](S003-evidence/) holds the findings and three real probe outputs — 16 KB. The 1175-file, 4.7 MB set behind the figures was **not** kept: generated data, stale on the first retag, and about two minutes to rebuild from the command its `README.md` records. Nothing went to `Server/Tests/ServerTests/Fixtures/` because slice 001 has not run and `Server/` does not exist yet. **The consequence to carry into 004: its tag-mapper tests are table-driven from three real cases plus hand-written rows, not from a real library**, so a tag shape absent from the owner's collection stays uncovered — which is what `scan-report.json`'s unused-key list is for.

**S003 grew a fifth question when B1 was resolved**: how many albums carry the disc marker in the title rather than in a disc tag. That number sized fork **F6** — and the answer narrowed F6's claim rather than confirming it. The addition did not change the spike's timebox, its assignment or what it unblocks; the same probe output answered it.

**Run S001 and S002 before slice 003.** Neither is in the linked list, but S001's fallback changes the volume layout that slice 003 ships, and S002's part 2 changes slice 004's configuration surface. Answering them after those slices land means reworking both.

## 3. Active Blockers

IDs run contiguously from **B1**. Never skip, never reuse — a gap means someone deleted a row instead of resolving it.

Each row was a **taste call only the project owner holds**. Every other unknown in the plan resolved to a spike or a version ladder and is not here — see [Unknown Triage](#7-unknown-triage). **Rows are resolved in place, never deleted** — the contiguous-ID rule above means a removed row reads as a lost one.

**Only B3 is still open.** B1 was answered by the owner on 2026-08-31; B2 collapsed to a decision once B1's adjacency guarantee became structural, and was resolved without going back to the owner.

| ID | Slice | Blocker | Raised | Owner | Resolution plan |
|---|---|---|---|---|---|
| B1 | 004, 007 | **Multi-disc albums: one wallet slot per disc, or one per album?** Keying on `(albumArtist, title, discNumber)` puts "Disc 1" and "Disc 2" in the grid as two separate tiles. Arguably exactly right for a CD-wallet concept — one physical disc, one slot — but it is a product call, not a technical one. The alternative groups discs under one album and keys tracks on `(discNumber, trackNumber)` | 2026-08-31 | Project owner | **Resolved 2026-08-31 — one tile per disc**, in the owner's words: *"1, but they must always be grouped. They should be a separate type, eg single disc, double disc type"*. The album key `(albumArtist, title, discNumber)` stands unchanged, so **no schema change and no migration**. Two riders ride on top, both satisfied in the app with no DTO and no server change: discs of one release always render adjacently, and the disc-set shape is a domain **type**, not something inferred at render time. Decision rows: 004 §6 (the key, `discCount` reconciliation, fork **F6**) and 007 §6 (`ReleaseKey`, `DiscSet`, `Release`, `ReleaseGrouper`, ladder **L10**) |
| B2 | 007 | **Default album grid ordering.** Album artist then year? Album artist then title? Recently added? v1 needs exactly one default and no sort control | 2026-08-31 | Project owner | **Resolved 2026-08-31 — not asked, decided.** B1 made adjacency structural, so ordering applies to **releases** and no sort can separate the discs of one release; the risk that made this worth asking about is gone. "Recently added" was then eliminated on fact rather than taste — `AlbumDTO` has no added-at field, so it needs a DTO and cache-schema change and is out of v1. The order is `albumArtist` (normalised exactly as `ReleaseKey` normalises it), then `year` ascending with unknown years last, then `title`, with `ReleaseKey` as the final tiebreak so the order is total. Not laddered: no crude rung and a better one, just two equivalents behind one sort descriptor. Decision row: 007 §6 |
| B3 | 007, 008 | **Placeholder for albums with no artwork.** Not specified anywhere in the plan. **Re-ranked 2026-08-31 — this is no longer a detail.** S003 measured the owner's library at **171 of 196 album directories with no artwork source of any kind**, so roughly **87% of grid tiles show the placeholder**. mp3 carries no embedded picture at all (0 of 340), and three `cover.jpg`-style files exist on the whole disk. The placeholder is not the empty state of the wallet, it **is** the wallet in v1 | 2026-08-31 | Project owner | **Ask — and it is now the most consequential of the three, not the least.** Still a genuine taste call: what a tile with no cover should look like is a design decision nobody else can make. But it is **not a blocker**, because ladder **L12** puts a crude rung behind a seam — 007 ships `AlbumArtworkPlaceholder` as a plain neutral tile and 008 replaces that one view. Worth answering with the 87% figure in mind: at that share, "a grey square" is a product decision about what Mix Tape looks like. Ladder rungs are in the [L12 row](#7-unknown-triage), not restated here |

## 4. Architecture Drift Log

Everything pre-flight validation turned up: a prior decision that no longer held by the time a later slice depended on it.

Ten rows, from three different kinds of looking. **The first five** were found during slice planning, before any slice started. **The next two came from S003**, the first entries here produced by evidence rather than by reading — both are cases where a written assumption met 1175 real files and lost. **The last three came from the `CLAUDE.md` audit**, and they are a third kind again: neither was found by planning a slice or by running an experiment, but by reading the always-loaded conventions file against the corpus it claims to summarise. two of them are cases where two documents each stated a fact and the two facts could not both be true, and the third is a criterion that quietly became unpassable when the world moved under it. What links all three is the shape of the failure rather than its cause: **each one reads as satisfied while the thing it protects is broken.** That is the class of fault a file loaded into every session makes worse rather than better, because the wrong half propagates into code before anyone re-reads the source.

**The B1 rework added none.** Drift is a prior decision that stopped holding underneath a later slice. B1's answer did not invalidate a prior decision — it settled an open question, and the departures it caused from the plan are recorded where this set records deliberate departures: fork **F6** with its decision row in 004, plus the **OA1** and **OA2** coverage rows. Adding a drift row for a deliberate fork would make the two columns mean the same thing.

| Date | Found in | What drifted | Resolution | Slices affected |
|---|---|---|---|---|
| 2026-08-31 | Slice planning | **The working directory is not a git repository.** No `.git`, no commits. The slice convention requires committing each slice document alongside its code with the slice id in the subject — that discipline is inert without a repository | `git init` and a first commit are slice 001's **first acceptance criterion**. **Resolved 2026-08-31 — the owner initialised the repository and committed (`4b340f7`, on `main`).** But it resolved into the row below rather than cleanly: the first commit predates any `.gitignore` | 001, and every slice after it |
| 2026-08-31 | Slice planning | The plan's Context section states the repository holds `api/` (empty) and `app/`. **`api/` does not exist.** Only `app/` and `docs/` are present | Phase 2's "rename `api/` to `Server/`" is a **create**, not a rename. No further consequence | 001 |
| 2026-08-31 | Slice planning | The **`slice-authoring`** and **`slice-set-review`** skills named as binding are not installed and are not reachable on this machine | [`docs/slices/README.md`](README.md) plus [`000-slice-template.md`](000-slice-template.md) and [`000-spike-template.md`](000-spike-template.md) restate the same rules — naming, linked-list wiring, one-fact-one-home, spike shape, pre-flight, checklist ownership — and were used as the operative spec. The `slice-set-review` pass was run **by hand** over this directory. If the skills are installed later, re-run both against this set | All |
| 2026-08-31 | Slice planning | **`CONTEXT-FORMAT.md` does not exist** at the repository root, and neither does `CONTEXT.md`. The glossary convention specifies the format file as the source for `CONTEXT.md`'s header | No `CONTEXT.md` was created — inventing a format to record terms that were resolved from written documents rather than with the owner would produce a file nobody agreed to. Raised to the project owner. Terms that need pinning (album artist versus track artist, cache versus download, claimed versus paired, album versus disc) are defined in the slices that use them until then | — |
| 2026-08-31 | Slice planning | **`apple-docs` was not reachable during planning.** Several Apple-platform behaviours the plan asserts are therefore unverified: Keychain accessibility semantics for a background session (005a), `context.delete(model:)` and `@Query` observation across a `ModelActor` (007), ImageIO downsampling option keys (008), `AVURLAssetHTTPHeaderFieldsKey` and `AVAudioSession` behaviour (009), background `URLSession` lifecycle and temporary-file lifetime (010), file eviction semantics (011) | Each of those six slices carries a **verification note in Section 3** and a pre-flight line requiring the check before implementation, with any correction logged as a decision row plus a row here. **No Apple API was recommended from memory as settled fact** | 005a, 007, 008, 009, 010, 011 |
| 2026-08-31 | **S003, run against the owner's library** | **The plan's Section 4 tag-mapping table is incomplete.** It does not list **`TPA`**, the ID3v2.2 "part of set" frame, which is the disc number on **122 of the owner's mp3s** and never co-occurs with `disc` (`TPA`-only 122, `disc`-only 559, both 0). Under the table as written those 122 files silently take `discNumber = 1`, which breaks the multi-disc Pharmacy sets outright and produces no error anywhere. S003 §7 named this table as the thing that would drift, and it did. Separately, the table's case-sensitivity was an open assumption, and FLAC writes `ALBUM` and `album_artist` **in the same file** | `TPA` added to the disc-number keys, and the whole-key case-insensitive lookup made mandatory rather than defensive — both as a decision row in 004 §6. **Not given a fork id**: the plan's table was factually wrong, not a considered decision 004 is departing from | 004 |
| 2026-08-31 | **S003, run against the owner's library** | **The artwork premise inverted, and two prior positions stopped holding with it.** The plan and 004a both assumed embedded-first with a directory fallback would usually find something, and 004a's own text claimed a grid of grey squares would mean the product had "lost its entire premise". Measured: **171 of 196 album directories have no artwork source of any kind (87%)**, mp3 **0 of 340**, m4a **82 of 728**, and exactly **3** `cover.jpg`/`folder.jpg`/`front.jpg` files on the whole disk. The plan's specific FLAC worry was wrong in the opposite direction — FLAC is **107/107** | 004a's Section 2 premise rewritten to the measured figures; ladder **L11** registered so the 13% ceiling has a named escape route; blocker **B3** re-ranked from the least consequential taste call to the most, with ladder **L12** added so it still blocks nothing; 007 updated to make `AlbumArtworkPlaceholder` a named component. **The FLAC contingency in S003 §5 got no row of its own** — a contingency that does not fire is a normal spike outcome, not a decision that stopped holding | 004a, 007, 008 |
| 2026-08-31 | **`CLAUDE.md` audit** | **The toolchain pinned at Swift 6.2 stopped holding: the machine is on Swift 6.4 / Xcode 27.** The template states Xcode 26 / Swift 6.2, and plan conflict **C5** resolved the Docker build stage to `swift:6.2-noble`. Slice 001's pre-flight read *"confirm the Swift toolchain is 6.2"* — as written it fails on the first day of the first slice. Demoting it to a warning would be the wrong fix, because `Shared/` compiles under both the Mac and the container: a 6.4-only construct passes locally and fails a Linux build nobody runs until CI. **C5's principle survives; its version number did not** | **Not a decision to reopen, and not an owner question.** Three forward edits, with the historical **C5** decision rows in 001 §6 and 003 §6 left untouched as the record they are: 001's pre-flight now checks *language mode Swift 6* and records the toolchain version rather than demanding 6.2; **003's pre-flight gains the pin** — check whether a `swift:6.4-noble` tag exists, bump the build stage if it does, otherwise hold `Shared/` and `Server/` to Swift 6.2 features and say so in a decision row — and 003's build-stage acceptance criterion now names the pinned tag rather than `6.2` literally. `CLAUDE.md`'s Swift rules carry the interim 6.2-features constraint until 003 lands, and 003's pre-flight is what retires it. **Whether the 6.4 image tag exists is a two-minute check by whoever builds 003, not a spike and not a question for the owner** — which is why it is assigned rather than asked | 001, 003, and every slice adding a type to `Shared/` |
| 2026-08-31 | **`CLAUDE.md` audit** | **Two header conventions each claimed line 1 of every Swift file, and nothing stated the order.** Plan §7, the handoff and slice 002's acceptance criteria all require `SPDX-License-Identifier` as the **first line**, and `scripts/check-spdx.sh` greps line 1. The author's standing Swift convention requires the standard Xcode header block, which begins `//  FileName.swift`. Slice 001 writes the repository's first Swift files, so every source file in the project was about to be written one of two incompatible ways — with `check-spdx.sh` failing on whichever half chose the other | **Resolved on the documents rather than on taste: SPDX line first, Xcode block below it.** "First line" is stated explicitly in three places; the header convention specifies a *format* and never claims a position, so this is the only reading that satisfies both. `CLAUDE.md`'s Conventions section now carries the literal combined header as a fenced example — agents copy examples and misread prose descriptions of file layout — and its Licensing section points at that one home rather than restating it. Decision row and a new acceptance criterion in **002**, which owns SPDX and the check script | 001, 002, and every slice that writes a source file |
| 2026-08-31 | **`CLAUDE.md` audit** | **Slice 001's first acceptance criterion had become unpassable while reading as passed.** The owner initialised the repository after 001 was drafted, so `git init` and "at least one commit" are already true — but the first commit predates any `.gitignore`, and **five files the same criterion forbids are tracked**: `.DS_Store`, `docs/slices/.DS_Store`, and three under `app/mixtape.xcodeproj/**/xcuserdata/` (`UserInterfaceState.xcuserstate`, `xcschememanagement.plist`, `Breakpoints_v2.xcbkptlist`). The trap is that **`.gitignore` does not untrack anything already in the index**, so an agent that adds the ignore file, re-reads the criterion and sees `git init` satisfied ticks the box with the forbidden files still committed. Same failure shape as the toolchain row: a check that reports success while the thing it protects is broken | Corrected forward, in 001. Section 3's bullet no longer asks for a `git init` that has happened — it asks for the `.gitignore` **and** the explicit `git rm --cached`, naming all five paths. The first acceptance criterion now asserts with **`git ls-files`** rather than by reading `.gitignore`, because reading the ignore file is precisely the check that passed while the index was dirty. 001's pre-flight drift list goes from two items to three. **Not run** — per the project's no-auto-commit rule the untracking command is handed over, not executed | 001 |

## 5. Plan Coverage

One row per numbered requirement in the plan. A requirement with no slice is the failure mode that no amount of per-slice review catches — it's only visible from here.

**Every section 1–7 of [`docs/plan/v1-architecture.md`](../plan/v1-architecture.md) is covered. There are no uncovered rows.**

Two requirements at the foot of the table are prefixed **OA** rather than a plan section number. They are **owner additions** — requirements the owner stated when resolving **B1**, after the plan was written. They are numbered separately so nobody goes hunting for a plan section that does not exist, and they are here rather than only in a slice because a `covers:` reference with no coverage row is exactly the fault this table catches.

| Plan ref | Requirement | Slice | Notes |
|---|---|---|---|
| **1** | **Shared DTO surface** | | Split across the slices that first need each type, rather than one DTO-only slice — a DTO slice would be a layer, not a vertical unit |
| 1.identity | SHA-256 ids; album from tags, track from path | 004 | The asymmetry is deliberate and load-bearing for 010 and 011 |
| 1.TrackDTO | Track fields, incl. `trackArtist` never used for grouping | 004 | |
| 1.AlbumDTO | Album fields, incl. `albumArtist` as the grouping key | 004 | |
| 1.LibraryManifestDTO | `revision`, `generatedAt`, `albums` | 004 | **Fork F1** — `revision` also hashes `hasArtwork` |
| 1.VersionResponseDTO | `apiVersion`, `serverVersion`, `claimed` | 001 | `claimed` becomes meaningful in 005 |
| 1.AuthExchange | Request and response DTOs | 005 | |
| 1.ErrorResponseDTO | `APIErrorCode` and message | 001, 005 | Defined in 001, first returned in 005 |
| 1.MixTapeJSON | Shared ISO 8601 encoder and decoder | 001 | Plan conflict **C4**, approved deviation |
| 1.linux | `Shared` compiles on Linux | 001, 003 | 001 greps; **003's CI job is the binding proof** |
| **2** | **SwiftData schema** | | |
| 2.cache | `CachedAlbum`, `CachedTrack` | 007 | |
| 2.downloads | `DownloadedAlbum`, `DownloadedTrack` | 010 | **Models are defined in 007 though unused there** — adding them in 010 would be a migration. 007 does not claim this ref; the lifecycle that satisfies it is 010's |
| 2.replacement | Full replacement leaves downloads intact | 007 | Proven by a named test, not by argument |
| 2.modelActor | `LibraryImporter` at the specified path | 007 | |
| **3** | **API endpoints** | | |
| 3.version | `GET /version`, no auth | 001 | |
| 3.authApple | `POST /auth/apple`, no auth, `403 notOwner` | 005 | |
| 3.library | `GET /library`, bearer, `ETag`, `304` | 006 | **Fork F2** — a defined `503` during the first-ever scan |
| 3.rescan | `POST /library/rescan`, `202`, `409` | 006 | |
| 3.artwork | `GET /artwork/{albumID}`, bearer, immutable cache | 008 | Depends on **S001** |
| 3.audio | `GET /audio/**`, bearer or `?token=`, `Range` | 009 | Depends on **S001**. Ladder **L7**. **Fork F5** — filename hazards |
| **4** | **Library scan design** | | |
| 4.scanned | Extensions walked; nothing transcoded | 004 | Plan conflict **C7** (Ogg) recorded, not reopened |
| 4.ffprobe | Bounded task group, capped concurrency | 004 | |
| 4.tagMapping | The tag key table | 004 | **S003 answered — the plan's table was incomplete.** `TPA` added; whole-key case-insensitivity now mandatory. Drift Log row, no fork id |
| 4.fallbacks | Missing/malformed tags, incl. "Various Artists" | 004 | **S003 made this the main path, not a safety net** — only 40.8% of files carry an album-artist tag, and 65 of 196 directories fall back to `artist`. "Various Artists" fires on 7 |
| 4.artwork | Embedded first, `cover.jpg` fallback, stream copy | 004a | **S003 answered, and inverted.** FLAC 107/107, mp3 0/340, 87% of directories with no source at all. Order unchanged; the contingency never fired. Ladder **L11** |
| 4.grouping | Normalised `(albumArtist, title, discNumber)` key | 004 | **B1 resolved — the key stands unchanged.** **Fork F6** strips a trailing disc marker from the title into `discNumber`, and `discCount` is reconciled across a release |
| 4.index | `actor LibraryIndex` and the JSON snapshot | 004 | Ladder **L4** |
| 4.triggers | Boot with/without snapshot; manual rescan; no watch | 004 | Ladder **L3**. Boot behaviour is 004's; the rescan *route* that triggers it is 006's `3.rescan` |
| **5** | **Auth flow** | | |
| 5.pairing | The exchange, server side | 005 | |
| 5.pairing.client | Button, exchange, Keychain storage | 005a | |
| 5.secret | `MIXTAPE_TOKEN_SECRET` or a generated `0600` file | 005 | Ladder **L5** — rotating it is the whole v1 revoke story |
| 5.middleware | HS256 verify plus owner `sub` check, no I/O | 005 | |
| 5.secondDevice | Same Apple ID pairs again; a different one is refused | 005a | 005 makes this true by construction but explicitly disclaims the ref — the behaviour is only observable with a client, so 005a owns it |
| 5.config | `MIXTAPE_APPLE_BUNDLE_ID` required | 005 | Plan conflict **C6** — `MIXTAPE_APPLE_TEAM_ID` is documented in 003's compose file and read by nothing, but 003 does not claim this ref |
| **6** | **Download lifecycle** | | |
| 6.states | `DownloadState`, and the album recompute rule | 010 | |
| 6.storage | Paths, backup exclusion, relative paths only | 010 | |
| 6.session | Background `URLSession` configuration | 010 | |
| 6.delegate | The `nonisolated` shim, with its justification in the file | 010 | The one justified shim in the codebase |
| 6.resume | Relaunch reattachment and reconciliation | 010 | |
| 6.localFirst | Local over remote, with the disk-existence check | 011 | **Fork F4** — orphaned bytes after a file move, accepted in v1 |
| 6.playbackRules | The queue is the album; next at the end stops | 009 | The product decision, with a mandatory source comment |
| **7** | **Repository and app layout** | | |
| 7.layout | Three packages, the directory tree | 001 | `api/` never existed — see Drift Log |
| 7.layers | Six layers as folders in one target | 001 | Plan conflict **C1**, resolved by the owner. Enforced by `check-layer-imports.sh` |
| 7.server | Hummingbird 2; `FileMiddleware` for all `Range` work | 001 | Server boot and routing are 001's. The two `FileMiddleware` mounts land under `3.artwork` (008) and `3.audio` (009), both gated on **S001** |
| 7.build | Dockerfile, caching, static stdlib, compose, CI filters | 003 | Plan conflict **C5** — `swift:6.2-noble`. Ladder **L2** |
| 7.licensing | Four `LICENSE` files, SPDX, DCO | 002 | Adds `check-spdx.sh`, which the plan does not name |
| **OA** | **Owner additions, stated when B1 was resolved** | | Post-date the plan, so they carry no plan section number |
| OA1.releaseGrouping | The discs of one release always render adjacently | 007 | Satisfied **structurally** — the grid iterates `[Release]` and a release owns its discs, so a foreign album between disc 1 and disc 2 is unrepresentable rather than merely unlikely. **Caveat, measured by S003:** the guarantee holds per *derived* release, and discs whose titles differ by more than the disc marker derive as two releases and so never come to be adjacent. One instance in the owner's library. F6 narrows its claim accordingly and 004 flags every such case in `scan-report.json` — visible, not silent |
| OA2.discSetType | The disc-set shape is a domain type, not inferred at render time | 007 | `DiscSet` — `.single` / `.multiDisc(discsPresent:discsExpected:)` — in `AppDomain`. `discsExpected` comes from 004's reconciled `discCount` and is `nil` where the tags never supplied one |

## 6. Plan Forks

Where a slice deliberately departs from the plan. Each has a decision row in the owning slice recording what was rejected and why — a fork with no decision row is the failure the slice template's Section 3 exists to catch.

| ID | Slice | Fork | Why |
|---|---|---|---|
| F1 | 004 | `revision` also hashes `hasArtwork` | Under the plan's definition, adding a `cover.jpg` and rescanning produces an identical `ETag`, 006 answers `304`, and the client never learns artwork appeared. One field, and it closes a silent failure |
| F2 | 006 | `GET /library` during the first-ever scan returns `503` `scanInProgress` with `Retry-After` | The plan leaves this undefined. On a large library it is a multi-minute window on a new user's very first run, and an empty grid reads as "my library is broken". Reuses an existing `APIErrorCode`, so no DTO changes |
| F3 | 010 | Deleting a download is driven from the downloads list off local rows alone | Retagging on the NAS mints a new album id, so the old download is stranded under an id the server no longer knows. If deletion needed a manifest entry, that album could never be removed |
| F4 | 011 | Orphaned bytes after a NAS file *move* are accepted in v1 | Track ids are path-derived, so a move mints a new id and strands the downloaded file. v1's escape hatch is "delete all downloads"; ladder **L9** is the sweep |
| F5 | 009 | Filename hazards are in scope with a named fixture set | The plan says "percent-decoded and resolved against the music root" and stops. Real libraries carry `#`, `?`, `&`, `+`, `%` and NFD unicode from macOS, each producing a `404` on a track that is plainly there |
| F6 | 004 | A trailing disc marker — `(Disc 2)`, `[Disc 2]`, `- Disc 2`, `CD2`, `Disk 2` — is stripped from the album title into `discNumber`; on conflict the disc tag wins and the discrepancy is logged. **Narrowed after S003 from a grouping guarantee to a grouping improvement, with the residue reported** | The plan maps the album title to the `album` tag verbatim, which makes `The Wall (Disc 1)` and `The Wall (Disc 2)` two different keys so the discs never group. **S003 then measured it and F6 came off worse than expected**: only 2 of 166 titles carry a marker, and the single real multi-disc case — `Digital Domain [Disc 1]` versus `Digital Domain - Nikfish.com.au [Disc 2]` — still does not group after stripping. Kept, because it is one tested function and it still catches the clean shape; **suffix-tolerant keys rejected**, since a rule loose enough to merge those two also merges `Greatest Hits` with `Greatest Hits Vol 2`, and a wrong merge destroys an album where a wrong split only annoys. What changed is the claim: 004 now flags any release whose `discCount` exceeds the discs found, so the residue is visible in `scan-report.json` and the owner can retag it |

## 7. Unknown Triage

Every open question and conflict in the plan, and where it went. Only genuine taste calls reached the owner.

**Plan open questions (5):**

| Plan OQ | Outcome | Where |
|---|---|---|
| 1 — Multi-disc albums | **Question, asked and answered** | **B1**, resolved 2026-08-31 — one tile per disc, plus **OA1** and **OA2**. Correctly a question rather than a ladder: the schema could not change later without a migration. The owner's two riders then *did* ladder — **L10** — because they sit entirely in the app behind `ReleaseGrouper` |
| 2 — Audio auth, query parameter or header | **Ladder L7** | v1 is `?token=`. Seam: `AudioURLProvider`, the single audio-URL construction point. Not spiked — the alternative rests on an undocumented key, and a passing experiment would not make it supported |
| 3 — Default grid ordering | **Was a question, withdrawn and decided** | **B2**, resolved 2026-08-31 without asking. B1 made disc adjacency structural, which removed the only consequence that made this worth an owner's time; "recently added" then failed on fact, needing a DTO field that does not exist. What was left was two equivalent orderings behind one sort descriptor, which is a decision to make, not a question to forward |
| 4 — No-artwork placeholder | **Question, plus ladder L12** | **B3**, and **re-ranked upward after S003** — at 87% of album directories with no artwork source, the placeholder is the grid's dominant visual state rather than an edge case. Still a question, because what it should look like is the owner's taste and nobody else's. The ladder is what stops it blocking 007 |
| 5 — Server directory layout, one volume or two | **Ladder L1** | v1 is one mount. Seam: `MIXTAPE_DATA_DIR` and `MIXTAPE_CACHE_DIR` as independent variables defaulting to subpaths of it. v2 is a compose edit, no code change |

**Plan Phase 2 empirical checks (2):** both became spikes — **S001** (dual `FileMiddleware`) and **S002** (`swift run Server` on macOS). **S003** was added: the plan's tag-mapping table is written from documentation, and a wrong table produces a wallet of one-track albums with no error anywhere. **It has now run, and it earned its place** — the table was in fact wrong (`TPA`), and question 4 inverted the artwork design's premise. Two Drift Log rows, two new ladders, a narrowed fork and a re-ranked blocker came out of four hours.

**One unknown was triaged during this round and deliberately did not become a spike.** S003 counted only `cover.jpg`, `folder.jpg` and `front.jpg` and found three on the whole disk; nobody has counted images stored under other names, which is the difference between "this library has no artwork" and "the artwork is named something else". Rather than a second owner-assigned spike, 004a's `scan-report.json` section records the image-file count per artwork-less directory, so the first real scan answers it. Same move that made `scan-report.json` permanent scope.

**Plan conflicts (7):** **C1** and **C5** are resolved by the owner and were not reopened; both are recorded as decision rows in 001 so Phase 3 treats them as approved. **C2** (repositories over a private actor) is recorded in 007, **C3** (protocols with `Mock*`/`Stub*` as the second conformer) in 005a, **C4** (`MixTapeJSON` in `Shared`) in 001, **C6** (unused Team ID) in 003 and 005, **C7** (Ogg Vorbis) in 004. None became a question.

**Version ladders (12).** A ladder is only valid if v1 sits behind the seam v2 replaces — every seam is named:

| ID | v1 rung | Seam | Slice |
|---|---|---|---|
| L1 | One bind mount | `MIXTAPE_DATA_DIR` / `MIXTAPE_CACHE_DIR` | 001, 003 |
| L2 | Single-architecture image | the `platforms:` input on the buildx step | 003 |
| L3 | Manual rescan, no filesystem watch | `LibraryScanner.scan()` | 004 |
| L4 | In-memory index plus a JSON snapshot | the `LibraryIndex` actor's method surface | 004 |
| L5 | Revoke by rotating the secret file | the `jti` claim, minted from day one, plus `TokenVerifier` | 005 |
| L6 | ImageIO downsample, `URLCache` for bytes | `ArtworkLoaderProtocol` | 008 |
| L7 | `?token=` on audio | `AudioURLProvider` | 009 |
| L8 | Whole-album download, no pause | `enqueue(album:)` over per-track rows | 010 |
| L9 | "Delete all downloads" as the orphan escape hatch | `DeleteDownloadUseCase` plus the `Downloads/` root helper | 011 |
| L10 | Release grouping derived client-side from `(albumArtist, title)` and `discCount` | `ReleaseGrouper` and `ReleaseKey` in `AppDomain` — the one derivation point. v2 is a server-supplied `releaseID` on `AlbumDTO`, which `ReleaseGrouper` reads instead of computing; no view and no cache model changes | 007 |
| L11 | Local artwork sources only — embedded, then a directory `cover.jpg`. **S003 measured this at 13% of album directories** | The album-level source-selection function in 004a. v2 appends an external source (Cover Art Archive or MusicBrainz) to its ordered list; extraction, caching, `hasArtwork` and stale removal are untouched | 004a |
| L12 | A plain neutral placeholder tile for albums with no artwork — which S003 makes roughly 87% of them | `AlbumArtworkPlaceholder` in `AppPresentation/Components/`. v2 is whatever **B3** resolves to, swapped into that one view by 008 | 007, 008 |

## Ordering Notes

Slice numbers are dependency and delivery order, not priority. Record why the order is what it is, so whoever reprioritises knows what they're overriding. v1 rungs go early.

**Infrastructure first, but only three slices of it.** 001–003 exist because their absence is expensive rather than because they deliver user value. 002 is second because the handoff requires open source *from the first public commit*, and a licensing defect cannot be quietly fixed once contributions arrive. 003 is third because its Linux CI job is the **binding proof** for `Shared` being Linux-clean — every later slice adds types to `Shared`, and until that job exists each one is guessing.

**The scan before any endpoint that serves it.** 004 produces a file you can open with `jq` and check against a library you know. A scan that groups wrongly still produces a *valid* manifest, so the failure is silent; debugging it through an HTTP response and a SwiftUI grid is strictly harder for no gain.

**Auth before every authenticated endpoint.** This is the one ordering constraint with no flexibility. 005 precedes 006, 008 and 009 so each can carry a "rejected without a token" acceptance criterion at the moment it is built. An endpoint that ships unauthenticated and has middleware retrofitted is an endpoint nobody ever tested unauthenticated.

**Then the client, in the order a user meets it.** 005a pair → 007 see the wallet → 008 see the covers → 009 play → 010 download → 011 play offline. Each is demonstrable on its own, and each is the natural next thing to ask for after the previous one.

**011 is separate from 010 on purpose.** 010 is shippable and testable alone — files on disk, rows in the store, a downloads list. Folding the playback-selection change into it would mean 010's tests could not distinguish "the download worked" from "playback picked the right source". 011 is the payoff, and it is the last slice of v1.

**What would reorder this set.** If **S001** takes its fallback, 003's volume layout changes and 008 and 009 change with it — none of them move, but all three need re-reading. **B1 is answered, so nothing stalls on it**; the order is unchanged, but the answer put new scope in both 004 (fork **F6**, `discCount` reconciliation) and 007 (`ReleaseKey`, `DiscSet`, `Release`, `ReleaseGrouper`), and it added **S003** question 5, so all three need re-reading before 004 starts. **S003 has run, so its branch is settled** — but its answer reweighted two slices without moving either. **004 got larger**: `TPA`, proven case-insensitivity, the probable-grouping-miss report and the rejected `compilation` tag are all new, and its tag-mapper tests are now anchored to three real probe outputs in [`S003-evidence/`](S003-evidence/) rather than to invented JSON alone. **004a got smaller in value and clearer in purpose**: it serves about 13% of albums, which is not a reason to defer it — the work is a stream copy and the 25 directories it covers are the only colour in the wallet — but it does mean **B3 now matters more than 004a does** to how v1 looks. Nothing reorders on that; 004a stays a P1 sub-slice of 004, in place. What it changes is where attention goes when the grid first renders.

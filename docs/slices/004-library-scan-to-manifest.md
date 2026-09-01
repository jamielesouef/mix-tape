---
slice_id: "004"
title: Library scan to a manifest on disk
priority: P0
complexity: L
ladder: "library freshness v1 of 2 — v2 is a filesystem watch, shared seam: LibraryScanner.scan(); and index storage v1 of 2 — v2 is GRDB, shared seam: the LibraryIndex actor's method surface"
depends_on:
  - { id: "003", type: hard, note: "the Linux CI job is the binding proof for the DTOs this slice adds to Shared" }
  - { id: "S003", type: hard, note: "the tag-mapping table is an assumption until this spike checks it against real data" }
  - { id: "S002", type: soft, note: "part 2 decides whether ffprobe needs an explicit path variable" }
previous_slice: "003"
next_slice: "004a"
parent_slice: none
covers: ["1.identity", "1.TrackDTO", "1.AlbumDTO", "1.LibraryManifestDTO", "4.scanned", "4.ffprobe", "4.tagMapping", "4.fallbacks", "4.grouping", "4.index", "4.triggers"]
created: 2026-08-31
---

# 004 — Library scan to a manifest on disk

← [previous](003-docker-image-and-ci.md) · [Master Checklist](MASTER-CHECKLIST.md) · [next](004a-album-artwork-extraction.md) →

> **Status, owner and blockers live in the master checklist, not here.** Dependencies live in this page's front matter and nowhere else. Each fact has one home; if you find yourself writing it twice, one of the two copies is going to be wrong in a fortnight.

## 1. Objective

Walk the music directory, read tags with `ffprobe`, group files into albums, and write a complete `LibraryManifestDTO` to `<cacheDir>/library.json`. Value observable on its own: point the server at a real music folder, boot it, and read a JSON file that correctly describes your library — before any endpoint serves it and before any app renders it.

## 2. Business Value & Priority

This is where the project's single most important decision is implemented: **albums are keyed on `(albumArtist, title, discNumber)`, never on `trackArtist`.** The handoff and the plan both say the same thing in the same words — keying on track artist explodes every compilation and every guest-feature track into a one-track album, and retrofitting it means a migration.

That is also why this slice comes before every endpoint that serves it. A scan that produces a wrong manifest still produces a *valid* manifest; the failure is silent and only visible against real data, on a real library, in a file you can open. Making the artefact a file on disk rather than an HTTP response means it can be inspected with `jq` and compared against what the owner knows their library contains. Debugging this through an API and a SwiftUI grid would be strictly harder for no gain.

**Ladder L3 — library freshness (this slice ships the crude rung).** v1 has no filesystem watch. Adding music means hitting rescan, which slice 006 exposes. The seam is `LibraryScanner.scan()` — one method, called by the boot path and later by the rescan route. A watcher in v2 calls that same method and nothing else changes. Named seam, so this is a ladder.

**Ladder L4 — index storage (this slice ships the crude rung).** v1 is `actor LibraryIndex` holding the manifest in memory, rebuilt at boot from `library.json`. The seam is that actor's method surface; a GRDB-backed v2 implements the same methods. The plan is confident this will never be needed for a personal library, and it is probably right — but the seam costs nothing because the actor exists either way.

## 3. Scope

**In scope:**

- `AlbumDTO`, `TrackDTO`, `LibraryManifestDTO` added to `Shared`, Linux-clean, exactly as the plan's section 1 tables specify
- SHA-256 id derivation in `Server/`, using swift-crypto (already present transitively via JWTKit): `AlbumDTO.id` from the canonical key `albumArtist\u{1F}title\u{1F}discNumber` trimmed, whitespace-collapsed and casefolded; `TrackDTO.id` from the library-relative file path
- Recursive walk of `MIXTAPE_MUSIC_DIR` for `.flac`, `.m4a`, `.mp3`, `.aac`, `.wav`, `.aiff`, `.aif`. **S003 found only three of those seven in the owner's library** — 728 `.m4a`, 340 `.mp3`, 107 `.flac` — so the other four ship untested against real data. All seven stay in the walk; the point of recording this is that a bug in `.wav` or `.aiff` handling will not surface from the owner's library and needs a fixture
- `MIXTAPE_FFPROBE_PATH` and `MIXTAPE_FFMPEG_PATH` read into `ServerConfiguration`, defaulting to resolution through `/usr/bin/env` and overridable to an absolute path. **Added by S002's fallback** — see Section 6. The `ffmpeg` variable is declared here though only 004a invokes the tool, so the pair is configured in one place rather than two.
- One `ffprobe -v quiet -print_format json -show_format -show_streams` `Process` per file, in a bounded `withTaskGroup` capped at `ProcessInfo.processInfo.activeProcessorCount`. **A non-zero `terminationStatus` is a reported failure, never an empty tag set** — `/usr/bin/env` exits `127` for a binary it cannot find without the `Process` throwing anything.
- The tag-mapping table from plan section 4, **plus `TPA`** as a disc-number key, read case-insensitively on the whole key from `format.tags` first then `streams[].tags`. **S003 proved both additions necessary**: 122 mp3s carry the disc number only as `TPA`, and FLAC mixes case inside a single file. The `streams[].tags` second place never fired on the owner's library and is retained defensively — but it must never be consulted for `title`, because `streams[].tags.title` exists and is not the track title
- Every fallback in the plan's missing-or-malformed table, including the **"Various Artists"** rule: if two or more distinct `artist` values appear in one directory with no album-artist tag anywhere in it, all of them get the literal `"Various Artists"`. **S003 makes this the main path, not an edge case** — only 40.8% of the owner's files carry an album-artist tag at all, and 72 of 196 directories have it on no file. Of those 72, **7** fire the "Various Artists" rule and **65** fall back to `artist`. The fallback table decides the album artist for well over half this library, so its tests matter as much as the happy path's
- Grouping on the normalised key, storing and displaying the **original** casing
- Stripping a trailing disc marker from the album title into `discNumber` — fork **F6**, see Section 6
- Reconciling `discCount` across every album sharing `(albumArtist, title)` to the maximum observed value, so the discs of one release agree on how many discs exist
- `revision` computed as a SHA-256, and `<cacheDir>/library.json` written atomically
- `actor LibraryIndex` — holds the current manifest, rebuilt at boot from the snapshot, replaced wholesale at the end of a scan
- Boot behaviour: snapshot present → load and serve, **no scan**; snapshot absent → scan, then serve
- **A probable-grouping-miss section in `scan-report.json`.** Group the finished albums by normalised `(albumArtist, title)`; where a group's maximum `discCount` exceeds the count of distinct `discNumber` values in it, flag **every** member with "`discCount` says N, found M". This is what makes **F6**'s residue visible rather than silent — see the F6 limitation row in Section 6
- `<cacheDir>/scan-report.json` — every skipped file with its reason, every file with no album-artist tag, every distinct tag key seen but not used, the probable grouping misses above, and **for each album with no artwork, whether its directory contained any image file at all**. That last field answers a question S003 could not: only three files on the owner's disk are named `cover.jpg`/`folder.jpg`/`front.jpg`, but nobody has counted differently-named images, and a report field costs less than a second spike. This section is **S003**'s fallback promoted to permanent scope; it is what makes a bad scan diagnosable instead of mysterious

**Out of scope** (name the slice it is deferred to):

- Artwork extraction and the `cover.jpg` fallback → **004a**
- `GET /library`, `POST /library/rescan`, and anything HTTP → **006**
- Filesystem watching → ladder **L3** v2, not v1
- MusicBrainz gap-filling → out of scope for v1, per the handoff
- Transcoding, and Ogg Vorbis support → out of scope. Plan conflict **C7**, recorded not reopened
- Incremental or partial rescans → out of scope; a rescan rebuilds everything

**Plan requirements covered:**

- `1.identity`, `1.TrackDTO`, `1.AlbumDTO`, `1.LibraryManifestDTO` — the DTOs and the id derivation, as specified.
- `4.scanned`, `4.ffprobe`, `4.tagMapping`, `4.fallbacks`, `4.grouping`, `4.index`, `4.triggers` — as specified, with **one deliberate fork on the `revision` definition**, recorded in Section 6 as decision **F1**. The plan computes `revision` over sorted album ids, track ids and byte sizes. That set does not include `hasArtwork`, so dropping a `cover.jpg` into an album directory and rescanning changes nothing observable — the `ETag` is identical, slice 006 returns `304`, and the client never learns artwork appeared. This slice includes `hasArtwork` in the hash. It is a one-field change now and a "why is my artwork missing" bug report later.

## 4. Pre-Flight Validation

Complete **before the first line of code**, not at close.

For **each id in `depends_on`**, in order — do not summarise, walk the list:

- [ ] **003** — opened. Its decision log still says `server.yml` compiles `Shared` on Linux. This slice triples the size of `Shared`; without that job the Linux claim is unproven.
- [ ] **S003** — spike. **Answered on 2026-08-31 against 1175 real files; the fallback was not taken.** Do not re-derive the tag table from the plan — build it from the spike's Section 6, and confirm all five of these are in the code before the mapper is called done:
  - **`TPA` is a disc-number key.** 122 mp3s carry the disc number only there, and never alongside `disc`. Omit it and those files silently become disc 1.
  - **The lookup is case-insensitive on the whole key.** Not a precaution any more — FLAC mixes `ALBUM` and `album_artist` inside one file.
  - **`format.tags` is always present**, and `streams[].tags` held nothing album-related in 1175 files. Keep the second place, but never read `title` from it.
  - **`scan-report.json` is permanent scope**, and it now also carries the probable-grouping-miss section and the no-artwork-directory image field.
  - **Do not key compilations on the `compilation` tag.** It exists and it is wrong in 57 of 196 directories — see the rejected-alternative row in Section 6.
- [x] **S002** — spike, part 2, **answered 2026-09-01 and unfavourable**. `ffprobe` was *not* discoverable from a `Process` that did not inherit a login shell's PATH, so the fallback applies: `MIXTAPE_FFPROBE_PATH` and `MIXTAPE_FFMPEG_PATH` are in this slice's scope, along with the `terminationStatus` check the spike's silent-failure finding forces. Two decision rows in Section 6, two acceptance criteria below.
- [ ] **Blocker B1 is resolved — confirm the resolution before starting the grouping code.** The project owner chose **one tile per disc**, so the album key `(albumArtist, title, discNumber)` stands unchanged and this slice's schema is unaffected. Two requirements ride on top of it, both landing in slice 007 rather than here: discs of one release must always render adjacently, and the disc-set shape is carried as a domain type. The only *scan-side* consequences are the two decision rows added below — `discCount` consistency across a release, and fork **F6**'s title stripping. If either is missing from Section 6, stop.
- [ ] Architecture standards doc re-read: `docs/plan/v1-architecture.md` sections 1 and 4.

**Drift found:** `none` — or what changed, plus a row in the checklist's Drift Log.

## 5. Acceptance Criteria

- [ ] Scanning a fixture library produces a `library.json` whose album count matches the expected count by hand.
- [ ] **With `ffprobe` unreachable, the scan fails loudly rather than producing an empty manifest.** Prove it the way S002 proved the hazard: run the server with a scrubbed `PATH` (`env -i PATH=/usr/bin:/bin:/usr/sbin:/sbin`) and no `MIXTAPE_FFPROBE_PATH` set. The scan must report the failure; a valid `library.json` with zero albums is the failure this criterion exists to catch, not a pass.
- [ ] **With `MIXTAPE_FFPROBE_PATH` set to the absolute path, the same scrubbed-PATH run succeeds.** The pair of runs is the criterion — either alone proves nothing.
- [ ] **A compilation with twelve distinct track artists and no album-artist tag produces exactly one album**, titled from the directory, with `albumArtist == "Various Artists"` and twelve tracks. This is the criterion the whole schema exists for.
- [ ] A track with a guest feature (`artist == "A feat. B"`, `album_artist == "A"`) groups under `"A"` and keeps `"A feat. B"` as its `trackArtist`.
- [ ] An album whose files disagree on casing and spacing (`"The  Beatles "` versus `"the beatles"`) produces **one** album, stored with the original casing of the first file in sort order.
- [ ] **F6 — a two-disc release tagged `The Wall (Disc 1)` and `The Wall (Disc 2)`, with no disc tag at all, produces two albums both titled `The Wall`, with `discNumber` `1` and `2`.** This is the criterion the fork exists for, and it is what makes slice 007's grouping possible.
- [ ] **F6 conflict case — a title saying `(Disc 2)` while the disc tag says `1` keeps `discNumber == 1`**, and the discrepancy appears in `scan-report.json`. The tag wins over the title.
- [ ] A title with a legitimate trailing parenthetical that is not a disc marker — `Physical Graffiti (Remastered)`, `Hail to the Thief (Special Edition)` — is left **untouched**. Over-stripping is the failure this criterion guards.
- [ ] **A `.mp3` whose only disc tag is `TPA: 2/2` yields `discNumber == 2` and `discCount == 2`.** 122 files in the owner's library depend on this and every one of them fails silently without it, so this criterion is checked against a committed fixture, not reasoned about.
- [ ] **A `.flac` whose tag keys mix case within one file — `ALBUM` uppercase, `album_artist` lowercase — maps every field correctly.** Fixture-driven, from the real FLAC sample S003 captured.
- [ ] `title` is never read from `streams[].tags`. A fixture whose `format.tags` has no `title` and whose `streams[0].tags.title` holds a stream label falls back to the **filename**, not to that label.
- [ ] **A directory where `compilation == "1"` on every file but all files share one `artist` does NOT become "Various Artists"** — it groups under that artist. The inverse also holds: a multi-artist directory with no `album_artist` and no `compilation` tag **does** become "Various Artists". These two are the 57-directory disagreement S003 measured, pinned as tests.
- [ ] `discCount` agrees across every disc of a release. A release where disc 1 is tagged `1/2` and disc 2 is tagged bare `2` yields `discCount == 2` on **both** albums. **Unit test only** — S003 found no bare disc tag in the owner's library, so no integration run exercises this.
- [ ] **A release whose `discCount` exceeds the discs actually found is flagged in `scan-report.json`,** every member of it, with the counts. Checked against the `Digital Domain` shape: two albums, correct `disc` tags of `1/2` and `2/2`, titles that differ by more than the disc marker. Both are flagged; **neither is merged**. This is the criterion that keeps F6's limitation visible instead of silent.
- [ ] A file with no tags at all still appears: title from the filename without extension, album from the parent directory, track number from filename sort order, disc `1`.
- [ ] A corrupt file that makes `ffprobe` exit non-zero is skipped, logged, counted in `skipped`, and listed in `scan-report.json`. **The scan completes.** One bad file never fails a scan.
- [ ] `revision` **changes** when a `cover.jpg` is added to an album directory and the library is rescanned. This is fork **F1** and it is the criterion that proves it.
- [ ] `revision` is stable across two scans of an unchanged library — byte-identical.
- [ ] `revision` changes when a file is added, removed, or its byte size changes.
- [ ] Booting with `library.json` present performs **no** scan. Verified by timing and by the absence of any `ffprobe` process, not by a log line.
- [ ] Booting with no snapshot scans, then serves.
- [ ] `library.json` is written atomically — a kill during a scan leaves either the old valid file or no file, never a truncated one.
- [ ] Scanning a fixture of 2000 albums completes, and the resulting JSON is inspected for size against the plan's ~5 MB estimate. If it is wildly off, that is a finding for slice 006's `ETag` and gzip design, and it goes in the Drift Log.
- [ ] No `@Model`, no SwiftData, nothing Apple-only enters `Shared`. `server.yml` is green.

## 6. Decision Log

**Write the row before you implement the decision, not after.** This is the whole mechanism. A decision log filled in at close is reconstructed from memory, and the rejected alternatives — the part the next slice's pre-flight actually needs — are exactly what memory loses first.

| Date | Decision | Alternatives rejected | Why |
|---|---|---|---|
| 2026-09-01 | **`ffprobe` and `ffmpeg` are located through `MIXTAPE_FFPROBE_PATH` and `MIXTAPE_FFMPEG_PATH`, read into `ServerConfiguration` like every other variable, defaulting to resolution through `/usr/bin/env` and overridable to an absolute path.** The Docker image sets neither, because the bundled tools are already on `PATH` there | Resolve through `PATH` alone; hardcode `/usr/local/bin/ffprobe`; hardcode `/opt/homebrew/bin/ffprobe`; probe a list of candidate directories at boot | **This is S002's pre-decided fallback, applied as written after part 2 came back unfavourable.** The tools are at `/opt/homebrew/bin` on Apple silicon, which a process launched outside a login shell does not inherit: `/usr/bin/env ffprobe` exits `127` under a scrubbed PATH while the absolute path works. Hardcoding either Homebrew prefix breaks the other architecture and the container; probing candidates is a guess that fails silently on the machine that has neither. Two variables cost two lines here and nothing in the image |
| 2026-09-01 | **A non-zero `terminationStatus` from `ffprobe` is a hard, reported failure — never an empty tag set** | Treat empty output as "no tags" and continue; rely on `do`/`catch` around `process.run()` | **S002 measured the failure mode and it is silent.** `/usr/bin/env` launches successfully even when the binary is not found — the `Process` does not throw, `env` itself exits `127`, and stdout is empty. A `catch` sees nothing. Without an explicit status check, a machine with no reachable `ffprobe` produces a complete, valid, entirely empty manifest and no error anywhere. That is the same shape as the faults in the checklist's Drift Log that read as satisfied while the thing they protect is broken |
| 2026-08-31 | **F1 — `revision` includes `hasArtwork` per album, a fork from the plan's definition** | The plan's definition (album ids, track ids, byte sizes only); a separate artwork revision; a client-side artwork poll | Under the plan's definition, adding `cover.jpg` to an album directory and rescanning produces an identical `revision`. Slice 006 then answers `304`, and the client never learns the artwork exists. `hasArtwork` is a `Bool` per album already in the DTO; hashing it costs nothing and closes a silent failure. **This is a fork — the plan's Section 4 text is now wrong on this point** |
| 2026-08-31 | Album ids are tag-derived, track ids are path-derived | Both path-derived; both tag-derived; UUIDs persisted in a sidecar | Straight from the plan, recorded here because slice 010 and slice 011 depend on the asymmetry: a tag-derived album id lets a downloaded album survive a rescan, and a path-derived track id means a retag does not orphan a downloaded file. The cost — a file *move* mints a new track id and strands the downloaded bytes — is accepted here and handled in slice 011 |
| 2026-08-31 | `scan-report.json` is permanent scope, not a debugging aid | Log lines only; nothing | A scan that silently produces a wallet of one-track albums is the expected failure mode, and log lines in a container on a NAS are not where anyone will look. This is also **S003**'s fallback, so it earns its place twice |
| 2026-08-31 | No filesystem watch in v1 (ladder **L3**) | `FSEvents`/`inotify` watcher; a periodic timer rescan | The seam is `LibraryScanner.scan()`. A watcher calls the same method. A timer would scan a large library repeatedly for no benefit on a library that changes weekly |
| 2026-08-31 | In-memory `actor LibraryIndex` plus a JSON snapshot (ladder **L4**) | GRDB; SQLite directly | The seam is the actor's method surface. The plan judges a personal library will never outgrow this and that is almost certainly right — but the actor exists either way, so the seam is free |
| 2026-08-31 | Ogg Vorbis is out of scope (plan conflict **C7**) | Add it; transcode it | AVFoundation does not play it natively and the server never transcodes. Recorded so it is a decision on the record rather than an omission |
| 2026-08-31 | **B1 resolved — one tile per disc. The album key `(albumArtist, title, discNumber)` stands unchanged** | Group discs under one album and key tracks on `(discNumber, trackNumber)` | **The project owner's call.** One physical disc, one slot, which is the CD-wallet metaphor taken literally. The schema in the plan is correct as written and needs no migration. The owner's two added requirements — always-adjacent discs, and a disc-set type — are satisfied entirely in the app (slice 007) with **no DTO and no server change**, because `(albumArtist, title)` and `discCount` are already present |
| 2026-08-31 | `discCount` is made consistent across a release: every album sharing `(albumArtist, title)` gets the **maximum** `discCount` observed among them | Store each disc's own tag value verbatim; leave `nil` where a disc's tag lacks the `N/M` form | Rippers commonly write `1/2` on disc 1 and a bare `2` on disc 2, so the discs of one release disagree about how many discs exist. Slice 007 derives the "of N" label from this field; an inconsistent value makes disc 1 say "of 2" and disc 2 say nothing. Taking the maximum is a set-wide reconciliation done while the whole album set is already in hand |
| 2026-08-31 | **F6 — a trailing disc marker is stripped from the album title into `discNumber`. A fork from the plan's tag mapping** | Take the `album` tag verbatim, as the plan specifies; strip nothing and accept ungrouped discs; strip anywhere in the title, not just the end | The plan maps album title to the `album` tag verbatim. But `The Wall (Disc 1)` and `The Wall (Disc 2)` produce two different `(albumArtist, title)` keys, so the two discs **do not group** — a direct failure of the requirement the owner added when resolving B1, on very common ripper output. Stripped conservatively: a trailing `(Disc N)`, `[Disc N]`, `- Disc N`, `CDN` or `Disk N` only, case-insensitive, at the end of the title. **On conflict with an explicit disc tag, the tag wins and the discrepancy is logged** — a title saying `Disc 2` while the tag says `1` is bad metadata, not an instruction. Note this changes `AlbumDTO.id`, which hashes the title; acceptable because nothing has shipped. Gated on **S003** question 5, which reports how often it matters |
| 2026-08-31 | **`TPA` is added to the disc-number keys, and the tag lookup is case-insensitive on the whole key. Both are corrections to the plan's Section 4 table, from S003's data** | Ship the plan's key list as written; add `TPA` only for `.mp3`; case-sensitive exact-match lookup | **S003 measured this, it is not a guess.** 122 files carry `TPA` — the ID3v2.2 "part of set" frame — and it never co-occurs with `disc` (`TPA`-only 122, `disc`-only 559, both 0), consistent with ffprobe normalising the v2.3/v2.4 frame to `disc` and passing the v2.2 frame through raw. Omitting it puts 122 files on `discNumber = 1` **silently**, which breaks the multi-disc Pharmacy sets outright. `TPA` also arrives in the `N/M` form, so it feeds `discCount` unchanged. Not gated on container type, because keying a tag lookup off the file extension is a second thing to get wrong for no gain. Case-insensitivity is likewise no longer defensive: FLAC writes `ALBUM`/`TITLE`/`ARTIST`/`DATE` uppercase alongside `album_artist`/`track`/`disc` lowercase **within a single file**. **This is a Drift Log entry, not a fork** — the plan's table was factually incomplete, not a considered decision this slice is departing from |
| 2026-08-31 | The `format.tags` → `streams[].tags` two-place lookup is kept, but `title` is **never** read from the second place | Drop the second place entirely, since it never fired; read every key from both places uniformly | S003 found `format.tags` present on all 1175 files and `streams[].tags` carrying nothing album-related, so the second place is unexercised — but the owner's library contains no Ogg or Vorbis-comment container at all, which is the case the plan added it for, so "it never fired" is not evidence it never will. The `title` carve-out is the real finding: `streams[].tags.title` **exists** and is a stream label, not the track title, so a uniform second-place lookup would read the wrong value on any file missing `format.tags.title` |
| 2026-08-31 | **Compilations are detected by the plan's directory rule. The `compilation` tag is rejected as a signal** | Key on `compilation == "1"`; use it as a tie-breaker alongside the directory rule | It looks like the better signal and it is not, by a wide margin. S003 measured it against directory contents: **wrong in 57 of 196 directories** — 41 flagged as compilations while holding a single artist, 16 genuinely multi-artist directories not flagged. It is an iTunes UI flag, set by whoever imported the file, and nothing keeps it true. The plan's rule — no `album_artist` anywhere in the directory **and** more than one distinct `artist` — fires on 7 directories and matches reality on all of them. Recorded with the numbers because the tag is visible in every probe output and will otherwise be proposed again |
| 2026-08-31 | **F6's claim is narrowed: title stripping is a normalisation that improves grouping, not a guarantee that discs group. The residue is detected and reported rather than hidden** | Leave F6 claiming the adjacency guarantee; drop F6 entirely now that the data shows it rare; make `ReleaseKey` tolerate a differing suffix so near-miss titles merge | **S003 question 5 found only 2 of 166 titles carry a marker, and the single real multi-disc case defeats F6**: `Digital Domain [Disc 1]` and `Digital Domain - Nikfish.com.au [Disc 2]` strip to `Digital Domain` and `Digital Domain - Nikfish.com.au`, which are still two keys. Keeping F6 anyway, because its cost is one tested function and it still catches the clean `The Wall (Disc 1)`/`(Disc 2)` shape that is common outside this library; dropping it would trade a real capability for nothing. **Suffix-tolerant keys rejected outright** — a rule loose enough to merge `Digital Domain` with `Digital Domain - Nikfish.com.au` also merges `Greatest Hits` with `Greatest Hits Vol 2`, and a wrong *merge* destroys an album while a wrong *split* only annoys. So the residue is made visible instead: the probable-grouping-miss section flags any release whose `discCount` exceeds the discs found, which flags this pair twice. The fix for the real case is the owner retagging one album title, and the report is what tells them to |
| 2026-08-31 | `discCount` max-reconciliation is kept, with its justification downgraded from "rippers commonly disagree" to "cheap insurance against a case this library does not contain" | Remove it now that the data says it never fires | The original row asserted that rippers commonly write `1/2` on disc 1 and a bare `2` on disc 2. **S003 refutes that for this library**: 681 disc tags, 681 in `N/M` form, zero bare. The reconciliation therefore never fires here and **its unit test is the only thing exercising it** — which is stated so nobody reads a green integration run as coverage. Kept because it is a `max()` over a set already in hand, and because removing it would make the first bare-tagged rip a silent "Disc 2" with no "of N" |

## 7. Sub-Slices

Split once: **[004a](004a-album-artwork-extraction.md)** covers artwork extraction. The scan produces a correct manifest with `hasArtwork` computed but no image files written; 004a writes the images. The split is real because the manifest is inspectable and correct without a single image existing, and artwork extraction is the part that shells out to `ffmpeg` rather than `ffprobe`.

## 8. Testing Strategy

- **Unit:** the tag mapper and the fallback table, against **fixture ffprobe JSON committed to the repository** rather than against real files. That keeps the suite hermetic and fast, and lets the awkward cases — missing tags, `3/12` track numbers, tags only in `streams[]` — be checked deterministically.
- **Where the real fixtures are, and what they do not cover.** [`docs/slices/S003-evidence/`](S003-evidence/) holds three real `ffprobe` outputs from the owner's library — a FLAC mixing tag case within one file, an mp3 carrying its disc number in `TPA`, and one half of the `Digital Domain` disc-marker pair. Use those three verbatim; each is a shape nobody would have invented, and two of them are the direct evidence behind decisions in Section 6. **Be clear about what this is not: the unit tests are table-driven from those three cases plus rows written by hand, not from 1175 real files.** The full probe set was deliberately not committed — it is regenerable, and [`S003-evidence/README.md`](S003-evidence/README.md) carries the command. So a tag shape that is absent from the owner's library is **still uncovered**, and four of the seven walked extensions have no real-data fixture at all. The safety net for that gap is `scan-report.json`'s unused-tag-key list, not this suite.
- **Unit:** the **F6** title stripper, as a table of input title to expected `(title, discNumber?)`. It needs both directions: every marker form stripped, and every innocent trailing parenthetical preserved. Over-stripping silently renames albums, so the negative cases matter more than the positive ones.
- **Unit:** `discCount` reconciliation across a release, including the disc-1-has-it-disc-2-does-not case.
- **Unit:** id derivation. Two files whose tags differ only in casing and whitespace must produce the same album id. Assert the id's literal hex value against a hand-computed constant, so a change in the canonicalisation is caught rather than absorbed.
- **Integration:** a small fixture music tree of real (tiny) audio files, scanned end to end, asserting the resulting `library.json`. This is the only suite that needs `ffprobe` present, so it is tagged and skippable when the binary is missing — but it runs in CI, where the container has it.
- **Test targets required:** `Server/Tests/ServerTests/`, created by slice 001. Swift Testing, suites tagged `.domain` for the mapper and `.repository` for the scan.

## 9. Keeping this document true

This slice is done when the page describes what was actually built — not when the code works. The discipline is **ordering**: the write happens *before* the thing it describes, so it sits on the critical path instead of after it, where it gets skipped.

| Before you… | Write this first |
|---|---|
| implement a decision | the Section 6 row, including what you rejected |
| start work | flip status in the master checklist |
| stop on a blocker | the Active Blockers row |
| build on a spike | that spike's Result section |
| widen scope | Section 3, and `depends_on` on any slice that is now affected |

And in the same commit as the code, not a follow-up: **commit this file alongside it**, with the slice id in the commit subject (`004: add library scan`).

Nothing checks any of this. That is the point of putting the writes first — a write you have to do to proceed is one you do; a write you are supposed to do afterwards is one you do not.

## 10. Definition of Done

- [ ] Acceptance criteria met
- [ ] Tests passing, in a target that exists
- [ ] Every `covers:` requirement satisfied, or forked with a decision row — **F1 and F6 are forks and each has one**
- [ ] Decision log written as you went, not reconstructed
- [ ] Pre-flight completed and drift resolved
- [ ] Master checklist row current. **B1 is already resolved**; confirm its decision row here matches the checklist's resolution
- [ ] `next_slice`'s `depends_on` reflects what actually shipped, not what was planned
- [ ] Both link directions checked: this page's `next_slice` and `004a`'s `previous_slice`

---
spike_id: "S003"
title: Does the plan's tag-mapping table match real ffprobe output across the owner's actual library?
timebox: 4 hours
unblocks: ["004", "004a"]
created: 2026-08-31
---

# S003 — ffprobe output shape against the real library

[Master Checklist](MASTER-CHECKLIST.md) · Unblocks: [004-library-scan-to-manifest](004-library-scan-to-manifest.md), [004a-album-artwork-extraction](004a-album-artwork-extraction.md)

> **Status, owner and the answer summary live in the master checklist, not here.** This page holds the question, the method, the fallback and the evidence. One fact, one home.
>
> **This spike was assigned to the project owner, because it needed their library.** It was a spike, not a question — commands and output, no design decision asked of them. **It ran on 2026-08-31 over all 1175 files and is answered**; Section 3 records the method as executed, Section 6 the results, and [`S003-evidence/`](S003-evidence/) the samples kept.

## 1. Question

Across a real library, what fraction of files does the plan's tag-mapping table read correctly, and which of its assumptions are wrong?

Five concrete values are wanted, not an impression:

1. How many files produce a `format.tags.album_artist` (or a listed variant) at all — this drives how often the "Various Artists" compilation rule fires.
2. Do any files put tags **only** in `streams[].tags` and not in `format.tags`? The plan says FLAC and Vorbis-comment containers differ; this confirms which, and whether the two-place lookup is actually needed.
3. Are there tag keys in real use that the plan's table does not list — `TPE2`, `ALBUM ARTIST` with a space, `album artist`, `Album Artist`?
4. Does `disposition.attached_pic == 1` actually appear on embedded artwork in `.flac` files, or only in `.m4a` and `.mp3`? FLAC stores pictures in a `METADATA_BLOCK_PICTURE` block, which ffprobe may or may not surface as a video stream with that disposition.

5. **How many albums carry the disc marker in the album *title* rather than in a disc tag?** Titles like `The Wall (Disc 1)`, `The Wall CD2`, `Sign o' the Times [Disc 2]` are common ripper output. And separately: what fraction of multi-disc releases carry the `N/M` form in the `disc` tag, so `discCount` is populated at all? Both numbers drive slice 004's fork **F6**.

## 2. Why this blocks

Slice 004's entire tag-mapping table and its fallback table are written from documentation, not from data. The plan says *"confirmed by inspection at plan time"* about Linux-cleanliness, but says nothing of the sort about tag shapes — that table is an assumption.

The consequence of getting it wrong is not a crash. It is a library that scans "successfully" and produces a wallet full of one-track albums, which is precisely the failure the `(albumArtist, title, discNumber)` key exists to prevent. That failure is silent, and it is only visible against real data.

Question 4 blocks **slice 004a** specifically: if FLAC artwork does not surface as `attached_pic`, the preferred artwork source is unavailable for the most likely format in a self-hoster's library, and 004a leans entirely on the `cover.jpg` fallback.

Question 5 blocks the **release grouping the project owner added when resolving B1**: discs of one release must always sit adjacent in the grid. Grouping is keyed on `(albumArtist, title)`, so a title carrying `(Disc 1)` versus `(Disc 2)` produces two *different* release keys and the two discs do not group. That is a direct failure of the owner's stated requirement, on data that is common rather than exotic.

## 3. Cheapest experiment that answers it

Run against the owner's real music directory. Read-only — nothing writes to the library.

**This section is now the record of what was actually done, not the plan it started as.** As drafted it proposed a hand-picked sample of awkward cases and "three commands". What ran on 2026-08-31 was broader and cheaper than that, and the difference matters when reading the counts in Section 6.

- [x] **Every audio file in `/Volumes/Music/Music` was probed, not a sample** — all 1175, across all seven extensions the scan walks. Sampling was abandoned because the parallel `find`/`xargs` pass costs about two minutes, and a sample can only ever confirm the shapes whoever picked it already suspected. `TPA` was not on anyone's list of suspects; a sample would very likely have missed it.
- [x] One `ffprobe -v quiet -print_format json -show_format -show_streams` per file, each output given an added `sourcePath` key so figures could be grouped back by directory — which is what made the by-directory counts (196 album directories, 72 with no album artist, 171 with no artwork) possible at all. The exact command is recorded in [`S003-evidence/README.md`](S003-evidence/README.md) with `$MUSIC` parameterised.
- [x] Every figure in Section 6 came from a `jq` aggregation over that full set, so all five questions are answered against the whole library rather than against a subset.
- [x] **A sixth thing was measured that was not asked for**: the reliability of the `compilation` tag, checked against each directory's actual artist spread. It is a tested negative and it is in Section 6.
- [x] Three representative outputs and the raw counts were preserved in [`S003-evidence/`](S003-evidence/); the 4.7 MB bulk was not. See Section 7.

**The aggregations as run.** Each figure in Section 6 came from one of these, over the full probe set in `$OUT` — the directory the regeneration command in [`S003-evidence/README.md`](S003-evidence/README.md) rebuilds. They are kept here because they are the method, and because that README points at this page for them.

```sh
# Q1 — album-artist coverage, and the by-directory split
jq -r 'select(.format.tags | to_entries | map(.key | ascii_downcase) | index("album_artist")) | .sourcePath' "$OUT"/*.json | wc -l
jq -r '.sourcePath' "$OUT"/*.json | sed 's|/[^/]*$||' | sort -u | wc -l

# Q2 — is anything album-related only in streams[].tags?
jq -r '.streams[]?.tags // {} | keys[]' "$OUT"/*.json | sort -u
jq -r 'select(.format.tags == null) | .sourcePath' "$OUT"/*.json | wc -l

# Q3 — every distinct format-level tag key actually in use
jq -r '.format.tags // {} | keys[]' "$OUT"/*.json | sort | uniq -c | sort -rn

# Q4 — embedded artwork by container
jq -r 'select(.streams[]?.disposition.attached_pic == 1) | .sourcePath' "$OUT"/*.json | sed 's|.*\.||' | sort | uniq -c

# Q5 — disc markers in titles, and the N/M form
jq -r '.format.tags.album // .format.tags.ALBUM // empty' "$OUT"/*.json | sort -u | grep -Eic '(\(|\[)?\b(disc|disk|cd) ?[0-9]'
jq -r '.format.tags.disc // .format.tags.DISCNUMBER // .format.tags.TPA // empty' "$OUT"/*.json | sort | uniq -c

# Tested negative — the compilation tag against each directory's real artist spread
jq -r '[.sourcePath | sub("/[^/]*$";""), (.format.tags.compilation // "0"), (.format.tags.artist // "")] | @tsv' "$OUT"/*.json | sort -u
```

**Explicitly not done, as intended:** no scanner, no DTO mapping, no Swift at all. This spike produced JSON and counts.

**It took roughly 20 minutes of wall clock against a four-hour timebox** — about two minutes to probe all 1175 files, the rest jq aggregation and follow-up checks. All five questions were answered, plus the compilation-flag test, and the Section 5 fallback was not taken on any of them. Worth recording next to the findings: the spike that corrected the plan's tag table and inverted its artwork premise cost a twelfth of the time set aside for it.

## 4. Timebox

`4 hours`. On expiry: stop, record what you learned, and take the fallback in Section 5. An overrunning spike is itself an answer — the thing is harder than the design assumed.

## 5. Fallback if the answer is unfavourable

Decided **before** running the experiment, so the result does not get argued with.

> **If the spike does not run, or the library is not available:** slice 004 ships the plan's table exactly as written, **plus** two things that make the gap recoverable rather than silent:
>
> 1. The tag lookup is case-insensitive on the *whole key* and strips spaces and underscores before comparison, so `TPE2`-style aliases are the only thing a miss can be. This is a wider net than the plan's literal key list at no extra cost.
> 2. The scan writes `<cacheDir>/scan-report.json` listing every file where no album-artist tag was found and every distinct tag key it saw but did not use. That report answers this spike's questions after the fact, from the first real scan, without anyone running `jq`.
>
> **If question 4 comes back negative for FLAC:** slice 004a reorders its sources — directory `cover.jpg`/`folder.jpg`/`front.jpg` is tried **first** for `.flac`, embedded first for everything else. Recorded as a decision row in 004a, not as new scope.
>
> **If question 5 does not run:** slice 004 ships fork **F6**'s title stripping anyway, with the conservative pattern set — a trailing `(Disc N)`, `[Disc N]`, `- Disc N`, `CDN` or `Disk N`, matched case-insensitively at the **end** of the title only. The failure mode of not stripping is ungrouped discs, which is precisely the requirement the owner added when resolving B1, so the default is to strip rather than to wait. Anything stripped is recorded in `scan-report.json` so a wrong strip is visible.

## 6. Result

Run against `/Volumes/Music/Music`: **1175 files, 196 album directories, 166 distinct album titles**. Containers: 728 `.m4a`, 340 `.mp3`, 107 `.flac`. **No `.wav`, `.aiff`, `.aif` or `.aac` at all** — 004 still walks all seven extensions, but four of them are unexercised by this library.

| | |
|---|---|
| **Album-artist coverage** | **479/1175 files = 40.8%.** FLAC 107/107 (100%), mp3 175/340 (51%), m4a 197/728 (27%). By directory: **72 of 196 have `album_artist` on no file at all**; of those, **7** have more than one distinct `artist` and fire the "Various Artists" rule, and **65** are single-artist and fall back to `artist`. The plan's fallback table is not a safety net here, it is the main path for over half the library |
| **Tags in `streams[].tags` only?** | **No — zero.** Every one of the 1175 files has `format.tags`, and no file has no tags anywhere. `streams[].tags` carry only `language`, `creation_time`, `encoder`, `comment`, `handler_name` and `title` — nothing album-related. The two-place lookup never fires on this library. **Hazard noted:** `streams[].tags.title` exists and is *not* the track title, so a naive second-place lookup for `title` would read the wrong value |
| **Unlisted tag keys found** | **`TPA` — 122 files, mp3 only. The ID3v2.2 "part of set" frame, i.e. the disc number, and the plan's table does not list it.** It never co-occurs with `disc` (TPA-only 122, `disc`-only 559, both 0; 122 + 559 = the 681 total below), consistent with ffprobe normalising the v2.3/v2.4 frame to `disc` and passing the v2.2 frame through raw. Without `TPA`, 122 files silently take `discNumber = 1`. **FLAC mixes case within a single file** — `ALBUM`/`TITLE`/`ARTIST`/`DATE` uppercase alongside `album_artist`/`track`/`disc` lowercase, which turns the case-insensitive whole-key lookup from a cheap precaution into a requirement. Also present and deliberately unused: `compilation`, `sort_album`, `sort_artist`, `sort_album_artist`, `iTunNORM`, `iTunSMPB`, `gapless_playback`, and the ID3v2.2 sort/composer frames `TSA`, `TS2`, `TT1`, `TSC`, `TSP`, `TSS`, `TCM`, `TST`, `TBP` |
| **`attached_pic` per container** | **Inverted from what the plan feared. FLAC 107/107 (100%), codec mjpeg — the plan's FLAC worry is unfounded and its contingency never fires.** The hole is elsewhere: **mp3 0/340 — not one mp3 has any video stream at all**, verified directly rather than inferred; m4a 82/728 (11%), codecs mjpeg and png. By directory: **25 of 196 have an embedded source, 171 do not**, and there are **exactly 3** `cover.jpg`/`folder.jpg`/`front.jpg` files on the whole disk. **171 of 196 album directories — 87% — have no artwork source of any kind** |
| **Titles carrying a disc marker** | **2 of 166 distinct titles** — rare, and **the one real case defeats fork F6 as specced**. The pair is `Digital Domain [Disc 1]` and `Digital Domain - Nikfish.com.au [Disc 2]`. Stripping the trailing marker leaves `Digital Domain` versus `Digital Domain - Nikfish.com.au`, still two different release keys, so the discs still do not group. Both have correct `disc` tags (`1/2` and `2/2`) and neither carries an `album_artist`, so both fall back to `artist == "Nik Fish"`. See 004 §6 for what F6 became |
| **`disc` tags in `N/M` form** | **681 present, 681 in `N/M` form, zero bare — 100%.** Distinct values: `1/1` ×557, `1/2` ×71, `2/2` ×50, `3/3` ×1, `2/3` ×1, `1/3` ×1. **004's `discCount` max-reconciliation therefore never fires on this library**; it is retained defensively and only its unit test exercises it. Multi-disc releases present: The Wall (Remastered 2011 Version), Pharmacy Volumes 1/2/3/5, Back 2 Back Vol.2, Bass Station Global Movement 1, Hard Trance, Live At Trance Escape, Live at SSL Crash Part 2001, Digital Domain |
| **Tested negative — the `compilation` tag** | Not one of the five questions, but tested because it looks like a better compilation signal than the plan's directory heuristic. **It is not, and it must not be adopted.** `compilation` appears on 782 files, 199 set to `"1"`. It disagrees with the directory contents in **57 of 196 directories** — 41 flagged as compilations with a single artist, 16 multi-artist directories not flagged. The plan's own rule fires on 7 directories and is sound. Recorded as a rejected alternative in 004 §6 so nobody proposes it later |
| **Evidence** | [`S003-evidence/`](S003-evidence/) — [`findings.md`](S003-evidence/findings.md) with every count and the method, plus the three cases the counts alone do not convey: [`flac-mixed-case-tags.json`](S003-evidence/flac-mixed-case-tags.json), [`mp3-TPA-disc-tag.json`](S003-evidence/mp3-TPA-disc-tag.json), [`disc-marker-in-title.json`](S003-evidence/disc-marker-in-title.json). 16 KB in total. The 1175-file, 4.7 MB probe set behind the figures was **deliberately not kept** — generated data, stale the moment anything is retagged, and about two minutes to regenerate from the command in [`S003-evidence/README.md`](S003-evidence/README.md) |
| **Date** | 2026-08-31 |

## 7. Consequences

- [x] Decision recorded in the decision log of: `004-library-scan-to-manifest.md` — `TPA`, the proven case-insensitivity requirement, the `streams[].tags` finding, what F6 became, the `discCount` downgrade, and the rejected `compilation` tag. And `004a-album-artwork-extraction.md` for question 4.
- [x] Affected slices updated (scope, dependencies, acceptance criteria): **004** and **004a**. Beyond the two this spike named: **007**, because question 4 makes the no-artwork placeholder the grid's dominant state rather than an edge case, and **B3** is re-ranked in the checklist for the same reason.
- [x] Master checklist spike row set to `Answered`, with the one-line answer.
- [x] **Throwaway probe output resolved by splitting it: the small evidence kept, the bulk dropped.** [`S003-evidence/`](S003-evidence/) holds `findings.md` and the three awkward-case probes — 16 KB, and each one is a shape nobody would have invented. The 1175-file, 4.7 MB set was **not** kept: it is generated data that is stale as soon as a file is retagged, and `README.md` records the command that rebuilds it in about two minutes with `$MUSIC` parameterised. Nothing was copied into `Server/Tests/ServerTests/Fixtures/` — **slice 001 has not run, so `Server/` does not exist**, and inventing a directory ahead of the slice that owns it would have put a fixture path in the tree before the test target that reads it.
- [x] The answer invalidated a prior decision: **Architecture Drift Log updated with two rows** — the plan's Section 4 tag table (missing `TPA`, exactly the drift this checkbox anticipated), and the artwork inversion (the plan's artwork-centric premise and B3's "pure taste" ranking both stopped holding at 87% coverage-free). **The FLAC contingency in Section 5 got no drift row**: it did not fire, and a contingency that does not fire is a normal spike outcome, not a decision that stopped holding.

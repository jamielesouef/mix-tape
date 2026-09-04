---
slice_id: "017"
title: Spec document reconciliation
priority: P2
complexity: S
ladder: none
depends_on:
  - { id: "016", type: hard, note: "last of the round — this slice reconciles the documents against what shipped, so it must run after everything that changes what shipped" }
  - { id: "013", type: hard, note: "013, 014, 015 and 016 each amend coverage rows and close triage items; this slice checks the result is consistent rather than repeating those edits" }
previous_slice: "016"
next_slice: none
parent_slice: none
covers: []
created: 2026-09-04
---

# 017 — Spec document reconciliation

← [previous](016-tvos-library-list.md) · [Master Checklist](MASTER-CHECKLIST.md) · none →

> **Status, owner and blockers live in the master checklist, not here.** Dependencies live in this page's front matter and nowhere else. Each fact has one home; if you find yourself writing it twice, one of the two copies is going to be wrong in a fortnight.

## 1. Objective

`docs/engineering-doc.md` stops contradicting the code. Observable on its own: an auditor
reading §8 and §9 against the tree raises no false defects — which today produces seven.

## 2. Business Value & Priority

The code follows `SPEC-DECISIONS.md`. The engineering doc was never edited to match, despite
several decisions saying it had been. Seven statements in the file `CLAUDE.md` calls the
source of truth are now wrong:

| Line | Says | Superseded by |
|---|---|---|
| 631 | `HomeScreen \| Continue Watching row, Recently Added per library` | decision 13 — Recently Added dropped |
| 526 | `/Items/Resume` | decision 6 — `/UserItems/Resume` |
| 570, 592 | `api_key={token}` | decision 7 |
| 592 | `maxStreamingBitrate=320000` | decision 43 |
| 443 | `AVPlayerLayer` | decision 18 |
| 508 | `GET /QuickConnect/Initiate` | decision 5 |
| 530 | `PlayedPercentage` | decision 8 — a field the server never sends |

This is P2 because none of it changes behaviour, and last because every slice ahead of it
moves something it would otherwise have to reconcile twice.

It is not, however, cosmetic. The `maxStreamingBitrate=320000` line is the exact value that
forced every ALAC and FLAC track through the transcoder and would have broken AC13f — the
doc still recommends it. An unattended build agent reading §8 has no way to know that line
lost an argument, and `CLAUDE.md`'s precedence rule only helps if the reader thinks to check
`SPEC-DECISIONS.md` for a contradiction it has no reason to suspect. The 2026-09-04
reconciliation nearly re-raised all seven as defects; a future audit will.

Three smaller inconsistencies close here too:

- `MASTER-CHECKLIST.md:13` says "Decisions 1–47 are binding". Decision 48 exists, is dated
  2026-09-04, and is already shipped in `Package.swift:7`, `RootTabScreen+iOS.swift` and six
  `pbxproj` build settings.
- Two coverage rows credit slices whose own `covers:` front matter omits the requirement:
  §1.8 credits 010 (`010-wallet.md` lists only §1.15 and §12.13a–e), and §1.13 credits 006
  (`006-video-avplayer-and-hls.md` lists only §1.10, §12.6, §12.8). Nothing checks the two
  representations against each other — the same duplication the checklist's own preamble
  warns about.
- All 12 V1 slices are `Done` and Active Blockers is empty, while three deferred follow-ups
  had no owning slice. This round gives them one; this slice confirms none were missed.

## 3. Scope

**In scope:**

- Correct the seven statements above in `docs/engineering-doc.md`, each with an inline
  reference to the decision that superseded it, so the correction is traceable and the next
  reader does not re-litigate it.
- Bump the checklist's "Decisions 1–47 are binding" line, and make it a reference to
  `SPEC-DECISIONS.md`'s highest decision rather than a hardcoded number that goes stale on
  the next decision.
- Fix the two coverage-row mismatches by updating the slices' `covers:` front matter to match
  the table — the table is right in both cases, and the Ordering Notes and Triage 2 both
  explain why.
- Run the whole "Before a build phase" checklist from `docs/slices/README.md` across the full
  set, 001–017 plus S001–S003, and fix what it finds.
- Confirm every triage item and fork either closed in this round or has an owning slice.
- Reconcile §13's build order with what was actually built: it lists eleven steps, numbers the
  last two both "11", and names XCUITests in a round that decision 4 deferred.

**Out of scope** (name the slice it's deferred to):

- Rewriting `AUDIT-FINDINGS.md` or `PREFLIGHT.md`. They are records of a moment, not
  standing specifications, and correcting them would destroy their value as records.
- Any code change. If reconciliation turns up a place where the *code* is wrong rather than
  the doc, that is a finding for a new slice, not a fix smuggled into a documentation pass.
  Record it and stop.
- Re-opening settled decisions. This slice makes the doc say what was decided; it does not
  revisit whether the decision was right.
- Restoring CI. `CLAUDE.md` bars it until the MVP and its local tests exist, and the deleted
  workflows stay deleted.

**Plan requirements covered:** none. This slice claims no §1 capability and no §12 criterion.
Its gate is the README's cross-document checklist plus the standard build, test, layer, glass
and lint run.

## 4. Pre-Flight Validation

- [ ] **016** — opened, and every slice ahead of it in this round is `Done`. Running this
      before the round finishes means reconciling documents that are still moving.
- [ ] **013** — opened. Confirm which coverage rows 013's S003 outcome changed: if the spike
      came back unfavourable, §12.15 now names 013 alongside 012 and this slice must not
      "correct" that back.
- [ ] Re-read `SPEC-DECISIONS.md` end to end and confirm the seven corrections in Section 2 are
      still the complete list — decisions 49+ may have been added during the round, and each
      one is a candidate for the same drift.
- [ ] Confirm no slice in the round widened its own `covers:` without the coverage table
      following. The mismatch this slice fixes was created exactly that way.

**Drift found:** `none` — or what changed, plus a row in the checklist's Drift Log.

## 5. Acceptance Criteria

- [ ] **AC17a** — Each of the seven statements in Section 2 now matches the code, and each
      carries the decision number that changed it.
- [ ] **AC17b** — Grepping `docs/engineering-doc.md` for `maxStreamingBitrate`, `api_key=`,
      `/Items/Resume`, `AVPlayerLayer`, `PlayedPercentage`, `QuickConnect/Initiate` and
      `Recently Added` returns either nothing or a line that names the superseding decision.
- [ ] **AC17c** — Every `next_slice` has a matching `previous_slice` on its target, both
      directions, across 001–017.
- [ ] **AC17d** — Delivery order in the checklist matches the linked-list order.
- [ ] **AC17e** — Every `depends_on` id exists and there is no cycle.
- [ ] **AC17f** — Every requirement in the engineering doc's scope list and in
      `SPEC-DECISIONS.md` appears in some slice's `covers:` or has a fork row saying why not.
      §12.11 stays the one deliberate exception (0 Series, decision 14).
- [ ] **AC17g** — No slice's `covers:` claims a requirement its acceptance criteria cannot
      demonstrate, and no slice's `covers:` disagrees with the coverage table.
- [ ] **AC17h** — Every fork has a decision row naming what was rejected.
- [ ] **AC17i** — Every triage item is closed or has an owning slice that is not `Done`.
- [ ] The full gate passes — this slice touches documents, but a docs-only slice that skips
      the gate is how a stray edit to a fenced code block ships.

## 6. Decision Log

**Write the row before you implement the decision, not after.**

| Date | Decision | Alternatives rejected | Why |
|---|---|---|---|
| 2026-09-04 | The engineering doc is corrected in place, with each correction naming its superseding decision, rather than left stale under `CLAUDE.md`'s precedence rule | (a) Leaving it and relying on precedence — `SPEC-DECISIONS.md` outranks it anyway; (b) marking the whole file historical and promoting `SPEC-DECISIONS.md` to sole spec | Precedence only protects a reader who suspects a contradiction. An agent reading §8 to build a stream URL has no trigger to check, and the `maxStreamingBitrate=320000` line is live wrong advice that would break AC13f. Promoting the decisions file was rejected because it is a chronological log, not a specification — it reads as a sequence of amendments and would be far worse as the thing you consult first. |

## 7. Sub-Slices

Not split — delivered as a single slice.

## 8. Testing Strategy

- **Unit / Integration / UI:** none. This slice changes no code.
- **The README's cross-document checklist is this slice's test suite.** Run it as a checklist,
  item by item across the whole directory, not slice by slice — its whole purpose is catching
  faults that are invisible from inside any single document. Note that the original convention
  ran a `slice-set-review` skill here and that it is not installed on this machine; the manual
  walk is the equivalent, and skipping it because it is manual defeats the slice.
- **Standard gate:** build and test both schemes, layer, glass, swiftformat. Unchanged code
  must stay unchanged.
- **Test targets required:** none new.

## 9. Keeping this document true

| Before you… | Write this first |
|---|---|
| implement a decision | the Section 6 row, including what you rejected |
| start work | flip status in the master checklist |
| stop on a blocker | the Active Blockers row |
| widen scope | Section 3, and `depends_on` on any slice that's now affected |

Commit this file alongside the edits, with the slice id in the subject (`017: …`).

## 10. Definition of Done

- [ ] Acceptance criteria met
- [ ] Every `covers:` requirement satisfied, or forked with a decision row
- [ ] Decision log written as you went, not reconstructed
- [ ] Pre-flight completed and drift resolved
- [ ] Master checklist row current, and the round's slices all `Done`
- [ ] `next_slice` is `none` and no slice points at 017 except 016
- [ ] Any code fault found during reconciliation is recorded as a new slice, not fixed here

---
title: Master Slice Checklist
---

# Master Checklist — mixtape V1

**This file is the only home for status, owner and blockers.** Slice documents don't carry them. Dependencies are the reverse: they live in each slice's `depends_on` front matter and are not repeated here.

That split is deliberate. Every fact duplicated across two files becomes two facts that disagree — which is how a slice ends up declaring no dependencies while its own pre-flight and this checklist each say something different.

Derived from [`../engineering-doc.md`](../engineering-doc.md) and [`../../SPEC-DECISIONS.md`](../../SPEC-DECISIONS.md). **`SPEC-DECISIONS.md` outranks both docs**; where a slice departs from the engineering doc, the departure is a numbered fork with a decision row in the owning slice — see [Plan Forks](#6-plan-forks).

Empty below. Phase 2 populates it.

## 1. Slices

Ordered by delivery sequence — the same order as the linked list.

| # | Slice | Priority | Cx | Owner | Status | Link |
|---|---|---|---|---|---|---|

Status: `Not started` · `In progress` · `Blocked` · `In review` · `Done`

## 2. Spikes

Spikes are not deliverables and are not in the linked list, so they get their own table.

| # | Question | Timebox | Unblocks | Status | Answer |
|---|---|---|---|---|---|

## 3. Active Blockers

| Slice | Blocked on | Since | Note |
|---|---|---|---|

## 4. Architecture Drift Log

Drift found during a slice's pre-flight: something changed underneath a slice after it was drafted. Recorded here, not in the slice.

| Date | Slice | What changed | Slices affected | Resolution |
|---|---|---|---|---|

## 5. Requirement Coverage

Every in-scope capability from engineering doc §1 and every acceptance criterion from §12 maps to a slice, or to a fork row saying why not.

| Requirement | Source | Slice | Satisfied how |
|---|---|---|---|

**Known unverifiable:** acceptance criterion 11 (series → season → episode ordering) has no test data — the library holds 0 Series and 0 Episodes. No slice may claim it. See `SPEC-DECISIONS.md` decision 14.

## 6. Plan Forks

Where a slice deliberately departs from the engineering doc. A fork with no decision row is the failure this section exists to catch. Departures already settled in `SPEC-DECISIONS.md` are **not** forks — they are decisions, and they need no row here.

| # | Slice | Departs from | Decision | Rejected |
|---|---|---|---|---|

## 7. Unknown Triage

Questions raised mid-build. Each becomes a spike, a decision, or an explicit deferral — never an assumption.

| # | Question | Raised by | Disposition |
|---|---|---|---|

## Ordering Notes

Why the delivery sequence is what it is, where it isn't obvious from `depends_on` alone. Engineering doc §13 defines the build order and its shippable checkpoints; deviations from it belong here with a reason.

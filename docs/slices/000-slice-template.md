---
slice_id: "NNN"              # "001", or "001a" for a sub-slice. Quote it — YAML eats leading zeros.
title: <Slice Name>
priority: P1                 # P0 | P1 | P2
complexity: M                # S | M | L
ladder: none                 # or: "auth v1 of 2 — v2 is slice 011, shared seam: TokenProvider"
depends_on:                  # THE ONLY place dependencies are written. Nothing restates this.
  - { id: "S001", type: hard, note: "needs the middleware answer" }
  - { id: "003",  type: soft, note: "can stub" }
previous_slice: "NNN"        # or none
next_slice: "NNN"            # or none
parent_slice: none           # sub-slices only
covers: []                   # plan requirement IDs this slice delivers, e.g. ["7.1", "7.2"]
created: YYYY-MM-DD
---

# NNN — <Slice Name>

← [previous](NNN-name.md) · [Master Checklist](MASTER-CHECKLIST.md) · [next](NNN-name.md) →

> **Status, owner and blockers live in the master checklist, not here.** Dependencies live
> in this page's front matter and nowhere else. Each fact has one home; if you find yourself
> writing it twice, one of the two copies is going to be wrong in a fortnight.

## 1. Objective
One or two sentences. What this delivers, and what value is observable on its own without
any unbuilt slice landing first.

## 2. Business Value & Priority
Why this, why now. If this is a rung on a version ladder, name the deferred rung and **the
seam they share** — a ladder without a named seam is debt.

## 3. Scope

**In scope:**
-

**Out of scope** (name the slice it's deferred to):
-

**Plan requirements covered:** mirror the `covers:` list and say how each is satisfied. If a
requirement is deliberately *not* being built the way the plan describes, that is a fork —
record it in Section 6 as a decision. A fork with no decision row is the failure this
section exists to catch.

## 4. Pre-Flight Validation
Complete **before the first line of code**, not at close.

For **each id in `depends_on`**, in order — don't summarise, walk the list:

- [ ] Opened it. Its decision log still says what this slice assumed.
- [ ] If it's a spike: it's answered, and the answer — not the hoped-for answer — is what
      this slice is built on. Note whether the fallback was taken.
- [ ] Its state matches what this slice assumed when drafted, not when it was written.
- [ ] Architecture standards doc re-read; nothing changed underneath this slice.

**Drift found:** `none` — or what changed, plus a row in the checklist's Drift Log.

## 5. Acceptance Criteria
- [ ]

## 6. Decision Log

**Write the row before you implement the decision, not after.** This is the whole
mechanism. A decision log filled in at close is reconstructed from memory, and the rejected
alternatives — the part the next slice's pre-flight actually needs — are exactly what
memory loses first.

| Date | Decision | Alternatives rejected | Why |
|---|---|---|---|

## 7. Sub-Slices
Split with `NNNa`, `NNNb`. Each is a full slice doc with `parent_slice` set.
If not split: _"Not split — delivered as a single slice."_

## 8. Testing Strategy
- **Unit / Integration / UI:**
- **Test targets required:** name them. If a target doesn't exist, creating it is this
  slice's job or a dependency's — don't assume there's somewhere for the tests to run.

## 9. Keeping this document true

This slice is done when the page describes what was actually built — not when the code
works. The discipline is **ordering**: the write happens *before* the thing it describes,
so it sits on the critical path instead of after it, where it gets skipped.

| Before you… | Write this first |
|---|---|
| implement a decision | the Section 6 row, including what you rejected |
| start work | flip status in the master checklist |
| stop on a blocker | the Active Blockers row |
| build on a spike | that spike's Result section |
| widen scope | Section 3, and `depends_on` on any slice that's now affected |

And in the same commit as the code, not a follow-up: **commit this file alongside it**, with
the slice id in the commit subject (`001: add storage layout`).

Nothing checks any of this. That's the point of putting the writes first — a write you have
to do to proceed is one you do; a write you're supposed to do afterwards is one you don't.

## 10. Definition of Done
- [ ] Acceptance criteria met
- [ ] Tests passing, in a target that exists
- [ ] Every `covers:` requirement satisfied, or forked with a decision row
- [ ] Decision log written as you went, not reconstructed
- [ ] Pre-flight completed and drift resolved
- [ ] Master checklist row current
- [ ] `next_slice`'s `depends_on` reflects what actually shipped, not what was planned
- [ ] Both link directions checked: this page's `next_slice` and that page's `previous_slice`

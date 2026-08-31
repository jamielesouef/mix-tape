---
spike_id: "SNNN"
title: <Question being answered>
timebox: <e.g. 2 hours, 1 day>
unblocks: ["NNN", "NNN"]     # slice ids this answers for. Not in the linked list.
created: YYYY-MM-DD
---

# SNNN — <Question being answered>

[Master Checklist](MASTER-CHECKLIST.md) · Unblocks: [NNN-name](NNN-name.md)

> **Status, owner and the answer summary live in the master checklist, not here.** This page
> holds the question, the method, the fallback and the evidence. One fact, one home.

## 1. Question
One sentence, phrased so it has a yes/no or a concrete value as an answer.

Bad: "Investigate FileMiddleware." Good: "Can two FileMiddleware instances with different
roots and different URL prefixes coexist in a single Hummingbird 2 application?"

## 2. Why this blocks
Which slice, and what specifically gets redesigned if the answer goes the wrong way. If
nothing gets redesigned, this isn't a spike — it's curiosity, and it doesn't belong in
`docs/slices/`.

## 3. Cheapest experiment that answers it
The smallest thing that produces a real answer, not a plausible one. Prefer a throwaway
project over touching the real codebase. Name the actual commands or steps.

- [ ] Step
- [ ] Step

**Explicitly not doing:** anything beyond what the question needs. A spike that grows a
feature is no longer a spike.

## 4. Timebox
`<duration>`. On expiry: stop, record what you learned, and take the fallback in Section 5.
An overrunning spike is itself an answer — the thing is harder than the design assumed.

## 5. Fallback if the answer is unfavourable
Decided **before** running the experiment, so the result doesn't get argued with.

> If two FileMiddleware instances can't coexist: single cache root, music mounted
> underneath. Affects slice 001's folder layout.

## 6. Result
| | |
|---|---|
| **Answer** | |
| **Evidence** | command output, error, doc link — not "it seemed to work" |
| **Date** | |

## 7. Consequences
- [ ] Decision recorded in the decision log of: `<slice>`
- [ ] Affected slices updated (scope, dependencies, acceptance criteria)
- [ ] Master checklist spike row set to `Answered`, with the one-line answer
- [ ] Throwaway code deleted, or moved somewhere clearly marked as a spike artefact
- [ ] If the answer invalidated a prior decision: Architecture Drift Log updated

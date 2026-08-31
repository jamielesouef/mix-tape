# Slices — Working Convention

A slice is a vertical, independently shippable unit of work. Not a layer ("the networking
layer"), not a time-box ("week three"). Each slice must build and deliver value on its own.

## Files

- `000-slice-template.md` — copy per slice
- `000-spike-template.md` — copy per spike
- `MASTER-CHECKLIST.md` — status, owner, blockers, drift, plan coverage
- `SNNN-evidence/` — a spike's kept evidence, named for the spike that produced it. Small, hand-picked artefacts only: the cases a count cannot convey, plus the command that regenerates the bulk. Not a fixtures directory and not a data dump — if it is large or regenerable, record how to rebuild it instead of keeping it

## Naming

```
001-live-chat-reconnect.md      slice
001a-reconnect-backoff.md       sub-slice of 001
S001-dual-file-middleware.md    spike
```

Three digits, kebab-case, no spaces. Numbers are dependency and delivery order, not
priority. Sub-slices append a lowercase letter. Spikes use the `S` prefix and their own
sequence.

## Spikes

A spike answers one blocking question and produces a decision, not a feature.

- Not in the linked list — declares `unblocks:` instead
- Has a timebox and a fallback decided **before** the experiment runs
- Never grows into the feature; throwaway code is deleted at close
- Timebox expiry is an answer: the thing is harder than the design assumed — take the fallback

A spike filed as a sub-slice (`001a`) is wrong twice: wrong name, and wrongly in the list.

## One fact, one home

| Fact | Lives only in |
|---|---|
| Dependencies | slice front matter `depends_on` |
| List position | slice front matter `previous_slice` / `next_slice` |
| Status, owner, blockers | `MASTER-CHECKLIST.md` |
| Plan coverage | checklist Coverage table + slice `covers:` |

Everywhere else links instead of restating. Slice docs have no status field; the checklist
has no dependency column. Duplicating a fact is how two files end up disagreeing.

Links are the exception, being two-sided: **editing `next_slice` means opening the target
and setting its `previous_slice` in the same edit.** Inserting a slice is three file edits.

## Before starting a slice

Run its pre-flight section. Slices land over weeks and assumptions rot. On drift: stop,
log it in the Drift Log, flag the affected slices — before writing code.

## Before a build phase

Run the `slice-set-review` skill over the whole directory. Cross-document faults — one-way
links, build order disagreeing with reading order, plan requirements no slice covers — are
invisible from inside any single slice.

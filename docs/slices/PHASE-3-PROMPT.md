# Phase 3 prompt — the hardening round (013–017)

Companion to [`PHASE-2-PROMPT.md`](PHASE-2-PROMPT.md), which drafted the V1 slice set. That
round was greenfield. **This one is not**, and the difference sets the doctrine below: there
is working code and a passing gate, so the risk is regression, not divergence.

## The goal

V1 is built and pushed. Twelve slices, 156 tests, a gate that reported clean on every commit.
An independent reconciliation then found six defects, three gate holes and seven stale
statements in the engineering doc — and, more to the point, found that **the gate could not
have caught most of them.** `MixtapePresentation` has no test target, so the entire UI
including the wallet was verified only by prose records of manual runs, and the gate asserted
a test count the caller supplied.

So the goal of this round is not "fix six defects". It is:

> **Make the gate capable of catching what it missed, then fix what it missed — in that
> order, so the fixes land verified rather than demonstrated.**

That ordering is the whole design of the round and the reason 013 runs ahead of the P0 defect
in 014. Full reasoning in [`MASTER-CHECKLIST.md`](MASTER-CHECKLIST.md) → Ordering Notes → "The
hardening round, 013–017". Findings in [`../v1-reconciliation.md`](../v1-reconciliation.md).

Done looks like: every slice 013–017 `Done`, every triage row closed or owned, §1.5 satisfied
on both platforms, §1.13 satisfied for pause and seek, §12.13c/d/e satisfied on every path
rather than the demonstrated one, and an engineering doc that raises no false defects when
read against the tree.

---

## Phase 0 — pre-flight deltas

The runbook's Phase 0 still applies in full. Three things are specific to this round, and the
first two will stall an unattended run.

**0.1 Widen the allow-list.** `.claude/settings.json` covers `xcodebuild`, `xcrun`,
`swiftformat`, `./scripts/*` and `git`. This round needs more, and a permission prompt with
nobody at the terminal just sits there:

| Add | Needed by |
|---|---|
| `Bash(idb *)` | 015 and 016 acceptance runs — synthesised taps, as 010 and 011 used |
| `Bash(docker *)` | 016's pre-flight plans `docker restart jellyfin`; the drift log shows an orphaned `/UserViews` item that a library scan would not prune |
| `Bash(nm*)`, `Bash(strings*)` | 013's acceptance criterion that no `Mock*` symbol survives in a release binary |
| `Bash(swift package*)` | 013 adds an SPM test target |
| `Bash(sed*)`, `Bash(find*)`, `Bash(cat*)`, `Bash(diff*)` | the gate scripts and the pbxproj diff 013's pre-flight requires |

**0.2 Guard the `objectVersion` pin before 013 starts.** This is the round's largest
unattended risk. `CLAUDE.md` requires `MixTape.xcodeproj` to stay at `objectVersion = 77` with
`preferredProjectObjectVersion = 77`; Xcode 27 rewrites both to `90` on sight, and no stable
hosted runner can open a `90`. **013 adds a test target — the single most likely action in the
whole round to trigger that rewrite.** Add a check to `scripts/gate.sh` so it fails loudly
rather than being caught in review:

```sh
grep -q 'objectVersion = 77' MixTape.xcodeproj/project.pbxproj &&
grep -q 'preferredProjectObjectVersion = 77' MixTape.xcodeproj/project.pbxproj ||
    { echo "objectVersion pin broken — Xcode 27 rewrote the project file"; exit 1; }
```

**0.3 Workflow size stays `medium`.** Phase 2 wanted `large` for a fan-out over the whole
spec. Execution here is dependency-ordered and sequential; the runbook's reasoning against
fan-out during execution applies unchanged.

---

## Prompt A — spike S003

Short, read-only against the code, and it decides whether 013's last scope bullet is an
annotation or a rework. Run it first; it is an hour and it changes nothing.

```bash
cd /Volumes/S990/Developer/personal/build-run
claude --model fable --effort high --permission-mode acceptEdits
```

Then paste:

---

Run spike S003 exactly as `docs/slices/S003-accessory-reduce-transparency.md` specifies.

The question is whether the iOS 26.1 `tabViewBottomAccessory` container renders opaque under
Reduce Transparency on its own, or whether the system's Liquid Glass stays translucent behind
the mini player and leaves §12.15 unsatisfied.

Follow Section 3's method: no code change, the existing build on a booted simulator, the two
screenshots, and the scroll-shift comparison on the pixels outside the mini player's own pill
but inside the accessory container. Resolve the simulator by UDID at runtime — this machine has
iOS 26.5 and 27.0 runtimes and no 26.0, so a hardcoded destination fails as a destination error
that reads like a project fault.

The timebox is one hour. **On expiry, stop and take the Section 5 fallback** — do not extend it,
and do not start implementing either outcome. A spike that grows into the feature is no longer a
spike.

Write the answer into Section 6 with the evidence, complete Section 7's consequences, and set the
S003 row in `docs/slices/MASTER-CHECKLIST.md` to `Answered` with the one-line answer. If the
answer is unfavourable, 013's scope changes and its complexity rises — say so in your reply
rather than editing 013's estimate silently.

---

## Prompt B — execution, slices 013–017

No ultracode: this round is dependency-ordered and sequential, and a fan-out would produce N
divergent opinions with nobody present to reconcile them.

```bash
cd /Volumes/S990/Developer/personal/build-run
claude --model fable --effort high --permission-mode acceptEdits
```

Set the goal first, to anchor the session across the run:

```
/goal Ship slices 013-017 in docs/slices/, each passing its own acceptance criteria and the CLAUDE.md slice gate, with the objectVersion 77 pin intact
```

Then paste:

---

Execute the hardening round: slices 013, 014, 015, 016 and 017 in
`docs/slices/`, in that order. Work them one at a time. A slice's gate must pass before the next
one starts.

**Sources, in precedence order.** `SPEC-DECISIONS.md` outranks everything; then
`docs/engineering-doc.md`; then `docs/architecture.md`; then `CLAUDE.md`. Where two disagree, the
higher wins — **except** that `docs/engineering-doc.md` is known to contain seven statements
superseded by decisions and not yet corrected. They are listed in slice 017 Section 2, and 017 is
the slice that fixes them. Until then, treat any of those seven lines as wrong and the decision as
right.

**This is not a greenfield run.** The gate passes today. Every commit must leave it passing:
`xcodebuild build` and `test` for both schemes with the UI bundles skipped, `./scripts/gate.sh`,
`./scripts/check-layer-imports.sh`, `./scripts/check-glass-fallback.sh`, `swiftformat --lint .`.
Resolve simulators by UDID at runtime, never a hardcoded OS version.

**Each slice document is the contract.** Its Section 5 acceptance criteria are what "done" means —
not your judgement of whether the code looks right. Work each slice's Section 4 pre-flight before
its first line of code, and its Section 6 decision rows before implementing the decisions they
describe, not after. Several slices name specific drift risks in their pre-flight; 016's is the
largest, because 011 has already had files moved underneath it twice.

**Constraints that bite if missed:**

- **`MixTape.xcodeproj` stays at `objectVersion = 77` with `preferredProjectObjectVersion = 77`.**
  013 adds a test target, which is the action most likely to make Xcode 27 rewrite them to `90`.
  Prefer editing `Package.swift` and the scheme XML directly over anything that opens the project
  in Xcode, and diff the pbxproj before every commit. If a diff shows `90`, revert it — do not
  "fix it later".
- Write no language or standard-library feature newer than Swift 6.2. This machine runs 6.4 and a
  6.4-only construct compiles here and breaks when CI returns.
- **Do not add XCUITest, do not touch the two stub files in `uiTests/`, and do not add CI.**
  Decision 4 and the CI removal both stand. Several acceptance criteria in 015 and 016 are
  exactly what a UI test would own; they stay manual this round, and the identifiers are what
  makes them writable later.
- **§1.1 is binding and 015 is where it gets violated by accident.** Reworking the album-finish
  handler is the one place a cross-album queue, a shuffle, a repeat or an autoplay looks like a
  natural refactor. The queue is the album. Those absences are the product.
- 013's gate changes are only real if you have seen them fail. Every acceptance criterion there
  beginning "Deleting…", "Moving…" or "Adding…" is a negative control: make the change, watch the
  gate fail, revert. Run each one.
- 016 deliberately creates a second library on the dev server. Plan its removal before creating
  it, and confirm `/Library/VirtualFolders` and `/UserViews` agree afterwards — the drift log
  records an orphan that survived a library scan and broke an acceptance run.
- Read the server through `scripts/jf-probe.swift` (decision 47). `curl` is globally denied on
  this machine.

**If a gate fails twice in a row with no progress between attempts, stop and record why in
`BLOCKED.md`.** Do not weaken the gate, delete the test, skip a unit test, or move on. Never mark
a slice complete with a failing or removed test. Skipping the two UI bundles is the only permitted
exclusion.

**Commit per slice**, message naming the slice (`013: …`), with the slice document in the same
commit as the code it describes.

Report at the end: which slices closed, which acceptance criteria you demonstrated versus
inferred, and anything you could not verify. Say so plainly rather than rounding up — the last
round's completion report read cleaner than the code was.

---

## Prompt C — verification sweep

One ultracode run after 017 closes.

```
ultracode: verify the hardening round against its own contract rather than against my summary of
it. Fan out one agent per slice, 013 through 017, each reading only that slice's document and the
code it touched, and reporting which of its Section 5 acceptance criteria are demonstrably met,
which are asserted without evidence, and which are unmet. Have independent agents adversarially
check each "met" claim before it is reported.

Then run the cross-document checklist in `docs/slices/README.md` under "Before a build phase"
across the whole set, 001–017 plus S001–S003.

Merge into one ranked, deduplicated summary. Rank by the gap between what a document claims and
what the code does, not by severity of the underlying bug — a small defect that a slice claims is
fixed is worse than a known one that is honestly recorded.
```

---

## After it finishes

1. **Read the ranked summary before the diff.** Spot-check the slices whose acceptance criteria
   were weakest — 015's AC15a and AC15b are manual simulator runs with no test behind them until
   the deferred XCUITest rung lands, and 016's AC16c and AC16e are focus behaviour, which is the
   hardest thing in this round to verify by reading.
2. **Check the pbxproj diff by hand**, whatever the gate says. The `objectVersion` guard in 0.2
   is new and unproven.
3. `/workflows` for per-agent token totals, to calibrate the next round's size guideline.
4. Push, and decide whether XCUITest — the deferred third rung of the verification ladder — is
   the next round now that a `MixtapePresentationTests` target exists to sit beside it.

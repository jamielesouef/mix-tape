---
slice_id: "002"
title: Licence split, DCO and the quickstart
priority: P0
complexity: S
ladder: none
depends_on:
  - { id: "001", type: hard, note: "needs the three directories to exist before a LICENSE can sit in each" }
previous_slice: "001"
next_slice: "003"
parent_slice: none
covers: ["7.licensing"]
created: 2026-08-31
---

# 002 — Licence split, DCO and the quickstart

← [previous](001-repo-skeleton-and-version.md) · [Master Checklist](MASTER-CHECKLIST.md) · [next](003-docker-image-and-ci.md) →

> **Status, owner and blockers live in the master checklist, not here.** Dependencies live in this page's front matter and nowhere else. Each fact has one home; if you find yourself writing it twice, one of the two copies is going to be wrong in a fortnight.

## 1. Objective

Make the repository legally publishable: four `LICENSE` files, an SPDX header on every source file, `CONTRIBUTING.md` with DCO sign-off, and a `README.md` that tells a stranger how to run it. Value observable on its own: the repository can be pushed public without a licensing defect, which the handoff requires from the *first* public commit.

## 2. Business Value & Priority

The handoff says "**open source** from the first public commit". A repository that goes public with an unclear licence cannot be quietly fixed later — contributions arrive under whatever the file said at the time, and re-licensing means chasing every contributor.

The specific hazard is directional and easy to get backwards: **MIT flows into AGPL; AGPL does not flow into MIT.** If `Shared/` were AGPL, the MIT claim on `App/` would be invalid, because the app links `Shared`. That is not a stylistic preference, it is the reason the split is shaped the way it is.

This slice is `S` and sits second because it is cheap and because the cost of deferring it is asymmetric — the risk is not "we forgot", it is "we published".

## 3. Scope

**In scope:**

- `Shared/LICENSE` — MIT
- `App/LICENSE` — MIT
- `Server/LICENSE` — AGPL-3.0-only, the full text
- `LICENSE` at the root — explains the split, states which directory is which, and states the MIT-into-AGPL direction so nobody "tidies" it later
- `SPDX-License-Identifier` as the **first line** of every source file in all three directories, matching that file's directory — **except a package manifest**, where Swift requires `// swift-tools-version:` on line 1 and the SPDX line therefore sits on line 2. That covers exactly two files: `Shared/Package.swift` (`MIT`) and `Server/Package.swift` (`AGPL-3.0-only`). Both are in scope and both count towards the file totals below
- `CONTRIBUTING.md` — licence by directory, DCO sign-off (`Signed-off-by:`), explicitly **not** a CLA
- `README.md` — what Mix Tape is, the CD-wallet concept in one paragraph, and a quickstart. The quickstart is a placeholder pointing at slice 003 until the compose file exists; it must not describe a compose file that is not there
- `scripts/check-spdx.sh` — walks every `.swift` file and exits non-zero on a miss. Two rules, keyed on the filename so the exemption is machine-checkable rather than a convention someone has to remember: a file named `Package.swift` must have `// swift-tools-version:` on line 1 and its directory's SPDX identifier on line 2; every other `.swift` file must have the SPDX identifier on line 1. The script must also **fail on a directory it cannot read**, never skip it — slice 001's layer check reported "clean" for a folder it never opened, and that failure mode is not to be re-shipped here

**Out of scope** (name the slice it is deferred to):

- The working `docker compose up` quickstart body → **003**
- Any dependency-licence audit of Hummingbird or JWTKit → not v1; both are Apache-2.0 and compatible with AGPL, recorded in Section 6 and not re-derived per slice
- A `NOTICE` file or third-party attribution bundle → not v1

**Plan requirements covered:**

- `7.licensing` — four `LICENSE` files, SPDX on every source file, `CONTRIBUTING.md` with DCO. Fully covered, with one addition the plan does not name: `scripts/check-spdx.sh`. A rule enforced by nothing is a rule that decays by slice 006, so the check is in scope and runs in CI from slice 003.

## 4. Pre-Flight Validation

Complete **before the first line of code**, not at close.

For **each id in `depends_on`**, in order — do not summarise, walk the list:

- [ ] **001** — opened. Its decision log still says the three directories are `Shared/`, `Server/`, `App/` and that the rename from `app/` happened. If 001 forked on directory names, every path in this slice is wrong.
- [ ] 001 is not a spike; no fallback to check.
- [ ] Confirm `Server/` genuinely contains no code copied from `App/` or vice versa. An AGPL file that arrived in `App/` by copy-paste is the failure this slice exists to prevent, and it is easiest to check while there are only a handful of files.
- [ ] Architecture standards doc re-read: `docs/plan/v1-architecture.md` section 7, Licensing.

**Drift found:** `none` — or what changed, plus a row in the checklist's Drift Log.

## 5. Acceptance Criteria

- [ ] Four `LICENSE` files exist at `LICENSE`, `Shared/LICENSE`, `App/LICENSE`, `Server/LICENSE`.
- [ ] `Server/LICENSE` is the full, unmodified AGPL-3.0 text. Not a summary, not a link.
- [ ] `./scripts/check-spdx.sh` exits `0`, and exits non-zero when the header is temporarily removed from one file. **Test the failure case.**
- [ ] Every `.swift` file under `Server/` declares `AGPL-3.0-only`; every one under `App/` and `Shared/` declares `MIT`.
- [ ] **The SPDX line is line 1 and the Xcode header block follows it**, in every `.swift` file, matching the fenced example in `CLAUDE.md`'s Conventions section. A file with the Xcode block first fails `check-spdx.sh` — check one deliberately, because this is the ordering that was undefined until this slice fixed it.
- [ ] **`Shared/Package.swift` and `Server/Package.swift` carry `// swift-tools-version:` on line 1 and their SPDX identifier on line 2**, matching the manifest example in `CLAUDE.md`. Both packages still build afterwards — `cd Shared && swift build` and `cd Server && swift build`. A manifest whose tools-version line has been displaced does not fail the licence check, it fails to build at all, so prove the build rather than only the grep.
- [ ] `check-spdx.sh` **fails a manifest with the two lines the wrong way round**, and fails a manifest with the SPDX line missing entirely. Both are failure cases to demonstrate, not to assume — a filename-keyed branch that never took its branch is untested code.
- [ ] `check-spdx.sh` **exits non-zero on an unreadable directory** rather than skipping it. Prove it: `chmod 000` one layer directory, run the script, restore it.
- [ ] `CONTRIBUTING.md` states the per-directory licence and requires `Signed-off-by:`, and does not mention a CLA.
- [ ] `README.md` exists, describes the project, and its quickstart section is honestly marked as landing in slice 003 rather than describing a file that does not exist.
- [ ] No file under `App/` or `Shared/` imports, includes or copies anything from `Server/`. Checked by grep, recorded in the commit.

## 6. Decision Log

**Write the row before you implement the decision, not after.** This is the whole mechanism. A decision log filled in at close is reconstructed from memory, and the rejected alternatives — the part the next slice's pre-flight actually needs — are exactly what memory loses first.

| Date | Decision | Alternatives rejected | Why |
|---|---|---|---|
| 2026-08-31 | `Shared/` is MIT, `Server/` is AGPL-3.0-only, `App/` is MIT | A single AGPL licence for the whole repository; a single MIT licence | AGPL on `Shared` would invalidate the MIT claim on `App`, because `App` links `Shared`. MIT everywhere would give away the server's copyleft protection, which is the point of AGPL on a self-hosted service. Settled in the handoff; recorded here so it is not re-derived |
| 2026-08-31 | **The SPDX line is line 1 and the Xcode header block sits below it.** One file header, two conventions, in this fixed order: `// SPDX-License-Identifier: <licence>`, a bare `//`, then the standard Xcode block. `check-spdx.sh` reads line 1 only | Xcode block first with SPDX beneath it; SPDX appended at the end of the header; `check-spdx.sh` scanning the first ten lines instead of the first one | Both conventions independently claimed line 1, and nothing said which won — so the repository's first Swift files, written in slice 001, were about to be written one of two incompatible ways with the check failing on half of them. Resolved on the documents rather than on taste: **"first line" is explicit** in plan §7, the handoff and this slice's own acceptance criteria, while the Xcode-header convention specifies a *format* and never claims a position. Widening the grep was rejected because a check that accepts a header anywhere in the first ten lines stops enforcing the thing the licence needs — an unambiguous machine-readable declaration at the top of the file. Recorded here because 002 owns SPDX and the script; the literal combined form lives in `CLAUDE.md`'s Conventions section, once, and this row does not restate it |
| 2026-09-01 | **A package manifest is the sole exemption from the line-1 rule: `// swift-tools-version:` on line 1, SPDX on line 2.** `check-spdx.sh` branches on the filename `Package.swift` and asserts both lines; every other `.swift` file keeps the line-1 assertion unchanged | Put SPDX on line 1 and the tools-version below it; drop the SPDX header from manifests entirely and rely on the directory `LICENSE`; have the script scan the first two lines of every file rather than branching | The rule as written was **unsatisfiable** for exactly two files, and slice 002 would have hit it head-on. Swift parses `// swift-tools-version:` positionally — displace it and the package does not build, so putting SPDX first is not a trade-off, it is broken. Omitting the header was rejected because a manifest is a source file that is copied and quoted on its own, and `Shared/Package.swift` is precisely the file whose MIT status must travel with it. Scanning two lines for everything was rejected for the same reason widening the grep was rejected in the row above: it weakens the assertion for all 20-odd other files to accommodate two. Branching on the filename keeps the exemption **narrow and machine-checkable** — an exemption a script cannot express is a hole, not an exemption |
| 2026-08-31 | DCO sign-off, not a CLA | Contributor Licence Agreement | A CLA needs a legal entity to assign rights to and deters casual contributors. DCO is a one-line trailer and is what the handoff asks for |
| 2026-08-31 | `scripts/check-spdx.sh` is in scope, though the plan does not name it | Trust the convention; a pre-commit hook only | An unenforced header convention is reliably broken by slice 006. A script that runs in CI catches it on the commit that broke it. A hook alone is skippable with `--no-verify` and is not run in CI |
| 2026-08-31 | Hummingbird and JWTKit licences accepted as Apache-2.0-compatible, checked once here | A per-slice dependency licence audit | The handoff caps the dependency list at these two. A recurring audit of a fixed two-item list is ceremony. If a third dependency is ever proposed, that slice re-opens this row |

## 7. Sub-Slices

Not split — delivered as a single slice.

## 8. Testing Strategy

- **Unit / Integration / UI:** none. This slice ships no behaviour, and a test asserting a licence file's contents is a test of a copy-paste.
- The enforcement is `scripts/check-spdx.sh`, exercised in both directions (passing tree, and a deliberately broken file) as an acceptance criterion. Slice 003 wires it into both CI workflows.
- **Test targets required:** none new. The targets created by slice 001 are untouched.

## 9. Keeping this document true

This slice is done when the page describes what was actually built — not when the code works. The discipline is **ordering**: the write happens *before* the thing it describes, so it sits on the critical path instead of after it, where it gets skipped.

| Before you… | Write this first |
|---|---|
| implement a decision | the Section 6 row, including what you rejected |
| start work | flip status in the master checklist |
| stop on a blocker | the Active Blockers row |
| build on a spike | that spike's Result section |
| widen scope | Section 3, and `depends_on` on any slice that is now affected |

And in the same commit as the code, not a follow-up: **commit this file alongside it**, with the slice id in the commit subject (`002: add licence split and DCO`).

Nothing checks any of this. That is the point of putting the writes first — a write you have to do to proceed is one you do; a write you are supposed to do afterwards is one you do not.

## 10. Definition of Done

- [ ] Acceptance criteria met
- [ ] Tests passing, in a target that exists — n/a, enforcement is `check-spdx.sh`
- [ ] Every `covers:` requirement satisfied, or forked with a decision row
- [ ] Decision log written as you went, not reconstructed
- [ ] Pre-flight completed and drift resolved
- [ ] Master checklist row current
- [ ] `next_slice`'s `depends_on` reflects what actually shipped, not what was planned
- [ ] Both link directions checked: this page's `next_slice` and `003`'s `previous_slice`

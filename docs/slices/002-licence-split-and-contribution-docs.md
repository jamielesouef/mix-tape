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
- `SPDX-License-Identifier` as the **first line** of every source file in all three directories, matching that file's directory
- `CONTRIBUTING.md` — licence by directory, DCO sign-off (`Signed-off-by:`), explicitly **not** a CLA
- `README.md` — what Mix Tape is, the CD-wallet concept in one paragraph, and a quickstart. The quickstart is a placeholder pointing at slice 003 until the compose file exists; it must not describe a compose file that is not there
- `scripts/check-spdx.sh` — greps every `.swift` file for a first-line SPDX header matching its directory, and exits non-zero on a miss

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
- [ ] `CONTRIBUTING.md` states the per-directory licence and requires `Signed-off-by:`, and does not mention a CLA.
- [ ] `README.md` exists, describes the project, and its quickstart section is honestly marked as landing in slice 003 rather than describing a file that does not exist.
- [ ] No file under `App/` or `Shared/` imports, includes or copies anything from `Server/`. Checked by grep, recorded in the commit.

## 6. Decision Log

**Write the row before you implement the decision, not after.** This is the whole mechanism. A decision log filled in at close is reconstructed from memory, and the rejected alternatives — the part the next slice's pre-flight actually needs — are exactly what memory loses first.

| Date | Decision | Alternatives rejected | Why |
|---|---|---|---|
| 2026-08-31 | `Shared/` is MIT, `Server/` is AGPL-3.0-only, `App/` is MIT | A single AGPL licence for the whole repository; a single MIT licence | AGPL on `Shared` would invalidate the MIT claim on `App`, because `App` links `Shared`. MIT everywhere would give away the server's copyleft protection, which is the point of AGPL on a self-hosted service. Settled in the handoff; recorded here so it is not re-derived |
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

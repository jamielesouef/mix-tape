# Phase 2 prompt

Launch:

```bash
cd /Volumes/S990/Developer/personal/build-run
claude --model fable --effort high --permission-mode plan
```

Then paste:

---

ultracode: draft the deliverable slice set for this build.

**Sources, in precedence order.** `SPEC-DECISIONS.md` outranks everything; then `docs/engineering-doc.md`; then `docs/architecture.md`; then `CLAUDE.md`. Where any two disagree, the higher one wins. `docs/jellyfin-openapi.json` is the API contract — it is the running server's own 10.11.11 spec, so treat it as accurate rather than aspirational.

**Decisions 1–32 in `SPEC-DECISIONS.md` are settled. Do not re-open them, do not re-derive them, and do not weigh alternatives where a decision already chose one.** Weigh alternatives only where the decisions leave room.

**`AUDIT-FINDINGS.md` is historical.** Every finding in it is already resolved by a decision. Read it for context only. Its section 1 labels ten items "blocking" with "Decision needed:" — those are answered, and one of them turned out not to be a real finding at all. Never treat anything in that file as an open question.

**Output.** One slice document per slice under `docs/slices/`, following `docs/slices/README.md` for naming and conventions and `docs/slices/000-slice-template.md` for structure — all ten sections, front matter included. Populate `docs/slices/MASTER-CHECKLIST.md`: the slice table, the requirement coverage table, and the ordering notes. Write a spike document instead of a slice for any question that must be answered before a slice can be designed.

**Frame each slice as an outcome plus gate criteria, not a step list.** The slice boundaries are the only audit surface on an unattended run, so they must be real: each slice builds, tests and delivers something observable on its own.

**Dependency order follows engineering doc §13**, whose shippable checkpoints are sign-in, then browse, then video, then music, then the wallet, then tvOS. Deviate only with a reason recorded in the checklist's Ordering Notes.

**`covers:` uses the engineering doc's own section numbering** — `§1.9` for a capability, `§12.6` for an acceptance criterion. Do not invent a requirement ID scheme.

**Constraints that bite if missed:**

- Slice 1 must include the `Package.swift` `swiftSettings` from decision 15 and the `uiTests/` rename from decision 3. Decision 15 fails silently — if `.defaultIsolation(MainActor.self)` does not land in slice 1, every later slice compiles without it and nothing warns.
- No slice may claim acceptance criterion 11. The library holds 0 Series and 0 Episodes, so it cannot be demonstrated. The checklist's coverage section already records this.
- XCUITest and CI are deferred (decisions 4 and the CI removal). No slice adds either. Accessibility identifiers, the accessibility pass and the Reduce Transparency pass all stay in scope.
- Gate criteria must be demonstrable with what exists: two video items (`mp4`/h264 and `mkv`/h264/aac), 4 albums, 46 tracks, and a live server at `http://localhost:8096`. A gate that needs data the library lacks will stall a run with nobody watching.

**Write only under `docs/slices/`.** Do not modify `SPEC-DECISIONS.md`, anything under `docs/` outside `docs/slices/`, `CLAUDE.md`, or any source file. If you believe a decision is wrong, say so in your reply — do not edit it.

---

## After it finishes

1. Review the slice set by hand — ordering, module boundaries, shared types, and whether any gate claims more than it can demonstrate. Run the cross-document checks in `docs/slices/README.md` under "Before a build phase".
2. Commit it. This is the contract the unattended run executes against, and the last human checkpoint.

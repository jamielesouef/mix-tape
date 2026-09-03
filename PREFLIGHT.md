# Phase 0 pre-flight — items that need you at a terminal

Workspace setup is done. What follows is everything the runbook's Phase 0 still
needs from an interactive terminal.

Already done, no action needed:

- Worktree at `/Volumes/S990/Developer/personal/build-run`, branch
  `build/adw-run` at `cf98ffc`. Commits verified working.
- Docs and API spec copied in, including the uncommitted and untracked ones.
- `.claude/settings.json` — runbook §0.3, verbatim.
- `CLAUDE.md` — lean build-repo version.

---

Also confirmed and needing nothing further:

- `claude --version` → **2.1.259**, clears 2.1.255 for Fable 5.1.
- 16 files in `~/.claude/agents`, **zero `model:` pins** — the `sonnet` default
  in `.claude/settings.json` will hold on every fan-out.
- Xcode 27.0, Swift 6.4, swiftformat 0.63.0 present.
- CI removed from this repo at your direction, to be reinstated after the MVP
  has local tests.
- **Workflow size set to `large` in `.claude/settings.json`**, not by `/config`.
  It is a real settings key, so a headless `-p` run picks it up with no
  interactive step. This is the one deliberate addition to the runbook's §0.3
  JSON. Because it persists, the runbook's "back to `medium` before phase 4" is
  now an edit to that file rather than a slash command.
- Local Jellyfin is up at `http://localhost:8096` (server name `mixtape`,
  startup wizard completed) from the compose file in the main repo.

---

## 1. Clear the Fable usage-credit consent prompt (runbook §0.2)

The silent overnight killer. In a background session Claude Code holds this
prompt for `dialogExpiry` and then ends the turn without sending the request.
Answer it once, interactively:

```bash
claude --model fable
> hello
# answer the "continue on Fable using usage credits" prompt if it appears
```

Skip only if you intend to run every phase headless with `-p`, where the prompt
is never shown and the request bills without asking.

---

## 2. Commit the Phase 0 state

The CI removal and the setup files are staged or untracked in the worktree, not
committed. Handing them to the run as a clean baseline:

```bash
cd /Volumes/S990/Developer/personal/build-run
git add -A
git commit -m "Phase 0: build workspace, lean CLAUDE.md, remove CI"
```

---

## Things for the Phase 1 spec audit to rank

Not blockers, but they are contradictions in the spec set and the audit should
surface them rather than quietly picking a reading:

1. **Three disagreeing layouts.** `main` has `iOS/source/` plus a `Shared/` SPM
   package; `feature/scaffolding` (this worktree's base) has `source/iOS`,
   `tests/iOS`, `uiTess/iOS`; engineering doc §3 specifies `Apps/MixtapeiOS` and
   `MixtapeKit/Sources/Mixtape*`. Build-order step 1 restructures regardless, but
   nothing says which is authoritative.
2. **The checked-in API spec is a major version ahead of the real server.**
   Measured, not inferred: `http://localhost:8096/System/Info/Public` reports
   **Jellyfin 10.11.11**. `docs/jellyfin-openapi.json` and `jellyfin-api.md`
   describe **12.0.0**. Engineering doc §1 requires demonstration against a live
   10.10+ server — which is the one running. Endpoint shapes and DTO fields in
   the 12.0.0 spec cannot be assumed present on 10.11.11. This should be the
   audit's top-ranked item: it is the difference between DTOs that compile and
   DTOs that decode. Cross-check against what the running server serves at
   `http://localhost:8096/api-docs/swagger`.
3. **tvOS deployment target.** `APPLETVOS_DEPLOYMENT_TARGET = 27.0` in some
   build configurations, `TVOS_DEPLOYMENT_TARGET = 26` in others. The docs say
   tvOS 26+.
4. **`uiTess/`** is the actual directory name for UI tests, spelled that way in
   `architecture.md`. Confirm it is intentional before the run propagates it.

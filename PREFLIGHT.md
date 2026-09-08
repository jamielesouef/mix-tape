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

## Resolved before Phase 1 — see SPEC-DECISIONS.md

All open questions are answered and recorded: layout is engineering doc §3
(`Apps/` + `MixtapeKit/`), tvOS deployment target is 26.0, the UI test directory
is `uiTests/`, and XCUITest is deferred to a later round with accessibility
identifiers and both passes kept in scope. `docs/architecture.md` was rewritten
where it contradicted those, since the repo's precedence rules would otherwise
have let the stale section outrank the engineering doc.

Two things are deferred and will come back — **XCUITest** and **CI**. Both are
recorded as deferrals with their seams named, not as scope cuts.

The list below is kept for the record; nothing on it is still open.

---

## Things for the Phase 1 spec audit to rank

Not blockers, but they are contradictions in the spec set and the audit should
surface them rather than quietly picking a reading:

1. **Three disagreeing layouts.** `main` has `iOS/source/` plus a `Shared/` SPM
   package; `feature/scaffolding` (this worktree's base) has `source/iOS`,
   `tests/iOS`, `uiTess/iOS`; engineering doc §3 specifies `Apps/MixtapeiOS` and
   `MixtapeKit/Sources/Mixtape*`. Build-order step 1 restructures regardless, but
   nothing says which is authoritative.
2. ~~**API spec version mismatch.**~~ **Resolved before Phase 1.**
   `docs/jellyfin-openapi.json` is now the running server's own 10.11.11 spec
   rather than the published 12.0.0 one. The two agreed on 293 paths and all
   V1 endpoints, but 12.0.0 was missing `/Videos/{itemId}/master.m3u8` and
   `/Audio/{itemId}/master.m3u8` — the HLS transcode paths behind
   `PlaybackMethod.transcodeHLS` and the music fallback. See
   `docs/jellyfin-api.md`. Nothing left for the audit here.
3. **tvOS deployment target.** `APPLETVOS_DEPLOYMENT_TARGET = 27.0` in some
   build configurations, `TVOS_DEPLOYMENT_TARGET = 26` in others. The docs say
   tvOS 26+.
4. **`uiTess/`** is the actual directory name for UI tests, spelled that way in
   `architecture.md`. Confirm it is intentional before the run propagates it.

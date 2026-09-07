# ADW Fable Runbook — Unattended Greenfield Build

Spec-to-app build with no human in the loop. Claude Fable 5.1 on the session,
Sonnet 5 on the fan-out, ultracode used as a per-prompt keyword only.

Inputs: engineering docs + API spec. No existing code.

Owner: Jamie Le Souëf. Model names, effort levels, tool behaviour and any pricing here were verified as of 2026-09-07 and age quickly; re-check them before reusing this runbook (slice 019).

---

## Model and effort doctrine

| Phase | Model | Effort | Ultracode | Permission mode |
|---|---|---|---|---|
| 1. Spec audit | `fable` | `high` | keyword | `plan` |
| 2. Plan draft | `fable` | `high` | keyword | `plan` |
| 3. Execution | `fable` | `high` | **off** | `acceptEdits` or `-p` |
| 4. Verification | `fable` | `high` | keyword | same as phase 3 |

Fan-out workers run Sonnet 5 in every phase via `CLAUDE_CODE_SUBAGENT_MODEL`.

**Why Fable on the session throughout:** it sustains long autonomous sessions,
investigates before acting, and verifies its own work more often than smaller
models. Self-verification is the property being bought — it substitutes for the
human checkpoint that has been removed.

**Why not `/effort ultracode` as a session setting:** it auto-orchestrates a
workflow for every substantive task, which competes with `adw-driver` for
ownership of the loop. The per-prompt keyword keeps orchestration explicit.

**Why no `opusplan` equivalent:** there isn't one for Fable. A plan/execute
model split would have to be done by hand, and execution is the phase with
nobody watching.

---

## Phase 0 — Pre-flight

Run once, before any unattended session.

### 0.1 Version check

```bash
claude update
claude --version   # need >= 2.1.255
```

- Fable 5.1 requires v2.1.255+
- `--effort ultracode` requires v2.1.203+
- Workflow size guideline requires v2.1.219+

### 0.2 Clear the billing consent prompt

**This is the failure that kills overnight runs silently.**

Depending on plan and seat tier, Fable usage can bill to usage credits, and
interactive sessions show a consent prompt before the first such request. In a
background or Remote Control session, Claude Code holds that prompt for
`dialogExpiry` (5 minutes by default) and then **ends the turn without sending
the request**.

Clear it now:

```bash
claude --model fable
> hello
# answer the "continue on Fable using usage credits" prompt if it appears
```

Once answered, it does not appear again. Alternatively run the build headless
with `-p`, where the prompt is never shown and the request is billed without
asking.

### 0.3 Settings

`.claude/settings.json` in the build repo:

```json
{
  "model": "fable",
  "env": {
    "CLAUDE_CODE_SUBAGENT_MODEL": "sonnet"
  },
  "subagentPromptCacheTtl": "1h",
  "permissions": {
    "allow": [
      "Read",
      "Edit",
      "Write",
      "Bash(swift build*)",
      "Bash(swift test*)",
      "Bash(xcodebuild *)",
      "Bash(git *)"
    ]
  }
}
```

Notes:

- `CLAUDE_CODE_SUBAGENT_MODEL` goes in the `env` block — there is no top-level
  key for it.
- Since v2.1.238 it is a **default, not an override**. A `model:` in subagent
  frontmatter or a per-invocation model wins. Strip `model:` from any
  `~/.claude/agents/*.md` you want on Sonnet, or set
  `CLAUDE_CODE_SUBAGENT_MODEL_FORCE`.
- `subagentPromptCacheTtl: "1h"` — workflow agents otherwise get a 5-minute
  cache. Worth it on long runs; 1-hour cache writes bill at a higher rate.
- The allow rules matter more than usual: an unattended run that hits a
  permission prompt just sits there.

### 0.4 Workflow size

```
/config          → Dynamic workflow size: large   (phases 1–2)
/config          → Dynamic workflow size: medium  (phase 4)
```

Or `/config workflowSizeGuideline=large`. Default is `medium` (<15 agents);
`large` is <50.

### 0.5 Workspace

```bash
git worktree add ../build-run main
# place docs + API spec inside the worktree
```

Write a lean `CLAUDE.md`: Swift/SwiftUI conventions, target platform, gate
criteria. Keep it short — it rides on every request and contributes to
classifier flags.

### 0.6 Prompt placement

Three blocks drive an unattended run, and each lives in a different place. Putting all three in one user message is the defect that stalled an earlier run — the model was told to finish the whole task, given no task, and asked to write a `<summary>` at the same time.

| Block | Where | Why |
|---|---|---|
| Autonomy + Delivering work + Scope + Edits + Progress (the `# Delegation` block optional) | `CLAUDE.md`, once | These are system-prompt additions. Re-sending them as a user turn rewrites the prefix and restarts the prompt cache. |
| The task | The per-task message, and nothing else | A message that is only "Continue from where you left off" gives the autonomy block nothing to bind to. |
| Compaction instruction (`Summarize the transcript inside <summary></summary> tags…`) | A separate call the harness makes when it compacts | Inside a task prompt it is a competing deliverable. Never paste it into a task. |

Optional tail for the per-task message, to cut round trips in bash-and-editor loops:

```
First privately list what you need next; then request every item that doesn't depend on
another's result in this one response.
```

Drop it if the run is not showing one-tool-call-per-turn.

Do not add a `# Subagents` block that says "don't wait for each subagent", "delegate management to a lead agent", or "one reviewer per task". The first is a harness property (the `Agent` tool blocks), the second adds a hop because the session already is the lead, the third roughly doubles token spend on trivial subtasks. The `# Delegation` block in `CLAUDE.md` is the replacement.

Do not inject and remove per-turn reminders, and do not rewrite the system prompt mid-session. Both restart the prompt cache and, on newer accounts, invalidate thinking blocks (HTTP 400).

---

## Phase 1 — Spec audit (last human checkpoint)

```bash
claude --model fable --effort high --permission-mode plan
```

Prompt:

```
ultracode: audit the API spec and engineering docs under <path> for
contradictions, undefined error cases, missing pagination and auth semantics,
inconsistent naming, and anything ambiguous enough to block implementation.
Fan out one agent per endpoint or doc section. Have independent agents
adversarially verify each finding before reporting it. Output a ranked list of
blocking ambiguities.
```

Then:

1. Read the report.
2. Resolve every ambiguity **yourself**. This is the last point a human
   intervenes before the build completes.
3. Write the answers to `SPEC-DECISIONS.md` in the repo and commit.

Plan mode keeps the agents read-only: workflow agents' tool calls receive the
same permission checks as any other tool call in the session.

---

## Phase 2 — Plan draft

Same session, still plan mode.

```
ultracode: draft three independent architectures for this build from the spec
and SPEC-DECISIONS.md. Weigh them against each other on testability, module
boundaries, and how well each isolates the API surface. Output the winner as a
deliverable slice set per the slice-authoring skill: each slice framed as an
outcome plus gate criteria, dependency-ordered.
```

Then:

1. Review the slice set by hand — ordering, module boundaries, shared types.
2. Commit it. This is the contract the unattended run executes against.

**Framing note:** Fable's guidance is to describe the outcome, not the steps.
Keep the slice boundaries (they are the only audit surface on an unattended
run) but write each slice as an outcome + gate, not a step list.

---

## Phase 3 — Execution

No ultracode. Greenfield execution is dependency-ordered, not parallel — a
fan-out here produces N divergent opinions about naming, actor isolation, and
error handling, with nobody present to reconcile them.

Interactive-background:

```bash
claude --model fable --effort high --permission-mode acceptEdits
```

Headless:

```bash
claude -p --model fable --effort high \
  --permission-mode acceptEdits \
  "Build <target> to satisfy the slice set in <path>. Work slices in dependency
   order. Each slice must pass its gate criteria before the next starts.
   Commit per slice.

   First privately list what you need next; then request every item that doesn't
   depend on another's result in this one response."
```

The message is the task and only the task. The autonomy and delivering-work blocks come from `CLAUDE.md` (0.6).

Set a goal to keep the session anchored across the long run:

```
/goal Ship <target> passing every slice gate in <path>
```

**Effort must be set at launch.** `/effort` in non-interactive mode applies to
the current session only and isn't saved; on Fable 5 it can report
`Not applied` while the first-run effort hold is in effect. Fable 5.1 has no
such hold, which is one more reason to be on 5.1. Pass `--effort` at launch
regardless.

---

## Phase 4 — Verification sweep

One ultracode run, after the skeleton exists.

```
ultracode: run `swift build` and the test suite, and keep fixing reported
errors until both pass or two rounds in a row make no progress. Then review
every changed file for correctness issues and merge the per-file findings into
one ranked, deduplicated summary.
```

---

## Phase 5 — Human close-out

- Read the ranked summary first, not the diff.
- Spot-check the slices whose gate criteria were weakest.
- `/workflows` → per-agent token totals across the three fan-outs. Use it to
  calibrate the next build's size guideline.

---

## Failure modes

| Symptom | Cause | Fix |
|---|---|---|
| Run stalls, then the turn ends with nothing sent | Fable usage-credit consent prompt hit `dialogExpiry` | Clear it interactively once (0.2), or run with `-p` |
| `/effort` reports `Not applied` | Non-interactive `/effort` during the Fable 5 first-run effort hold | Pass `--effort` at launch |
| Output quality changes mid-run | Safety classifier flagged a request; session continued on the fallback model | Check the transcript for a fallback notice. Biology → Opus 5, cybersecurity → Opus 4.8. Can fire on request 1 from CLAUDE.md or git context; test with `claude --safe-mode` |
| Fan-out cost far above estimate | Subagent model didn't route | grep `"model"` in `~/.claude/projects/<proj>/<session>/subagents/agent-<id>.jsonl`; check for `model:` frontmatter overriding the env var |
| Run sits waiting forever | Permission prompt with nobody at the terminal | Add the tool to allow rules before starting |
| Unexpected workflows during execution | `/effort ultracode` left on as a session setting | `/effort high`; use the keyword per-prompt instead |
| Session refuses to ask what the task is, and does nothing | Message was "Continue from where you left off" with no task, under the autonomy block | Restate the concrete task and where the work lives (0.6) |
| Turn ends with a `<summary>` block instead of work | Compaction instruction pasted into the task prompt | Remove it; compaction is a separate harness call (0.6) |
| Prompt cache restarts every turn | Autonomy block re-sent as a user message, or per-turn reminders injected and removed | Move the block to `CLAUDE.md`; keep history append-only |
| Long deliverable drafted in thinking, then written again; `max_tokens` hit | `xhigh` or `max` effort | Stay on `high` unless a measured gain says otherwise |

---

## Reference

- Effort ladder on Fable 5.1 / Fable 5 / Opus 5 / Sonnet 5:
  `low`, `medium`, `high`, `xhigh`, `max`. Default `high`.
- `high` is the recommended default. `xhigh`/`max` can draft a long deliverable in thinking and then write it again — slower, and a `max_tokens` risk. Move up only where a gain has been measured.
- Anti-narration lines ("hold all findings for the final response") silence the model mid-task. Remove them from any harness or `CLAUDE.md` prompt before adding a progress-update instruction, or the two fight.
- `ultracode` is not a sixth effort level — it sends `xhigh` plus automatic
  workflow orchestration. Session-scoped; not accepted by `effortLevel` or
  `CLAUDE_CODE_EFFORT_LEVEL`.
- `ultrathink` is unrelated: a per-turn in-context nudge that does not change
  the effort sent to the API and does not start a workflow.
- Workflow limits: 16 concurrent agents, 1,000 agents per run, 4,096 items per
  `parallel()` / `pipeline()` call.
- Sessions with ultracode on suppress the `Large workflow` warning — another
  reason to keep it off as a session setting.

Docs: `code.claude.com/docs/en/workflows`, `code.claude.com/docs/en/model-config`, `platform.claude.com/docs/en/build-with-claude/prompt-engineering/prompting-claude-fable-5-1`

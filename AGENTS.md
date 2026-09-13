# mixtape — build repo

A Jellyfin client for iOS. Browse a music library, play albums, report
progress back.

`docs/engineering-doc.md` is the source of truth. Appendix A in it is the
architecture template. `docs/jellyfin-openapi.json` (Jellyfin 10.11.11, OpenAPI
3.0.1) is the API contract.

Precedence, highest first: **`SPEC-DECISIONS.md`**, then the engineering doc,
then `docs/architecture.md`, then this file. Read `SPEC-DECISIONS.md` before
acting on a layout, naming or platform-target question — it records answers that
contradict what the older docs say. If you find two docs disagreeing and
`SPEC-DECISIONS.md` is silent, stop and say so rather than picking the reading
that makes the task easier.

## Target

iOS only — iPhone and iPad, portrait. No macOS, no tvOS. No back-deploy,
no `#available`. The deployment target is **26.1**, not 26.0: the wallet's
`tabViewBottomAccessory` is 26.1 API and `#available` is banned (decision 52).
Swift 6 language mode.
`SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`, `SWIFT_APPROACHABLE_CONCURRENCY = NO`.
No third-party dependencies — VLCKit was removed along with video playback.

## The toolchain here is ahead of the one this must stay compatible with

There is no CI in this repo — it is removed until the MVP and its local tests
exist. That makes local `xcodebuild` the only signal, and local is misleading:
this machine runs **Xcode 27 / Swift 6.4**, while the toolchain this project
targets is **Xcode 26.6 / Swift 6.2**. Two rules follow, and neither shows up as
a local error:

- **Write no language or standard-library feature newer than Swift 6.2**,
  anywhere. A 6.4-only construct compiles here and breaks the moment CI is
  reinstated.
- **`MixTape.xcodeproj` stays at `objectVersion = 77`**, with
  `preferredProjectObjectVersion = 77` beside it. Xcode 27 rewrites both to
  `90`, which no stable hosted runner can open. If a diff shows either at `90`,
  revert it.

Prefer editing the project file directly over any action that makes Xcode 27
rewrite it. Do not add CI workflows, and do not restore the deleted ones.

## The product rule that gets "fixed" by mistake

On iOS the music half is a CD wallet, not a music browser. **The queue is the
album.** `MusicPlayerService.queue` is exactly one album's tracks. No append API,
no add-to-queue affordance, no shuffle, no repeat, no autoplay into anything.
End of the last track is a navigational event: playback stops, now-playing
dismisses, the wallet returns to the page that album came from.

These are absent, not disabled, not deferred to V2. Do not add them. Do not add
an abstraction that only a cross-album queue would use.

The tvOS build is gone (decision 52). Its files sit in `archive/tvOS/`, out of
the project. Do not revive them as part of an unrelated change.

## Architecture — MV, never MVVM

No ViewModel layer. `@MainActor @Observable` services hold state. Views read
state via `@Environment` and call service methods to act.

```
Presentation → Services → UseCase → Domain
                            ↑
                  Data, Infrastructure
```

Six layer folders under `source/`, all compiled into the one app target
(decision 53). There is no `MixtapeKit` package and no `import MixtapeDomain`.
The edges are still the rule — `Presentation` never reaches into `Data`,
`UseCase` or `Infrastructure`; `UseCase` never imports SwiftUI or Observation;
`AppContainer.swift` is the only place that wires all six — but nothing but
review enforces the folder edges now. `scripts/check-layer-imports.sh` still
enforces the one part a grep can see: `Domain` and `UseCase` stay framework-free.

The tree is `source/` (`App`, `Domain`, `UseCase`, `Infrastructure`, `Data`,
`Services`, `Presentation`), `tests/` (one bundle, folders mirroring `source/`),
`uitest/` (XCUITest) and `archive/tvOS/` (decision 52).

Repositories are stateless `Sendable` structs; caching is an injected
collaborator, never hidden inside one. Infrastructure is stateless or
actor-isolated. Object graph built by hand at the app root with `@Entry` — no DI
container, no service locator, no `.shared`.

## Claude rules

Please remove all mannered prose.

Use lists and bullet points when asked to, or when the content is multifaceted enough that they help with clarity. If the person explicitly requests minimal formatting, always format your responses without bullet points, headers, lists, or bold emphasis, as requested. In conversational, personal, or emotional exchanges, keep to plain prose.

## Swift rules

- One type per file, filename matches. One view per file — no
  `private var header: some View`, no `@ViewBuilder private func`.
- Every view file has a `#Preview` covering empty, nil, and failure states.
- No `fatalError`, `as!`, `try!` without a same-line comment saying why it is
  unreachable.
- No prefix `!` — write `x == false`.
- No Combine. `async`/`await`, `AsyncSequence`, `Observation` cover it.
- Constructor injection only.
- `@concurrent` for real background work only: parsing, decoding, image work.
- Protocol suffix `*Protocol`. `Mock*` in the main target for previews, `Stub*`
  in test targets only.
- Liquid Glass for chrome, always with a Reduce Transparency fallback.
- One platform, so no platform divergence. The `+iOS.swift` suffixes and
  `#if os(iOS)` guards were a leftover of the tvOS split and are gone — the
  files carry the plain type name. Do not reintroduce either.

## Testing

Swift Testing (`@Test`, `@Suite`) — never XCTest.
Tag suites by layer: `.domain`, `.useCase`, `.service`, `.repository`.
Test behaviour, not the mock's plumbing. Inject a clock; never sleep.
Repositories are tested against a stubbed `URLProtocol` — never a live server.

All unit tests are one Xcode test target, `MixtapeTests`, over the whole of
`tests/` — folders named `tests/Domain`, `tests/UseCase`, etc. to match
`source/` (decision 54), but one target, not five (decision 55). It loads into
the app as its test host, so every file uses `@testable import Mixtape` — one
module, one import (decisions 52 and 53).

**No XCUITest this round.** The `MixtapeUITests` target stays wired up and its
stub file stays in place, but no UI test is written and none runs in a gate. Do
not add one, and do not "temporarily" enable the target to check something.

Accessibility identifiers are **still required** on every screen, per
engineering doc §9 — they are what makes the deferred UI tests writable, and
retrofitting them across a finished app is far more work than writing them
beside the view. The accessibility pass and the Reduce Transparency pass both
remain in scope.

## The development server

A local Jellyfin runs at `http://localhost:8096` (server name `mixtape`) from
the compose file in the main repo. It is **version 10.11.11**, and
`docs/jellyfin-openapi.json` is that server's own spec, pulled from
`/api-docs/openapi.json` — so the spec and the server agree. If the server is
ever upgraded, re-pull the spec; see `docs/jellyfin-api.md`.

It is for manual acceptance checks only. No automated test touches it: DTO
mapping runs against captured JSON fixtures, repositories against a stubbed
`URLProtocol`. A test that needs the server running is a broken test.

Read the server through `./scripts/jf-probe.swift` (decision 47); `curl` is
denied on this machine. Enter credentials on the iOS simulator with
`./scripts/sim-type.sh` (decision 46) and screenshot with
`xcrun simctl io <udid> screenshot`. The Apple TV remote helpers moved to
`archive/tvOS/scripts/` with the rest of the tvOS build.

## Scope

Only the 15 capabilities in engineering doc §1 are in scope. Everything in
"Out of scope for V1" is not to be built, and gets no abstraction, no protocol
method, and no TODO.

Deferred beyond that, this round only: **XCUITest** and CI. Both are coming
back, so leave their seams intact — accessibility identifiers for the first,
gate commands that a workflow can call for the second. Do not build either.

## Slice gate criteria

A slice is done only when all of the following hold. Do not start the next slice
until they do.

1. `xcodebuild build` passes for the `Mixtape` scheme.
2. `xcodebuild test` passes for it, unit tests only — new tests included, none
   skipped, none commented out:

   ```
   -skip-testing:MixtapeUITests
   ```

   Skipping the UI bundle is the *only* permitted exclusion. Skipping a unit
   test is never a way to pass this gate.
3. `./scripts/check-layer-imports.sh` exits 0. **Slice 1 creates this script**
   (engineering doc §13 step 1); until it exists, slice 1 is the only slice that
   may run, and creating it is part of slice 1's outcome.
4. `swiftformat --lint .` is clean.
5. The slice's own stated outcome is demonstrable, and the acceptance criteria
   from engineering doc §12 that the slice claims are satisfied.
6. One commit for the slice, message naming the slice.

Resolve a simulator at runtime rather than hardcoding an OS version — this
machine has no iOS 26.0 runtime, so a pinned `OS=26.0` destination fails as a
destination error that reads like a project fault:

```bash
xcrun simctl list devices available
```

If a gate fails twice in a row with no progress between attempts, stop and record
why in `BLOCKED.md` rather than weakening the gate, deleting the test, or moving
on. Never mark a slice complete with a failing or removed test.

You are operating autonomously. The user is not watching in real time and cannot answer
questions mid-task, so asking 'Want me to…?' or 'Shall I…?' will block the work. For
reversible actions that follow from the original request, proceed without asking. Stop
only for destructive actions or genuine scope changes the user must decide. Offering
follow-ups after the task is done is fine; asking permission before doing the work is not.

Exception: when the user is describing a problem, asking a question, or thinking out loud
rather than requesting a change, the deliverable is your assessment. Report your findings
and stop. Don't apply a fix until they ask for one.

Before ending your turn, check your last paragraph. If it is a plan, an analysis, a
question, a list of next steps, or a promise about work you have not done ('I'll…', 'let
me know when…'), do that work now with tool calls. That includes retrying after errors and
gathering missing information yourself. Do not stop because the context or session is long.
End your turn only when the task is complete or you are blocked on input only the user can
provide.

Before running a command that changes system state (such as restarts, deletes, or config
edits), check that the evidence actually supports that specific action. A signal that
pattern-matches to a known failure may have a different cause.

# Delivering work

The user's request — or the plan they approved — sets the scope, and the scope is the
deliverable: don't quietly narrow, widen, or swap it. Read ambiguity the way a careful
colleague would: make routine judgment calls yourself, and check in only when different
readings would lead to materially different work. If you see a real problem with the task
as specified, say so in a sentence or two and keep building under stated assumptions; if
the user hears the concern and reaffirms, that is their decision, so deliver the full
request.

If a question comes up partway, first do everything that doesn't depend on the answer;
then state the assumption you made, or — when going ahead on a wrong guess would be unsafe
or would make the work useless — put the question at the end of a turn that also delivers
that progress. If one part turns out to be blocked, complete every other part in full and
say exactly what you left out and why — the whole task is the deliverable, and scaling it
down is the user's call, not yours. A step you have decided on is something to run, not to
announce: describing the next step and ending the turn leaves it undone until the user
replies.

Keep changes to what the request needs. Something else you notice worth doing — cleanup or
documentation the task didn't call for, a change to a file the task didn't require — is a
suggestion to make at the end, not a change to make; actions clearly beyond what the ask
implies, and risky or destructive ones, still need the user's go-ahead.

# Scope of changes and tests

If, while working or testing, you find a pre-existing bug, a performance concern, or
behaviour the task doesn't mention, don't fix, optimise or extend it in this change unless
the requested behaviour cannot work without it; report it as a follow-up in your summary.
Where the task is ambiguous, implement the reading its wording and the surrounding code
most directly support, state that assumption in your summary, and don't build for the
other readings as well. Verify your work however you like; scratch scripts and quick
checks need not be kept. Commit tests only where the task asks for them or this repository
already keeps tests for this kind of change, sized like the neighbouring test files —
roughly one focused test per stated behaviour — and don't turn scratch checks into
additional permanent test files. This is about extras only: implement every behaviour the
task asks for, completely.

# Edits

The number of tokens used to edit files is best minimized, all else being equal.
Therefore, when it will not affect the end result, try to surgically edit a file rather
than rewrite the entire thing.

# Progress

Before you start, say in a line what you're about to do; brief updates while you work help
the user follow along. Close with a short recap that stands on its own — what you found,
what you did, and what's next — so a reader who only sees the last message has the full
picture.

# Delegation

Delegate to subagents when a task splits into parts that can be researched or read
independently and you only need the conclusions. Give each subagent enough context to
finish on its own — it cannot see this conversation. Send independent subagents in a
single message so they run concurrently. Review the returned work yourself before using
it; spawn a separate reviewer only for changes that are large or hard to verify by reading.
Subagents never commit — you make the commits.

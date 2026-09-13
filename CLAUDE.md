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

## Swift code quality

Write Swift for human readers first. Optimise for clarity, locality, and ease of review rather than brevity or minimising line count.

Follow these references, in priority order:

1. Swift API Design Guidelines
2. Google Swift Style Guide
3. Airbnb Swift Style Guide
4. Kodeco Swift Style Guide
5. Repository `.swiftformat` and SwiftLint configuration

### General principles

- Clarity at the call site is more important than brevity.
- Prefer obvious, conventional Swift over clever or compressed Swift.
- Match the style and abstractions already present in the surrounding code.
- Do not introduce abstractions merely to reduce repetition.
- Do not combine unrelated operations just because Swift syntax permits it.
- Keep control flow shallow and easy to scan.
- Prefer early exits with `guard` where they make the happy path clearer.
- Prefer meaningful intermediate values over deeply nested expressions.
- Prefer descriptive names over abbreviations.
- Avoid unnecessary comments. Prefer code whose intent is apparent from naming and structure.
- Comments should explain why something exists, not restate what the code does.

### Function structure

Functions should read as a sequence of distinct logical steps.

Use blank lines between conceptual phases such as:

- validation and early exits
- cancellation or cleanup
- creation of local state
- mutation of instance state
- data transformation
- calls into controllers, repositories, or services
- reporting, telemetry, or other side effects
- asynchronous follow-up work

Do not produce a long uninterrupted block of unrelated statements.

Prefer:

```swift
guard let session, queue.indices.contains(index) else {
    return
}

progressTask?.cancel()

let generation = OperationGeneration()
let track = queue[index]

currentGeneration = generation
currentIndex = index
position = .zero
status = .preparing

let stream = buildAudioStreamURL(
    track: track,
    session: session,
    playSessionID: playSessionID
)

controller.load(url: stream.url)
controller.play()

status = .playing

await refreshNowPlayingAsync(generation: generation)
```

Avoid:

```swift
guard let session, queue.indices.contains(index) else {
    return
}
progressTask?.cancel()
let generation = OperationGeneration()
let track = queue[index]
currentGeneration = generation
currentIndex = index
position = .zero
status = .preparing
let stream = buildAudioStreamURL(track: track, session: session, playSessionID: playSessionID)
controller.load(url: stream.url)
controller.play()
status = .playing
await refreshNowPlayingAsync(generation: generation)
```

### Function calls and declarations

Keep short, genuinely simple calls on one line.

Use multiline formatting when a call:

- has several labelled arguments
- is difficult to scan on one line
- mixes closures with other arguments
- approaches the configured line-length limit
- benefits from visually exposing the role of each argument

Prefer:

```swift
let stream = buildAudioStreamURL(
    track: track,
    session: session,
    playSessionID: playSessionID
)
```

over a dense equivalent when the multiline form is easier to read.

Do not force every call to be multiline. Use judgement based on readability.

### Expressions

Do not optimise for the fewest expressions or statements.

Avoid dense expressions containing multiple transformations, optional operations, closures, or side effects.

Prefer:

```swift
let activeTracks = tracks.filter(\.isActive)
let sortedTracks = activeTracks.sorted(using: sortOrder)
```

when it is easier to understand than chaining everything together.

Keep fluent chains together when the sequence itself is the clearest representation.

### Naming

Names should make usage understandable without consulting the declaration.

- Use nouns for values and types.
- Use verbs or verb phrases for actions.
- Name booleans so they read as assertions, such as `isPlaying`, `hasNextTrack`, or `canRetry`.
- Avoid vague names such as `data`, `info`, `value`, `result`, `item`, or `manager` when a more precise domain name exists.
- Avoid abbreviations unless they are conventional within Swift or the codebase.
- Do not encode type information redundantly in names.

### Types and APIs

Prefer small APIs with clear responsibilities.

Do not add:

- unnecessary protocols
- wrapper types with no behavioural purpose
- generic abstractions for a single concrete use
- helper functions used only once unless they materially improve readability
- dependency layers solely to make code appear architecturally pure

Extract code when the extracted concept has a meaningful name or isolates a coherent responsibility.

### Swift-specific style

- Prefer type inference when the type is obvious.
- Avoid explicit `self` unless required or useful for disambiguation.
- Prefer optional shorthand binding such as `guard let session else`.
- Prefer modern Swift APIs and language features supported by the deployment target.
- Prefer value semantics unless identity or shared mutable state is required.
- Respect Swift 6 strict concurrency.
- Treat actor isolation, `Sendable`, and task lifetime as correctness concerns, not compiler obstacles.
- Do not use `@unchecked Sendable` to silence concurrency errors unless the safety invariant is understood and documented.
- Prefer structured concurrency over detached or unstructured tasks.
- Avoid unnecessary `Task {}` wrappers.

### SwiftUI

- Use SwiftUI-first design.
- Keep views declarative.
- Do not move simple presentation logic into unnecessary view models.
- Prefer focused `@Observable` models where mutable shared state is actually required.
- Keep side effects outside `body`.
- Extract subviews when they represent meaningful UI concepts or materially improve readability, not merely to reduce line count.

### Changes to existing code

Before editing:

- inspect nearby code
- preserve established terminology
- preserve architectural boundaries
- reuse existing helpers and patterns where appropriate

Do not rewrite surrounding code unless doing so is necessary for the requested change.

Avoid unrelated cleanup in focused changes.

### Formatting

The repository formatter is authoritative.

After editing Swift files, run:

```bash
swiftformat .
```

Do not manually fight formatter output.

Formatting is only the final mechanical pass. Code should already be organised into readable logical sections before formatting.

### Final review

Before considering Swift work complete, reread the changed code as if reviewing another engineer's pull request.

Check that:

- intent is obvious without reconstructing the implementation mentally
- functions have a clear narrative flow
- logical phases are visually separated
- names communicate domain meaning
- expressions are not unnecessarily dense
- control flow is straightforward
- concurrency is correct
- no needless abstraction was introduced
- the resulting code looks like deliberate production Swift rather than generated code

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

```bash
xcrun simctl list devices available
```

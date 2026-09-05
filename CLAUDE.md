# mixtape — build repo

A Jellyfin client for iOS and tvOS. Browse video and music libraries, play both,
report progress back.

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

iOS 26+, tvOS 26+. No macOS. No back-deploy, no `#available`.
Swift 6 language mode.
`SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`, `SWIFT_APPROACHABLE_CONCURRENCY = NO`.
VLCKit is the only third-party dependency.

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

tvOS gets a conventional focus-driven album grid. No wallet there.

## Architecture — MV, never MVVM

No ViewModel layer. `@MainActor @Observable` services hold state. Views read
state via `@Environment` and call service methods to act.

```
Presentation → Services → UseCase → Domain
                            ↑
                  Data, Infrastructure
```

Six SPM targets in `MixtapeKit`, layout and dependency edges per engineering doc
§3. `MixtapePresentation` never depends on `MixtapeData`, `MixtapeUseCase`, or
`MixtapeInfrastructure`. `MixtapeUseCase` never imports SwiftUI or Observation.
The composition root in the app target is the only place that sees all six.

Repositories are stateless `Sendable` structs; caching is an injected
collaborator, never hidden inside one. Infrastructure is stateless or
actor-isolated. Object graph built by hand at the app root with `@Entry` — no DI
container, no service locator, no `.shared`.

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
- Platform divergence: two files with `#if os(iOS)` / `#if os(tvOS)`, named for
  what they are. Never one file branching inside a body.

## Testing

Swift Testing (`@Test`, `@Suite`) — never XCTest.
Tag suites by layer: `.domain`, `.useCase`, `.service`, `.repository`.
Test behaviour, not the mock's plumbing. Inject a clock; never sleep.
Repositories are tested against a stubbed `URLProtocol` — never a live server.

**No XCUITest this round.** The `iOSUITests` and `tvOSUITests` targets stay
wired up and their stub files stay in place, but no UI test is written and none
runs in a gate. Do not add one, and do not "temporarily" enable the targets to
check something.

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
denied on this machine. Drive the Apple TV simulator with
`./scripts/tv-remote.sh <udid> up|down|left|right|select|menu|type:TEXT`
(decision 49) — `idb ui key` and `idb ui remote` are refused on this
CoreSimulator, and the Xcode 26.6 Simulator app's keyboard never reaches tvOS.
Screenshot between presses with `xcrun simctl io <udid> screenshot`; there is
no accessibility tree for tvOS over `idb`, so identifier queries wait for XCUITest.

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

1. `xcodebuild build` passes for both the `iOS` and `tvOS` schemes.
2. `xcodebuild test` passes for both schemes, unit tests only — new tests
   included, none skipped, none commented out:

   ```
   -skip-testing:iOSUITests      # iOS scheme
   -skip-testing:tvOSUITests     # tvOS scheme
   ```

   Skipping the UI bundles is the *only* permitted exclusion. Skipping a unit
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

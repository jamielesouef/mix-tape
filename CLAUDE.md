# Mix Tape

An album-centric Jellyfin client for iOS and tvOS. Browse and play video and music from a Jellyfin server, with a music experience built around one idea: pulling a CD out of a wallet. SwiftUI, MV architecture, no subscriptions and no server of our own to maintain.

**Read before working:** [`docs/architecture.md`](docs/architecture.md) is authoritative for app architecture. [`docs/engineering-doc.md`](docs/engineering-doc.md) is the approved V1 specification — scope, layers, API contract, screens, acceptance criteria. Precedence, highest first: the [settled decisions](#settled-decisions), then the architecture doc, then the engineering doc — and this file loses to all three.

## The product rule that gets "fixed" by mistake

The design concept is pulling a CD out of a wallet. You pick an album, it plays, it finishes, you are back at the wallet.

**The queue *is* the album.** Loading an album replaces the player queue entirely. Next on the final track stops playback and does nothing else — it never advances to another album. There is no cross-album queue, no shuffle, no repeat, no algorithmic up-next. This is deliberate, it is the whole concept, and it must not be "improved". Code that enforces it carries a comment saying so.

Three things follow, and all three are tested:

- `MusicPlayerService` has no `enqueue`, no `append`, no `shuffle`, no `repeatMode`. `play(album:tracks:startingAt:)` **replaces** the queue and is the only way tracks get into it.
- Shuffle and repeat controls are **absent** from the UI, not hidden and not disabled.
- End of the last track is a *navigational* event. The now-playing surface dismisses and the wallet returns to the sleeve that just finished.

The wallet itself is **iOS only**. tvOS gets a conventional focus-driven album grid — the metaphor depends on touch and on holding the device, and it does not survive a ten-foot interface. Do not build it there. Video is unaffected by any of this.

## Jellyfin is the server

We do not ship a server. The previous architecture — a Hummingbird service in Docker on a NAS, a `Shared` DTO package, an AGPL server licence, ffmpeg tag scanning, a Linux CI job — **is gone**. Do not reintroduce any of it, and do not port code forward from it without a reason that survives being said out loud.

What replaced it:

- **The Jellyfin HTTP API is the whole backend.** Target Jellyfin **10.10+**. Every instance serves its own OpenAPI spec at `{base}/api-docs/swagger` — check that against the running server before trusting any endpoint shape written down here or in the engineering doc.
- **One `Authorization: MediaBrowser …` header format on every request**, including unauthenticated ones. Never `X-Emby-Authorization` — Jellyfin is removing it in 10.13.
- **`DeviceId` is a UUID generated once and kept in the Keychain.** It must survive app restarts and reinstall-free updates. Jellyfin keys sessions, Quick Connect approvals and transcode jobs off it, so regenerating it silently breaks all three.
- **Use the query-parameter form of user-scoped endpoints** — `/Items?userId=…`, never `/Users/{userId}/Items`. The path form is deprecated.
- **Jellyfin returns PascalCase.** Explicit `CodingKeys` on every DTO. No key decoding strategy, ever — a strategy that silently half-works is worse than a compile error.
- **Progress-reporting failures are logged and swallowed.** A dropped `/Sessions/Playing/Progress` must never surface as a playback error.
- Self-hosted servers on plain HTTP over LAN are the normal case, so `NSAllowsArbitraryLoads` is on. That is a deliberate trade, documented in the README, not an oversight to tighten.

## Playback

Video has exactly three paths, decided once in `ResolveVideoPlaybackUseCase` and nowhere else:

| Method | When |
|---|---|
| `.directAVPlayer` | Server direct-plays **and** the container/codec is AVPlayer-native |
| `.directVLC` | Server direct-plays but AVPlayer would refuse — mkv, webm, vp9, av1, dts, opus |
| `.transcodeHLS` | No direct source; play the server's HLS transcode URL |

We send **one permissive device profile** covering VLC's range, not AVPlayer's. That is the point of carrying VLCKit at all: it keeps MKV/HEVC/DTS off the server's transcoder. `isAVPlayerNative(_:)` is a pure Domain function with a fixture table — the branch decision is unit-tested without a server.

`VLCPlayerController` is the **only** file in the repository that imports VLCKit. Presentation sees `VideoPlayerControlling` and an `AnyView`, never an `AVPlayer` and never a `VLCMediaPlayer`. That isolation is what makes the LGPL story simple and what makes VLCKit removable.

Music takes no `PlaybackInfo` round-trip. The `/Audio/{id}/universal` URL asks for the containers Apple decodes natively — `flac,alac,m4a,mp3,aac,wav,aiff` — so a properly tagged library direct-streams every time. The HLS fallback exists for genuine exotica; when it fires, log the item ID at `.info` on the `playback` category. **A transcode on a music library is a diagnostic, not a normal path.**

## Repository layout

```
mixtape/
├── Apps/
│   ├── MixtapeiOS/      App target: App.swift, Assets, Info.plist. Nothing else
│   └── MixtapeTV/       App target: App.swift, Assets, Info.plist. Nothing else
├── MixtapeKit/          Swift package. Six library targets, one per layer
├── docs/                architecture.md, engineering-doc.md, slices/
└── scripts/             check-layer-imports.sh, check-spdx.sh
```

The six layers are **six library targets in one local package**, not six folders in one app target. Two app targets share the code, so a package is required regardless — and once it exists, letting SwiftPM enforce the dependency edges is free. `Package.swift` is the enforcement; `check-layer-imports.sh` is the backstop for what the manifest cannot express.

App targets contain `App.swift`, the asset catalog and the Info.plist. The composition root is the **only** file in the repository that imports all six library targets. If a view, a model or a helper lands in an app target, it is in the wrong place.

## App architecture — MV, never MVVM

**No ViewModels, ever.** `@MainActor @Observable final class` services hold state and are the only place state is written. Views read state through `@Environment` and call service methods to act.

```
Presentation → Services → UseCase → Domain
                             ↑
                   Data, Infrastructure
```

| Target | Holds | May depend on |
|---|---|---|
| `MixtapeDomain` | Entities, value types, domain errors, pure rules | Foundation only |
| `MixtapeUseCase` | One type per use case, repository protocols | `MixtapeDomain` |
| `MixtapeServices` | `@MainActor @Observable` classes — the only writers of state | `MixtapeUseCase`, `MixtapeDomain` |
| `MixtapeInfrastructure` | `JellyfinHTTPClient`, keychain, players, logging, VLCKit | Foundation, SDKs |
| `MixtapeData` | Repository implementations, DTO-to-Domain mapping | `MixtapeUseCase`, `MixtapeDomain`, `MixtapeInfrastructure` |
| `MixtapePresentation` | SwiftUI views only | `MixtapeServices`, `MixtapeDomain` |

- `MixtapeUseCase` and `MixtapeDomain` never import SwiftUI, Observation, UIKit or AVFoundation. `scripts/check-layer-imports.sh` enforces this and fails the build.
- `MixtapePresentation` does not list `MixtapeData`, `MixtapeUseCase` or `MixtapeInfrastructure` as dependencies. If a view needs data shaped differently, that is the service's job.
- `MixtapeData` repositories are stateless `Sendable` structs. No caching hidden inside a repository — caching is its own injected collaborator.
- `MixtapeInfrastructure` is stateless or actor-isolated. Never a plain class with mutable state. The player controllers are the exception and are `@MainActor` by necessity.
- No DTO escapes `MixtapeData`. Mapping happens in a `*Mapper.swift` beside the repository that owns it.
- No use case or repository type appears in a view's signature.
- Liquid Glass by default for chrome, and **every** use ships a Reduce Transparency fallback. A glass surface with no fallback is a defect, not a polish item.

Group by feature inside a layer, not by file type: `MixtapeServices/<Feature>/`, `MixtapeUseCase/UseCases/<Feature>/`, `MixtapePresentation/Screens/<Feature>/`. Presentation components split by role instead: `Components/Cards/`, `Chrome/`, `Feedback/`, `Rows/`, `Styles/`.

Where iOS and tvOS layouts genuinely diverge, write **two files**, each wrapped in `#if os(…)` and named for what it is — `MovieLibraryGrid.swift` and `MovieLibraryShelf.swift` — never one file with a platform branch inside the body. One view per file still holds.

Wire with `@Entry`, never a hand-rolled `EnvironmentKey`. Build the whole object graph once, by hand, at the app root. No DI container, no service locator.

## Swift rules

- Swift 6 strict concurrency throughout, non-negotiable. Swift 6 language mode is the invariant. The local toolchain runs ahead of what CI pins — Xcode 27 / Swift 6.4 on the machine, Xcode 26.6 in CI — so the pins below, not the local compiler, are what the code is really held to.
- **Write no language or standard-library feature newer than Swift 6.2, anywhere in the repository.** `App/` builds on GitHub's `macos-26` runner under **Xcode 26.6**, a Swift 6.2 toolchain. A 6.4-only construct passes locally and fails a build nobody runs until CI.
- **The app project stays at `objectVersion = 77`.** Xcode 27 writes `90`, which no stable hosted runner can open. `preferredProjectObjectVersion` is pinned to `77` alongside it — that is the setting that otherwise lets Xcode 27 rewrite the format on the next open. If a diff shows either back at `90`, revert it rather than bumping the runner.
- iOS 26+, tvOS 26+. No back-deploy, no `#available` checks. No macOS target in V1.
- Project level: `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`, `SWIFT_APPROACHABLE_CONCURRENCY = NO`.
- Actors stay actors. `nonisolated` fixes `Decodable` warnings — never convert an actor to `@MainActor final class` to silence one.
- `@concurrent` for real background work only: image decoding is the one place in V1 that qualifies.
- No `DispatchQueue` in new code. `Mutex` over `NSLock`.
- No `@unchecked Sendable` and no `nonisolated(unsafe)` without a justification comment saying why it is safe.
- No Combine. `async`/`await`, `AsyncSequence` and Observation cover it.
- Constructor injection only. No singletons, no `.shared`, except wrapped system types behind a protocol.
- No abstraction without a second conformer. Repository protocols are exempt: their `Mock*`/`Stub*` test doubles are the second conformer.
- `x == false`, never prefix `!`.
- One type per file, filename matching the type. One view per file — no `private var header: some View`, no `@ViewBuilder private func`.
- Every view file has a `#Preview` covering its states, including empty, nil and failure.
- No `fatalError`, `as!` or `try!` without a same-line comment saying why it is unreachable.
- Protocol suffix `*Protocol`. Test doubles `Mock*` (main target, for previews) and `Stub*` (test target only).
- 2-space indentation. No inline comments. Trailing commas on multi-line argument lists.
- No `TODO` or `FIXME` in committed code.

## Testing

- Swift Testing (`@Test`, `@Suite`) for unit tests. **Never XCTest**, except for XCUITest.
- Tag suites by layer: `.domain`, `.useCase`, `.service`, `.repository`.
- Every use case and service is tested against injected `Mock*`/`Stub*`, never a real `MixtapeData` implementation.
- **Never test a repository against a live Jellyfin instance.** Stub `URLProtocol`, and map DTOs against captured JSON fixtures in `Tests/MixtapeDataTests/Fixtures/`.
- Inject a clock. Quick Connect polling and progress reporting are both timer-driven and neither test may sleep.
- Test behaviour, not the mock's plumbing.
- One happy-path XCUITest per platform, launched into a stubbed session via `-uitest-signed-in`, driven off accessibility identifiers and never visible text.
- **`MusicPlayerService` gets a suite dedicated to the §1.1 invariants** — next past the final track stops, a second `play(album:)` replaces rather than appends, `finishedAlbumID` fires exactly once. These are the tests that stop someone helpfully adding a cross-album queue in six months.

## Persistence

**There is no SwiftData in V1.** Nothing is cached to disk. The Keychain holds the access token and the device UUID, and that is the entire persistent state of the app.

Images are cached in memory only, in an `NSCache` capped at 120 MB, and are expected to be lost on backgrounding. That is fine — Jellyfin serves them fast and the URLs are stable.

Downloads and offline playback are out of scope. When they land, the boundary that matters is the one the old architecture already got right: **download models are local truth and carry their own copy of every field needed to render and play.** No relationship crosses from a cache model to a download model, so a library refresh cannot delete something the user downloaded. Do not build the cache layer in a way that makes that split hard to add later.

## Licensing

MIT throughout. There is no server package and no AGPL boundary any more — the dual-licence split, and the reasoning about MIT flowing into AGPL, went with the server.

**VLCKit is LGPL-2.1-or-later.** It stays dynamically linked as the vendored xcframework, and it is reachable from exactly one file. Do not statically link it, do not vendor modified VLCKit sources, and do not let a second file import it. The licence obligation is satisfied by dynamic linking plus attribution in the app's acknowledgements; anything else means legal review.

`SPDX-License-Identifier: MIT` is the **first line** of every source file, above the Xcode header block. `scripts/check-spdx.sh` enforces it. A `Package.swift` is the sole exception, because Swift parses `// swift-tools-version:` positionally and will not build a manifest without it on line 1 — so there the tools-version is line 1 and SPDX is line 2. The script keys that exemption on the filename. An exemption a script cannot check is not an exemption, it is a hole.

## Settled decisions

Resolved by the project owner. Record them, do not relitigate them.

| | Decision |
|---|---|
| D1 | **Jellyfin replaces the in-house server.** No Hummingbird, no `Shared` package, no Docker, no Linux CI. The maintenance cost of a music server is not worth paying when Jellyfin exists |
| D2 | Six layers as **six library targets in one package**, not folders in one target. Two app targets force a package anyway, so the compile-time enforcement is free. This is a deliberate reversal of the previous project's C1 |
| D3 | Repository protocols are allowed. Their test doubles are the second conformer |
| D4 | Ship **both** AVPlayer and VLCKit, with one permissive device profile. Direct play beats a smaller binary — transcoding a 4K remux on a NAS is the failure mode this exists to avoid |
| D5 | Quick Connect is the **primary** sign-in path on tvOS, password secondary. Typing a password on a Siri Remote is the worst experience in the app |
| D6 | The wallet is **iOS only**. tvOS gets a conventional grid |
| D7 | Video is a conventional Jellyfin client. The album doctrine applies to music and nothing else |
| D8 | No SwiftData in V1. Keychain and an in-memory image cache are the whole persistence story |

Deliberate V1 simplifications each have a named seam. Reach for the seam rather than reopening the decision.

**Where a slice's decision log departs from the engineering doc, the slice wins,** recorded as a numbered fork in [`docs/slices/MASTER-CHECKLIST.md`](docs/slices/MASTER-CHECKLIST.md) with what was rejected and why. If you find the engineering doc and a slice disagreeing and there is no fork row, that is drift — log it in the checklist's Drift Log and stop, rather than picking the reading that makes the task easier.

## How work is done here

Work is delivered as **slices** in [`docs/slices/`](docs/slices/), in number order. The engineering doc's build order (§13) defines that sequence and its shippable checkpoints — sign-in, then browse, then video, then music, then the wallet, then tvOS. Each slice document is the specification for its own build; the master checklist is the only home for status, owner and blockers.

- Complete the slice's pre-flight validation **before the first line of code**.
- Write a decision-log row **before** implementing the decision it describes, including the alternatives rejected. A log filled in at close is reconstructed from memory, and the rejected alternatives are exactly what memory loses first.
- Widening scope means editing the slice's Section 3 and the `depends_on` of anything now affected.
- The slice document and its code belong in **one** commit, with the slice id in the subject (`001: add package skeleton`). You do not run it — hand over the one command that commits both together.

## Conventions

- **Australian spelling in prose and documentation. American spelling in identifiers.** `colour` in a comment, `color` in a property name.
- Never hard-wrap markdown prose at a column limit — one line per paragraph. Never reflow tables, fenced code blocks, headings or list items.
- Swift file headers use the standard Xcode format, **below** the SPDX line. Date `DD/MM/YYYY`, two spaces after `//` on the `Created by` line, name `Jamie Le Souëf`.
- **Do not auto-commit.** Leave work in the working tree and hand over the command.
- **`main` is a protected branch and refuses a direct push, administrators included.** Work lands through a pull request — branch, commit, push the branch, open the PR with `gh`. No approving review is required, so a solo change is not blocked, but the pull request itself is. Force pushes and branch deletion are refused, and history must stay linear.
- **Never add `Co-Authored-By` trailers or any AI attribution** to a commit, PR, issue or any other artefact.
- Use the `gh` CLI for GitHub operations, never the REST API directly.

```swift
// SPDX-License-Identifier: MIT
//
//  PlaybackPlan.swift
//  MixtapeDomain
//
//  Created by Jamie Le Souëf on 03/09/2026.
//
```

## Verify

```bash
xcodebuild -scheme Mixtape   -destination 'generic/platform=iOS Simulator'  -configuration Debug build
xcodebuild -scheme MixtapeTV -destination 'generic/platform=tvOS Simulator' -configuration Debug build
xcodebuild test -scheme Mixtape   -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.0'
xcodebuild test -scheme MixtapeTV -destination 'platform=tvOS Simulator,name=Apple TV 4K (3rd generation),OS=26.0'
./scripts/check-layer-imports.sh         # test the failure case too, not just the pass
./scripts/check-spdx.sh                  # ditto — break one header on purpose
swiftformat --lint .
```

Against a live server, the checks that matter are in the engineering doc's acceptance criteria — in particular: an mp4/h264 movie and an mkv/hevc/dts movie both play with **no transcode session** in the Jellyfin dashboard, and a FLAC album does the same.

A check that has never failed is not known to work. When you add one, prove it fails.

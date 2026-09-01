# Mix Tape

Self-hosted, album-centric music server and client. A Plex alternative for music, built to avoid subscriptions. Swift server (Hummingbird 2, Docker on a NAS) plus a SwiftUI client for iOS, iPadOS and macOS. Open source from the first public commit.

**Read before working:** [`docs/app-architecture-template.md`](docs/app-architecture-template.md) is authoritative for app architecture. [`docs/plan/v1-architecture.md`](docs/plan/v1-architecture.md) is the approved v1 design. [`docs/handoff.md`](docs/handoff.md) is the project brief. Precedence, highest first: the [settled decisions](#settled-decisions) and the numbered forks, then the template, then the plan — and this file loses to all three.

## The product rule that gets "fixed" by mistake

The design concept is pulling a CD out of a wallet. You pick an album, it plays, it finishes, you are back at the wallet.

**The queue *is* the album.** Loading an album replaces the player queue entirely. Next on the final track stops playback and does nothing else — it never advances to another album. There is no cross-album queue, no shuffle, no algorithmic up-next. This is deliberate, it is the whole concept, and it must not be "improved". Code that enforces it carries a comment saying so.

## Repository layout

```
mixtape/
├── Shared/      Swift package. DTOs. ZERO external dependencies. Must compile on Linux
├── Server/      Swift package. Hummingbird 2, JWTKit, .package(path: "../Shared")
├── App/         MixTape.xcodeproj. Six layer folders in ONE target
├── docs/        plan, handoff, architecture template, slices
└── scripts/     check-layer-imports.sh, check-spdx.sh
```

`Shared` has its own `Package.swift` deliberately. If the app depended on a manifest declaring Hummingbird, Xcode would resolve and clone Hummingbird's entire dependency tree on every project open despite never building it. Split manifests keep app dependency resolution at zero external packages. Do not merge the manifests, and do not create a `Shared` target inside the server package.

Both sides reference `Shared` by relative path. No tags, no versioning — a DTO change is immediately visible on both sides. That is the point of the monorepo.

## Shared must stay Linux-clean

`Codable`, `Sendable`, Foundation-only types. No SwiftData, no `@Observable`, no Core Graphics, no UIKit, no SwiftUI, no Apple-only Foundation API.

When it breaks on Linux the temptation is to duplicate the type. **Do not.** Fix the type so it stays portable.

One approved non-DTO lives there: `MixTapeJSON`, holding a `JSONEncoder` and `JSONDecoder` both configured `.iso8601`. It exists so the two sides cannot drift on date encoding. Never construct a bare `JSONEncoder()` or `JSONDecoder()` in `Server/` or `App/` — go through `MixTapeJSON`.

Interim check until the Linux CI job lands: `grep -r "import SwiftData\|import CoreGraphics\|import UIKit\|import SwiftUI\|@Observable" Shared/` returns nothing.

## App architecture — MV, never MVVM

**No ViewModels, ever.** `@MainActor @Observable final class` services hold state and are the only place state is written. Views read state through `@Environment` and call service methods to act.

The six layers are **folders inside one app target**, not six build targets. Dependency direction is unchanged:

```
Presentation → Services → UseCase → Domain
                             ↑
                   Data, Infrastructure
```

| Folder | Holds | May depend on |
|---|---|---|
| `AppDomain` | Entities, value types, domain errors, pure rules | Foundation only |
| `AppUseCase` | One type per use case, repository protocols | `AppDomain` |
| `AppServices` | `@MainActor @Observable` classes — the only writers of state | `AppUseCase`, `AppDomain` |
| `AppInfrastructure` | `APIClient` (an actor), keychain, logging | Foundation, SDKs |
| `AppData` | Repository implementations, DTO-to-Domain mapping, `Persistence/` | `AppUseCase`, `AppDomain`, `AppInfrastructure` |
| `AppPresentation` | SwiftUI views only | `AppServices`, `AppDomain` |

- `AppUseCase` and `AppDomain` never import SwiftUI or Observation. `scripts/check-layer-imports.sh` enforces this by folder path and fails the build.
- `AppData` repositories are stateless `Sendable` structs. No caching hidden inside a repository — caching is its own injected collaborator.
- `AppInfrastructure` is stateless or actor-isolated. Never a plain class with mutable state.
- Exception: SwiftData `ModelContainer`, `@Model` types and store actors live in `AppData/Persistence/`.
- No use case or repository type appears in a view's signature. If a view needs data shaped differently, that is the service's job.
- `AppPresentation` uses Liquid Glass by default for chrome, and every use of it ships a Reduce Transparency fallback. The template requires the fallback; a glass surface with no fallback is a defect, not a polish item.

Group by feature inside a layer, not by file type: `AppServices/<Feature>/`, `AppUseCase/UseCases/<Feature>/`, `AppPresentation/Screens/<Feature>/`. Presentation components split by role instead: `Components/Cards/`, `Chrome/`, `Feedback/`, `Rows/`, `Styles/`.

Wire with `@Entry`, never a hand-rolled `EnvironmentKey`. Build the whole object graph once, by hand, at the app root. No DI container, no service locator.

## Swift rules

- Swift 6 strict concurrency throughout, non-negotiable. Swift 6 language mode is the invariant. The local toolchain runs ahead of what CI pins — Xcode 27 / Swift 6.4 on the machine, Xcode 26.6 and `swift:6.2-noble` in CI — so the pins below, not the local compiler, are what the code is really held to.
- **Write no language or standard-library feature newer than Swift 6.2, anywhere in the repository.** Not an interim measure — slice 003 pinned both sides and this is the standing rule. `Shared/` and `Server/` compile inside `swift:6.2-noble`, and `App/` builds on GitHub's `macos-26` runner under **Xcode 26.6**, which is a Swift 6.2 toolchain. A 6.4-only construct passes on the local machine and fails a build nobody runs until CI, on either side.
- **The app project stays at `objectVersion = 77`.** Xcode 27 writes `90`, which no stable hosted runner can open. `preferredProjectObjectVersion` is pinned to `77` alongside it — that is the setting that otherwise lets Xcode 27 rewrite the format on the next open. If a diff ever shows either back at `90`, revert it rather than bumping the runner.
- iOS 26+, macOS 26+. No back-deploy, no `#available` checks.
- Project level: `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`, `SWIFT_APPROACHABLE_CONCURRENCY = YES`.
- Actors stay actors. `nonisolated` fixes `Decodable` warnings — never convert an actor to `@MainActor final class` to silence one.
- `@concurrent` for real background work only: parsing, decoding, image work.
- No `DispatchQueue` in new code. `Mutex` over `NSLock`.
- No `@unchecked Sendable` and no `nonisolated(unsafe)` without a justification comment saying why it is safe.
- **`DownloadSessionDelegate` is the only justified `nonisolated` delegate shim in the codebase.** A background `URLSession` delegate genuinely cannot be `@MainActor`, and its justification is written in the file. Do not add a second one — if concurrency is fighting you elsewhere, that is a design problem, not a shim.
- No SwiftData `@Model` object crosses an isolation boundary. Use a `ModelActor` for import and pass `PersistentIdentifier`, never the objects.
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
- Every use case and service is tested against injected `Mock*`/`Stub*`, never a real `AppData` implementation.
- Test behaviour, not the mock's plumbing.
- One happy-path XCUITest per screen, driven off accessibility identifiers, never visible text.

## Data model

**The single most important schema decision:** store album artist separately from track artist, and key albums on `(albumArtist, title, discNumber)`. Keying on track artist explodes every compilation and every guest-feature track into a one-track album. Retrofitting this means a migration.

**Multi-disc:** one grid tile per disc, but the discs of a release must always render adjacently. Adjacency is structural, not a sort rule — the grid iterates `[Release]` and a release owns its discs, so a foreign album between disc 1 and disc 2 is unrepresentable. The disc-set shape is a domain type (`DiscSet`), not something inferred at render time.

**SwiftData has a hard split, and it is the whole boundary:**

- **Cache models** (`CachedAlbum`, `CachedTrack`) — the server is the source of truth. A changed manifest replaces them wholesale. No incremental sync logic.
- **Download models** (`DownloadedAlbum`, `DownloadedTrack`) — local truth. Not derivable from the server. They carry their own copy of every field needed to render and play, and never read a cache model.

**No SwiftData relationship crosses between the two groups.** They associate only by matching `id` strings, joined in memory at read time. That absence of a relationship is what makes a full manifest replacement unable to touch a download. If a NAS rescan wipes downloaded albums off the phone, the app feels broken.

Download file paths are stored **relative** to the downloads root, never absolute. The app container path changes between launches and updates.

## Server

- Hummingbird 2, structured-concurrency native. Chosen over Vapor for footprint.
- **Direct play only. The server never transcodes.** AVFoundation natively plays FLAC, ALAC, MP3, AAC, WAV and AIFF. Ogg Vorbis is the only meaningful gap and is out of scope.
- `FileMiddleware` handles HTTP `Range`. **Never hand-roll byte-range streaming.**
- **No image processing on the server.** Linux has no Core Graphics. Serve the original embedded artwork; the client downsamples with ImageIO and caches the result.
- Tag scanning shells out to `ffprobe -print_format json`, and artwork extraction to `ffmpeg -c:v copy` — a stream copy, never a re-encode. Both come from the `ffmpeg` package in the Docker image. Invoking a binary is licence-clean; **do not link ffmpeg.**
- Library index is an in-memory structure rebuilt at boot and snapshotted to JSON. Genuinely sufficient for a personal library. GRDB only if it outgrows it.
- Sign in with Apple is used **once**, for pairing. The server then issues its own long-lived token. Apple's identity token is never the session token — it is short-lived, and refreshing it needs a client secret Apple caps at six months.
- All configuration is read into one `ServerConfiguration` type. Do not reach for `ProcessInfo` elsewhere.

## Licensing

| Path | Licence |
|---|---|
| `Shared/` | MIT |
| `App/` | MIT |
| `Server/` | AGPL-3.0-only |

`Shared` **must** stay permissive. MIT flows into AGPL; AGPL does not flow into MIT. An AGPL `Shared` would make the MIT client claim invalid. `SPDX-License-Identifier` is the **first line** of every source file, matching that file's directory, and it sits **above** the Xcode header block — see [Conventions](#conventions) for the exact combined form. No AGPL code is reachable from the app target.

**The one exception, and it is mechanical, not discretionary: a package manifest.** Swift parses `// swift-tools-version:` positionally and will not build a `Package.swift` that does not carry it on line 1. So in a manifest the tools-version line is line 1 and the SPDX line is **line 2**. `Shared/Package.swift` is `MIT`; `Server/Package.swift` is `AGPL-3.0-only`. `scripts/check-spdx.sh` encodes exactly this — for a file named `Package.swift` it asserts line 1 matches `swift-tools-version` and line 2 is the directory's SPDX; for every other `.swift` file it asserts line 1 is the SPDX. No other file is exempt, and the exemption is keyed on the filename so the script can express it. An exemption a script cannot check is not an exemption, it is a hole.

## Settled decisions

Resolved by the project owner. Record them, do not relitigate them. Full reasoning is in the plan's Conflicts section.

| | Decision |
|---|---|
| C1 | Six layers as **folders in one app target**, not six build targets. Every other template rule holds |
| C2 | `APIClient` is the actor and `LibraryRepository` is a stateless struct. `LibraryService` holds no private actor |
| C3 | Repository protocols are allowed. Their test doubles are the second conformer |
| C4 | `MixTapeJSON` lives in `Shared` despite "DTOs only" |
| C5 | One Swift language level covers the whole repository, because `Shared` compiles under both sides. The Docker build stage is `swift:6.2-noble` — **not** the handoff's `swift:6.1-noble`. The local toolchain has since moved ahead of 6.2; see [Swift rules](#swift-rules) |
| C6 | `MIXTAPE_APPLE_TEAM_ID` is documented but read by nothing in v1. Only the bundle ID is needed to verify an identity token |
| C7 | Ogg Vorbis is out of scope |

Deliberate v1 simplifications each have a named seam and are recorded as numbered ladders in [`docs/slices/MASTER-CHECKLIST.md`](docs/slices/MASTER-CHECKLIST.md). Reach for the seam rather than reopening the decision.

**Where a slice's decision log departs from the plan, the slice wins.** Those departures are numbered forks (F1–F6) in the same checklist, each with a decision row saying what was rejected and why. So the precedence, highest first, is: **settled decisions and forks, then the template, then the plan.** Settled decisions sit above the template because that is what they are for — C1 contradicts the template outright and wins. If you find the plan and a slice disagreeing and there is no fork row, that is drift — log it in the checklist's Drift Log and stop, rather than picking the reading that makes the task easier.

## How work is done here

Work is delivered as **slices** in [`docs/slices/`](docs/slices/), in number order. Each slice document is the specification for its own build, and the master checklist is the only home for status, owner and blockers.

- Complete the slice's pre-flight validation **before the first line of code**.
- Write a decision-log row **before** implementing the decision it describes, including the alternatives rejected. A log filled in at close is reconstructed from memory, and the rejected alternatives are exactly what memory loses first.
- Widening scope means editing the slice's Section 3 and the `depends_on` of anything now affected.
- The slice document and its code belong in **one** commit, with the slice id in the subject (`001: add monorepo skeleton`). Per [Conventions](#conventions) you do not run it — hand over the one command that commits both together, rather than committing the code now and the document later.

## Conventions

- **Australian spelling in prose and documentation. American spelling in identifiers.** `colour` in a comment, `color` in a property name.
- Never hard-wrap markdown prose at a column limit — one line per paragraph. Never reflow tables, fenced code blocks, headings or list items.
- Swift file headers use the standard Xcode format, **below** the SPDX line — see the exact shape below. Date `DD/MM/YYYY`, two spaces after `//` on the `Created by` line, name `Jamie Le Souëf`.
- **Do not auto-commit.** Leave work in the working tree and hand over the command.
- **Never add `Co-Authored-By` trailers or any AI attribution** to a commit, PR, issue or any other artefact.
- Use the `gh` CLI for GitHub operations, never the REST API directly.

Copy this header shape exactly. The SPDX line must be line 1 or `check-spdx.sh` fails, and its licence must match the directory — `MIT` under `Shared/` and `App/`, `AGPL-3.0-only` under `Server/`.

```swift
// SPDX-License-Identifier: MIT
//
//  AlbumDTO.swift
//  Shared
//
//  Created by Jamie Le Souëf on 31/08/2026.
//
```

A `Package.swift` is the sole exception, because Swift requires the tools-version line first — SPDX moves to line 2 and nothing else changes:

```swift
// swift-tools-version: 6.2
// SPDX-License-Identifier: MIT
//
//  Package.swift
//  Shared
//
//  Created by Jamie Le Souëf on 31/08/2026.
//
```

## Verify

```bash
cd Shared && swift build                 # resolves ZERO external packages
cd Server && swift build && swift test
swift run Server                         # then: curl -i localhost:8080/version
xcodebuild -scheme MixTape -destination 'generic/platform=iOS Simulator' build
./scripts/check-layer-imports.sh         # test the failure case too, not just the pass
./scripts/check-spdx.sh                  # ditto — break one header on purpose
grep -r "import SwiftData\|import CoreGraphics\|import UIKit\|import SwiftUI\|@Observable" Shared/
```

**Docker is a packaging step, not a dev loop.** `swift run Server` on macOS runs the identical binary against a local music folder with the app pointed at `localhost`. The moment a container is needed to test a change, iteration speed dies. The Linux CI job is what catches Apple-only API that slipped in.

A check that has never failed is not known to work. When you add one, prove it fails.

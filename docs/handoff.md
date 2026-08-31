# Mix Tape — Project Planning Handoff

This document carries the full context for a greenfield project. Nothing exists
in the repository yet, so this file **is** the source of truth until the Plan
phase produces `CLAUDE.md` and the decision docs.

Run each phase as its own Claude Code session. Do not combine them. Each phase
header states the model and mode to use.

> Claude Code runs subagents on the session model. A session started on Opus
> dispatches Opus subagents; a session started on Sonnet dispatches Sonnet
> subagents. Set the model before starting the session, not partway through.

---

## Project brief

**Mix Tape** is a self-hosted music server and client app — a Plex alternative
for music, built to avoid subscriptions.

The design concept is the nostalgia of pulling an album out of a CD wallet and
putting it on. It is album-centric, not track-centric. There is no cross-album
queue, no shuffle, no algorithmic up-next. You pick an album, it plays, it
finishes, you are back at the wallet. A single track can be selected within an
album, but the album is the unit.

**Server:** Swift, Hummingbird 2, runs in Docker on a NAS.
**Client:** SwiftUI, targeting iOS, iPadOS and macOS.
**Licensing:** client and shared code MIT, server AGPL-3.0.
**Open source** from the first public commit.

### v1 feature scope

- Served music library, browsable as albums
- Metadata (read from embedded file tags, MusicBrainz only as a gap-filler later)
- Album artwork
- On-device download of albums for offline playback
- Album grid view
- Playback controls: play, next, previous, back to albums — nothing else
- Sign in with Apple

Anything not on this list is out of scope for v1.

---

## Architecture decisions already made

These are settled. The Plan phase should record them, not relitigate them. If
the plan discovers a decision is unworkable, say so explicitly rather than
silently substituting an alternative.

### Repository layout

Single repository, three separate Swift packages:

```
mixtape/
├── Shared/
│   ├── Package.swift              no external dependencies
│   └── Sources/Shared/            DTOs only
├── Server/
│   ├── Package.swift              depends on ../Shared by path
│   ├── Sources/Server/
│   └── Tests/ServerTests/
├── App/
│   ├── MixTape.xcodeproj          depends on ../Shared by path
│   └── Sources/
├── Dockerfile
├── docker-compose.yml
├── LICENSE                        explains the split
└── .github/workflows/
```

`Shared` has its own `Package.swift` deliberately. If the app depended on a
manifest that declared Hummingbird, Xcode would resolve and clone Hummingbird
and its entire dependency tree on every project open despite never building it.
Splitting the manifest keeps app dependency resolution at zero external packages.

Both `Server` and `App` reference `Shared` via `.package(path: "../Shared")`.
No tags, no versioning — a DTO change is immediately visible on both sides.
This is the whole point of the monorepo and must be preserved.

### Shared must stay Linux-clean

`Shared` contains `Codable` structs and nothing else. No SwiftData, no
`@Observable`, no Core Graphics, no Apple-only Foundation APIs. It compiles on
Linux or the server build breaks.

The temptation when it breaks will be to duplicate the type. Do not. Fix the
type so it stays portable.

### Server

- Hummingbird 2, structured-concurrency native, chosen over Vapor for footprint
- `FileMiddleware` handles HTTP `Range` requests — do not hand-roll byte-range streaming
- **Direct play only.** The server never transcodes. AVFoundation natively plays
  FLAC, ALAC, MP3, AAC, WAV and AIFF, which covers effectively every real music
  library. Ogg Vorbis is the only meaningful gap and is out of scope.
- Library index: in-memory structure rebuilt at boot, snapshotted to JSON. This
  is genuinely sufficient for a personal library. GRDB only if it outgrows it.
- Tag scanning shells out to `ffprobe -print_format json`, bundled in the Docker
  image. There is no good Swift tag-reading library on Linux. Invoking a binary
  is licence-clean; do not link ffmpeg.
- **No image processing on the server.** Linux has no Core Graphics. Serve the
  original embedded artwork and let the client downsample with ImageIO and cache
  the result. This removes an entire dependency class from the server.
- A `/version` endpoint returning an API version integer, from day one.

### Client

**The app architecture is defined in `docs/app-architecture-template.md`. That
file is authoritative — read it before this section.** What follows here is
project-specific detail layered on top of it, not a replacement for it. Where
the two disagree, the template wins; flag the conflict rather than resolving it
silently.

SwiftUI, MV pattern — no ViewModels, ever. Views bind directly to `@Observable`
services.

Services to plan for:

- `LibraryService` — `@MainActor @Observable final class`, with a `private actor`
  fetcher for network calls
- `PlaybackService` — wraps `AVQueuePlayer`, holds the current album and index,
  feeds `MPNowPlayingInfoCenter` and `MPRemoteCommandCenter`
- `DownloadService` — background `URLSession`. This is the concurrency friction
  point: delegate callbacks fire off-main and can arrive after an app relaunch,
  so it cannot be cleanly `@MainActor`. Expect a `nonisolated` delegate shim
  that hops to the main actor.
- `AuthService` — server-issued token stored in Keychain

Playback rules:

- The queue **is** the album. Loading an album replaces the queue entirely.
- Next on the final track stops playback and does nothing else. It does not
  advance to another album. This is a deliberate design decision, not an
  oversight — it is the CD-wallet concept.
- `AVAudioSession` `.playback` category plus the background audio capability,
  or playback stops on lock.

### Data model

The single most important detail: store **album artist** separately from
**track artist**, and key albums on `(albumArtist, albumTitle, discNumber)`.
Keying on track artist explodes every compilation and every guest-feature track
into its own one-track album. Retrofitting this means a migration — get it right
in the first schema.

SwiftData on device, with a hard split:

- **Library data is a cache.** The server is the source of truth. A changed
  manifest can replace the local copy wholesale — no incremental sync logic.
- **Downloads are local truth.** They are not derivable from the server and must
  survive a library rescan. Separate models, separate lifecycle. If a rescan on
  the NAS wipes downloaded albums off the phone, the app feels broken.

SwiftData models are not `Sendable`. Use a `ModelActor` for import and pass
`PersistentIdentifier` across isolation boundaries — never the objects.

### Authentication

Sign in with Apple, used **once**, for pairing only.

- First SIWA login claims the server: store Apple's `sub` claim as the owner
- Server validates the identity token against Apple's public keys (JWTKit works
  on Linux)
- Server then issues **its own** long-lived token; every subsequent request uses
  that

Do not use Apple's identity token as the session token. It is short-lived, and
refreshing it requires server-to-server calls with a client secret JWT that
Apple caps at six months — an indefinite rotation chore on a box in a cupboard.

Team ID and bundle ID must be configuration, never hardcoded. Every person who
self-hosts builds the app with their own signing team.

### Build pipeline

Multi-stage Dockerfile, build context at repo root:

```dockerfile
FROM swift:6.1-noble AS build
WORKDIR /build
COPY Shared Shared
COPY Server/Package.swift Server/Package.resolved Server/
WORKDIR /build/Server
RUN swift package resolve
COPY Server .
RUN swift build -c release --static-swift-stdlib

FROM ubuntu:noble
RUN apt-get update \
 && apt-get install -y ffmpeg ca-certificates \
 && rm -rf /var/lib/apt/lists/*
COPY --from=build /build/Server/.build/release/Server /usr/local/bin/
ENTRYPOINT ["Server"]
```

Resolving dependencies before copying sources keeps source edits from re-fetching
Hummingbird. `--static-swift-stdlib` means the runtime image needs no Swift
runtime, only ffmpeg.

Build a single architecture matching the target NAS. Cross-building Swift under
QEMU on a CI runner takes 20+ minutes; add a second architecture only on demand.

CI, with path filters:

- `server.yml` on `Server/**` and `Shared/**` — `swift test`, then buildx and
  push to GHCR
- `app.yml` on `App/**` and `Shared/**` — `xcodebuild test` on a macOS runner
  against an iOS simulator destination

A DTO change fires both. A SwiftUI change fires neither server job.

**Docker is a packaging step, not a dev loop.** `swift run Server` on macOS runs
the identical binary against a local music folder with the app pointed at
localhost. Preserve this — the moment a container is needed to test a change,
iteration speed dies. The Linux CI job is what catches Apple-only APIs that
slipped in.

### Licensing

| Path | Licence |
|---|---|
| `Shared/` | MIT |
| `App/` | MIT |
| `Server/` | AGPL-3.0-only |

`Shared` **must** be permissive. MIT flows into AGPL; AGPL does not flow into
MIT. An AGPL `Shared` would make the MIT client claim invalid.

`LICENSE` file in each of the three directories, plus a root `LICENSE`
explaining the split. `SPDX-License-Identifier` as the first line of every
source file. `CONTRIBUTING.md` stating which licence a PR falls under by
directory, with DCO sign-off rather than a CLA.

### Swift conventions

- Swift 6 strict concurrency throughout, non-negotiable
- MV pattern — no ViewModels
- Services as `@MainActor @Observable final class`; `private actor` fetchers for
  network calls
- Actors stay actors — `nonisolated` fixes `Decodable` warnings, never convert
  to `@MainActor final class`
- `Mutex` over `NSLock`; no `DispatchQueue` in new code
- No `@unchecked Sendable` or `nonisolated(unsafe)` without a justification comment
- `== false` over `!` negation
- Swift Testing for unit tests — never XCTest
- SwiftData for storage
- 2-space indentation, no inline comments, trailing commas on multi-line
  argument lists
- Australian spelling in prose, American spelling in identifiers

---

## Phase 1 — Plan

**Model & mode: Opus, plan mode.**

Greenfield architecture with unresolved schema and endpoint design. This needs
reasoning about data modelling trade-offs and Linux/Apple API boundaries, not
pattern matching.

Read in order before producing anything:

1. `docs/app-architecture-template.md` — authoritative for app architecture
2. This entire document

Produce a written plan covering:

1. **`Shared` DTO surface.** Every type crossing the boundary: album, track,
   artist, library manifest, version response, auth exchange. Field-by-field,
   with the album-artist/track-artist split explicit. Confirm each type compiles
   on Linux.

2. **SwiftData schema.** The cache models and the download models, with the
   boundary between them stated. Show how a full manifest replacement leaves
   downloads intact. Name the `ModelActor` and its import path.

3. **API endpoints.** Full list for v1 with methods, paths, request and response
   types, and auth requirements. Include the artwork endpoint and the range-served
   audio endpoint.

4. **Library scan design.** How `ffprobe` output maps to DTOs, how albums are
   grouped, what happens to files with missing or malformed tags, and when the
   scan runs (boot, manual trigger, filesystem watch).

5. **Auth flow.** The pairing exchange end to end, token format, storage on both
   sides, and what happens on a second device.

6. **Download lifecycle.** States a downloaded album moves through, where files
   live on disk, how the background session resumes after relaunch, and how
   playback chooses local over remote.

7. **Open questions.** Anything this document leaves genuinely undecided. List
   them rather than picking silently.

Write the plan to `docs/plan/v1-architecture.md`. Do not create any other files.
Do not write any implementation code.

---

## Phase 2 — Execute

**Model & mode: Sonnet, normal mode.**

Mechanical scaffolding from an approved plan. No architectural judgement
required once Phase 1 is agreed.

Read in order before writing anything:

1. `docs/app-architecture-template.md` — authoritative for app architecture
2. `docs/plan/v1-architecture.md`
3. This handoff document

Do not write any code until you have read all three.

Scaffold the repository:

1. Three `Package.swift` manifests with correct path dependencies and platform
   declarations
2. `Shared` DTOs exactly as specified in the plan
3. Hummingbird server skeleton — routing, `/version`, `FileMiddleware`
   configuration, and stubbed handlers that return typed empty responses
4. Xcode project for the app with iOS, iPadOS and macOS destinations, linking
   `Shared`, with empty service shells matching the plan's names and shapes
5. `Dockerfile` and `docker-compose.yml` with a music directory bind mount
6. Both CI workflows with path filters
7. All four `LICENSE` files, `CONTRIBUTING.md`, and `README.md` with a working
   docker-compose quickstart
8. `CLAUDE.md` capturing the conventions and architecture from this document

### Constraints

- Do NOT implement scanning, playback, auth or download logic — scaffolding only
- Do NOT add dependencies beyond Hummingbird and JWTKit
- Do NOT put anything Apple-only in `Shared`
- Do NOT create a `Shared` target inside the server package

### Verification

- `swift build` succeeds in `Server/`
- `swift build` succeeds in `Shared/` with zero external dependencies resolved
- `xcodebuild -scheme MixTape build` succeeds for an iOS simulator destination
- `docker build .` produces an image, and `docker run` starts and answers
  `/version`
- `grep -r "import SwiftData\|import CoreGraphics\|@Observable" Shared/` returns
  nothing

---

## Phase 3 — Review

**Model & mode: Opus, plan mode.**

Reviewing architectural conformance on a greenfield skeleton, where the cost of
a wrong foundation is a migration later.

Read in order: `docs/app-architecture-template.md`, `docs/plan/v1-architecture.md`,
this document, then the full scaffold. Form no opinions until all four are read.

Review for:

- **Template conformance.** The app scaffold matches
  `docs/app-architecture-template.md` in structure, naming and layering. Any
  deviation is either justified in the plan or is a blocking issue.
- **Layering.** Anything Apple-only in `Shared`. Any server type duplicating a
  `Shared` type instead of using it.
- **Data model.** Album keying uses `(albumArtist, albumTitle, discNumber)`.
  Cache models and download models are genuinely separate, and a manifest
  replacement cannot orphan a download.
- **Concurrency.** Swift 6 strict clean. No `DispatchQueue`. Services are
  `@MainActor @Observable final class`. Fetchers are actors. No `@unchecked
  Sendable` without justification. No SwiftData model crossing an isolation
  boundary.
- **Architecture.** No ViewModels. No protocol or abstraction introduced without
  a second conformer.
- **Build.** Docker layer ordering actually caches. `--static-swift-stdlib`
  present. CI path filters correct. `swift run Server` works on macOS without
  Docker.
- **Licensing.** Four `LICENSE` files present and correct. SPDX headers on every
  source file. No AGPL code reachable from the app target.
- **Style.** 2-space indentation, no inline comments, no TODO/FIXME.

Produce a verdict:

```
## Verdict

**Decision:** APPROVE / REQUEST CHANGES / NEEDS DISCUSSION

**Blocking issues:**
- [issue] — [file:line]

**Non-blocking suggestions:**
- [suggestion]
```

---

**Model & mode:** Opus, plan mode — start with Phase 1; this is greenfield
architecture and schema design, not mechanical execution.

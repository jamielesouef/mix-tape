# Mix Tape

A Jellyfin client for iOS 26. Browse video and music libraries, play both, report progress back to the server.

## Where to read

- `AGENTS.md` (mirrored to `CLAUDE.md`) — the working rules; outranks every other document here.
- `docs/engineering-doc.md` — the V1 spec: scope (§1), layout (§3), acceptance criteria (§12), build order (§13).
- `docs/jellyfin-api.md` and `docs/jellyfin-openapi.json` — the API contract, Jellyfin 10.11.11.

## Toolchain

The project targets Xcode 26.6 / Swift 6.2, Swift 6 language mode, `MainActor` default isolation. A newer Xcode may open it, but write nothing newer than Swift 6.2 and keep `MixTape.xcodeproj` at `objectVersion = 77` — see `CLAUDE.md`. VLCKit is the only third-party dependency, resolved as a remote SPM package on the app target.

## Layout

One Xcode project, three targets: `Mixtape` (the iOS app, built from `source/`), `MixtapeTests` (`tests/`) and `MixtapeUITests` (`uitest/`). `source/` holds the six layer folders — `Domain`, `UseCase`, `Data`, `Infrastructure`, `Services`, `Presentation` — plus `App/` for the composition root. The architecture is MV (no ViewModels); the dependency edges are in engineering doc §3, and `scripts/check-layer-imports.sh` enforces the framework rule the compiler can no longer see.

## The development server

A local Jellyfin 10.11.11 (`docker-compose.yml`, or the `mixtape-jellyfin:local` image from the main repo) at `http://localhost:8096`. Credentials live in a gitignored `.jellyfin-dev.env` at the repo root — `JELLYFIN_BASE_URL`, `JELLYFIN_API_KEY`, `JELLYFIN_USERNAME`, `JELLYFIN_PASSWORD`, `JELLYFIN_USER_ID` (decision 45). Read the server through `./scripts/jf-probe.swift [METHOD] /path` (decision 47); No automated test touches the server.

## Building and verifying

```bash
xcodebuild build -project MixTape.xcodeproj -scheme Mixtape -destination 'generic/platform=iOS Simulator'
./scripts/gate.sh   # build, unit tests, layer, glass and swiftformat checks
```

The gate fails on any failing or skipped test and appends one line per run to the gitignored `.gate-log`. Tests are Swift Testing; the UI test bundle exists but is not run this round.

# Mix Tape

A Jellyfin client for iOS 26 and tvOS 26. Browse video and music libraries, play both, report progress back to the server.

## Where to read

- `SPEC-DECISIONS.md` — numbered decisions; outranks every other document.
- `docs/engineering-doc.md` — the V1 spec: scope (§1), layout (§3), acceptance criteria (§12), build order (§13).
- `docs/slices/MASTER-CHECKLIST.md` — status of every slice, spikes, drift log, requirement coverage and triage.
- `docs/jellyfin-api.md` and `docs/jellyfin-openapi.json` — the API contract, Jellyfin 10.11.11.
- `CLAUDE.md` — the working rules for anyone (or any agent) editing this repo.

## Toolchain

The project targets Xcode 26.6 / Swift 6.2, Swift 6 language mode, `MainActor` default isolation. A newer Xcode may open it, but write nothing newer than Swift 6.2 and keep `MixTape.xcodeproj` at `objectVersion = 77` — see `CLAUDE.md`. VLCKit is the only third-party dependency, resolved through SPM.

## Layout

One Xcode project with two thin app targets (`Apps/MixtapeiOS`, `Apps/MixtapeTV`, composition root in `Apps/Shared`) over one local package, `MixtapeKit`, with six library targets: `MixtapeDomain`, `MixtapeUseCase`, `MixtapeServices`, `MixtapeData`, `MixtapeInfrastructure`, `MixtapePresentation`. The architecture is MV (no ViewModels); the dependency edges are in engineering doc §3 and enforced by `scripts/check-layer-imports.sh`.

## The development server

A local Jellyfin 10.11.11 (`docker-compose.yml`, or the `mixtape-jellyfin:local` image from the main repo) at `http://localhost:8096`. Credentials live in a gitignored `.jellyfin-dev.env` at the repo root — `JELLYFIN_BASE_URL`, `JELLYFIN_API_KEY`, `JELLYFIN_USERNAME`, `JELLYFIN_PASSWORD`, `JELLYFIN_USER_ID` (decision 45). Read the server through `./scripts/jf-probe.swift [METHOD] /path` (decision 47); drive the Apple TV simulator through `./scripts/tv-remote.sh <udid> up|down|left|right|select|menu|type:TEXT` (decision 49). No automated test touches the server.

## Building and verifying

```bash
xcodebuild build -project MixTape.xcodeproj -scheme iOS  -destination 'generic/platform=iOS Simulator'
xcodebuild build -project MixTape.xcodeproj -scheme tvOS -destination 'generic/platform=tvOS Simulator'
./scripts/gate.sh   # both builds, both unit-test runs, layer, glass and swiftformat checks
```

The gate reads the expected test count per suite from `docs/slices/test-count.txt` and appends one line per run to the gitignored `.gate-log`. Tests are Swift Testing; the UI test bundles exist but are not run this round.

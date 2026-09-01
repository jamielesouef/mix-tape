# Mix Tape

A self-hosted, album-centric music server and client. A Plex alternative for music, built to avoid subscriptions.

A Swift server (Hummingbird 2, running in Docker on a NAS) plus a SwiftUI client for iOS, iPadOS and macOS.

## The concept

Pulling a CD out of a wallet.

You open Mix Tape and see a grid of album covers. You pick one, it plays, it finishes, and you are back at the wallet. **The queue is the album.** There is no cross-album queue, no shuffle and no algorithmic up-next — when the last track ends, playback stops.

That is not a missing feature. It is the product.

## What it does

- Scans a music folder on your NAS and builds an album-centric library index. Album artist is stored separately from track artist, so compilations and guest features do not explode into one-track albums.
- Serves the library, the embedded artwork and the audio itself over HTTP.
- **Direct play only. The server never transcodes.** FLAC, ALAC, MP3, AAC, WAV and AIFF all play natively on Apple devices.
- Pairs once with Sign in with Apple, then issues its own long-lived token. One owner, and the server refuses anybody else.
- Downloads albums to the device for offline listening, with downloads kept structurally separate from the cache so a library rescan can never delete them.

## Status

Early. Work is delivered as numbered slices, and [`docs/slices/MASTER-CHECKLIST.md`](docs/slices/MASTER-CHECKLIST.md) is the live picture of what is built and what is not.

## Quickstart

**Not here yet.** The `Dockerfile` and `docker-compose.yml` land in [slice 003](docs/slices/003-docker-image-and-ci.md), and this section will be replaced with a real `docker compose up` walkthrough at that point. It is deliberately empty rather than aspirational — a quickstart that describes files which do not exist is worse than none.

Until then, you can run the server directly on a Mac:

```bash
cd Server
swift run Server
curl -i localhost:8080/version
```

Docker is a packaging step, not the development loop.

## Repository layout

```
mixtape/
├── Shared/      Swift package. DTOs. Zero external dependencies. Compiles on Linux
├── Server/      Swift package. Hummingbird 2, JWTKit
├── App/         MixTape.xcodeproj. Six layer folders in one target
├── docs/        plan, handoff, architecture template, slices
└── scripts/     check-layer-imports.sh, check-spdx.sh
```

## Licence

The licence depends on the directory: `Shared/` and `App/` are MIT, `Server/` is AGPL-3.0-only. [`LICENSE`](LICENSE) explains why, and why the direction matters.

## Contributing

See [`CONTRIBUTING.md`](CONTRIBUTING.md). Commits need a DCO `Signed-off-by:` trailer. There is no CLA.

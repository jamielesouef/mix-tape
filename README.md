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

You need Docker, a folder of music, and about two minutes.

```bash
git clone <this repository>
cd mixtape
MIXTAPE_HOST_MUSIC_DIR=/path/to/your/music docker compose up -d
```

Then check it answered:

```bash
curl -i localhost:8080/version
```

You should get `200` and a small JSON body — `{"apiVersion":1,"serverVersion":"0.1.0","claimed":false}`. `claimed: false` means no owner has paired with this server yet, which is correct on a first run.

Your music is mounted **read-only**. Mix Tape never writes to your library. Everything the server creates — the owner claim, the library index, extracted artwork — goes in a Docker volume instead.

To stop it: `docker compose down`. To stop it and throw away the server's state as well: `docker compose down -v`.

### Configuration

Every setting is an environment variable, and `docker-compose.yml` documents each one where it is declared.

| Variable | What it does |
| --- | --- |
| `MIXTAPE_HOST_MUSIC_DIR` | The folder on **your** machine holding the music. Defaults to `./music` |
| `MIXTAPE_APPLE_BUNDLE_ID` | The bundle identifier of your build of the app. Needed once pairing exists |
| `MIXTAPE_TOKEN_SECRET` | Signs the token the server issues after pairing. Leave it unset and the server generates and stores one |

### Running the server without Docker

Docker is how Mix Tape is packaged, not how it is developed. On a Mac the same binary runs directly:

```bash
cd Server
swift run Server
```

The moment a container rebuild is needed to test a change, iteration speed dies — so it deliberately is not needed.

## Repository layout

```
mixtape/
├── Shared/      Swift package. DTOs. Zero external dependencies. Compiles on Linux
├── Server/      Swift package. Hummingbird 2, JWTKit
├── App/         MixTape.xcodeproj. Six layer folders in one target
├── docs/        plan, handoff, architecture template, slices
└── scripts/     check-layer-imports.sh, check-spdx.sh
```

The image is built from the `Dockerfile` at the root and published to GHCR by `.github/workflows/server.yml`.

## Licence

The licence depends on the directory: `Shared/` and `App/` are MIT, `Server/` is AGPL-3.0-only. [`LICENSE`](LICENSE) explains why, and why the direction matters.

## Contributing

See [`CONTRIBUTING.md`](CONTRIBUTING.md). Commits need a DCO `Signed-off-by:` trailer. There is no CLA.

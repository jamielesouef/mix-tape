# Contributing to Mix Tape

Thanks for looking. Mix Tape is a self-hosted, album-centric music server and client, and it is open source from its first public commit.

## The licence depends on the directory

Before you write a line, know which licence your change lands under. [`LICENSE`](LICENSE) at the root explains the split and why it points the way it does.

| Path | Licence |
| --- | --- |
| `Shared/` | MIT |
| `App/` | MIT |
| `Server/` | AGPL-3.0-only |

`Shared/` must stay permissive. MIT flows into AGPL; AGPL does not flow into MIT. An AGPL `Shared` would invalidate the MIT claim on the app, because the app links `Shared`.

Every `.swift` file carries an `SPDX-License-Identifier` line matching its directory. Run [`scripts/check-spdx.sh`](scripts/check-spdx.sh) before you push — it is the same check CI runs, and it fails on a missing, wrong or displaced header.

## Sign your work — the Developer Certificate of Origin

Mix Tape uses the [Developer Certificate of Origin](https://developercertificate.org) (DCO). **There is no CLA.** You keep the copyright on what you write; you are not assigning anything to anybody.

Add a `Signed-off-by:` trailer to every commit, using your real name and an email address you can be reached at:

```
Signed-off-by: Jane Citizen <jane@example.com>
```

`git commit -s` adds it for you. A pull request whose commits are not signed off cannot be merged.

Signing off means you agree to the DCO: that you wrote the change, or have the right to submit it under the licence of the directory it lands in.

## Signing, if you build for macOS or a device

Simulator builds need no signing, so `xcodebuild -destination 'generic/platform=iOS Simulator'` and CI both work straight from a clone.

A macOS build or a build to a real device does need a signing team, because the app's entitlements require a development certificate. `DEVELOPMENT_TEAM` is deliberately not committed — it identifies whoever owns the signing account, and this is a public repository. Create `App/Local.xcconfig`, which is gitignored, containing one line:

```
DEVELOPMENT_TEAM = YOURTEAMID
```

`App/Signing.xcconfig` includes it optionally, so a clone without that file builds for the simulator with no warning.

## Before you open a pull request

- `cd Shared && swift build` — this must resolve **zero** external packages.
- `cd Server && swift build && swift test`
- `xcodebuild -scheme MixTape -destination 'generic/platform=iOS Simulator' build`
- `./scripts/check-spdx.sh`
- `./scripts/check-layer-imports.sh`

Read [`CLAUDE.md`](CLAUDE.md) first. It is short, and it holds the conventions that a review will otherwise ask you to change: Swift 6 strict concurrency, the MV architecture with no ViewModels, the layer dependency rules, and the file header shape.

## The one product rule that gets "fixed" by mistake

The design concept is pulling a CD out of a wallet. You pick an album, it plays, it finishes, you are back at the wallet.

**The queue is the album.** Loading an album replaces the player queue entirely. Next on the final track stops playback and does nothing else — it never advances to another album. There is no cross-album queue, no shuffle and no algorithmic up-next.

This is deliberate. It is the whole concept, and a pull request that "improves" it will be declined.

## Commit messages

Short, imperative, one change per commit. No emojis. Work is delivered as slices, so a commit that implements a slice carries the slice id in the subject — `002: add licence split and DCO`.

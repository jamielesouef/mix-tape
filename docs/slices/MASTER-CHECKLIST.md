---
title: Master Slice Checklist
---

# Master Checklist — mixtape V1

**This file is the only home for status, owner and blockers.** Slice documents don't carry them. Dependencies are the reverse: they live in each slice's `depends_on` front matter and are not repeated here.

That split is deliberate. Every fact duplicated across two files becomes two facts that disagree — which is how a slice ends up declaring no dependencies while its own pre-flight and this checklist each say something different.

Derived from [`../engineering-doc.md`](../engineering-doc.md) and [`../../SPEC-DECISIONS.md`](../../SPEC-DECISIONS.md). **`SPEC-DECISIONS.md` outranks both docs**; where a slice departs from the engineering doc, the departure is a numbered fork with a decision row in the owning slice — see [Plan Forks](#6-plan-forks).

Populated 2026-09-03 (Phase 2). Decisions 1–47 are binding on every row below.

## 1. Slices

Ordered by delivery sequence — the same order as the linked list.

| # | Slice | Priority | Cx | Owner | Status | Link |
|---|---|---|---|---|---|---|
| 001 | Package skeleton and gates | P0 | L | adw-run | Done | [001](001-package-skeleton-and-gates.md) |
| 002 | Domain model and pure rules | P0 | M | adw-run | Not started | [002](002-domain-model-and-pure-rules.md) |
| 003 | HTTP client, keychain and logger | P0 | M | adw-run | Not started | [003](003-http-client-keychain-logger.md) |
| 004 | Sign in — checkpoint: you can sign in | P0 | L | adw-run | Not started | [004](004-sign-in.md) |
| 005 | Browse — checkpoint: you can browse | P0 | L | adw-run | Not started | [005](005-browse.md) |
| 006 | Video: AVPlayer direct and HLS | P0 | L | adw-run | Not started | [006](006-video-avplayer-and-hls.md) |
| 007 | Video: VLC direct | P0 | M | adw-run | Not started | [007](007-video-vlc.md) |
| 008 | Playback reporting and resume | P0 | M | adw-run | Not started | [008](008-playback-reporting-and-resume.md) |
| 009 | Music playback — checkpoint: music plays, one album at a time | P1 | L | adw-run | Not started | [009](009-music-playback.md) |
| 010 | The Wallet | P1 | L | adw-run | Not started | [010](010-wallet.md) |
| 011 | tvOS presentation | P1 | L | adw-run | Not started | [011](011-tvos-presentation.md) |
| 012 | Accessibility and Reduce Transparency pass | P1 | M | adw-run | Not started | [012](012-accessibility-and-reduce-transparency.md) |

Status: `Not started` · `In progress` · `Blocked` · `In review` · `Done`

Slices 001–003 are foundation: they claim no `§1` capability or `§12` criterion and are gated on builds, tests and the layer script alone.

## 2. Spikes

Spikes are not deliverables and are not in the linked list, so they get their own table.

| # | Question | Timebox | Unblocks | Status | Answer |
|---|---|---|---|---|---|
| [S001](S001-vlckit-spm-resolution.md) | Does VLCKit resolve as an SPM binary dependency with iOS 26 and tvOS 26 simulator slices and link into `MixtapeInfrastructure` under Swift 6 mode with MainActor default isolation? | 2 h | 007 | Answered | **Yes** — resolves and links on iOS 26.5 and tvOS 26.5 simulators under Swift 6 mode + `MainActor` default isolation via `tylerjonesio/vlckit-spm` exact `3.6.0`, product `VLCKitSPM`; no vendoring needed. Module is `MobileVLCKit` (iOS) / `TVVLCKit` (tvOS), so the one importing file uses `#if os(...)` imports. 778.7 MB binary artefact. 2026-09-03. |
| [S002](S002-stream-authorization-header.md) | Can `AVPlayerController` and `VLCPlayerController` each send `Authorization: MediaBrowser …` on a stream request using public API only? (decision 33; answered per player) | 3 h | 006, 007, 009 | Answered | **AVPlayer: yes** — `AVAssetResourceLoaderDelegate` on a custom-scheme asset carries the header (206 + plays on an auth-required endpoint; `-1013` without). **VLCKit: yes, only via libavformat** — MRL `avio://http://…` + `:avio-options={headers='Authorization: MediaBrowser …'}`; VLC's own http access has no header option and `:http-token` sends Bearer (401). `ApiKey` fallback works for both. **Finding:** `/Videos/{itemId}/stream` is anonymous on 10.11.11; `universal` and `master.m3u8` require auth, and `maxStreamingBitrate=320000` transcoded ALAC. **Decided:** decision 42 puts `ApiKey` in the query on every client-built stream URL for both players and closes decision 33; decision 43 drops `maxStreamingBitrate`. 2026-09-03. |

## 3. Active Blockers

| Slice | Blocked on | Since | Note |
|---|---|---|---|

## 4. Architecture Drift Log

Drift found during a slice's pre-flight: something changed underneath a slice after it was drafted. Recorded here, not in the slice.

| Date | Slice | What changed | Slices affected | Resolution |
|---|---|---|---|---|
| 2026-09-03 | S002 | Decisions 7 and 33 assume the client must authenticate the stream URL it builds. On Jellyfin 10.11.11 `/Videos/{itemId}/stream` and `/Audio/{itemId}/stream` carry no `security` requirement and serve 206 with no auth and with a bogus token; `/Audio/{itemId}/universal` and `master.m3u8` do require auth. | 006, 007, 009 | Closed 2026-09-03 by decisions 42 and 43: every client-built stream URL carries `ApiKey` in the query for both players (decision 7 amended, decision 33 closed); 009's universal URL drops `maxStreamingBitrate`. Triage 5's "send nothing" is reversed; Triage 6 is closed. |

## 5. Requirement Coverage

Every in-scope capability from engineering doc §1 and every acceptance criterion from §12 maps to a slice, or to a fork row saying why not.

| Requirement | Source | Slice | Satisfied how |
|---|---|---|---|
| §1.1 Connect to one server by URL, validate it | eng doc §1 | 004 | `ValidateServerUseCase` + `JellyfinAuthRepository.serverIdentity(at:)`; decision 31 null-identity check |
| §1.2 Sign in with username + password | eng doc §1 | 004 | `SignInWithPasswordUseCase`; AC2 |
| §1.3 Sign in with Quick Connect | eng doc §1 | 004 | `StartQuickConnectUseCase` + `PollQuickConnectUseCase` (decision 21); AC3 on tvOS |
| §1.4 Persist session, restore, sign out | eng doc §1 | 004 | `KeychainSessionStore`, `RestoreSessionUseCase`, `SignOutUseCase`; AC4, AC14 |
| §1.5 List the user's libraries | eng doc §1 | 005 (iOS), 011 (tvOS demonstration) | `FetchLibrariesUseCase` + `LibraryListScreen` / tvOS tabs |
| §1.6 Browse a movie library; movie detail | eng doc §1 | 005 (iOS), 011 (tvOS demonstration) | `MovieLibraryGrid` + `MovieDetailScreen`; `MovieLibraryShelf` on tvOS |
| §1.7 Browse TV → series → seasons → episodes | eng doc §1 | 005 | Code and tests only, against hand-authored fixtures; AC11 unclaimed (0 series, decision 14) |
| §1.8 Browse a music library → albums → tracks | eng doc §1 | 005 (iOS grid), 010 (iOS wallet), 011 (tvOS demonstration) | `AlbumGrid` + `AlbumDetailScreen`; wallet replaces the grid on iOS |
| §1.9 Continue Watching row on Home | eng doc §1 | 005 | `FetchContinueWatchingUseCase` via `GET /UserItems/Resume` (decision 6); Continue Watching only (decision 13) |
| §1.10 Play video: AVPlayer direct, VLC direct, HLS transcode | eng doc §1 | 006 (AVPlayer, HLS), 007 (VLC), 011 (tvOS demonstration) | `ResolveVideoPlaybackUseCase` (decision 12), `AVPlayerController` (decision 18), `VLCPlayerController`; AC6, AC7, AC8 |
| §1.11 Resume from last position; mark watched at ≥90% | eng doc §1 | 008 | `startAt` from `PlaybackState.position`; 0.9 rule at stop (decision 8); AC9, AC10 |
| §1.12 Play music: album queue, next/prev, background, lock screen | eng doc §1 | 009 (iOS), 011 (tvOS demonstration) | `MusicPlayerService` + `AudioPlayerController`; §1.1 invariants suite; AC12, AC13 |
| §1.13 Report playback start / progress / stop | eng doc §1 | 006 (start, decision 37), 008 (progress, stopped), 009 (music, decision 34) | Three report use cases (decision 19) called by both services; `PlayMethod` from `PlaybackPlan.playMethod` for video (decision 11) and from `BuildAudioStreamURLUseCase`'s return value for music (decision 40) |
| §1.14 Remote images with in-memory cache | eng doc §1 | 005 | `ImageService` (120 MB `NSCache`) + `JellyfinImageURLBuilder` (decision 25) |
| §1.15 The Wallet | eng doc §1 | 010 | `WalletScreen`, `WalletPage`, `AlbumSleeve`, pull-out and return-to-sleeve |
| §12.1 `localhost:8096` with no scheme connects | eng doc §12 | 004 | AC1 against the live server |
| §12.2 Wrong password: inline error, username kept | eng doc §12 | 004 | AC2 |
| §12.3 tvOS Quick Connect signs in within 10 s | eng doc §12 | 004 | AC3 on the Apple TV simulator (see Ordering Notes) |
| §12.4 Relaunch lands signed in | eng doc §12 | 004 | AC4 |
| §12.5 Home shows Continue Watching with progress bars | eng doc §12 | 005, re-verified in 008 | 005 seeds a resume point via Jellyfin Web on the 48.4 s mkv; 008 uses an app-created one |
| §12.6 mp4/h264 plays via `.directAVPlayer`, no transcode | eng doc §12 | 006 | Start report sent (decision 37); `/Sessions` shows `NowPlayingItem`, `PlayMethod: DirectPlay`, no `TranscodingInfo` |
| §12.7 mkv plays via `.directVLC`, no transcode | eng doc §12 | 007 | F1 mkv/h264/aac routes to VLC by container (decision 14); same `/Sessions` check as §12.6 |
| §12.8 Rejected source plays via `.transcodeHLS`, dashboard shows transcode | eng doc §12 | 006 | DEBUG launch argument `-mixtape-force-transcode` injects the restrictive profile; with the start report sent, `/Sessions` shows `PlayMethod: Transcode` and `TranscodingInfo` |
| §12.9 Watch 30 s, exit, Resume at ≈30 s | eng doc §12 | 008 | F1 mkv (48.4 s); `GET /UserItems/Resume` agrees |
| §12.10 Finishing a movie marks it watched | eng doc §12 | 008 | Avatar mp4 (20.8 s); `UserData.Played` true |
| §12.11 Series → season → episode ordering | eng doc §12 | — | **Unverifiable.** 0 Series, 0 Episodes (decision 14). No slice claims it. |
| §12.12 Album advances; lock screen art/title/artist; remote next | eng doc §12 | 009 | AC12 |
| §12.13 Backgrounding keeps music playing | eng doc §12 | 009 | AC13 |
| §12.13a Wallet 2×2 / 3×3 fixed pages (as reworded by decision 20) | eng doc §12 | 010 | Grid keyed to horizontal size class; an iPad device type on the iOS 26.5 runtime is created for the 3×3 half |
| §12.13b Sleeve lifts into album header and back | eng doc §12 | 010 | `matchedGeometryEffect` |
| §12.13c End of album: stop, dismiss, land on the sleeve pulsing | eng doc §12 | 010 | `finishedAlbumID` → return-to-sleeve sequence |
| §12.13d 13c after backgrounding | eng doc §12 | 010 | Same sequence without animation on foreground |
| §12.13e No shuffle/repeat/add-to-queue; next disabled on final track | eng doc §12 | 010 | Absence audit at the wallet level; 009's invariants suite |
| §12.13f FLAC album produces no transcode session | eng doc §12 | — | **Unverifiable until the FLAC album exists** (decision 35). All 46 tracks are m4a/alac. No slice claims it; 009 is the natural owner once the album is added. |
| §12.14 Sign out clears the Keychain | eng doc §12 | 004 | AC14 |
| §12.15 Reduce Transparency: no translucent glass | eng doc §12 | 012 | Shared glass modifier + mechanical grep gate + simulator check on both platforms |
| §12.16 Server unreachable mid-browse shows retry | eng doc §12 | 005 | Unit-tested `.failed` state plus a manual check with the server stopped |

**Known unverifiable:** acceptance criterion 11 (series → season → episode ordering) has no test data — the library holds 0 Series and 0 Episodes. No slice may claim it. See `SPEC-DECISIONS.md` decision 14. Acceptance criterion 13f is unverifiable until the FLAC album from decision 35 exists; same rule.

## 6. Plan Forks

Where a slice deliberately departs from the engineering doc. A fork with no decision row is the failure this section exists to catch. Departures already settled in `SPEC-DECISIONS.md` are **not** forks — they are decisions, and they need no row here.

| # | Slice | Departs from | Decision | Rejected |
|---|---|---|---|---|
| F1 | 001, 003 | §3 lists four test targets and no home for Infrastructure tests | `JellyfinHTTPClient` tests live in `MixtapeDataTests`, tagged `.repository`; no `MixtapeInfrastructureTests` target | A fifth test target for one type |
| F2 | 004 | §10 has `.signedIn` route to `RootTabScreen` | Until 005, `.signedIn` routes to `SettingsScreen` so AC14 is demonstrable in 004; 005 moves it into the Settings tab | A throwaway tab shell in 004 |
| F3 | 006 | §8 hardcodes one device profile inside the repository | `DeviceProfile` is an injected value; DEBUG launch argument `-mixtape-force-transcode` swaps in a restrictive profile so AC8 plays live. Shipped profile unchanged (decision 14) | Fixture-only AC8; changing the shipped profile |
| F4 | 010 | §9.1's optional tilt sheen and §7's `DeviceAttitudeReader` | Not built. §9.1 gates it on "an afternoon", which an unattended run cannot judge; `DeviceAttitudeReading` remains the named seam | Building it behind Reduce Motion |

## 7. Unknown Triage

Questions raised mid-build. Each becomes a spike, a decision, or an explicit deferral — never an assumption.

| # | Question | Raised by | Disposition |
|---|---|---|---|
| 1 | How does `MixtapeServices` hold `VideoPlayerControlling` and `AudioPlayerController`, which §7 places in `MixtapeInfrastructure`, when §3 gives Services no edge to Infrastructure? `VideoPlayerControlling.makeView() -> AnyView` rules out moving the protocol to `MixtapeUseCase` or `MixtapeDomain`, and Infrastructure cannot import Services to conform. | Phase 2 verification | **Decided 2026-09-03 by the project owner (decision 36): add a `MixtapeServices → MixtapeInfrastructure` edge** to `Package.swift` and `check-layer-imports.sh`, applied in slice 001 so 006 and 009 inherit it. Rejected: declaring the player protocols in `MixtapeServices` and conforming in the app target (retroactive conformance across two modules, compiler warning). Recorded as decision 36. |
| 2 | Does `GET /Sessions` show `PlayMethod`, `NowPlayingItem` or `TranscodingInfo` for a stream request that has not yet sent `POST /Sessions/Playing`? | Phase 2 verification | **Measured no** (decision 37): with a transcode running, `/Sessions` shows none of the three, and `/Videos/ActiveEncodings` is 405. `ReportPlaybackStartUseCase` moves to 006 so AC6, AC7 and AC8 are claimed in full by 006 and 007. |
| 3 | No iPad simulator exists, so AC13a's 3×3 half has no device. | Phase 2 verification | There is no iPadOS runtime and no iOS 26.0. 010's gate creates one with `xcrun simctl create` using an iPad device type against the iOS 26.5 runtime before demonstrating. |
| 4 | When the FLAC album from decision 35 lands, which slice claims AC13f? | decision 35 | 009 re-opens and claims `§12.13f`; update the coverage row and 009's `covers:` at that point. |
| 5 | `/Videos/{itemId}/stream` and `/Audio/{itemId}/stream` are anonymous on 10.11.11 (spec: no `security` block, no global security; live: 206 with no auth, 206 with `Token="deadbeef"`). Should 006/007 send any auth on that URL, and if so which mechanism, given S002 proved AVPlayer carries the header via `AVAssetResourceLoaderDelegate` and VLC only via the `avio://` MRL + `:avio-options` route (or `ApiKey` for either)? | S002 | **Superseded and reversed by decision 42 (2026-09-03): 006 and 007 send `ApiKey` in the query string on `/Videos/{itemId}/stream`, for both players.** The first disposition — send nothing — was faithful to the server today but built on undocumented anonymity, and `ApiKey` costs one query parameter with no delegate. No player carries the `Authorization` header; the `avio://` route and the resource-loader delegate are both rejected. Decision 33 closed, decision 7 amended. |
| 6 | 009's `/Audio/{itemId}/universal` URL at `maxStreamingBitrate=320000` made the server transcode the ALAC track to HLS (`TranscodeReasons=ContainerBitrateExceedsLimit`); at `140000000` it direct-streamed `audio/mp4`. Under header auth the HLS child URI carries no token, so AVPlayer would need the full custom-scheme loader for every child and segment; under `ApiKey` auth the server propagates `ApiKey=` into the child URI and AVPlayer fetches children natively. | S002 | **Closed by decisions 42 and 43 (2026-09-03):** `maxStreamingBitrate` is dropped entirely — `320000` is 320 kbps and forced every ALAC and FLAC track through the transcoder, which would have broken AC13f — and the universal URL carries `ApiKey` in the query, the one mechanism the server propagates into the HLS child URI. |

## Ordering Notes

Why the delivery sequence is what it is, where it isn't obvious from `depends_on` alone. Engineering doc §13 defines the build order and its shippable checkpoints; deviations from it belong here with a reason.

- The sequence is §13's, renumbered per decision 26: tvOS presentation is 011, the accessibility and Reduce Transparency pass is 012, and XCUITest is deferred out of the set (decision 4).
- **VLCKit edge deferred from 001 to 007.** §3's table lists VLCKit on `MixtapeInfrastructure`, but 001 declares the six targets without it so a resolution failure that belongs to S001 cannot fail 001's gate. 007 adds the edge in the shape S001 records.
- **S002 runs before 006, S001 before 007.** Decision 33 widened the auth spike to both players and made it block 006. Both spikes are throwaway and can run as soon as 001 exists; 009 also depends on S002 because `AudioPlayerController` is an `AVPlayer`.
- **AC3 (tvOS Quick Connect) is claimed in 004, not 011.** The sign-in screens are platform-shared, the tvOS ordering (Quick Connect first) is a one-line difference, and the Apple TV simulator is the one that is booted. 011 does not re-demonstrate it.
- **AC5 is claimed in 005 with a resume point seeded via Jellyfin Web**, because no player exists yet to create one; 008 re-verifies it with an app-created position.
- **008 follows 007** because AC9 needs a 30 s watch and only the 48.4 s F1 mkv is long enough; the 20.8 s Avatar mp4 cannot demonstrate it. F1 routes to VLC by container.
- **`ReportPlaybackStartUseCase` lands in 006, not 008** (decision 37). `/Sessions` shows nothing for a device until the start report is sent, so 006 and 007 need it to gate AC6, AC7 and AC8 on their own behaviour. 008 keeps progress, stopped and resume.
- **009 follows 008** because decision 34 has `MusicPlayerService` call all three report use cases, two of which 008 builds.
- **Settings is the signed-in root in 004** until 005 delivers `RootTabScreen` (fork F2), so AC14 has a sign-out affordance before the tab shell exists.
- **003's tests live in `MixtapeDataTests`** (fork F1); it therefore has a real gate of its own without a fifth test target.
- **The tvOS scheme must build at every slice from 005 onward.** Shared presentation means any iOS-only view lands in an `#if os(iOS)` file with a tvOS counterpart named for what it is; 011 replaces the minimal counterparts with real tvOS chrome.
- **The Services → Infrastructure edge (decision 36) lands in 001**, so 006 and 009 inherit it and neither waits on a manifest change of its own.
- **The credentials file (decision 45) and `scripts/jf-probe.swift` (decision 47) land in 001**, because `curl` is globally denied on this machine and 004 is the first slice that needs to sign in. Every server-observable criterion from 004 onward reads the server through the probe.

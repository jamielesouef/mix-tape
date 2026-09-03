# mixtape — V1 Engineering Spec

A Jellyfin client for iOS and tvOS. Browse a Jellyfin server's video and music libraries, play both, report progress back.

This document is the single source of truth for the V1 build. Appendix A is the architecture template every rule here derives from — follow it literally. Anything not listed in **In scope** is out of scope for V1.

---

## 1. Scope

### In scope

| # | Capability |
|---|---|
| 1 | Connect to one Jellyfin server by URL, validate it |
| 2 | Sign in with username + password |
| 3 | Sign in with Quick Connect (code + poll) |
| 4 | Persist session in Keychain, restore on launch, sign out |
| 5 | List the user's libraries (movies, TV, music) |
| 6 | Browse a movie library; movie detail screen |
| 7 | Browse a TV library → series → seasons → episodes |
| 8 | Browse a music library → albums → tracks |
| 9 | "Continue watching" row on Home |
| 10 | Play video: direct play (AVPlayer), direct play (VLCKit), or HLS transcode (AVPlayer) |
| 11 | Resume video from last position; mark watched at ≥90% |
| 12 | Play music: album queue, next/prev, background audio, lock screen / remote controls |
| 13 | Report playback start / progress / stop to the server |
| 14 | Remote images (posters, backdrops, album art) with in-memory cache |
| 15 | **The Wallet** — iOS-only album-centric browsing surface (§9.1) |

### Out of scope for V1 — do not build

Downloads and offline playback · multi-server / multi-user switching · search · Live TV and DVR · SyncPlay · AirPlay/Cast target UI beyond what AVPlayer gives free · external subtitle tracks and subtitle styling · audio/subtitle track switching mid-playback · collections, playlists, favourites, watched toggling · trick-play thumbnails · Chapters UI · widgets · settings beyond sign out · localisation beyond en.

Do not add abstractions for any of the above. No protocol gets a method that only a future feature would call.

Note the deliberate absences in §1.1 are a different category — those are not deferrals and must not be added in V2 either.

### 1.1 Product principle — the queue is the album

The music half of this app is not a generic Jellyfin music browser. It is a CD wallet from 2003.

You open the app and see a grid of album covers in plastic sleeves. You pick one. It plays. It finishes. You are back at the wallet.

**The queue is the album.** There is no cross-album queue, no shuffle, no algorithmic up-next, no autoplay into a recommendation. When the last track ends, playback stops and the UI returns you to the wallet page you pulled that album from.

That is not a missing feature. It is the product. Three consequences that are binding on the implementation:

1. `MusicPlayerService.queue` is only ever the track list of exactly one album. There is no API to append to it, and no "add to queue" affordance anywhere in the UI.
2. There is no shuffle control and no repeat control. Not hidden, not disabled — absent.
3. End of the last track is a *navigational* event, not just a playback one. The now-playing surface dismisses and the wallet scrolls to the album that just finished.

This applies to **iOS only**. tvOS keeps a conventional focus-driven album grid — the wallet metaphor depends on touch and on the device being held, and it does not survive a ten-foot interface. Do not build it there.

Video is unaffected by any of this.

### Definition of done

`xcodebuild build` and `xcodebuild test` pass for both schemes, `scripts/check-layer-imports.sh` exits 0, `swiftformat --lint .` is clean, and every acceptance criterion in §12 is demonstrable against a live Jellyfin 10.10+ server.

---

## 2. Platform and toolchain

Per Appendix A "Platform baseline", plus:

- **Targets**: iOS 26+, tvOS 26+. No macOS target in V1.
- **Xcode 26, Swift 6.2, Swift 6 language mode.**
- `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`, `SWIFT_APPROACHABLE_CONCURRENCY = NO` at project level.
- **Dependencies**: `VLCKit` (SPM, xcframework, iOS + tvOS slices) — the only third-party dependency. Nothing else. No Alamofire, no Kingfisher, no SDWebImage.
- **Licensing note**: VLCKit is LGPL. Link it dynamically (the xcframework already is) and keep it isolated to a single infrastructure type so it can be removed without touching any other layer.

### Capabilities and Info.plist

- iOS: Background Modes → Audio, AirPlay and Picture in Picture.
- Both: `NSAppTransportSecurity` → `NSAllowsArbitraryLoads = true`. Self-hosted Jellyfin servers on plain HTTP over LAN are the normal case; refusing them makes the app useless. Document this in the README.
- Both: `UIBackgroundModes` audio only. No fetch, no processing.

---

## 3. Package and target layout

One local SPM package, `MixtapeKit`, with six library targets matching Appendix A. Two thin app targets that contain only `App.swift`, the asset catalog and the Info.plist.

```
mixtape/
├─ Mixtape.xcodeproj
├─ Apps/
│  ├─ MixtapeiOS/          # App target: MixtapeApp.swift, Assets, Info.plist
│  └─ MixtapeTV/           # App target: MixtapeApp.swift, Assets, Info.plist
├─ MixtapeKit/
│  ├─ Package.swift
│  └─ Sources/
│     ├─ MixtapeDomain/
│     ├─ MixtapeUseCase/
│     ├─ MixtapeServices/
│     ├─ MixtapeInfrastructure/
│     ├─ MixtapeData/
│     └─ MixtapePresentation/
│  └─ Tests/
│     ├─ MixtapeDomainTests/
│     ├─ MixtapeUseCaseTests/
│     ├─ MixtapeServicesTests/
│     └─ MixtapeDataTests/
└─ scripts/check-layer-imports.sh
```

Dependency edges declared in `Package.swift` — nothing else is permitted to import across layers:

| Target | Depends on |
|---|---|
| `MixtapeDomain` | — |
| `MixtapeUseCase` | `MixtapeDomain` |
| `MixtapeInfrastructure` | `MixtapeDomain`, VLCKit |
| `MixtapeData` | `MixtapeUseCase`, `MixtapeDomain`, `MixtapeInfrastructure` |
| `MixtapeServices` | `MixtapeUseCase`, `MixtapeDomain` |
| `MixtapePresentation` | `MixtapeServices`, `MixtapeDomain` |

`MixtapePresentation` must **not** list `MixtapeData`, `MixtapeUseCase` or `MixtapeInfrastructure` as dependencies. The composition root in the app target is the only place that sees all six.

### Platform-specific views

One shared `MixtapePresentation` target. Where iOS and tvOS layouts genuinely diverge, write two files, each wrapped in `#if os(iOS)` / `#if os(tvOS)`, named for what they are — `MovieLibraryGrid.swift` (iOS) and `MovieLibraryShelf.swift` (tvOS) — never one file with a branch inside the body. One view per file still holds.

---

## 4. Domain (`MixtapeDomain`)

Foundation only. Value types, `Sendable`, no reference types.

### Entities

```swift
struct ServerIdentity: Sendable, Equatable {   // from /System/Info/Public
    let id: String
    let name: String
    let version: String
    let baseURL: URL
}

struct UserSession: Sendable, Equatable {
    let serverURL: URL
    let userID: String
    let userName: String
    let accessToken: String
    let deviceID: String
}

enum MediaKind: String, Sendable { case movie, series, season, episode, musicAlbum, audio }

struct Library: Sendable, Identifiable, Equatable {
    let id: String
    let name: String
    let kind: LibraryKind          // .movies, .tvShows, .music, .unsupported
    let imageTag: String?
}

struct MediaItem: Sendable, Identifiable, Equatable {
    let id: String
    let name: String
    let kind: MediaKind
    let overview: String?
    let productionYear: Int?
    let runtime: Duration?
    let indexNumber: Int?          // episode / track number
    let parentIndexNumber: Int?    // season number
    let seriesName: String?
    let albumArtist: String?
    let primaryImageTag: String?
    let backdropImageTag: String?
    let parentPrimaryImageTag: String?   // album art inherited by tracks
    let playback: PlaybackState
}

struct PlaybackState: Sendable, Equatable {
    let position: Duration
    let isWatched: Bool
    var hasResumePoint: Bool { position > .seconds(0) }
}
```

### Playback plan — the core domain decision

```swift
enum PlaybackMethod: Sendable, Equatable {
    case directAVPlayer        // native container/codec, AVPlayer plays the static stream
    case directVLC             // container/codec AVPlayer refuses, VLCKit plays the static stream
    case transcodeHLS          // server-side transcode, AVPlayer plays the HLS playlist
}

struct PlaybackPlan: Sendable, Equatable {
    let itemID: String
    let mediaSourceID: String
    let playSessionID: String
    let method: PlaybackMethod
    let streamURL: URL
    let startPosition: Duration
    let totalDuration: Duration?
}
```

### Supporting value types

Every name used elsewhere in this spec is defined here. Nothing else gets invented.

```swift
enum LibraryKind: Sendable { case movies, tvShows, music, unsupported }
enum ImageKind: Sendable { case primary, backdrop }

struct PageRequest: Sendable, Equatable { let startIndex: Int; let limit: Int }
struct Page<Element: Sendable>: Sendable { let items: [Element]; let totalCount: Int; let startIndex: Int }

struct QuickConnectHandshake: Sendable, Equatable { let secret: String; let code: String }

struct PlaybackReport: Sendable, Equatable {
    let itemID: String
    let mediaSourceID: String
    let playSessionID: String
    let position: Duration
    let isPaused: Bool
    let method: PlaybackMethod
}

enum LoadState<Value: Sendable>: Sendable {
    case idle, loading
    case loaded(Value)
    case failed(MixtapeError)
}

enum PlayerStatus: Sendable, Equatable {
    case idle, preparing, playing, paused
    case failed(MixtapeError)
}

enum QuickConnectUIState: Sendable, Equatable {
    case waiting(code: String)
    case failed(MixtapeError)
}
```

`AuthContext` (the header inputs: base URL, device ID, app version, optional token) lives in `MixtapeInfrastructure` beside `JellyfinHTTPClient`, not in Domain — it is a transport concern.

### Errors

```swift
enum MixtapeError: Error, Sendable, Equatable {
    case serverUnreachable
    case notAJellyfinServer
    case invalidCredentials
    case quickConnectUnavailable
    case quickConnectExpired
    case sessionExpired            // 401 on an authenticated call
    case noPlayableSource
    case transport(String)         // human-readable, already localised
    case decoding
}
```

### Pure rules (unit-tested, no I/O)

- `PlaybackState.isWatched` is set when `position / duration >= 0.9`.
- `MediaItem.displayTitle` — episodes render as `S2E4 · Title`, tracks as `3. Title`.
- `Duration` ↔ Jellyfin ticks: `ticks = seconds * 10_000_000`. Put this in `Duration+Ticks.swift` in Domain and use it nowhere else but Domain and Data.

---

## 5. Use cases (`MixtapeUseCase`)

One type per file, one `callAsFunction` (or single `execute`) each. Repository protocols live here.

### Repository protocols

```swift
protocol AuthRepositoryProtocol: Sendable {
    func serverIdentity(at url: URL) async throws -> ServerIdentity
    func authenticate(userName: String, password: String, server: ServerIdentity) async throws -> UserSession
    func isQuickConnectEnabled(server: ServerIdentity) async throws -> Bool
    func initiateQuickConnect(server: ServerIdentity) async throws -> QuickConnectHandshake
    func quickConnectState(secret: String, server: ServerIdentity) async throws -> Bool
    func authenticateWithQuickConnect(secret: String, server: ServerIdentity) async throws -> UserSession
}

protocol LibraryRepositoryProtocol: Sendable {
    func libraries(session: UserSession) async throws -> [Library]
    func items(in libraryID: String, kind: MediaKind, page: PageRequest, session: UserSession) async throws -> Page<MediaItem>
    func item(id: String, session: UserSession) async throws -> MediaItem
    func seasons(seriesID: String, session: UserSession) async throws -> [MediaItem]
    func episodes(seriesID: String, seasonID: String, session: UserSession) async throws -> [MediaItem]
    func tracks(albumID: String, session: UserSession) async throws -> [MediaItem]
    func continueWatching(session: UserSession) async throws -> [MediaItem]
}

protocol PlaybackRepositoryProtocol: Sendable {
    func resolveVideo(itemID: String, startAt: Duration, session: UserSession) async throws -> PlaybackPlan
    func audioStreamURL(itemID: String, session: UserSession) -> URL
    func reportStart(_ report: PlaybackReport, session: UserSession) async throws
    func reportProgress(_ report: PlaybackReport, session: UserSession) async throws
    func reportStopped(_ report: PlaybackReport, session: UserSession) async throws
}

protocol SessionStoreProtocol: Sendable {
    func load() throws -> UserSession?
    func save(_ session: UserSession) throws
    func clear() throws
}

protocol ImageURLBuilderProtocol: Sendable {
    func url(itemID: String, tag: String?, kind: ImageKind, maxHeight: Int, session: UserSession) -> URL?
}
```

### Use case list

| Type | Does |
|---|---|
| `ValidateServerUseCase` | URL → `ServerIdentity`; normalises scheme and trailing slash, tries `https` then `http` |
| `SignInWithPasswordUseCase` | credentials → `UserSession`, persisted via `SessionStoreProtocol` |
| `StartQuickConnectUseCase` | → `QuickConnectHandshake` (code + secret) |
| `PollQuickConnectUseCase` | secret → `UserSession?`; one poll, no timer (the service owns cadence) |
| `RestoreSessionUseCase` | → `UserSession?` from Keychain |
| `SignOutUseCase` | clears Keychain, no server call |
| `FetchLibrariesUseCase` | → `[Library]`, filtering `.unsupported` |
| `FetchLibraryItemsUseCase` | paged items for a library |
| `FetchItemDetailUseCase` | one item |
| `FetchSeasonsUseCase` / `FetchEpisodesUseCase` / `FetchAlbumTracksUseCase` | hierarchy |
| `FetchContinueWatchingUseCase` | resume row |
| `ResolveVideoPlaybackUseCase` | item + start position → `PlaybackPlan` |
| `BuildAudioStreamURLUseCase` | track → URL |
| `ReportPlaybackUseCase` | start / progress / stopped, one method each |

`MixtapeUseCase` imports Foundation and `MixtapeDomain`. Nothing else. `check-layer-imports.sh` fails the build on `import SwiftUI`, `import Observation`, `import UIKit`, `import AVFoundation` anywhere under `Sources/MixtapeUseCase` or `Sources/MixtapeDomain`.

---

## 6. Services (`MixtapeServices`)

`@MainActor @Observable final class`. The only place state is written. Constructor injection of use cases. Every service exposes a `static let placeholder` for `@Entry` defaults and a `Mock*` sibling for previews.

### `SessionService`

```swift
@MainActor @Observable
final class SessionService {
    enum State: Equatable { case loading, signedOut, signedIn(UserSession) }
    private(set) var state: State = .loading
    private(set) var serverIdentity: ServerIdentity?
    private(set) var error: MixtapeError?

    func restore() async
    func validateServer(urlText: String) async
    func signIn(userName: String, password: String) async
    func startQuickConnect() async                 // sets quickConnect
    func cancelQuickConnect()
    func signOut()

    private(set) var quickConnect: QuickConnectUIState?   // .idle / .waiting(code:) / .failed
}
```

Quick Connect polling: a `Task` that polls `PollQuickConnectUseCase` every **5 seconds** for at most **5 minutes**, cancelled on `cancelQuickConnect()`, on success, and in `deinit` via a stored `Task` handle. On expiry set `.quickConnectExpired`.

Any use case throwing `.sessionExpired` puts the service back to `.signedOut` and clears the Keychain. This is the single place session expiry is handled.

### `LibraryService`

Holds `libraries`, `continueWatching`, and a `[String: LoadState<Page<MediaItem>>]` keyed by library ID so tab switches don't refetch. Methods: `loadHome()`, `loadLibrary(id:)`, `loadMore(libraryID:)`, `refresh()`.

Paging: `limit = 60`, `startIndex` advanced by the returned count. `loadMore` is a no-op while a load is in flight or the page was short.

### `SeriesService`

`seasons(for:)` and `episodes(seasonID:)` with a per-series cache. Cleared on `refresh()`.

### `VideoPlaybackService`

```swift
@MainActor @Observable
final class VideoPlaybackService {
    private(set) var plan: PlaybackPlan?
    private(set) var status: PlayerStatus     // .idle, .preparing, .playing, .paused, .failed(MixtapeError)
    private(set) var position: Duration
    private(set) var duration: Duration?

    func play(item: MediaItem) async
    func togglePlayPause()
    func seek(to: Duration)
    func stop() async
}
```

Owns a `VideoPlayerControlling` (see §7) chosen from `plan.method`. Owns a progress timer: reports to the server **on start, every 10 s, on pause, on seek completion, and on stop**. Never more often — the server treats each report as a session heartbeat.

### `MusicPlayerService`

```swift
@MainActor @Observable
final class MusicPlayerService {
    /// Always exactly one album. See §1.1 — this is an invariant, not a starting point.
    private(set) var album: MediaItem?
    private(set) var queue: [MediaItem]
    private(set) var currentIndex: Int?
    private(set) var status: PlayerStatus
    private(set) var position: Duration

    /// Set when the last track ends. The wallet observes this, returns the user
    /// to the sleeve that just finished, then calls `acknowledgeFinish()`.
    private(set) var finishedAlbumID: String?

    var current: MediaItem? { currentIndex.map { queue[$0] } }

    func play(album: MediaItem, tracks: [MediaItem], startingAt index: Int) async
    func togglePlayPause()
    func next() async
    func previous() async      // restarts the track if position > 3 s
    func seek(to: Duration)
    func stop() async
    func acknowledgeFinish()
}
```

Single long-lived instance for the app's lifetime. Configures `AVAudioSession` `.playback` on first play, wires `MPRemoteCommandCenter` (play, pause, next, previous, changePlaybackPosition) and updates `MPNowPlayingInfoCenter` on every track change and every 5 s. Advances to the next track on `AVPlayerItemDidPlayToEndTime`.

Deliberately absent, per §1.1: no `enqueue`, no `append`, no `shuffle`, no `repeatMode`. `play(album:tracks:startingAt:)` **replaces** the queue every time — that is the only way tracks get into it.

At the end of the last track: stop, set `finishedAlbumID`, leave `album` and `queue` in place so the wallet can animate back to the right sleeve. `MPRemoteCommandCenter.nextTrackCommand` is disabled on the final track so the lock screen doesn't offer a skip that goes nowhere.

**Direct play preference.** The audio URL asks for the containers Apple plays natively first (`flac,alac,m4a,mp3,aac,wav,aiff`) so a well-tagged library never touches the server's transcoder. The HLS fallback stays in place for anything genuinely exotic, but a transcode on a music library is a tagging bug worth logging at `.info` on the `playback` category.

### `ImageService`

Wraps `ImageURLBuilderProtocol` plus an in-memory `NSCache<NSURL, UIImage>` limited to 120 MB. Exposes `func image(for: MediaItem, kind: ImageKind, maxHeight: Int) async -> UIImage?`. Decoding happens in a `@concurrent` function — this is one of the few places `@concurrent` is warranted.

---

## 7. Infrastructure (`MixtapeInfrastructure`)

Stateless or actor-isolated. No plain class with mutable state.

| Type | Notes |
|---|---|
| `JellyfinHTTPClient` | `struct`, `Sendable`. Wraps `URLSession`. Builds the auth header, encodes/decodes JSON, maps status codes to `MixtapeError`. |
| `KeychainStore` | `struct`, `Sendable`. Generic `Data` get/set/delete for one service+account pair. |
| `AVPlayerController` | `@MainActor final class`, conforms to `VideoPlayerControlling`. Owns an `AVPlayer` and a `AVPlayerLayer`-backed view. |
| `VLCPlayerController` | `@MainActor final class`, conforms to `VideoPlayerControlling`. The **only** file that imports `VLCKit`. |
| `AudioPlayerController` | `@MainActor final class`. `AVPlayer` for audio + `AVAudioSession` + now-playing wiring. |
| `AppLogger` | `struct` over `os.Logger`, one subsystem, categories `network`, `playback`, `auth`. |
| `DeviceAttitudeReader` | iOS only, optional (§9.1). `@MainActor final class` over `CMMotionManager`, exposes an `AsyncStream<Double>` of roll. Behind `DeviceAttitudeReading` so the sleeve view never sees CoreMotion. Skip the type entirely if the tilt sheen is cut. |

### HTTP client contract

```swift
struct JellyfinHTTPClient: Sendable {
    let session: URLSession
    func get<T: Decodable & Sendable>(_ path: String, query: [URLQueryItem], auth: AuthContext) async throws -> T
    func post<Body: Encodable & Sendable, T: Decodable & Sendable>(_ path: String, body: Body, query: [URLQueryItem], auth: AuthContext) async throws -> T
    func post<Body: Encodable & Sendable>(_ path: String, body: Body, query: [URLQueryItem], auth: AuthContext) async throws
}
```

**Authorization header** — one format, on every request including unauthenticated ones:

```
Authorization: MediaBrowser Client="mixtape", Device="<device name>", DeviceId="<stable UUID>", Version="<CFBundleShortVersionString>", Token="<access token, omitted when signing in>"
```

Do not use `X-Emby-Authorization`; Jellyfin is removing it.

`DeviceId` is a UUID generated once and stored in the Keychain alongside the token. It must survive app restarts — Jellyfin keys sessions and transcode jobs off it. `Device` is `UIDevice.current.name` on iOS, `"Apple TV"` on tvOS.

Status code mapping: `401` → `.invalidCredentials` on the auth endpoints, `.sessionExpired` elsewhere. `404`/`5xx` → `.transport`. `URLError.cannotFindHost`/`.cannotConnectToHost`/`.timedOut` → `.serverUnreachable`.

JSON decoding: Jellyfin returns PascalCase. Use explicit `CodingKeys` on every DTO — no `.convertFromSnakeCase`, no key strategy.

### `VideoPlayerControlling`

```swift
@MainActor
protocol VideoPlayerControlling: AnyObject {
    var onPositionChange: ((Duration) -> Void)? { get set }
    var onEnded: (() -> Void)? { get set }
    var onFailure: ((MixtapeError) -> Void)? { get set }
    func load(url: URL, startAt: Duration, headers: [String: String])
    func play()
    func pause()
    func seek(to: Duration)
    func teardown()
    func makeView() -> AnyView
}
```

`AVPlayerController.makeView()` returns a `VideoPlayer`-backed representable; `VLCPlayerController.makeView()` returns a `UIViewRepresentable` wrapping `VLCVideoView`. Presentation only ever sees `AnyView` and the protocol — never `AVPlayer`, never `VLCMediaPlayer`.

---

## 8. Data (`MixtapeData`) and the Jellyfin API contract

Repositories are stateless `Sendable` structs holding a `JellyfinHTTPClient`. DTOs are `internal`, live beside the repository that uses them, and are mapped to Domain types in a `*Mapper.swift`. No DTO ever crosses out of `MixtapeData`.

Base path: all paths below are relative to `serverURL`. Do **not** prefix `/emby`.

### Auth — `JellyfinAuthRepository`

| Call | Endpoint |
|---|---|
| Validate server | `GET /System/Info/Public` → `{Id, ServerName, Version}`. Unauthenticated. |
| Password sign-in | `POST /Users/AuthenticateByName` body `{"Username": …, "Pw": …}` → `{AccessToken, User: {Id, Name}}` |
| Quick Connect available | `GET /QuickConnect/Enabled` → `true`/`false`. A `401` also means unavailable. |
| Quick Connect start | `GET /QuickConnect/Initiate` → `{Secret, Code}` |
| Quick Connect poll | `GET /QuickConnect/Connect?secret=<secret>` → `{Authenticated: Bool, …}` |
| Quick Connect finish | `POST /Users/AuthenticateWithQuickConnect` body `{"Secret": …}` → same shape as password sign-in |

Quick Connect requires the `Authorization` header with a stable `DeviceId` on **every** call in the flow, including `Initiate` — the server binds the approval to that device.

### Library — `JellyfinLibraryRepository`

Use the query-parameter form of every user-scoped endpoint. The `/Users/{userId}/…` path form is deprecated.

| Call | Endpoint |
|---|---|
| Libraries | `GET /UserViews?userId={uid}` → `Items[]` with `CollectionType` ∈ `movies`, `tvshows`, `music` |
| Library items | `GET /Items?userId={uid}&parentId={lib}&includeItemTypes={Movie\|Series\|MusicAlbum}&recursive=true&sortBy=SortName&sortOrder=Ascending&fields=Overview,PrimaryImageAspectRatio&imageTypeLimit=1&enableImageTypes=Primary,Backdrop&startIndex={n}&limit=60` |
| Item detail | `GET /Items/{itemId}?userId={uid}&fields=Overview,MediaSources` |
| Seasons | `GET /Shows/{seriesId}/Seasons?userId={uid}` |
| Episodes | `GET /Shows/{seriesId}/Episodes?userId={uid}&seasonId={seasonId}&fields=Overview` |
| Album tracks | `GET /Items?userId={uid}&parentId={albumId}&includeItemTypes=Audio&sortBy=ParentIndexNumber,IndexNumber,SortName` |
| Continue watching | `GET /Items/Resume?userId={uid}&limit=12&mediaTypes=Video&fields=Overview` |

Paged responses are `{Items: [...], TotalRecordCount: Int, StartIndex: Int}` → `Page<MediaItem>`.

`UserData` on each item gives `PlaybackPositionTicks`, `Played`, `PlayedPercentage` → `PlaybackState`.

### Images — `JellyfinImageURLBuilder`

```
{base}/Items/{itemId}/Images/Primary?tag={tag}&fillHeight={maxHeight}&quality=90
{base}/Items/{itemId}/Images/Backdrop/0?tag={tag}&fillHeight={maxHeight}&quality=90
```

Tracks have no art of their own — fall back to `parentPrimaryImageTag` against the album's ID. Image URLs need no auth header when a `tag` is present, but send it anyway for consistency.

### Playback resolution — `JellyfinPlaybackRepository`

`POST /Items/{itemId}/PlaybackInfo?userId={uid}` with body:

```json
{
  "DeviceProfile": { ... see below ... },
  "StartTimeTicks": 0,
  "MaxStreamingBitrate": 120000000,
  "EnableDirectPlay": true,
  "EnableDirectStream": true,
  "EnableTranscoding": true,
  "AllowVideoStreamCopy": true,
  "AllowAudioStreamCopy": true,
  "AutoOpenLiveStream": true
}
```

Response gives `PlaySessionId` and `MediaSources[]`, each with `Id`, `SupportsDirectPlay`, `SupportsDirectStream`, `TranscodingUrl`, `Container`, `RunTimeTicks`, `MediaStreams[]`.

**Device profile.** Send *one* permissive profile that declares what the app can play across both players — VLCKit's range, not AVPlayer's. This keeps the server from transcoding MKV/HEVC/AC3 needlessly. Declare direct-play profiles for containers `mp4,m4v,mov,mkv,webm` with video codecs `h264,hevc,vp9,av1` and audio codecs `aac,mp3,ac3,eac3,flac,alac,opus,dts`; one transcoding profile for `hls` / `ts` / `h264` / `aac` as the fallback.

**Choosing the method** — this logic lives in `ResolveVideoPlaybackUseCase`, not in the repository:

```
pick the first MediaSource, else throw .noPlayableSource

if source.supportsDirectPlay || source.supportsDirectStream {
    url = {base}/Videos/{itemId}/stream?static=true
          &mediaSourceId={id}&playSessionId={psid}&api_key={token}
    method = isAVPlayerNative(source) ? .directAVPlayer : .directVLC
} else if let path = source.transcodingUrl {
    url = {base}{path}          // already contains api_key and playSessionId
    method = .transcodeHLS
} else {
    throw .noPlayableSource
}
```

`isAVPlayerNative(_:)` is a pure Domain function, unit-tested with a table of fixtures:

- container ∈ `mp4`, `m4v`, `mov`
- video codec ∈ `h264`, `hevc`
- audio codec ∈ `aac`, `mp3`, `alac`, `ac3`, `eac3`
- everything else (mkv, webm, vp9, av1, dts, flac, opus, truehd) → VLC

### Music streaming

No `PlaybackInfo` round-trip for audio. Build the URL directly:

```
{base}/Audio/{itemId}/universal?userId={uid}&deviceId={did}&api_key={token}
  &maxStreamingBitrate=320000&container=flac,alac,m4a,mp3,aac,wav,aiff
  &transcodingContainer=ts&transcodingProtocol=hls&audioCodec=aac
```

The container list is everything Apple platforms decode natively, so a properly tagged library direct-streams every time. The HLS fallback is there for the exceptions; when it fires, log the item ID at `.info` on the `playback` category — on a music library a transcode is a diagnostic, not a normal path.

### Progress reporting — same repository

| Event | Endpoint |
|---|---|
| Start | `POST /Sessions/Playing` |
| Progress | `POST /Sessions/Playing/Progress` |
| Stop | `POST /Sessions/Playing/Stopped` |

Body for all three:

```json
{ "ItemId": "…", "MediaSourceId": "…", "PlaySessionId": "…",
  "PositionTicks": 123456789, "IsPaused": false, "CanSeek": true,
  "PlayMethod": "DirectPlay" | "DirectStream" | "Transcode" }
```

Failures here are logged and swallowed. A dropped progress report must never surface as a playback error.

---

## 9. Presentation (`MixtapePresentation`)

Every view file carries a `#Preview` covering loaded, empty, and failure states, driven by `Mock*` services. No view takes a use case or repository in its signature.

### Screens — iOS

| Screen | Contents |
|---|---|
| `ServerEntryScreen` | URL field, Connect button, inline error |
| `SignInScreen` | Username, password, Sign In; "Use Quick Connect" when enabled |
| `QuickConnectScreen` | Large code, "waiting for approval" spinner, Cancel |
| `RootTabScreen` | Tabs: Home, Libraries, Music, Settings. Mini player docked above the tab bar when audio is playing |
| `HomeScreen` | Continue Watching row, Recently Added per library |
| `LibraryListScreen` | List of libraries |
| `MovieLibraryGrid` | Poster grid, 2-up compact / 4-up regular, paged |
| `SeriesLibraryGrid` | Poster grid |
| `MovieDetailScreen` | Backdrop, title, year, runtime, overview, Play / Resume |
| `SeriesDetailScreen` | Season picker → episode list |
| `EpisodeRow` | Thumbnail, `S2E4 · Title`, progress bar |
| `WalletScreen` | The CD wallet — paged sleeves of album art. The Music tab's root. See §9.1 |
| `WalletPage` | One page of the wallet: a fixed 2×2 (compact) / 3×3 (regular) block of sleeves |
| `AlbumSleeve` | One album in a plastic sleeve. Art, glass sheen, tap target |
| `AlbumDetailScreen` | Pulled-out disc: art, album artist, year, track list, Play |
| `NowPlayingScreen` | Sheet: art, title, scrubber, prev/play/next. No shuffle, no repeat, no queue button |
| `VideoPlayerScreen` | Full-screen cover hosting `plan`-selected player view + custom overlay |
| `SettingsScreen` | Server name, user, Sign Out |

### 9.1 The Wallet (iOS only)

The music tab's root is not a scrolling grid. It is a binder of clear plastic sleeves that you page through sideways.

**Layout.** A horizontal `TabView(.page)` — or `ScrollView(.horizontal)` with `.scrollTargetBehavior(.paging)` — of `WalletPage`s. Each page is a fixed grid: **2×2 on compact width, 3×3 on regular**. Fixed, not adaptive: a page that reflows is a grid, not a wallet. Albums fill pages in the library's sort order; a partial last page keeps its empty slots visible as empty sleeves. A page indicator sits below.

**The sleeve.** `AlbumSleeve` is the album art inset in a rounded rect with a thin light border and a single diagonal specular highlight across the upper-left — the plastic. This is the one place in the app where Liquid Glass is doing representational work rather than chrome, so it is worth the care. Under Reduce Transparency the sheen is dropped entirely and the sleeve becomes a flat bordered card; under Reduce Motion the highlight stops tracking device attitude.

**Optional, if it is cheap:** the highlight's angle follows `CMMotionManager` device attitude at 30 Hz, so tilting the phone catches the light. Gate it behind Reduce Motion and skip it if it costs more than an afternoon — the wallet works without it.

**Pulling a disc out.** Tapping a sleeve pushes `AlbumDetailScreen` with a `matchedGeometryEffect` on the artwork, so the art lifts out of its sleeve and becomes the album header. One namespace, one modifier pair. Do not build a bespoke transition.

**Putting it back.** When `MusicPlayerService.finishedAlbumID` becomes non-nil, `WalletScreen`:

1. dismisses `NowPlayingScreen` and pops `AlbumDetailScreen`,
2. scrolls to the page containing that album,
3. briefly highlights the sleeve (a 0.4 s border pulse — the disc sliding home),
4. calls `acknowledgeFinish()`.

This is the whole point of the feature. It must work even if the user backgrounded the app during the last track; on foreground, run the same sequence without the animation.

**Not present anywhere on this surface:** shuffle, repeat, add-to-queue, "play all", up-next, a global play button. If a control would let a second album's tracks reach the queue, it does not exist.

**Empty and failure states.** No albums → an empty wallet with a single line of copy, not a spinner. Load failure → an empty wallet with a retry. `WalletScreen`'s `#Preview` covers full page, partial page, empty and failed.

### Screens — tvOS

No wallet here — §1.1 explains why. Same information architecture, different chrome:

- `RootTabScreen` uses a top `TabView` with Home / Movies / Shows / Music / Settings.
- Grids become `LazyVGrid` shelves inside a `ScrollView`, focus-driven, no mini player.
- `MovieDetailScreen` is a full-bleed backdrop with the metadata block bottom-left.
- `QuickConnectScreen` is the *primary* sign-in path on tvOS — present it first, with "Sign in with a password" as the secondary action.
- `VideoPlayerScreen` uses the system transport controls where AVPlayer is in play; for VLC, a custom overlay driven by the Siri Remote's play/pause and swipe gestures.

### Chrome

Liquid Glass for navigation bars, the mini player and player overlays. Every glass surface needs a `@Environment(\.accessibilityReduceTransparency)` fallback to an opaque material. No exceptions.

### Accessibility identifiers

Every interactive element gets a stable `accessibilityIdentifier` in `Identifiers.swift` (one enum per screen). UI tests query these, never visible text.

---

## 10. Composition root

Built by hand in each app target. Both app targets share this shape; only the root screen differs.

```swift
@main
struct MixtapeApp: App {
    @State private var container = AppContainer()

    var body: some Scene {
        WindowGroup {
            RootScreen()
                .environment(\.sessionService, container.sessionService)
                .environment(\.libraryService, container.libraryService)
                .environment(\.seriesService, container.seriesService)
                .environment(\.videoPlaybackService, container.videoPlaybackService)
                .environment(\.musicPlayerService, container.musicPlayerService)
                .environment(\.imageService, container.imageService)
        }
    }
}
```

`AppContainer` is a `@MainActor` struct in the app target that constructs the client, the repositories, the use cases and the services in that order — the only file in the codebase that imports all six library targets. No DI framework, no service locator, no `.shared`.

Environment wiring uses `@Entry`:

```swift
extension EnvironmentValues {
    @Entry var sessionService: SessionService = .placeholder
    @Entry var libraryService: LibraryService = .placeholder
    // …one per service
}
```

`RootScreen` switches on `sessionService.state`: `.loading` → splash, `.signedOut` → the server/sign-in flow, `.signedIn` → `RootTabScreen`.

---

## 11. Testing

Swift Testing (`@Test`, `@Suite`) for unit tests. XCTest only for XCUITest.

Tag suites by layer: `.domain`, `.useCase`, `.service`, `.repository`.

**Required coverage:**

- **Domain**: `isAVPlayerNative` across a fixture table of container/codec combinations; tick conversion round-trips; watched threshold at 89.9% / 90.0% / 90.1%; `displayTitle` for episode, track, movie.
- **UseCase**: every use case against `Mock*` repositories — success, `.sessionExpired`, `.serverUnreachable`. `ResolveVideoPlaybackUseCase` gets a case per `PlaybackMethod` branch plus `.noPlayableSource`.
- **Services**: `SessionService` restore/sign-in/expiry transitions; Quick Connect poll success, cancellation, and timeout (inject a clock, do not sleep); `LibraryService` paging including the short-page stop condition.
- **`MusicPlayerService` — the §1.1 invariants get their own suite**: `next()` past the final track stops rather than advancing; `play(album:…)` called twice replaces the queue rather than appending; `finishedAlbumID` is set exactly once at end-of-album and cleared by `acknowledgeFinish()`; `previous()` restarts the track above 3 s and steps back below it. These are the tests that stop someone helpfully adding a cross-album queue later.
- **Data**: DTO → Domain mapping against captured JSON fixtures in `Tests/MixtapeDataTests/Fixtures/`. Repositories tested with a stubbed `URLProtocol`, never a live server.

**XCUITest**, one happy path per platform: launch with a stubbed session via a launch argument (`-uitest-signed-in`), open Movies, open the first movie, tap Play, assert the player view exists. Driven entirely off accessibility identifiers.

Never test a repository against a real Jellyfin instance in CI.

---

## 12. Acceptance criteria

1. Entering `192.168.1.10:8096` with no scheme resolves and connects.
2. Wrong password shows an inline error and does not clear the username field.
3. Quick Connect on tvOS: code appears, approving in Jellyfin Web signs the app in within 10 s.
4. Force-quit and relaunch lands directly on Home — no sign-in prompt.
5. Home shows Continue Watching with correct progress bars.
6. An `.mp4/h264/aac` movie plays via `.directAVPlayer` — confirm no transcode session in the Jellyfin dashboard.
7. An `.mkv/hevc/dts` movie plays via `.directVLC` — again, no transcode session.
8. A source the profile rejects plays via `.transcodeHLS` and the dashboard shows a transcode.
9. Watch 30 s, exit, return: the item offers Resume at ≈30 s and the Jellyfin dashboard reflects it.
10. Finishing a movie marks it watched in Jellyfin Web.
11. Series → season → episode navigation works and episodes are ordered correctly.
12. Album playback advances through the queue; lock screen shows art, title and artist; the remote's next button skips.
13. Backgrounding the app on iOS keeps music playing.
13a. The wallet pages horizontally in fixed 2×2 blocks on iPhone; rotating to landscape or running on iPad gives 3×3 without reflowing mid-page.
13b. Tapping a sleeve lifts the artwork into the album header; going back puts it into the sleeve it came from.
13c. Playing an album to the end stops playback, dismisses now-playing, and lands on the wallet page holding that album with its sleeve pulsing.
13d. 13c still happens correctly when the app was backgrounded for the final track and is foregrounded afterwards.
13e. Nowhere in the music UI is there a shuffle, repeat, or add-to-queue control, and the lock screen's next-track button is disabled on the final track.
13f. Playing a FLAC album produces no transcode session in the Jellyfin dashboard.
14. Signing out clears the Keychain — relaunch shows the server entry screen.
15. Reduce Transparency on: no glass surface renders translucent.
16. Server unreachable mid-browse shows a retry affordance, not a blank screen.

---

## 13. Build order

Build in this sequence; each step compiles and its tests pass before the next starts.

1. Package skeleton, six targets, `check-layer-imports.sh` wired as a build phase.
2. Domain types + pure rules + their tests.
3. `JellyfinHTTPClient`, `KeychainStore`, `AppLogger`.
4. Auth repository + auth use cases + `SessionService` + sign-in screens. **Ship-able checkpoint: you can sign in.**
5. Library repository + browse use cases + `LibraryService`/`SeriesService` + browse screens + `ImageService`. **Checkpoint: you can browse.**
6. Playback repository + `ResolveVideoPlaybackUseCase` + `AVPlayerController` + `VideoPlaybackService` + player screen (AVPlayer path only).
7. `VLCPlayerController` + the `.directVLC` branch.
8. Progress reporting + resume.
9. `AudioPlayerController` + `MusicPlayerService` + `AlbumDetailScreen` + `NowPlayingScreen` + remote/now-playing wiring, on a plain album grid. **Checkpoint: music plays, one album at a time.**
10. Replace the grid with the wallet: `WalletScreen`, `WalletPage`, `AlbumSleeve`, the matched-geometry pull-out, the return-to-sleeve sequence. Motion tilt last, and only if step 10 came in cheap.
11. tvOS presentation layer (no wallet).
11. XCUITests, accessibility pass, Reduce Transparency pass.

---

## Appendix A — Swift MV architecture template (authoritative)

> Generic template. Pulled from trimr project. Use for new iOS/Swift apps.

### Core rule

No ViewModel layer. `@MainActor @Observable` **services** hold state. Views read state through `@Environment`. Views call service methods to act.

### Platform baseline

- iOS 26+, MacOS 26+, tvOS 26+ ONLY. No back-deploy. No `#available` checks.
- Xcode 26, Swift 6.2, Swift 6 language mode.
- Set at project level:
  - `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`
  - `SWIFT_APPROACHABLE_CONCURRENCY = NO`
- Use `@concurrent` for real background work only (parsing, decoding, image work).
- Swift Testing for unit tests. XCTest only for UI automation (XCUITest).
- Liquid Glass by default for chrome. Always give a Reduce Transparency fallback.

### Six layers, one direction

```
Presentation → Services → UseCase → Domain
                              ↑
                    Data, Infrastructure
```

| Target | Holds | Depends on |
|---|---|---|
| `AppDomain` | Entities, value types, domain errors, pure business rules | Foundation only |
| `AppUseCase` | One type per use case, repository protocols | `AppDomain` |
| `AppServices` | `@MainActor @Observable` classes — only place state is written | `AppUseCase`, `AppDomain` |
| `AppInfrastructure` | Network client, keychain, logging, third-party SDKs | Foundation, SDKs |
| `AppData` | Repository implementations, DTO-to-Domain mapping | `AppUseCase`, `AppDomain`, `AppInfrastructure` |
| `AppPresentation` | SwiftUI views only | `AppServices`, `AppDomain` |

Rules:

- `AppUseCase` never imports SwiftUI or Observation. Enforce with a build-phase script that greps for those imports and fails the build (`scripts/check-layer-imports.sh` in trimr).
- `AppData` repositories: stateless `Sendable` structs. No caching hidden inside a repository — caching is its own injected collaborator.
- `AppInfrastructure`: stateless or actor-isolated. No plain class with mutable state and no actor.
- Exception: SwiftData `ModelContainer`, `@Model` types, and store actors live in `AppData/Persistence/` — persistence and its repository stay together.
- `AppPresentation`: no use case or repository type in a View's signature. If a view needs data shaped differently, that's the service's job.

### Feature subfolders (not one flat folder per layer)

Inside each layer, group by feature, not by file type:

```
AppServices/<Feature>/
AppUseCase/UseCases/<Feature>/
AppPresentation/Screens/<Feature>/
```

Shared cross-feature code gets its own `Shared/` or `Mocks/` folder per layer.

Presentation components split further by role, not feature:

```
AppPresentation/Components/Cards/
AppPresentation/Components/Chrome/
AppPresentation/Components/Feedback/
AppPresentation/Components/Rows/
AppPresentation/Components/Styles/
```

### Wiring into the environment

Use `@Entry`, not hand-rolled `EnvironmentKey`:

```swift
extension EnvironmentValues {
    @Entry var profileService: ProfileService = .placeholder
}
```

Build the whole object graph once, by hand, at the app root. No DI container, no service locator.

```swift
@main
struct AppRoot: App {
    @State private var profileService = ProfileService(
        fetchProfileUseCase: FetchProfileUseCase(repository: ProfileRepository(client: apiClient))
    )
    var body: some Scene {
        WindowGroup {
            RootView().environment(\.profileService, profileService)
        }
    }
}
```

### Code style rules

- One type per file. Filename matches type name.
- One view per file. No `private var header: some View`, no `@ViewBuilder private func`.
- Every view file has a `#Preview` covering its states (empty, nil, failure included).
- No `fatalError`, `as!`, `try!` without a same-line comment saying why it's unreachable.
- No prefix `!`. Write `x == false`, not `!x`.
- No Combine. `async`/`await`, `AsyncSequence`, `Observation` cover it.
- Constructor injection only. No singletons, no `.shared`, except wrapped system-wide types behind a protocol.
- Protocol suffix: `*Protocol`. Test doubles: `Mock*` (in main target, for previews), `Stub*` (test target only).

### Testing

- Swift Testing only (`@Test`, `@Suite`) for unit tests.
- Tag suites by layer: `.domain`, `.useCase`, `.service`, `.repository`.
- Test behaviour, not the mock's plumbing.
- Every UseCase and Service type gets tests against injected `Mock*`/`Stub*` — never the real `AppData` implementation.
- XCUITest for one happy-path UI test per screen. Drive it off accessibility identifiers, never visible text.

### Commands to verify a new project

```bash
xcodebuild -scheme <App> -destination 'generic/platform=iOS Simulator' -configuration Debug build
xcodebuild test -scheme <App> -destination 'platform=iOS Simulator,name=<Sim>,OS=<Version>'
./scripts/check-layer-imports.sh
swiftformat --lint .
```

### What to copy vs rewrite for a new app

Copy as-is: layer boundaries, the import-check script, `@Entry` wiring pattern, code style rules, testing rules.

Rewrite per app: Domain entities, use cases, service list, screen list — all product-specific.

---

## Appendix B — Verification commands

```bash
xcodebuild -scheme Mixtape   -destination 'generic/platform=iOS Simulator'  -configuration Debug build
xcodebuild -scheme MixtapeTV -destination 'generic/platform=tvOS Simulator' -configuration Debug build
xcodebuild test -scheme Mixtape   -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.0'
xcodebuild test -scheme MixtapeTV -destination 'platform=tvOS Simulator,name=Apple TV 4K (3rd generation),OS=26.0'
./scripts/check-layer-imports.sh
swiftformat --lint .
```

## Appendix C — API references

Jellyfin's own OpenAPI spec is served by every instance at `{base}/api-docs/swagger`. Check it against the running server before assuming any endpoint shape below is current.

- [Jellyfin API authorization header format](https://gist.github.com/nielsvanvelzen/ea047d9028f676185832e51ffaf12a6f)
- [API authentication — jellyfin/jellyfin#12990](https://github.com/jellyfin/jellyfin/issues/12990)
- [QuickConnectController.cs](https://github.com/jellyfin/jellyfin/blob/master/Jellyfin.Api/Controllers/QuickConnectController.cs)
- [Quick Connect flow — Jellyfin Kotlin SDK](https://kotlin-sdk.jellyfin.org/guide/authentication.html)
- [Legacy auth removal in 10.13](https://github.com/seerr-team/seerr/issues/2278)
- [Deprecated `/Users/{userId}/…` paths](https://community.firecore.com/t/update-jellyfin-api-use-of-deprecated-paths/54999)
- [DeviceProfile reference](https://typescript-sdk.jellyfin.org/interfaces/generated-client.DeviceProfile.html)
- [PlaybackInfoResponse reference](https://typescript-sdk.jellyfin.org/interfaces/generated-client.PlaybackInfoResponse.html)
- [Jellyfin video playback walkthrough](https://gist.github.com/kylehowells/74f538c766a244a3666319860a937030)

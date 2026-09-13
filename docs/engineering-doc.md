# mixtape — V1 Engineering Spec

A Jellyfin client for iOS. Browse a Jellyfin server's music library, play albums, report progress back.

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
| 5 | List the user's libraries (music) |
| 6 | Browse a music library → albums → tracks |
| 7 | Play music: album queue, next/prev, background audio, lock screen / remote controls |
| 8 | Report playback start / progress / stop to the server |
| 9 | Remote images (album art) with in-memory cache |
| 10 | **The Wallet** — iOS-only album-centric browsing surface (§9.1) |

### Out of scope for V1 — do not build

Downloads and offline playback · multi-server / multi-user switching · search · SyncPlay · AirPlay/Cast target UI beyond what the system gives free · collections, playlists, favourites, watched toggling · widgets · settings beyond sign out · localisation beyond en.

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

### Definition of done

`xcodebuild build` and `xcodebuild test` pass for the `Mixtape` scheme, `scripts/check-layer-imports.sh` exits 0, `swiftformat --lint .` is clean, and every acceptance criterion in §12 is demonstrable against a live Jellyfin 10.10+ server.

---

## 2. Platform and toolchain

Per Appendix A "Platform baseline", plus:

- **Targets**: iOS 26+. No macOS, no tvOS in V1.
- **Xcode 26, Swift 6.2, Swift 6 language mode.**
- `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`, `SWIFT_APPROACHABLE_CONCURRENCY = NO` at project level.
- **Dependencies**: none. No Alamofire, no Kingfisher, no SDWebImage.

### Capabilities and Info.plist

- Background Modes → Audio.
- `NSAppTransportSecurity` → `NSAllowsArbitraryLoads = true`. Self-hosted Jellyfin servers on plain HTTP over LAN are the normal case; refusing them makes the app useless. Document this in the README.
- `UIBackgroundModes` audio only. No fetch, no processing.

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
│     ├─ MixtapeDataTests/
│     └─ MixtapePresentationTests/      # slice 013: pure presentation helpers, no view rendering
└─ scripts/
   ├─ check-layer-imports.sh            # layer edges the gate enforces (§13 step 1)
   ├─ check-glass-fallback.sh           # every Material site reads Reduce Transparency (slice 012)
   ├─ gate.sh                           # the slice gate, counted against docs/slices/test-count.txt (slice 013)
   ├─ jf-probe.swift                    # server-observable acceptance checks (decision 47)
   ├─ sim-type.sh                       # types a credential into the iOS simulator without echoing it (decision 46)
   └─ tv-remote.sh + tvkey.m            # Siri Remote presses for the Apple TV simulator (decision 49)
```

Dependency edges declared in `Package.swift` — nothing else is permitted to import across layers:

| Target | Depends on |
|---|---|
| `MixtapeDomain` | — |
| `MixtapeUseCase` | `MixtapeDomain` |
| `MixtapeInfrastructure` | `MixtapeDomain` |
| `MixtapeData` | `MixtapeUseCase`, `MixtapeDomain`, `MixtapeInfrastructure` |
| `MixtapeServices` | `MixtapeUseCase`, `MixtapeDomain` |
| `MixtapePresentation` | `MixtapeServices`, `MixtapeDomain` |

`MixtapePresentation` must **not** list `MixtapeData`, `MixtapeUseCase` or `MixtapeInfrastructure` as dependencies. The composition root in the app target is the only place that sees all six.

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

enum MediaKind: String, Sendable { case musicAlbum, audio }

struct Library: Sendable, Identifiable, Equatable {
    let id: String
    let name: String
    let kind: LibraryKind          // .music, .unsupported
    let imageTag: String?
}

struct MediaItem: Sendable, Identifiable, Equatable {
    let id: String
    let name: String
    let kind: MediaKind
    let overview: String?
    let productionYear: Int?
    let runtime: Duration?
    let indexNumber: Int?          // track number
    let parentIndexNumber: Int?    // disc number
    let albumArtist: String?
    let primaryImageTag: String?
    let backdropImageTag: String?
    let parentPrimaryImageTag: String?   // album art inherited by tracks
    let playback: PlaybackState
}

struct PlaybackState: Sendable, Equatable {
    let position: Duration
    var hasResumePoint: Bool { position > .seconds(0) }
}
```

### Supporting value types

Every name used elsewhere in this spec is defined here. Nothing else gets invented.

```swift
enum LibraryKind: Sendable { case music, unsupported }
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

- `MediaItem.displayTitle` — tracks render as `3. Title`.
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
    func tracks(albumID: String, session: UserSession) async throws -> [MediaItem]
}

protocol PlaybackRepositoryProtocol: Sendable {
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
| `FetchAlbumTracksUseCase` | album → tracks |
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

Holds `libraries` and a `[String: LoadState<Page<MediaItem>>]` keyed by library ID so tab switches don't refetch. Methods: `loadHome()`, `loadLibrary(id:)`, `loadMore(libraryID:)`, `refresh()`.

Paging: `limit = 60`, `startIndex` advanced by the returned count. `loadMore` is a no-op while a load is in flight or the page was short.

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

`DeviceId` is a UUID generated once and stored in the Keychain alongside the token. It must survive app restarts — Jellyfin keys sessions off it. `Device` is `UIDevice.current.name`.

Status code mapping: `401` → `.invalidCredentials` on the auth endpoints, `.sessionExpired` elsewhere. `404`/`5xx` → `.transport`. `URLError.cannotFindHost`/`.cannotConnectToHost`/`.timedOut` → `.serverUnreachable`.

JSON decoding: Jellyfin returns PascalCase. Use explicit `CodingKeys` on every DTO — no `.convertFromSnakeCase`, no key strategy.

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
| Quick Connect start | `POST /QuickConnect/Initiate` → `{Secret, Code}` (decision 5 — the spec declares `POST`; corrected by slice 017) |
| Quick Connect poll | `GET /QuickConnect/Connect?secret=<secret>` → `{Authenticated: Bool, …}` |
| Quick Connect finish | `POST /Users/AuthenticateWithQuickConnect` body `{"Secret": …}` → same shape as password sign-in |

Quick Connect requires the `Authorization` header with a stable `DeviceId` on **every** call in the flow, including `Initiate` — the server binds the approval to that device.

### Library — `JellyfinLibraryRepository`

Use the query-parameter form of every user-scoped endpoint. The `/Users/{userId}/…` path form is deprecated.

| Call | Endpoint |
|---|---|
| Libraries | `GET /UserViews?userId={uid}` → `Items[]` with `CollectionType` ∈ `music` |
| Library items | `GET /Items?userId={uid}&parentId={lib}&includeItemTypes=MusicAlbum&recursive=true&sortBy=SortName&sortOrder=Ascending&fields=Overview,PrimaryImageAspectRatio&imageTypeLimit=1&enableImageTypes=Primary,Backdrop&startIndex={n}&limit=60` |
| Item detail | `GET /Items/{itemId}?userId={uid}&fields=Overview,MediaSources` |
| Album tracks | `GET /Items?userId={uid}&parentId={albumId}&includeItemTypes=Audio&sortBy=ParentIndexNumber,IndexNumber,SortName` |

Paged responses are `{Items: [...], TotalRecordCount: Int, StartIndex: Int}` → `Page<MediaItem>`.

`UserData` on each item gives `PlaybackPositionTicks` and `Played` → `PlaybackState`. It does not give `PlayedPercentage` — the server never sends that field, and the 90 % rule is computed client-side from position and runtime (decision 8; corrected by slice 017).

### Images — `JellyfinImageURLBuilder`

```
{base}/Items/{itemId}/Images/Primary?tag={tag}&fillHeight={maxHeight}&quality=90
{base}/Items/{itemId}/Images/Backdrop/0?tag={tag}&fillHeight={maxHeight}&quality=90
```

Tracks have no art of their own — fall back to `parentPrimaryImageTag` against the album's ID. Image URLs need no auth header when a `tag` is present, but send it anyway for consistency.

### Music streaming

No `PlaybackInfo` round-trip for audio. Build the URL directly:

```
{base}/Audio/{itemId}/universal?userId={uid}&deviceId={did}&ApiKey={token}
  &container=flac,alac,m4a,mp3,aac,wav,aiff
  &transcodingContainer=ts&transcodingProtocol=hls&audioCodec=aac
```

The token travels as `ApiKey` in the query (decision 42) and there is **no** `maxStreamingBitrate`: the old `320000` forced every ALAC and FLAC track through the transcoder (decision 43, spike S002). Corrected by slice 017.

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
| `RootTabScreen` | Tabs: Libraries, Music, Settings. Mini player docked above the tab bar when audio is playing |
| `LibraryListScreen` | List of libraries |
| `WalletScreen` | The CD wallet — paged sleeves of album art. The Music tab's root. See §9.1 |
| `WalletPage` | One page of the wallet: a fixed 2×2 (compact) / 3×3 (regular) block of sleeves |
| `AlbumSleeve` | One album in a plastic sleeve. Art, glass sheen, tap target |
| `AlbumDetailScreen` | Pulled-out disc: art, album artist, year, track list, Play |
| `NowPlayingScreen` | Sheet: art, title, scrubber, prev/play/next. No shuffle, no repeat, no queue button |
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

### Chrome

Liquid Glass for navigation bars, the mini player and player overlays. Every glass surface needs a `@Environment(\.accessibilityReduceTransparency)` fallback to an opaque material. No exceptions.

### Accessibility identifiers

Every interactive element gets a stable `accessibilityIdentifier` in `Identifiers.swift` (one enum per screen). UI tests query these, never visible text.

---

## 10. Composition root

Built by hand in the app target.

```swift
@main
struct MixtapeApp: App {
    @State private var container = AppContainer()

    var body: some Scene {
        WindowGroup {
            RootScreen()
                .environment(\.sessionService, container.sessionService)
                .environment(\.libraryService, container.libraryService)
                .environment(\.musicPlayerService, container.musicPlayerService)
                .environment(\.imageService, container.imageService)
        }
    }
}
```

`AppContainer` is a `@MainActor` struct in the app target that constructs the client, the repositories, the use cases and the services in that order — the only file in the codebase that wires all six layers together. No DI framework, no service locator, no `.shared`.

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

- **Domain**: tick conversion round-trips; `displayTitle` for a track.
- **UseCase**: every use case against `Mock*` repositories — success, `.sessionExpired`, `.serverUnreachable`.
- **Services**: `SessionService` restore/sign-in/expiry transitions; Quick Connect poll success, cancellation, and timeout (inject a clock, do not sleep); `LibraryService` paging including the short-page stop condition.
- **`MusicPlayerService` — the §1.1 invariants get their own suite**: `next()` past the final track stops rather than advancing; `play(album:…)` called twice replaces the queue rather than appending; `finishedAlbumID` is set exactly once at end-of-album and cleared by `acknowledgeFinish()`; `previous()` restarts the track above 3 s and steps back below it. These are the tests that stop someone helpfully adding a cross-album queue later.
- **Data**: DTO → Domain mapping against captured JSON fixtures in `Tests/MixtapeDataTests/Fixtures/`. Repositories tested with a stubbed `URLProtocol`, never a live server.

**XCUITest**, one happy path: launch with a stubbed session via a launch argument (`-uitest-signed-in`), open the Music tab, open the first album, tap Play, assert the now-playing view exists. Driven entirely off accessibility identifiers.

Never test a repository against a real Jellyfin instance in CI.

---

## 12. Acceptance criteria

1. Entering `localhost:8096` with no scheme resolves and connects.
2. Wrong password shows an inline error and does not clear the username field.
3. Force-quit and relaunch lands directly on the Libraries tab — no sign-in prompt.
4. Album playback advances through the queue; lock screen shows art, title and artist; the remote's next button skips.
5. Backgrounding the app keeps music playing.
5a. The wallet pages horizontally in fixed 2×2 blocks on iPhone; rotating to landscape or running on iPad gives 3×3 without reflowing mid-page.
5b. Tapping a sleeve lifts the artwork into the album header; going back puts it into the sleeve it came from.
5c. Playing an album to the end stops playback, dismisses now-playing, and lands on the wallet page holding that album with its sleeve pulsing.
5d. 5c still happens correctly when the app was backgrounded for the final track and is foregrounded afterwards.
5e. Nowhere in the music UI is there a shuffle, repeat, or add-to-queue control, and the lock screen's next-track button is disabled on the final track.
5f. Playing a FLAC album produces no transcode session in the Jellyfin dashboard.
6. Signing out clears the Keychain — relaunch shows the server entry screen.
7. Reduce Transparency on: no glass surface renders translucent.
8. Server unreachable mid-browse shows a retry affordance, not a blank screen.

---

## 13. Build order

Build in this sequence; each step compiles and its tests pass before the next starts.

1. Package skeleton, six targets, `check-layer-imports.sh` wired as a build phase.
2. Domain types + pure rules + their tests.
3. `JellyfinHTTPClient`, `KeychainStore`, `AppLogger`.
4. Auth repository + auth use cases + `SessionService` + sign-in screens. **Ship-able checkpoint: you can sign in.**
5. Library repository + browse use cases + `LibraryService` + browse screens + `ImageService`. **Checkpoint: you can browse.**
6. Progress reporting.
7. `AudioPlayerController` + `MusicPlayerService` + `AlbumDetailScreen` + `NowPlayingScreen` + remote/now-playing wiring, on a plain album grid. **Checkpoint: music plays, one album at a time.**
8. Replace the grid with the wallet: `WalletScreen`, `WalletPage`, `AlbumSleeve`, the matched-geometry pull-out, the return-to-sleeve sequence. Motion tilt last, and only if step 8 came in cheap.
9. Accessibility pass and Reduce Transparency pass. XCUITest was in this step and is deferred out of the round by decision 4; the identifiers it needs are written here.
10. Hardening round: presentation test target and gate hardening, wallet finish ownership, and this document's reconciliation.

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
xcodebuild -scheme Mixtape -destination 'generic/platform=iOS Simulator' -configuration Debug build
xcodebuild test -scheme Mixtape -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
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


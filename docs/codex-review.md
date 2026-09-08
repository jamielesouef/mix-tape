# Project review report

## Overall assessment

The project has a strong architectural foundation: clear module boundaries, manual dependency injection, typed domain models, structured concurrency, explicit DTO mapping, and unusually thorough delivery documentation.

It is not yet release-ready. The main risks are session isolation, asynchronous playback races, possible credential leakage through VLC logging, incorrect handling of Jellyfin direct-stream sources, and iOS signing/privacy configuration. The documentation is extensive but substantially behind the implementation; Slice 017 correctly acknowledges that reconciliation is still outstanding.

No files were modified, and no builds or tests were run during the review.

## Review scope

I reviewed:

- All Markdown documentation under `docs/`, starting with the engineering, architecture, API, design, runbook, decision, slice, and evidence documents.
- The pinned Jellyfin OpenAPI document, focusing on all endpoints and schemas used by the application.
- All Swift production modules, application composition, platform-specific presentation code, and test sources.
- Package, Xcode, entitlement, Info.plist, Docker, formatting, and gate configuration.
- The current uncommitted Slice 016 implementation.

Read-only validation performed:

- Layer import check: passed.
- Glass fallback check: passed.
- SwiftFormat lint: 0 of 268 files require formatting.
- Current manifest: 184 `@Test` declarations.
- No compilation, test execution, simulator use, or live Jellyfin requests.

The worktree changed externally during the review. The final snapshot has Slice 016 marked **In progress** and Slice 017 **Not started**, with uncommitted library-list/focus work. Findings involving that work are identified as provisional.

## High-severity findings

### 1. Session changes do not invalidate user-specific services

`SessionService` clears its own credentials on sign-out or expiry, but it does not reset the long-lived services created by `AppContainer`.

`LibraryService` and `SeriesService` retain libraries, pages, details, seasons, episodes, and tracks without namespacing them by server or user. Several screens only fetch when their service is in an idle state. Consequently, signing into another server or account in the same process can expose cached media from the previous session and suppress the new fetch.

Music and video controllers are similarly retained. There is no session-owned guarantee that active playback, progress tasks, or reporting state are terminated when credentials disappear.

Recommendation: add a session-lifecycle coordinator. On sign-out, expiry, or identity replacement it should synchronously stop both players, cancel work, invalidate in-flight generations, and clear every user-scoped cache. Add integration tests that switch between two fake users and servers.

### 2. Playback transitions are vulnerable to network delays and stale asynchronous completion

In `MusicPlayerService`, next, previous, natural completion, and stop await the stopped-report request before performing the local transition. With the configured 15-second HTTP timeout, skipping or natural advancement can produce a network-sized playback gap; stop can leave audio running while the report is pending.

The service also lacks an operation-generation token. Rapid play/next/stop operations can allow an older artwork request, reporting operation, or progress task to update a newer track. A replacement `play` does not first stop and report the previous track.

`VideoPlaybackService` has related races:

- A stale resolution failure can replace a newer playback state with `.failed`.
- Replaying the same item can pass the item-ID-only stale-result check.
- Old controller callbacks are not associated with a controller or operation generation.
- A progress task can start after playback has already been replaced or stopped.

Recommendation: make local transport transitions immediate, snapshot reporting identity and position, serialize reporting independently, and attach a generation UUID to each playback operation. Revalidate the UUID after every suspension point. Test using deliberately suspended repositories and image loaders.

### 3. VLC diagnostic logging can expose access tokens

Playback URLs contain Jellyfin `ApiKey` query parameters. `VLCPlayerController` forwards raw VLC warning/error messages into logging, and the logger marks messages public.

The retained VLC evidence demonstrates that messages may include the complete media resource locator. In production that can disclose the user token through unified logs or collected diagnostics.

Recommendation: never log raw VLC messages. Redact URLs and all authentication query parameters, or replace the message with a fixed diagnostic code and safe structured fields.

### 4. “Direct Stream” currently requests the original file

`ResolveVideoPlaybackUseCase` treats `supportsDirectPlay` and `supportsDirectStream` identically: both receive a `/Videos/.../stream?static=true` URL, differing only in the method later reported to Jellyfin.

The pinned OpenAPI contract describes `static=true` as sending the original file without encoding. Jellyfin’s own stream-building source also treats direct stream/remux separately from static original-file playback. Therefore a source that requires container remuxing may receive an incompatible original file while the client reports `DirectStream`. This is an inference from the pinned contract and official source, but it is a strong one. [Jellyfin StreamBuilder](https://github.com/jellyfin/jellyfin/blob/master/MediaBrowser.Model/Dlna/StreamBuilder.cs)

Recommendation: use Jellyfin’s direct-stream URL/parameters for direct-stream-only sources. Reserve `static=true` for actual direct play. Add a fixture where direct play is false and direct stream is true, asserting both the URL and successful player path.

### 5. iOS privacy and entitlements are not production-ready

The app’s normal use case includes connecting to a LAN Jellyfin server, but `Apps/MixtapeiOS/Info.plist` has no `NSLocalNetworkUsageDescription`. Apple directs apps that access the local network to provide this purpose string. [Apple TN3179](https://developer.apple.com/documentation/technotes/tn3179-understanding-local-network-privacy?changes=_4_9)

Both application plists also enable unrestricted `NSAllowsArbitraryLoads`. That is broader than the local HTTP-server requirement and should be replaced with the narrowest workable policy.

`mixtape.entitlements`, attached to the iOS target, declares capabilities for Sign in with Apple, Siri, Wi-Fi information, deprecated playable content, side-button access, macOS hardened-runtime/sandbox behavior, and low-latency streaming. No matching application implementation was found. The low-latency entitlement is documented for visionOS streamed-game scenarios. [Apple capabilities overview](https://developer.apple.com/help/account/capabilities/capabilities-overview/), [low-latency streaming entitlement](https://developer.apple.com/documentation/bundleresources/entitlements/com.apple.developer.low-latency-streaming?changes=l_4)

Recommendation: remove every unused entitlement, retain only exercised capabilities, add the local-network purpose string, and review the ATS exception before signing or distribution.

## Medium-severity implementation findings

### Video scrubber over-reports seeks

`VLCPlayerView+iOS` calls `scrub` for every slider value update. VLC immediately emits a seek event, and the service sends a playback report for every event. A drag can therefore create many server requests.

Use local drag state and perform one seek/report when editing ends, as the music scrubber already does.

### Lock-screen artwork disappears after the first heartbeat

`MusicPlayerService` supplies artwork during the asynchronous initial update, but periodic refreshes pass `nil`. `AudioPlayerController` reconstructs the entire now-playing dictionary, so the first five-second refresh removes the image.

Retain the current artwork or update only the elapsed-time/rate keys. The existing cadence test should also assert artwork retention.

### Audio-session lifecycle is incomplete

`AudioPlayerController` marks configuration complete before two ignored throwing calls. One transient failure can therefore prevent all future configuration attempts.

There is no interruption, route-change, or media-services-reset handling. Video playback also does not independently establish the playback audio category, so video-first playback can inherit the default session behavior, which obeys the Ring/Silent switch. Apple documents `.playback` for media that should continue with the silent switch enabled. [AVAudioSession](https://developer.apple.com/documentation/avfaudio/avaudiosession?changes=_2), [playback category](https://developer.apple.com/documentation/avfaudio/avaudiosession/category-swift.struct/playback?changes=_2)

A shared audio-session coordinator should own activation, interruptions, route changes, resets, and safe diagnostics.

### Image caching underestimates memory use

`ImageService` advertises a 120 MB cache, but cache cost is the compressed network byte count. The decoded image can consume substantially more memory. Concurrent requests for the same URL are not coalesced, HTTP status is not validated, and decoding/preparation is not explicitly completed before display.

Use downsampling or `preparingForDisplay()`, decoded dimensions for cost, response validation, and an in-flight task cache. [Apple `preparingForDisplay()`](https://developer.apple.com/documentation/uikit/uiimage/preparingfordisplay%28%29?changes=__8)

### Keychain replacement can lose valid credentials

`KeychainStore` deletes the existing value before adding the replacement. If the add fails, the old credential or device ID is lost.

Use `SecItemUpdate`, falling back to add only when the item does not exist. Avoid silently creating a temporary per-launch device ID when persistence fails.

### Reduce Transparency fallback is still translucent

The VLC fallbacks in `VLCPlayerView+iOS` and its tvOS counterpart use `Color.black.opacity(0.8)` while describing the result as opaque. This leaves video visible and conflicts with the documented accessibility requirement.

The glass check passes because it recognizes the fallback marker, not because it validates opacity.

### Audio playback method is inferred, not observed

`JellyfinPlaybackRepository` infers direct play or transcoding from the item’s container, treating a missing container as direct play. Server decisions can also depend on codecs, profiles, bitrate, and device capabilities, so reporting can be wrong.

Prefer a server-provided playback decision or observed response. At minimum, do not represent missing metadata as proven direct play.

### Smaller correctness concerns

- `LibraryService` replaces accumulated paginated content with a failure state when loading a later page fails.
- Refresh does not invalidate existing in-flight requests, so an old response can repopulate a freshly cleared cache.
- Track and series requests have no duplicate-request coalescing.
- `JellyfinHTTPClient` interpolates device metadata into a quoted authorization header without escaping quotes or backslashes.
- The episodes `SortBy=ParentIndexNumber,IndexNumber` request is contract-ambiguous: the OpenAPI description allows comma-delimited values while its schema looks singular. Treat this as an integration-validation gap rather than a confirmed defect.
- The sign-in flow offers no route to change a server after successful validation but before authentication.

## Documentation findings

### The engineering document is materially stale

`docs/engineering-doc.md` still presents itself as the main implementation contract, but differs from both the decision log and source in important ways:

- Quick Connect initiation says `GET`; the implementation and Decision 5 use `POST`.
- Continue Watching uses `/Items/Resume`; the implementation uses `/UserItems/Resume`.
- It describes `PlayedPercentage`, while the mapper correctly uses `Played`.
- Image examples use `fillHeight` and authentication; the implementation uses `maxHeight`, unauthenticated image URLs, and album fallback IDs/tags.
- It specifies `AVPlayerLayer`; the UI uses AVKit `VideoPlayer`.
- Several repository/use-case signatures predate the present playback plans, audio streams, separate reporting use cases, and series-plus-season episode requests.
- Audio examples still put `api_key` in the URL and impose a 320 kbps cap, both reversed by Decisions 42–43.
- The module graph omits the approved Services → Infrastructure player edge and the Presentation test target.
- Scheme names and gate commands are stale.
- Server support is described broadly as 10.10+, while the repository’s captured contract is 10.11.11.

Slice 017 should make the decision log and shipped implementation authoritative, then regenerate this document rather than patching isolated passages.

### Other documentation inconsistencies

- `docs/architecture.md` is superseded but still looks operational. It retains old platform, XCUITest, and build-command expectations. Give it a prominent archival banner or remove it.
- `docs/design/player-design-prompt.md` prohibits card borders/plastic sheen and describes cover expansion into the player, while the engineering design explicitly mandates plastic wallet sleeves and a separate album-detail-to-now-playing flow.
- `docs/slices/MASTER-CHECKLIST.md` contains text saying Slice 017 “replaced” documentation even though Slice 017 remains not started.
- `docs/slices/016-tvos-library-list.md` says iOS and first-of-kind resolution are out of scope, while the current uncommitted implementation changes both. Its acceptance criteria remain unchecked, so this should be reconciled before marking the slice done.
- The Slice 003 evidence script uses full-resolution crop coordinates, but the retained screen captures are reduced to 460×1000 and the separate accessory strips have different dimensions. `diff.py` therefore produces empty/zero regions for part of its analysis and cannot reproduce the published measurements from retained artifacts.
- `docker-compose.yml` uses `jellyfin/jellyfin:latest`, while documentation and fixtures target 10.11.11. New development environments are not reproducible.
- `README.md` contains only the project title. It provides no supported-platform, setup, Jellyfin, secrets, run, verification, or documentation-entry guidance.
- The ADW/Fable runbook embeds rapidly aging tool/model/version/pricing assumptions without an owner or verified-as-of date.

## Testing assessment

The test structure is good, but the current manifest is not proof that the current snapshot passes.

Strengths include isolated test modules, closure-based fakes, URLProtocol stubbing, captured fixtures, deterministic pure helpers, and a gate that checks per-suite manifests and result bundles across both platforms.

Important gaps:

- No delayed-collaborator tests for rapid play, stop, seek, sign-out, or same-item replay races.
- No cross-user/session cache isolation tests.
- No direct-stream-only integration contract test.
- No assertion that periodic Now Playing updates preserve artwork.
- Presentation tests primarily exercise extracted resolution logic rather than SwiftUI rendering, focus, sheets, or accessibility behavior.
- XCUITest targets remain templates and are deliberately excluded under Decision 4. That is an accepted project decision, but still leaves the focus/accessibility/playback flows dependent on manual runtime acceptance.
- The 184 count measures declarations, not parameterized cases, behavioral depth, or coverage.

The current tvOS focus concern remains correctly open in Slice 016, including the player’s up/down move-command handling. It should be resolved through the listed physical/simulator acceptance checks rather than treated as statically proven.

## What is working well

- Strong six-module dependency direction and narrow third-party boundaries.
- One clear composition root rather than a service locator.
- Swift 6 concurrency defaults, explicit isolation for mutable services, and `Sendable` value types.
- No production force unwraps or `fatalError` patterns found.
- Exact VLCKit package pinning.
- Clean DTO-to-domain separation and explicit coding keys.
- Consistent typed errors and loading states.
- Generally good task cancellation and weak captures.
- Accessibility identifiers and platform-specific view separation.
- Sensitive environment files are ignored.
- Static architecture, glass-fallback, and formatting checks currently pass.

## Recommended remediation order

1. Redact VLC diagnostics and remove unnecessary entitlements.
2. Implement session-owned teardown and cache invalidation.
3. Add operation generations to both playback services and remove network reporting from the critical transport path.
4. Correct direct-stream URL construction.
5. Fix video seek reporting, Now Playing artwork retention, and audio-session lifecycle.
6. Complete Slice 016 runtime acceptance.
7. Execute Slice 017 as a deliberate documentation rewrite, including README and reproducible Jellyfin pinning.
8. Add concurrency/session/integration tests before considering the current test count a release signal.

No repository files were changed during the review. This report file was subsequently added at the user’s request.

---

## Disposition (added 2026-09-07)

Every finding above is mapped to a slice, a decision, or a recorded reason for no change. Status lives in `docs/slices/MASTER-CHECKLIST.md`; this table only says where each finding went. The report itself is left as written, including statements that were true of the snapshot it reviewed (016 in progress, 017 not started) and are no longer.

| Finding | Where it went |
|---|---|
| High 1 — session changes do not invalidate user-specific services | Slice 020 |
| High 2 — playback transitions vulnerable to network delays and stale completion | Slice 021 |
| High 3 — VLC diagnostic logging can expose access tokens | Slice 019: `redactingURLs` strips every URL from libVLC messages before they reach the `playback` log; tested in `MixtapeDataTests` |
| High 4 — "Direct Stream" requests the original file | Slice 022 |
| High 5 — iOS privacy and entitlements | Slice 019: `mixtape.entitlements` emptied; `NSLocalNetworkUsageDescription` added to both plists; `NSAllowsArbitraryLoads` kept by 019 decision row (plain-`http://` home servers by hostname or IP) |
| Medium — video scrubber over-reports seeks | Slice 019: the iOS VLC slider holds the drag and scrubs once on release |
| Medium — lock-screen artwork disappears after the first heartbeat | Slice 019: `MusicPlayerService` keeps the current track's artwork and passes it on every refresh; the cadence test asserts it |
| Medium — audio-session lifecycle incomplete | Split: the `didConfigureSession` flag → 019; interruptions, route changes, media-services reset and video's `.playback` category → slice 023 |
| Medium — image caching underestimates memory use | Slice 023 |
| Medium — keychain replacement can lose valid credentials | Slice 019: `SecItemUpdate` first, `SecItemAdd` only on `errSecItemNotFound` |
| Medium — Reduce Transparency fallback still translucent | Slice 019: opaque `.black` on both platforms |
| Medium — audio playback method is inferred, not observed | Recorded, no change: decision 23 chose the `universal` endpoint and container inference, and decision 39 states that a nil container/codec is treated as native. `/Audio/{id}/universal` returns no playback decision to observe; the alternative is a `PlaybackInfo` round-trip per track, which decision 23 rejected. Re-open as a decision if a wrong `PlayMethod` is ever observed on the dashboard |
| Smaller — `LibraryService` replaces accumulated pages with a failure | Slice 023 |
| Smaller — refresh does not invalidate in-flight requests | Sign-out case → slice 020; general refresh → slice 023 |
| Smaller — no duplicate-request coalescing for tracks and series | Slice 023 |
| Smaller — `JellyfinHTTPClient` header interpolation without escaping | Slice 019: `\` and `"` escaped in the device name; tested |
| Smaller — episodes `SortBy` contract ambiguity | Recorded as a validation gap, no change: the pinned spec's description allows comma-delimited values and the server has answered the request correctly in every acceptance run since 005. A fixture-level check is not possible because the ambiguity is in the server's contract, not the client's mapping |
| Smaller — no route to change server before authentication | Slice 019: `SessionService.clearServer()` and a "Change server" button (`signIn.changeServerButton`) |
| Docs — engineering document materially stale | Closed by slice 017 before this table was written: Quick Connect `POST`, `/UserItems/Resume`, `Played`, `ApiKey`, no bitrate cap, `VideoPlayer` not `AVPlayerLayer`, image URL shape, test-target tree and §13 build order each carry the superseding decision in place (017 AC17a/b) |
| Docs — `docs/architecture.md` looks operational | Slice 019: superseded banner at the top |
| Docs — `player-design-prompt.md` contradicts §9 | Slice 019: precedence banner at the top |
| Docs — checklist says 017 "replaced" text while 017 not started | Overtaken: 017 is Done (commit `ad22315`), so the statement is now true |
| Docs — 016 says iOS and first-of-kind are out of scope while the implementation changes both | Overtaken: 016's second pass (commit `a3aa10a`) reconciled its decision log — the list appears only for a kind with more than one library; a single library still resolves first-of-kind — and ticked its criteria |
| Docs — S003 `diff.py` cannot reproduce the published numbers from retained artefacts | Slice 019: reproducibility note in S003 §6 |
| Docs — `docker-compose.yml` uses `:latest` | Slice 019: pinned to `jellyfin/jellyfin:10.11.11`; `docs/jellyfin-api.md` reconciled |
| Docs — `README.md` is only a title | Slice 019: written |
| Docs — runbook has no owner or verified-as-of date | Slice 019: added |
| Testing — no delayed-collaborator race tests | Slice 021 |
| Testing — no cross-user/session cache isolation tests | Slice 020 |
| Testing — no direct-stream-only contract test | Slice 022 |
| Testing — no assertion that periodic Now Playing updates preserve artwork | Slice 019 |
| Testing — presentation tests exercise extracted logic, not rendering | Recorded, no change this round: decision 4 defers XCUITest and slice 013's decision log records why presentation tests target platform-shared helpers (one manifest serves both schemes) |
| Testing — XCUITest targets are templates | Decision 4; unchanged |
| Testing — the 184 count measures declarations | Recorded: decision 38 and slice 013 chose declarations as the gate's unit deliberately, checked twice (source and result bundle) |
| tvOS focus concern (016) | Closed by 016's second pass on the Apple TV simulator (`scripts/tv-remote.sh`, decision 49) |

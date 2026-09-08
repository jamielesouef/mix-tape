---
slice_id: "019"
title: Codex review — bounded fixes
priority: P1
complexity: M
ladder: none
depends_on:
  - { id: "018", type: hard, note: "the seek path this slice's scrubber and artwork fixes sit beside; 018 deleted the clamp and its test, and raised Triage 24" }
  - { id: "013", type: hard, note: "MixtapeServicesTests, MixtapeDataTests and the test-count manifest the gate reads" }
previous_slice: "018"
next_slice: "020"
parent_slice: none
covers: []
created: 2026-09-07
---

# 019 — Codex review — bounded fixes

← [previous](018-audio-end-of-track-failure.md) · [Master Checklist](MASTER-CHECKLIST.md) · [next](020-session-owned-teardown.md) →

> **Status, owner and blockers live in the master checklist, not here.** Dependencies live in this page's front matter and nowhere else. Each fact has one home; if you find yourself writing it twice, one of the two copies is going to be wrong in a fortnight.

## 1. Objective

Every finding in `docs/codex-review.md` that is one or two files and needs no new seam is fixed, and every finding that is not gets a named owner in the disposition table appended to that document. Observable on its own: a stream URL can no longer reach the unified log through libVLC, the iOS app declares no capability it does not use, and the lock screen keeps its artwork past the first five-second refresh.

## 2. Business Value & Priority

The review found one disclosure risk that exists today — `VLCBridgeLogger` forwards raw libVLC messages, which the retained 007 evidence shows can carry the whole media resource locator including `ApiKey`, into a `.public` log — and a set of small correctness defects (lost lock-screen artwork, a keychain write that deletes before it adds, a video scrubber that reports per pixel, a "fallback" that is 80 % black, an audio-session flag set before the calls it guards). None of them needs the session or generation work of 020–021, so they land first and cheaply. P1 because the log finding is a credential path; the rest rides along because each is smaller than the slice that would otherwise carry it.

## 3. Scope

**In scope**, one acceptance criterion each:

- **Codex High #3** — `VLCBridgeLogger.handleMessage` (`MixtapeInfrastructure/Video/VLCPlayerController.swift`) logs `"VLC: \(message)"` at `.public`. The raw message is never logged again: the level and a fixed text are, plus the message with every `http(s)://…` run redacted. Stays `nonisolated`.
- **Codex High #5** — `mixtape.entitlements` is emptied (the file stays so `CODE_SIGN_ENTITLEMENTS` in the pbxproj is untouched — CLAUDE.md forbids anything that makes Xcode 27 rewrite the project). `NSLocalNetworkUsageDescription` is added to both `Info.plist`s. `NSAllowsArbitraryLoads` stays, by decision row.
- **Artwork** — `MusicPlayerService.refreshNowPlaying()` passes `artwork: nil` and `AudioPlayerController.updateNowPlaying` rebuilds the whole dictionary, so the first 5 s refresh drops the image. The service keeps the last artwork it loaded for the current track and passes it on every refresh; the cadence test asserts it.
- **Keychain** — `KeychainStore.set` deletes then adds. It updates first and adds only on `errSecItemNotFound`.
- **Video scrubber** — `VLCPlayerView+iOS.swift` calls `controller.scrub(to:)` on every slider value change; the drag is held locally and `scrub` is called once on release, the shape 015 gave `NowPlayingScreen`.
- **VLC fallback opacity** — `VLCPlayerView+iOS.swift:53` and `VLCPlayerView+tvOS.swift:67` use `.black.opacity(0.8)` as the Reduce Transparency fallback; both become opaque `.black`.
- **Audio session flag** — `AudioPlayerController.configureSessionIfNeeded` sets `didConfigureSession = true` before its two `try?` calls; it is set only when both succeed.
- **Authorization header** — `JellyfinHTTPClient.swift:50` interpolates the device name into a quoted header without escaping `"` or `\`; both are escaped, with a `MixtapeDataTests` test.
- **Change server** — after `validateServer` succeeds there is no way back to server entry. `SessionService.clearServer()` resets `serverIdentity`, `error` and any Quick Connect state, and `SignInScreen` gains a "Change server" button (`signIn.changeServerButton`), which returns `SignInFlow` to `ServerEntryScreen` on both platforms.
- **Triage 24** — the decision-23 HLS fallback is reproduced on the iOS simulator against a non-native fixture before any change; the finding and the decision are recorded in §6.
- **Documents** — `docker-compose.yml` pinned to `10.11.11`; a real `README.md`; a superseded banner on `docs/architecture.md`; a precedence banner on `docs/design/player-design-prompt.md`; a note in `S003-accessory-reduce-transparency.md` that `diff.py`'s crop coordinates are full-resolution while the retained captures are 460×1000; an owner and verified-as-of line on `docs/adw-fable-runbook.md`; a disposition table appended to `docs/codex-review.md`.

**Out of scope** (owner named):

- Codex High #1, session teardown and cache invalidation → 020.
- Codex High #2, playback generations and reporting off the transport path → 021.
- Codex High #4, direct-stream URL construction → 022.
- Audio-session interruptions, route changes, video's audio category; `ImageService` cost, coalescing and validation; `LibraryService` pagination failure, refresh invalidation, request coalescing → 023.
- Recorded, not changed: the audio `PlayMethod` inference (decisions 23 and 39 state that assumption); the episodes `SortBy` contract ambiguity (a validation gap, not a defect); the test-count remark (decision 38, slice 013).

**Plan requirements covered:** none. Defect and hygiene work, gated on builds, tests and the scripts plus the demonstrations below.

## 4. Pre-Flight Validation

- [x] **018** — opened; its decision log still reads as this slice assumes and Triage 24 is open with this slice as owner.
- [x] **013** — opened; `docs/slices/test-count.txt` is the manifest; this slice adds tests and changes it in the same commit.
- [x] Architecture standards doc re-read.

**Drift found:** one item. The running dev server is the main repo's compose (`mixtape-jellyfin:local`, still 10.11.11), not this repo's `docker-compose.yml`; the pin here is documentary until that compose is rebuilt. Recorded here, no checklist row — no slice depends on which compose file is running.

## 5. Acceptance Criteria

- [x] **AC19a** — `grep -n 'VLC: \\(message)' MixtapeKit/Sources` finds nothing; the logger's redaction is exercised by a `MixtapeDataTests` test over the pure redaction helper (a URL with `ApiKey=` in, no scheme or token out).
- [x] **AC19b** — `mixtape.entitlements` contains an empty `<dict/>`; both `Info.plist`s carry `NSLocalNetworkUsageDescription`; the iOS build signs and launches on the simulator.
- [x] **AC19c** — the cadence test asserts the artwork passed at the 5 s and 10 s refreshes is the artwork loaded at start; on the simulator the lock screen (Control Centre) still shows the cover 15 s into a track.
- [x] **AC19d** — `KeychainStore.set` calls `SecItemUpdate` before `SecItemAdd`; sign out and sign in twice on the simulator, relaunch, and the session restores.
- [x] **AC19e** — a VLC drag on the iOS simulator produces one `/Sessions/Playing/Progress` report per drag, read through `jf-probe.swift` (position jumps once, not per pixel).
- [x] **AC19f** — `grep -n 'opacity(0.8)' MixtapeKit/Sources/MixtapeInfrastructure` finds nothing; `check-glass-fallback.sh` still passes.
- [x] **AC19g** — `didConfigureSession` is assigned after both audio-session calls succeed.
- [x] **AC19h** — a `MixtapeDataTests` test signs in with device name `Jamie's "iPhone" \ test` and the captured header carries `Device="Jamie's \"iPhone\" \\ test"`.
- [x] **AC19i** — a `MixtapeServicesTests` test: `clearServer()` after `validateServer` leaves `serverIdentity == nil`, `error == nil`, `quickConnect == .idle`; on the simulator the "Change server" button returns to server entry.
- [x] **AC19j** — Triage 24 has a §6 row naming the cause, measured on the iOS simulator, and is closed or re-owned in the checklist.
- [x] **AC19k** — every codex finding appears in the disposition table with a slice, a decision or a reason.
- [x] `xcodebuild build` and `test` pass for both schemes; layer, glass and swiftformat clean.

**Evidence, 2026-09-07, iPhone 17 Pro simulator (iOS 26.5) against `localhost:8096`, read through `scripts/jf-probe.swift`, `idb ui describe-all` and `log stream`.** Gate: `.gate-log` 12:28:50, 187/0/0 on both schemes. *AC19b* — the build signed with the empty entitlements file and launched. *AC19c* — playing "King Of Terrors": the `com.apple.amp.mediaremote:NowPlaying` log shows `Setting nowPlayingInfo` at 12:38:33.264 (start) and 12:38:38.311 (the 5 s refresh) each followed by `Setting nowPlayingInfo artwork (id: 1e23d9474dfd6737)` with `ArtworkDataWidth = 768`; before this slice the second update carried no artwork. *AC19d* — sign out, sign in, sign out, sign in, `simctl terminate` and relaunch: Home, then Settings showing `Name, localhost` and `User, test`. *AC19e* — F1 (mkv, VLC) playing at 7 s; one `idb ui swipe` across `vlcPlayer.scrubber` (1.5 s); `/Sessions` `PositionTicks` went from the music session to F1 at 32.4 s in one jump, and the `com.apple.CFNetwork` summary log recorded exactly one completed task (12:40:32.559) in the swipe window — one report per drag. *AC19i* — after `serverEntry.connectButton`, `signIn.changeServerButton` returned the flow to `serverEntry.urlField` and `serverEntry.connectButton`. *AC19j* — see the Triage 24 row in §6; the fixture is `media/music/Mixtape Test/Non Native/1. Opus Test.opus` (ogg/opus, 40 s) on the dev server, item `0e3a6c6e0dd22a631090ac869b55b8fa`. Observed for 020: the mini player kept playing "In the Name of the Father" through sign-out and both sign-ins — codex High #1 as built.

## 6. Decision Log

**Write the row before you implement the decision, not after.**

| Date | Decision | Alternatives rejected | Why |
|---|---|---|---|
| 2026-09-07 | `NSAllowsArbitraryLoads` stays in both `Info.plist`s, with `NSLocalNetworkUsageDescription` added beside it. | (a) Remove it and rely on `NSAllowsLocalNetworking`; (b) an `NSExceptionDomains` list. | A home Jellyfin is routinely plain `http://` by hostname or LAN IP (`http://nas.home`, `http://192.168.1.20:8096`), which the local-networking exemption does not cover, and the server is user-entered so no domain list can be written ahead of time. Narrowing it is a product decision for `SPEC-DECISIONS.md`, not a hygiene fix. |
| 2026-09-07 | libVLC messages are logged as `"VLC <level>: <message with every http(s) URL replaced by <url>>"` through a pure `nonisolated` helper, `redactingURLs(_:)`, tested in `MixtapeDataTests` (fork F1 gives Infrastructure no target of its own). | (a) Log only a fixed text and drop the message — loses the diagnostic that made 007 debuggable; (b) strip only the `ApiKey` query item — the MRL also carries `deviceId` and any future query credential. | The message minus its URLs keeps the codec and demuxer diagnostics and cannot carry a token. |
| 2026-09-07 | `mixtape.entitlements` becomes an empty dictionary rather than being detached from the target. | Removing `CODE_SIGN_ENTITLEMENTS` from the pbxproj. | Touching the project file invites the `objectVersion = 90` rewrite CLAUDE.md forbids; an empty entitlements file is a valid signing input. |
| 2026-09-07 | The last artwork is kept on `MusicPlayerService` as `@ObservationIgnored private var artwork: UIImage?`, cleared in `start(index:)` and set by `refreshNowPlayingAsync()`. | Keeping it in `AudioPlayerController` and merging dictionaries there. | The service already owns the artwork provider and the refresh cadence; the controller stays a stateless dictionary writer. |
| 2026-09-07 | "Change server" is a `SessionService.clearServer()` plus one button on `SignInScreen`; `SignInFlow` needs no change because it already branches on `serverIdentity == nil`. | A navigation stack over the three sign-in screens. | The flow is a three-way `if` on service state; one more state transition is the smallest change that makes the route exist. |
| 2026-09-07 | Triage 24 is a server-emitted playlist defect, reproduced on the iOS simulator, and its fix is re-owned to 023. Cause: for a non-native track (`ogg`/opus, container list excluded) `/Audio/{id}/universal` returns a master playlist whose child URI is `main.m3u8?…&TranscodeReasons=ContainerNotSupported, VideoCodecNotSupported, AudioCodecNotSupported` — the enum list is joined with `", "` and the spaces are **not** percent-encoded. AVPlayer requests that URI as written; Kestrel rejects a request line containing spaces with `400 Bad Request` before Jellyfin logs anything, which is why the server log was silent and `CFHTTP` reported `err=-16845 … http response 400`. A raw socket `GET` with the spaces reproduces the 400; the same path with `%20` returns 200, and `jf-probe.swift` gets 200 because `URL(string:)` encodes the spaces. The segment URIs inside `main.m3u8` carry the same query, so the bad playlist cannot be fixed by rewriting one URL in flight. Meanwhile the app kept `status == .playing` and reported a rising position for a stalled player — 021's stale-completion class. | (a) Fix here by pointing AVPlayer at `/Audio/{id}/main.m3u8` directly with the client's own query (no `TranscodeReasons`), which the probe shows is a valid VOD playlist whose segments then inherit a space-free query; (b) an `AVAssetResourceLoaderDelegate` that rewrites the master; (c) report upstream and wait. | (a) is the right fix but changes the decision-23 URL shape and `PlayMethod` handling for non-native tracks, which is audio hardening, not a bounded fix — 023 owns it with this row as its spec. (b) is the full custom-scheme loader Triage 6 rejected. (c) is not a client fix. |

## 7. Sub-Slices

Not split — delivered as a single slice.

## 8. Testing Strategy

- **Unit:** `MixtapeServicesTests` (`.service`) — artwork retention in the cadence test, `clearServer()`. `MixtapeDataTests` (`.repository`) — header escaping via the stubbed `URLProtocol`, URL redaction helper.
- **Demonstration (Infrastructure has no target, fork F1):** keychain update path, VLC single-report drag, lock-screen artwork, "Change server", Triage 24 — all on the iOS 26.5 simulator against `localhost:8096`, read through `jf-probe.swift`.
- **Test targets required:** `MixtapeServicesTests`, `MixtapeDataTests` (exist). `docs/slices/test-count.txt` changes in the same commit.

## 9. Keeping this document true

| Before you… | Write this first |
|---|---|
| implement a decision | the Section 6 row, including what you rejected |
| start work | flip status in the master checklist |
| stop on a blocker | the Active Blockers row |
| widen scope | Section 3, and `depends_on` on any slice that's now affected |

Commit this file alongside the code, with the slice id in the subject (`019: …`).

## 10. Definition of Done

- [x] Acceptance criteria met
- [x] Tests passing, in a target that exists
- [x] Decision log written as you went, not reconstructed
- [x] Pre-flight completed and drift resolved
- [x] Master checklist row current
- [x] `next_slice`'s `depends_on` reflects what actually shipped
- [x] Both link directions checked

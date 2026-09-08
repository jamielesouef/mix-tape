---
slice_id: "005"
title: Browse
priority: P0
complexity: L
ladder: none
depends_on:
  - { id: "003", type: hard, note: "JellyfinLibraryRepository and ImageService build directly on JellyfinHTTPClient and its status-code mapping" }
  - { id: "004", type: hard, note: "needs SessionService's signed-in state, AppContainer, and RootScreen; replaces the interim SettingsScreen root with RootTabScreen" }
previous_slice: "004"
next_slice: "006"
parent_slice: none
covers: ["§1.5", "§1.6", "§1.7", "§1.8", "§1.9", "§1.14", "§12.5", "§12.16"]
created: 2026-09-03
---

# 005 — Browse

← [previous](004-sign-in.md) · [Master Checklist](MASTER-CHECKLIST.md) · [next](006-video-avplayer-and-hls.md) →

> **Status, owner and blockers live in the master checklist, not here.** Dependencies live in this page's front matter and nowhere else. Each fact has one home; if you find yourself writing it twice, one of the two copies is going to be wrong in a fortnight.

## 1. Objective

Signed in, the user sees their libraries, a Continue Watching row, movie and series grids with detail screens, and an album grid with track lists, all with images loading, on both iOS and tvOS.

A request failure shows a retry affordance rather than a blank screen. This is observable on its own: Play/Resume buttons exist on the detail screens but do nothing until slice 006 and slice 009 wire them up.

## 2. Business Value & Priority

This is the build's second demonstrable checkpoint — "you can browse" — and it is the foundation every later slice launches from: no video screen and no music screen exists without a library, a grid and a detail screen to reach it from.

It also proves the whole read path — repository, DTO, mapper, service, screen — for every content type in scope except the queue-invariant-heavy music player, which slice 009 covers on its own terms. Priority P0. No ladder: this is the browse read path built once, not a first rung of a bigger one.

## 3. Scope

**In scope:**

- `JellyfinLibraryRepository` (`MixtapeData`) implementing `LibraryRepositoryProtocol` against the corrected §8 calls: `GET /UserViews`, `GET /Items` (library items, filtered by `includeItemTypes`), `GET /Items/{itemId}` (detail, `fields=` kept per decision 26), `GET /Shows/{seriesId}/Seasons`, `GET /Shows/{seriesId}/Episodes` with `sortBy=ParentIndexNumber,IndexNumber` (decision 27), `GET /Items` for album tracks, and `GET /UserItems/Resume` for Continue Watching (decision 6, not `/Items/Resume`). `userId` sent on every call.
- DTOs beside the repository, mapped in `*Mapper.swift` files: `primaryImageTag` from `ImageTags["Primary"]`, `backdropImageTag` from `BackdropImageTags.first`, track album art from `AlbumId` + `AlbumPrimaryImageTag` (decision 25), `isWatched` set from `UserData.Played` verbatim (decision 8), resume position from `PlaybackPositionTicks`.
- `JellyfinImageURLBuilder` implementing `ImageURLBuilderProtocol`: `maxHeight` query key (not `fillHeight`), returns `nil` when the relevant tag is `nil`, no auth header on image requests (decision 25).
- Use cases in `MixtapeUseCase`: `FetchLibrariesUseCase` (filters `.unsupported`), `FetchLibraryItemsUseCase`, `FetchItemDetailUseCase`, `FetchSeasonsUseCase`, `FetchEpisodesUseCase`, `FetchAlbumTracksUseCase`, `FetchContinueWatchingUseCase`.
- `LibraryService` (`MixtapeServices`): `libraries`, `continueWatching`, per-library `LoadState<Page<MediaItem>>` cache; `loadHome()` loads Continue Watching only (decision 13, no Recently Added); `loadLibrary(id:)`, `loadMore(libraryID:)` paging at `limit = 60` with a short-page stop; `refresh()`.
- `SeriesService.episodes(seriesID:seasonID:)` taking both ids (decision 30), with a per-series cache cleared on `refresh()`.
- `ImageService`: `NSCache` capped at 120 MB, `@concurrent` decode function.
- Screens (`MixtapePresentation`): `RootTabScreen` (iOS: Home, Libraries, Music, Settings tabs; mini-player slot reserved, filled in slice 009), `HomeScreen` (Continue Watching row only), `LibraryListScreen`, `MovieLibraryGrid`, `SeriesLibraryGrid` (mirrors `MovieLibraryGrid` — same generic `/Items` call, same layout rules, decision 26), `MovieDetailScreen` (Play/Resume buttons present, wired in slice 006), `SeriesDetailScreen`, `EpisodeRow`, `AlbumGrid` (plain grid, shared across platforms this slice — the iOS wallet replacement lands in slice 010), `AlbumDetailScreen` (track list, Play wired in slice 009), `SettingsScreen` moved out of the composition root and into the Settings tab.
- Platform split per the engineering doc: `RootTabScreen` and `MovieLibraryGrid`/`SeriesLibraryGrid` each get an iOS file and a tvOS counterpart file, named for what they are, so the tvOS scheme keeps compiling. The tvOS counterparts this slice are minimal (a plain focus-driven list or grid) — the shelf-based tvOS chrome from engineering doc §9's tvOS table lands in slice 011.
- Accessibility identifier enums, one file per screen (decision 17).
- Liquid Glass navigation chrome with a Reduce Transparency fallback through one shared modifier.

**Out of scope** (name the slice it's deferred to):

- Video playback. `MovieDetailScreen`'s Play/Resume buttons render but do not invoke a player — slice 006.
- Track playback. `AlbumDetailScreen`'s Play button renders but does not start audio — slice 009.
- The iOS wallet. `AlbumGrid` is a plain shared grid this slice; its iOS replacement, and `AlbumGrid` becoming tvOS-only, are slice 010.
- Full tvOS presentation — the shelf chrome, five-tab tvOS `RootTabScreen`, full-bleed `MovieDetailScreen` backdrop — is slice 011. This slice only keeps the tvOS scheme building.
- Recently Added on Home — permanently out of scope per decision 13, not deferred.
- Series → season → episode ordering as a demonstrated acceptance criterion (AC11). The code and its `sortBy` fix ship this slice; the server holds 0 Series and 0 Episodes, so AC11 stays unverifiable per decision 14 and is not claimed here.

**Plan requirements covered:**

- `§1.5` — list the user's libraries: `FetchLibrariesUseCase` + `LibraryService.libraries` + `LibraryListScreen`.
- `§1.6` — browse a movie library and its detail screen: `MovieLibraryGrid` + `MovieDetailScreen`.
- `§1.7` — browse a TV library → series → seasons → episodes: `SeriesDetailScreen`, `EpisodeRow`, `SeriesService`. Code and tests only — AC11 is not claimed (decision 14).
- `§1.8` — browse a music library → albums → tracks: `AlbumGrid` + `AlbumDetailScreen`.
- `§1.9` — Continue Watching row on Home: `FetchContinueWatchingUseCase` + `HomeScreen`.
- `§1.14` — remote images with an in-memory cache: `ImageService` + `JellyfinImageURLBuilder`.
- `§12.5` — Home shows Continue Watching with correct progress bars: demonstrated with a resume point seeded via Jellyfin Web on the 48.4 s F1 mkv.
- `§12.16` — server unreachable mid-browse shows a retry affordance, not a blank screen: unit-tested `.failed` state plus a manual check with the server stopped.

## 4. Pre-Flight Validation

Complete **before the first line of code**, not at close.

**`003` — HTTP client, keychain, logger:**

- [x] Opened it. Its decision log still says what this slice assumed: `JellyfinHTTPClient` maps status codes per decisions 9 and 10, decodes PascalCase via explicit `CodingKeys`, and assembles the `Authorization: MediaBrowser …` header with `Device` resolved per platform.
- [x] Not a spike — n/a.
- [x] Its state matches what this slice assumed when drafted: `JellyfinHTTPClient`, `AuthContext` and `AppLogger` exist and are proven against a stubbed `URLProtocol`; nothing about the client's shape has changed since this slice was drafted.
- [x] Architecture standards doc re-read; nothing changed underneath this slice.

**`004` — Sign in:**

- [x] Opened it. Its decision log still says what this slice assumed: the `.signedIn` root is `SettingsScreen` only as an interim state, explicitly until this slice delivers `RootTabScreen`.
- [x] Not a spike — n/a.
- [x] Its state matches what this slice assumed when drafted: a signed-in `UserSession` is reachable from `SessionService.state`, `AppContainer` builds the object graph, and `@Entry` environment wiring exists for one service per key per engineering doc §10.
- [x] Architecture standards doc re-read; nothing changed underneath this slice.

**Drift found:** none blocking. Two things 004 shipped that this slice builds on rather than what it planned: `SessionService.handleSessionExpiry()` is a public method (not a protocol) and is the one call every browse service makes on `.sessionExpired`; and preview state comes from `Mock*Service` enums of static factories returning real service instances over `Mock*` repositories in `MixtapeUseCase/Mocks/`, so this slice follows that shape for `LibraryService`, `SeriesService` and `ImageService`.

## 5. Acceptance Criteria

- [x] `xcodebuild build` passes for the `iOS` and `tvOS` schemes.
- [x] `xcodebuild test` with `-skip-testing:iOSUITests` / `-skip-testing:tvOSUITests` passes for both schemes. Gate 2 expected executed-test count per scheme: **104** — 15 Domain, 34 Data (11 client + 8 auth repository + 12 library repository + 3 image URL builder), 23 UseCase (15 auth + 8 library), 32 Services (13 session + 13 library + 3 series + 3 image); parameterised tests count once. Verified 2026-09-03 via `./scripts/gate.sh 104`.
- [x] `./scripts/check-layer-imports.sh` exits 0.
- [x] `swiftformat --lint .` is clean.
- [x] `.repository` suite in `MixtapeDataTests` passes against fixtures in `Tests/MixtapeDataTests/Fixtures/` captured from the dev server through `jf-probe` (`user-views`, `items-movies`, `items-albums`, `items-tracks`, `item-detail-movie`, `user-items-resume`); `shows-seasons.hand-authored.json` and `shows-episodes.hand-authored.json` are written from the OpenAPI schema and say so in both the filename and a `_source` key.
- [x] `.service` suite for `LibraryService` covers paging at 60, `startIndex` advancing by the returned count, the short-page stop, the full-page-equals-total stop, the in-flight no-op, the already-loaded no-op, failure → `.failed` with retry, session expiry routed to `SessionService`, and `refresh()`.
- [x] tvOS scheme builds with the shared screens compiling unmodified; the platform-split files are `RootTabScreen+iOS/tvOS.swift` and `PosterGrid+iOS/tvOS.swift`.
- [x] AC5: resume point seeded on the 48.4 s F1 mkv (30 s, `PlaybackPositionTicks = 300000000`) through `jf-probe POST /UserItems/{id}/UserData`; signed in on the iPhone 17 Pro simulator through `idb`, Home's Continue Watching row shows F1 with a progress bar reading 62 % (`home.card.<id>` `AXValue: 62%`), matching 30 / 48.4. **Manual, recorded 2026-09-03.**
- [x] AC16: unit-tested `.failed` state (`LibraryServiceTests`, `SeriesServiceTests`); then the Jellyfin container was stopped (`docker stop jellyfin`), the app relaunched, and Home showed the retry affordance (`retry.messageLabel` "Couldn't reach the server…", `retry.retryButton`) rather than a blank screen; the container was started again and Retry loaded Home. Note: the first Retry immediately after the container came back failed with `.transport("The network connection was lost.")` — the server answered `/System/Info/Public` before it served library calls — and the second Retry succeeded. **Manual, recorded 2026-09-03; no automated test touched the server.**

## 6. Decision Log

**Write the row before you implement the decision, not after.** This is the whole mechanism. A decision log filled in at close is reconstructed from memory, and the rejected alternatives — the part the next slice's pre-flight actually needs — are exactly what memory loses first.

| Date | Decision | Alternatives rejected | Why |
|---|---|---|---|
| 2026-09-03 | Continue Watching calls `GET /UserItems/Resume` | `GET /Items/Resume` (engineering doc §8) | `/Items/Resume` is swallowed by the templated `/Items/{itemId}` route and returns 400; `/UserItems/Resume` returns 200 — SPEC-DECISIONS 6 |
| 2026-09-03 | `HomeScreen` shows Continue Watching only | Recently Added per library (engineering doc §9) | §1's capability list never names Recently Added and states anything unlisted is out of scope; every supporting detail for it — method, cache shape, refresh trigger — is undefined — SPEC-DECISIONS 13 |
| 2026-09-03 | `PlaybackState.isWatched` set from `UserData.Played` verbatim on mapping | computing `position / duration >= 0.9` at mapping time | `PlayedPercentage` never arrives (0 of 46 items) and the mapper has no duration to divide by at that moment; the 0.9 rule applies only during active local playback — SPEC-DECISIONS 8 |
| 2026-09-03 | Episodes call sorts explicitly with `sortBy=ParentIndexNumber,IndexNumber` | no `sortBy` (engineering doc §8) | AC11 requires episodes "ordered correctly"; a legal sort key existing in the schema is not the same as the call using one — SPEC-DECISIONS 27 |
| 2026-09-03 | `SeriesService.episodes(seriesID:seasonID:)` takes both ids | `episodes(seasonID:)` (engineering doc §6) | a bare `seasonID` cannot reach the endpoint, and `SeriesService` has no state to recover `seriesID` from — SPEC-DECISIONS 30 |
| 2026-09-03 | Image mapping fixed against the server: `primaryImageTag` from `ImageTags["Primary"]`, `backdropImageTag` from `BackdropImageTags.first`, track art falls back to `AlbumId` + `AlbumPrimaryImageTag`, image requests carry no auth header | scalar `PrimaryImageTag`; sending the auth header on image requests anyway "for consistency" (engineering doc §8) | probed against the server: the scalar field is `null`, `BackdropImageTags` is an array (empty here, which is normal), a track's own `ImageTags` is empty so the album fallback is mandatory, and an unauthenticated image request returns 200 — SPEC-DECISIONS 25 |
| 2026-09-03 | `SeriesLibraryGrid` mirrors `MovieLibraryGrid` exactly — same generic `/Items` call, same layout rules | a bespoke column spec for the series grid | no distinct column spec exists for it in the engineering doc, and none is warranted since the endpoint and layout are identical — SPEC-DECISIONS 26 |
| 2026-09-03 | `RootTabScreen` replaces `SettingsScreen` as the `.signedIn` root; `SettingsScreen` moves into the Settings tab | leaving `SettingsScreen` as the permanent root | slice 004 pre-recorded `SettingsScreen`-as-root as an interim state precisely so AC14 was demonstrable before this slice existed; this slice discharges that interim state as planned, not as a new fork |
| 2026-09-03 | AC11 (series → season → episode ordering) is not claimed by this slice, though the code and its sort fix ship here | claiming AC11 against hand-authored fixtures alone | the server holds 0 Series and 0 Episodes; proving the sort key is used is not the same as proving the demonstrated behaviour, and decision 14 forbids any slice from claiming an unverifiable criterion — SPEC-DECISIONS 14 |
| 2026-09-03 | `scripts/jf-probe.swift` gains an optional trailing JSON body argument (`./scripts/jf-probe.swift POST /UserItems/{id}/UserData?userId=… '{"PlaybackPositionTicks":300000000}'`), and AC5's resume point is seeded that way rather than through Jellyfin Web | Seeding by hand in Jellyfin Web; a second script | Decision 47 makes the probe the one server tool and 004 already gave it a method argument; nobody is at a browser during an unattended run. `POST /UserItems/{itemId}/UserData` writes the position directly and the 48.4 s F1 mkv then appears in `/UserItems/Resume` — noted for 008, whose AC9 creates the position through the stopped report instead and may meet the server's minimum-resume-duration rule on the same short file |
| 2026-09-03 | `MediaItem` gains `albumID: String?` (Domain) | Threading the album id through the views; a separate track type | Decision 25 makes `AlbumId` + `AlbumPrimaryImageTag` the mandatory source of track art, and `ImageService.image(for: MediaItem…)` takes only the item, so the item has to carry the album id. One optional field beside `parentPrimaryImageTag`, which already exists for the same reason |
| 2026-09-03 | `Library` and `MediaItem` gain `Hashable`; `LoadState` and `Page` gain conditional `Equatable` | Wrapper identifier types for navigation; comparing `LoadState` by hand in tests | `NavigationLink(value:)` needs a `Hashable` value and the two grids push the domain value directly; the service tests assert whole `LoadState` values |
| 2026-09-03 | `LibraryMapper` drops an item whose `Type` is outside `MediaKind` from a list response and throws `.decoding` for a detail response | Failing the whole page on one unknown type; adding `MediaKind.other` | `/UserItems/Resume` can return `Video` (home videos) and `/Items` under a music view can return `MusicArtist`; failing the page would fire AC16's retry affordance on a healthy server, and a catch-all kind is an abstraction with no screen behind it |
| 2026-09-03 | The platform split for the poster grid happens once, in `PosterGrid+iOS.swift` (2-up compact / 4-up regular, paged) and `PosterGrid+tvOS.swift` (a plain 6-up focus grid); `MovieLibraryGrid` and `SeriesLibraryGrid` are shared files that read `LibraryService` and hand items and a destination to `PosterGrid` | Four files: an iOS and a tvOS copy of each of `MovieLibraryGrid` and `SeriesLibraryGrid` | Decision 26 says the two grids are identical apart from the destination; splitting each by platform is four near-identical files. Slice 011 replaces `PosterGrid+tvOS.swift` with the shelf chrome and leaves the two library grids alone |
| 2026-09-03 | `LibraryService.loadHome()` loads `libraries` as well as Continue Watching; `loadLibrary(id:)` resolves the library's kind from the loaded list and loads it first if needed | A separate `loadLibraries()` the tab screens call | The Libraries and Music tabs need the list and Home is the first screen shown; one call at the root leaves nothing for a tab to forget |
| 2026-09-03 | `LibraryService` also holds `details: [String: LoadState<MediaItem>]` (from `FetchItemDetailUseCase`) and `tracks: [String: LoadState<[MediaItem]>]` (from `FetchAlbumTracksUseCase`), cleared on `refresh()` | A third service for albums; detail screens showing only the item they were pushed with | §6 gives `SeriesService` the series hierarchy and nothing else a home for tracks and detail; both are library reads with the same session and expiry handling |
| 2026-09-03 | The Music tab shows `AlbumGrid` for the first `.music` library; further music libraries are reachable from the Libraries tab | A picker across music libraries in the Music tab | The dev server has one music library and the spec names none; the Libraries tab already lists every library |
| 2026-09-03 | `LibraryService`, `SeriesService` and `ImageService` take `SessionService` by constructor, read the `UserSession` from `.signedIn`, and call `handleSessionExpiry()` on `.sessionExpired`; a call with no signed-in session is a no-op | Passing the session into every service method from the view | 004 built `handleSessionExpiry()` for exactly this; views never see a `UserSession` |
| 2026-09-03 | `JellyfinHTTPClient` encodes request bodies with `.sortedKeys` | Relaxing 004's body assertion to a contains-check | 004's `authenticate sends username and pw` test compared the raw body and started failing under this slice's test load because `JSONEncoder` key order is not stable; sorting the keys makes every body deterministic at the one place bodies are encoded, and the one assertion is updated to the sorted order |
| 2026-09-03 | `MockMedia` in `MixtapeServices/Mocks/` re-exports the mock repository's sample data for previews | Presentation importing `MixtapeUseCase` to reach `MockLibraryRepository.sample*` | `check-layer-imports.sh` forbids that import and it would be the first time Presentation saw a repository type; one static enum keeps the previews on the right side of the edge |
| 2026-09-03 | `ImageService` imports UIKit and holds `NSCache<NSURL, UIImage>`; nothing in Services imports `MixtapeInfrastructure` this slice | Fetching images through `JellyfinHTTPClient` | Decision 25: image requests are anonymous, so `URLSession` is enough and the wider Services → Infrastructure edge (decision 36) stays unused until the player controllers need it |
| 2026-09-03 | AC5 is seeded for the user the app signs in as, whose id is read from `/Sessions` after sign-in, not for `JELLYFIN_USER_ID` | Trusting the env file's user id | `.jellyfin-dev.env` carries a `JELLYFIN_USER_ID` that belongs to a different account from the one `JELLYFIN_USERNAME` / `JELLYFIN_PASSWORD` sign in as, so a resume point seeded against the env id never reached the app's Home. Logged in the Drift Log for 006–009 |

## 7. Sub-Slices

Not split — delivered as a single slice.

## 8. Testing Strategy

- **Unit / Integration / UI:** Unit tests only — no XCUITest, no CI, per CLAUDE.md and decision 4. `.repository` tests for `JellyfinLibraryRepository` and its mappers against a stubbed `URLProtocol` and captured JSON fixtures (movies, albums, tracks, item detail, Resume); seasons and episodes fixtures are hand-authored from `docs/jellyfin-openapi.json` since the server returns 0 Series, and the fixture file says so. `.service` tests for `LibraryService` (paging at `limit = 60`, the short-page stop condition, failure → `.failed`) and for `SeriesService` where it holds cacheable behaviour worth a test.
- **Test targets required:** `MixtapeDataTests` (repository and mapper tests, fixtures under `Tests/MixtapeDataTests/Fixtures/`) and `MixtapeServicesTests` (service tests). Both targets already exist from slice 001; this slice adds tests to them, not new targets.

## 9. Keeping this document true

This slice is done when the page describes what was actually built — not when the code works. The discipline is **ordering**: the write happens *before* the thing it describes, so it sits on the critical path instead of after it, where it gets skipped.

| Before you… | Write this first |
|---|---|
| implement a decision | the Section 6 row, including what you rejected |
| start work | flip status in the master checklist |
| stop on a blocker | the Active Blockers row |
| build on a spike | that spike's Result section |
| widen scope | Section 3, and `depends_on` on any slice that's now affected |

And in the same commit as the code, not a follow-up: **commit this file alongside it**, with the slice id in the commit subject (`005: add browse screens and repositories`).

Nothing checks any of this. That's the point of putting the writes first — a write you have to do to proceed is one you do; a write you're supposed to do afterwards is one you don't.

## 10. Definition of Done

- [x] Acceptance criteria met
- [x] Tests passing, in a target that exists
- [x] Every `covers:` requirement satisfied, or forked with a decision row (§1.7 ships code and tests; AC11 is not claimed, per decision 14)
- [x] Decision log written as you went, not reconstructed
- [x] Pre-flight completed and drift resolved
- [x] Master checklist row current
- [x] `next_slice`'s `depends_on` reflects what actually shipped, not what was planned
- [x] Both link directions checked: this page's `next_slice` and that page's `previous_slice`

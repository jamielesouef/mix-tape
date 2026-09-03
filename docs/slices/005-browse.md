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

- [ ] Opened it. Its decision log still says what this slice assumed: `JellyfinHTTPClient` maps status codes per decisions 9 and 10, decodes PascalCase via explicit `CodingKeys`, and assembles the `Authorization: MediaBrowser …` header with `Device` resolved per platform.
- [ ] Not a spike — n/a.
- [ ] Its state matches what this slice assumed when drafted: `JellyfinHTTPClient`, `AuthContext` and `AppLogger` exist and are proven against a stubbed `URLProtocol`; nothing about the client's shape has changed since this slice was drafted.
- [ ] Architecture standards doc re-read; nothing changed underneath this slice.

**`004` — Sign in:**

- [ ] Opened it. Its decision log still says what this slice assumed: the `.signedIn` root is `SettingsScreen` only as an interim state, explicitly until this slice delivers `RootTabScreen`.
- [ ] Not a spike — n/a.
- [ ] Its state matches what this slice assumed when drafted: a signed-in `UserSession` is reachable from `SessionService.state`, `AppContainer` builds the object graph, and `@Entry` environment wiring exists for one service per key per engineering doc §10.
- [ ] Architecture standards doc re-read; nothing changed underneath this slice.

**Drift found:** none.

## 5. Acceptance Criteria

- [ ] `xcodebuild build` passes for the `iOS` and `tvOS` schemes.
- [ ] `xcodebuild test` with `-skip-testing:iOSUITests` / `-skip-testing:tvOSUITests` passes for both schemes.
- [ ] `./scripts/check-layer-imports.sh` exits 0.
- [ ] `swiftformat --lint .` is clean.
- [ ] `.repository` suite in `MixtapeDataTests` passes against fixtures in `Tests/MixtapeDataTests/Fixtures/` for UserViews, Items (movies, albums, tracks), item detail, and Resume; seasons and episodes fixtures are hand-authored from the OpenAPI schema (the server has 0 Series) and labelled as such in the fixture file.
- [ ] `.service` suite for `LibraryService` covers paging, the short-page stop condition, and a failure transition to `.failed`.
- [ ] tvOS scheme builds with the shared screens compiling unmodified and the iOS-only screens split into `#if os(iOS)` files with a tvOS counterpart file.
- [ ] AC5: seed a resume point via Jellyfin Web on the 48.4 s F1 mkv; Home's Continue Watching row shows it with a correct progress bar.
- [ ] AC16: point the app at an unreachable host; the unit-tested `.failed` state is confirmed, and a manual check with the local server stopped shows the retry affordance and is recorded as manual per CLAUDE.md's rule that no automated test touches the live server.

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

- [ ] Acceptance criteria met
- [ ] Tests passing, in a target that exists
- [ ] Every `covers:` requirement satisfied, or forked with a decision row
- [ ] Decision log written as you went, not reconstructed
- [ ] Pre-flight completed and drift resolved
- [ ] Master checklist row current
- [ ] `next_slice`'s `depends_on` reflects what actually shipped, not what was planned
- [ ] Both link directions checked: this page's `next_slice` and that page's `previous_slice`

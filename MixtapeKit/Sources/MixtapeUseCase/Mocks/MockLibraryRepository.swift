//  MockLibraryRepository.swift
//  MixtapeUseCase
//
//  Created by Jamie Le Souëf on 03/09/2026.
//

#if DEBUG
    import Foundation
    import MixtapeDomain

    /// Closure-driven test double for previews and use-case tests. Each closure defaults to sample
    /// data so a preview needs to override only the call it is about.
    public nonisolated struct MockLibraryRepository: LibraryRepositoryProtocol {
        public var librariesResult: @Sendable (UserSession) async throws -> [Library]
        public var itemsResult: @Sendable (String, MediaKind, PageRequest, UserSession) async throws -> Page<MediaItem>
        public var itemResult: @Sendable (String, UserSession) async throws -> MediaItem
        public var seasonsResult: @Sendable (String, UserSession) async throws -> [MediaItem]
        public var episodesResult: @Sendable (String, String, UserSession) async throws -> [MediaItem]
        public var tracksResult: @Sendable (String, UserSession) async throws -> [MediaItem]
        public var continueWatchingResult: @Sendable (UserSession) async throws -> [MediaItem]

        public init(
            librariesResult: @escaping @Sendable (UserSession) async throws -> [Library] = { _ in sampleLibraries },
            itemsResult: @escaping @Sendable (String, MediaKind, PageRequest, UserSession) async throws -> Page<MediaItem> = { _, kind, page, _ in
                let items: [MediaItem] = switch kind {
                case .movie: sampleMovies
                case .series: [sampleSeries]
                case .musicAlbum: sampleAlbums
                case .season, .episode, .audio: []
                }
                return Page(items: items, totalCount: items.count, startIndex: page.startIndex)
            },
            itemResult: @escaping @Sendable (String, UserSession) async throws -> MediaItem = { id, _ in
                (sampleMovies + sampleAlbums + [sampleSeries]).first { $0.id == id } ?? sampleMovies[0]
            },
            seasonsResult: @escaping @Sendable (String, UserSession) async throws -> [MediaItem] = { _, _ in sampleSeasons },
            episodesResult: @escaping @Sendable (String, String, UserSession) async throws -> [MediaItem] = { _, _, _ in sampleEpisodes },
            tracksResult: @escaping @Sendable (String, UserSession) async throws -> [MediaItem] = { _, _ in sampleTracks },
            continueWatchingResult: @escaping @Sendable (UserSession) async throws -> [MediaItem] = { _ in sampleContinueWatching },
        ) {
            self.librariesResult = librariesResult
            self.itemsResult = itemsResult
            self.itemResult = itemResult
            self.seasonsResult = seasonsResult
            self.episodesResult = episodesResult
            self.tracksResult = tracksResult
            self.continueWatchingResult = continueWatchingResult
        }

        public func libraries(session: UserSession) async throws -> [Library] {
            try await librariesResult(session)
        }

        public func items(in libraryID: String, kind: MediaKind, page: PageRequest, session: UserSession) async throws -> Page<MediaItem> {
            try await itemsResult(libraryID, kind, page, session)
        }

        public func item(id: String, session: UserSession) async throws -> MediaItem {
            try await itemResult(id, session)
        }

        public func seasons(seriesID: String, session: UserSession) async throws -> [MediaItem] {
            try await seasonsResult(seriesID, session)
        }

        public func episodes(seriesID: String, seasonID: String, session: UserSession) async throws -> [MediaItem] {
            try await episodesResult(seriesID, seasonID, session)
        }

        public func tracks(albumID: String, session: UserSession) async throws -> [MediaItem] {
            try await tracksResult(albumID, session)
        }

        public func continueWatching(session: UserSession) async throws -> [MediaItem] {
            try await continueWatchingResult(session)
        }

        // MARK: - Sample data

        public static let sampleLibraries = [
            Library(id: "lib-movies", name: "Movies", kind: .movies, imageTag: "t-movies"),
            Library(id: "lib-shows", name: "Shows", kind: .tvShows, imageTag: "t-shows"),
            Library(id: "lib-music", name: "Music", kind: .music, imageTag: "t-music"),
            Library(id: "lib-books", name: "Books", kind: .unsupported, imageTag: nil),
        ]

        public static let sampleMovies = [
            item(id: "movie-1", name: "Avatar: Fire and Ash", kind: .movie, year: 2025, runtime: .seconds(21), overview: "Water, then fire.", primary: "p1", backdrop: "b1"),
            item(id: "movie-2", name: "F1", kind: .movie, year: 2025, runtime: .seconds(48), overview: "Fast cars.", primary: "p2", backdrop: "b2", position: .seconds(30)),
        ]

        public static let sampleSeries = item(id: "series-1", name: "The Show", kind: .series, year: 2020, overview: "Episodes happen.", primary: "p3", backdrop: "b3")

        public static let sampleSeasons = [
            item(id: "season-1", name: "Season 1", kind: .season, indexNumber: 1, seriesName: "The Show", primary: "s1"),
            item(id: "season-2", name: "Season 2", kind: .season, indexNumber: 2, seriesName: "The Show", primary: "s2"),
        ]

        public static let sampleEpisodes = [
            item(id: "episode-1", name: "Pilot", kind: .episode, runtime: .seconds(1500), overview: "It begins.", indexNumber: 1, parentIndexNumber: 1, seriesName: "The Show", primary: "e1"),
            item(id: "episode-2", name: "Second", kind: .episode, runtime: .seconds(1500), indexNumber: 2, parentIndexNumber: 1, seriesName: "The Show", primary: "e2", position: .seconds(600)),
        ]

        public static let sampleAlbums = [
            item(id: "album-1", name: "Even In Arcadia", kind: .musicAlbum, year: 2025, albumArtist: "Sleep Token", primary: "a1"),
            item(id: "album-2", name: "Sundowning", kind: .musicAlbum, year: 2019, albumArtist: "Sleep Token", primary: "a2"),
            item(id: "album-3", name: "This Place Will Become Your Tomb", kind: .musicAlbum, year: 2021, albumArtist: "Sleep Token", primary: "a3"),
            item(id: "album-4", name: "Take Me Back To Eden", kind: .musicAlbum, year: 2023, albumArtist: "Sleep Token", primary: "a4"),
            item(id: "album-5", name: "King Of Terrors", kind: .musicAlbum, year: 2025, albumArtist: "President", primary: "a5"),
        ]

        public static let sampleTracks = [
            item(id: "track-1", name: "Look To Windward", kind: .audio, runtime: .seconds(380), indexNumber: 1, parentIndexNumber: 1, albumArtist: "Sleep Token", parentPrimary: "a1", albumID: "album-1"),
            item(id: "track-2", name: "Emergence", kind: .audio, runtime: .seconds(305), indexNumber: 2, parentIndexNumber: 1, albumArtist: "Sleep Token", parentPrimary: "a1", albumID: "album-1"),
        ]

        public static let sampleContinueWatching = [sampleMovies[1], sampleEpisodes[1]]

        private static func item(
            id: String, name: String, kind: MediaKind, year: Int? = nil, runtime: Duration? = nil, overview: String? = nil,
            indexNumber: Int? = nil, parentIndexNumber: Int? = nil, seriesName: String? = nil, albumArtist: String? = nil,
            primary: String? = nil, backdrop: String? = nil, parentPrimary: String? = nil, albumID: String? = nil, position: Duration = .zero,
        ) -> MediaItem {
            MediaItem(
                id: id, name: name, kind: kind, overview: overview, productionYear: year, runtime: runtime,
                indexNumber: indexNumber, parentIndexNumber: parentIndexNumber, seriesName: seriesName, albumArtist: albumArtist,
                primaryImageTag: primary, backdropImageTag: backdrop, parentPrimaryImageTag: parentPrimary, albumID: albumID,
                playback: PlaybackState(position: position, isWatched: false),
            )
        }
    }
#endif

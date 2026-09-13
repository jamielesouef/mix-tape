//  MockLibraryRepository.swift
//  mixtape
//
//  Created by Jamie Le Souëf on 03/09/2026.
//

#if DEBUG
    import Foundation

    nonisolated struct MockLibraryRepository: LibraryRepositoryProtocol {
        var librariesResult: @Sendable (UserSession) async throws -> [Library]
        var itemsResult: @Sendable (String, MediaKind, PageRequest, UserSession) async throws -> Page<MediaItem>
        var itemResult: @Sendable (String, UserSession) async throws -> MediaItem
        var tracksResult: @Sendable (String, UserSession) async throws -> [MediaItem]

        init(
            librariesResult: @escaping @Sendable (UserSession) async throws -> [Library] = { _ in sampleLibraries },
            itemsResult: @escaping @Sendable (String, MediaKind, PageRequest, UserSession) async throws -> Page<MediaItem> = { _, kind, page, _ in
                let items: [MediaItem] = switch kind {
                case .musicAlbum: sampleAlbums
                case .audio: []
                }
                return Page(items: items, totalCount: items.count, startIndex: page.startIndex)
            },
            itemResult: @escaping @Sendable (String, UserSession) async throws -> MediaItem = { id, _ in
                sampleAlbums.first { $0.id == id } ?? sampleAlbums[0]
            },
            tracksResult: @escaping @Sendable (String, UserSession) async throws -> [MediaItem] = { _, _ in sampleTracks },
        ) {
            self.librariesResult = librariesResult
            self.itemsResult = itemsResult
            self.itemResult = itemResult
            self.tracksResult = tracksResult
        }

        func libraries(session: UserSession) async throws -> [Library] {
            try await librariesResult(session)
        }

        func items(in libraryID: String, kind: MediaKind, page: PageRequest, session: UserSession) async throws -> Page<MediaItem> {
            try await itemsResult(libraryID, kind, page, session)
        }

        func item(id: String, session: UserSession) async throws -> MediaItem {
            try await itemResult(id, session)
        }

        func tracks(albumID: String, session: UserSession) async throws -> [MediaItem] {
            try await tracksResult(albumID, session)
        }

        // MARK: - Sample data

        static let sampleLibraries = [
            Library(id: "lib-music", name: "Music", kind: .music, imageTag: "t-music"),
            Library(id: "lib-books", name: "Books", kind: .unsupported, imageTag: nil),
        ]

        static let sampleAlbums = [
            item(id: "album-1", name: "Even In Arcadia", kind: .musicAlbum, year: 2025, albumArtist: "Sleep Token", primary: "a1"),
            item(id: "album-2", name: "Sundowning", kind: .musicAlbum, year: 2019, albumArtist: "Sleep Token", primary: "a2"),
            item(id: "album-3", name: "This Place Will Become Your Tomb", kind: .musicAlbum, year: 2021, albumArtist: "Sleep Token", primary: "a3"),
            item(id: "album-4", name: "Take Me Back To Eden", kind: .musicAlbum, year: 2023, albumArtist: "Sleep Token", primary: "a4"),
            item(id: "album-5", name: "King Of Terrors", kind: .musicAlbum, year: 2025, albumArtist: "President", primary: "a5"),
        ]

        static let sampleTracks = [
            item(
                id: "track-1", name: "Look To Windward", kind: .audio, runtime: .seconds(380), indexNumber: 1,
                parentIndexNumber: 1, albumArtist: "Sleep Token", parentPrimary: "a1", albumID: "album-1",
            ),
            item(
                id: "track-2", name: "Emergence", kind: .audio, runtime: .seconds(305), indexNumber: 2,
                parentIndexNumber: 1, albumArtist: "Sleep Token", parentPrimary: "a1", albumID: "album-1",
            ),
        ]

        private static func item(
            id: String, name: String, kind: MediaKind, year: Int? = nil, runtime: Duration? = nil, overview: String? = nil,
            indexNumber: Int? = nil, parentIndexNumber: Int? = nil, albumArtist: String? = nil,
            primary: String? = nil, backdrop: String? = nil, parentPrimary: String? = nil, albumID: String? = nil, position: Duration = .zero,
        ) -> MediaItem {
            MediaItem(
                id: id, name: name, kind: kind, overview: overview, productionYear: year, runtime: runtime,
                indexNumber: indexNumber, parentIndexNumber: parentIndexNumber, albumArtist: albumArtist,
                primaryImageTag: primary, backdropImageTag: backdrop, parentPrimaryImageTag: parentPrimary, albumID: albumID,
                playback: PlaybackState(position: position),
            )
        }
    }
#endif

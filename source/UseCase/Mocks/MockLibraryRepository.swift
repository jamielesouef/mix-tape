//  MockLibraryRepository.swift
//  mixtape
//
//  Created by Jamie Le Souëf on 03/09/2026.
//

#if DEBUG

    struct MockLibraryRepository: LibraryRepositoryProtocol {
        // MARK: - Properties

        var librariesResult: @Sendable (UserSession) async throws -> [Library]
        var itemsResult: @Sendable (String, MediaKind, PageRequest, UserSession) async throws
            -> Page<MediaItem>
        var itemResult: @Sendable (String, UserSession) async throws -> MediaItem
        var tracksResult: @Sendable (String, UserSession) async throws -> [MediaItem]

        // MARK: - Initialization

        init(
            librariesResult: @escaping @Sendable (UserSession) async throws -> [Library] = { _ in
                sampleLibraries
            },
            itemsResult: @escaping @Sendable (
                String,
                MediaKind,
                PageRequest,
                UserSession
            ) async throws
                -> Page<MediaItem> = { _, kind, page, _ in
                    let items: [MediaItem] =
                        switch kind {
                        case .musicAlbum: sampleAlbums
                        case .audio: []
                        }
                    return Page(items: items, totalCount: items.count, startIndex: page.startIndex)
                },
            itemResult: @escaping @Sendable (String, UserSession) async throws
                -> MediaItem = { id, _ in
                    sampleAlbums.first { $0.id == id } ?? sampleAlbums[0]
                },
            tracksResult: @escaping @Sendable (String, UserSession) async throws
                -> [MediaItem] = { _, _ in
                    sampleTracks
                }
        ) {
            self.librariesResult = librariesResult
            self.itemsResult = itemsResult
            self.itemResult = itemResult
            self.tracksResult = tracksResult
        }

        // MARK: - LibraryRepositoryProtocol

        func libraries(session: UserSession) async throws -> [Library] {
            try await librariesResult(session)
        }

        func items(
            in libraryID: String,
            kind: MediaKind,
            page: PageRequest,
            session: UserSession
        ) async throws -> Page<MediaItem> {
            try await itemsResult(libraryID, kind, page, session)
        }

        func item(id: String, session: UserSession) async throws -> MediaItem {
            try await itemResult(id, session)
        }

        func tracks(albumID: String, session: UserSession) async throws -> [MediaItem] {
            try await tracksResult(albumID, session)
        }

        // MARK: - Sample data

        static let sampleLibraries = MockLibrarySamples.libraries
        static let sampleAlbums = MockLibrarySamples.albums
        static let sampleTracks = MockLibrarySamples.tracks
    }
#endif

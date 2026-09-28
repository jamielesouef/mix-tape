//  MockServerLibraryRepository.swift
//  mixtape
//
//  Created by Jamie Le Souëf on 28/09/2026.
//

/// Stands in for `JellyfinLibraryRepository` behind `LibraryRepositoryProtocol`, serving
/// `MockServerDataset` instead of a real Jellyfin `/Items` response.
struct MockServerLibraryRepository: LibraryRepositoryProtocol {
    func libraries(session _: UserSession) async throws -> [Library] {
        [MockServerDataset.library]
    }

    func items(
        in libraryID: String,
        kind: MediaKind,
        page: PageRequest,
        session _: UserSession
    ) async throws -> Page<MediaItem> {
        guard libraryID == MockServerDataset.libraryID else {
            return Page(items: [], totalCount: 0, startIndex: page.startIndex)
        }

        let all = kind == .musicAlbum ? MockServerDataset.albums : MockServerDataset.allTracks
        let slice = Self.slice(all, page: page)

        return Page(items: slice, totalCount: all.count, startIndex: page.startIndex)
    }

    func item(id: String, session _: UserSession) async throws -> MediaItem {
        if let album = MockServerDataset.album(id: id) {
            return album
        }

        guard let track = MockServerDataset.allTracks.first(where: { $0.id == id }) else {
            throw MixtapeError.transport("Unknown mock item \(id)")
        }

        return track
    }

    func tracks(albumID: String, session _: UserSession) async throws -> [MediaItem] {
        MockServerDataset.tracks(albumID: albumID)
    }

    // MARK: - Private

    private static func slice(_ items: [MediaItem], page: PageRequest) -> [MediaItem] {
        guard page.startIndex < items.count else {
            return []
        }

        let end = min(items.count, page.startIndex + page.limit)

        return Array(items[page.startIndex ..< end])
    }
}

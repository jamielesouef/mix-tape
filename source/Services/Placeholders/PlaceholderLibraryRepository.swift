//  PlaceholderLibraryRepository.swift
//  mixtape
//
//  Created by Jamie Le Souëf on 04/09/2026.
//

nonisolated struct PlaceholderLibraryRepository: LibraryRepositoryProtocol {
    func libraries(session _: UserSession) async throws -> [Library] {
        throw MixtapeError.serverUnreachable
    }

    func items(in _: String, kind _: MediaKind, page _: PageRequest, session _: UserSession) async throws -> Page<MediaItem> {
        throw MixtapeError.serverUnreachable
    }

    func item(id _: String, session _: UserSession) async throws -> MediaItem {
        throw MixtapeError.serverUnreachable
    }

    func tracks(albumID _: String, session _: UserSession) async throws -> [MediaItem] {
        throw MixtapeError.serverUnreachable
    }
}

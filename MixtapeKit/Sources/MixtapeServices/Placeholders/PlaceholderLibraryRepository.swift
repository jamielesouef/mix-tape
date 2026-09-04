//  PlaceholderLibraryRepository.swift
//  MixtapeServices
//
//  Created by Jamie Le Souëf on 04/09/2026.
//

import MixtapeDomain
import MixtapeUseCase

/// The release-build collaborator behind `LibraryService.placeholder` and
/// `SeriesService.placeholder` (slice 013). Every call fails as unreachable.
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

    func seasons(seriesID _: String, session _: UserSession) async throws -> [MediaItem] {
        throw MixtapeError.serverUnreachable
    }

    func episodes(seriesID _: String, seasonID _: String, session _: UserSession) async throws -> [MediaItem] {
        throw MixtapeError.serverUnreachable
    }

    func tracks(albumID _: String, session _: UserSession) async throws -> [MediaItem] {
        throw MixtapeError.serverUnreachable
    }

    func continueWatching(session _: UserSession) async throws -> [MediaItem] {
        throw MixtapeError.serverUnreachable
    }
}

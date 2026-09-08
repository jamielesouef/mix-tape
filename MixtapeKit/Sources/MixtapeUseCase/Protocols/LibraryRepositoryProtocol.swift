//  LibraryRepositoryProtocol.swift
//  MixtapeUseCase
//
//  Created by Jamie Le Souëf on 03/09/2026.
//

import MixtapeDomain

/// Engineering doc §5, corrected by decisions 6, 27 and 30.
public nonisolated protocol LibraryRepositoryProtocol: Sendable {
    func libraries(session: UserSession) async throws -> [Library]
    func items(in libraryID: String, kind: MediaKind, page: PageRequest, session: UserSession) async throws -> Page<MediaItem>
    func item(id: String, session: UserSession) async throws -> MediaItem
    func seasons(seriesID: String, session: UserSession) async throws -> [MediaItem]
    func episodes(seriesID: String, seasonID: String, session: UserSession) async throws -> [MediaItem]
    func tracks(albumID: String, session: UserSession) async throws -> [MediaItem]
    func continueWatching(session: UserSession) async throws -> [MediaItem]
}

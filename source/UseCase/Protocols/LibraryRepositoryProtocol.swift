//  LibraryRepositoryProtocol.swift
//  mixtape
//
//  Created by Jamie Le Souëf on 03/09/2026.
//

nonisolated protocol LibraryRepositoryProtocol: Sendable {
    func libraries(session: UserSession) async throws -> [Library]
    func items(in libraryID: String, kind: MediaKind, page: PageRequest, session: UserSession) async throws -> Page<MediaItem>
    func item(id: String, session: UserSession) async throws -> MediaItem
    func tracks(albumID: String, session: UserSession) async throws -> [MediaItem]
}

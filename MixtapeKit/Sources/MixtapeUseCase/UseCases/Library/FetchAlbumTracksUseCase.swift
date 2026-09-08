//  FetchAlbumTracksUseCase.swift
//  MixtapeUseCase
//
//  Created by Jamie Le Souëf on 03/09/2026.
//

import MixtapeDomain

/// The whole album, unpaged (decision 26): §1.1 needs every track, never a page.
public nonisolated struct FetchAlbumTracksUseCase: Sendable {
    private let repository: any LibraryRepositoryProtocol

    public init(repository: any LibraryRepositoryProtocol) {
        self.repository = repository
    }

    public func callAsFunction(albumID: String, session: UserSession) async throws -> [MediaItem] {
        try await repository.tracks(albumID: albumID, session: session)
    }
}

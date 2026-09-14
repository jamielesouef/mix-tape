//  FetchAlbumTracksUseCase.swift
//  mixtape
//
//  Created by Jamie Le Souëf on 03/09/2026.
//

nonisolated struct FetchAlbumTracksUseCase: Sendable {
    private let repository: any LibraryRepositoryProtocol

    init(repository: any LibraryRepositoryProtocol) {
        self.repository = repository
    }

    func callAsFunction(albumID: String, session: UserSession) async throws -> [MediaItem] {
        try await repository.tracks(albumID: albumID, session: session)
    }
}

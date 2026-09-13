//  FetchAlbumTracksUseCase.swift
//  mixtape
//
//  Created by Jamie Le Souëf on 03/09/2026.
//

public nonisolated struct FetchAlbumTracksUseCase: Sendable {
    private let repository: any LibraryRepositoryProtocol

    public init(repository: any LibraryRepositoryProtocol) {
        self.repository = repository
    }

    public func callAsFunction(albumID: String, session: UserSession) async throws -> [MediaItem] {
        try await repository.tracks(albumID: albumID, session: session)
    }
}

//  FetchEpisodesUseCase.swift
//  MixtapeUseCase
//
//  Created by Jamie Le Souëf on 03/09/2026.
//

import MixtapeDomain

/// Takes both ids: the endpoint needs the series and a bare season id cannot reach it (decision 30).
public nonisolated struct FetchEpisodesUseCase: Sendable {
    private let repository: any LibraryRepositoryProtocol

    public init(repository: any LibraryRepositoryProtocol) {
        self.repository = repository
    }

    public func callAsFunction(seriesID: String, seasonID: String, session: UserSession) async throws -> [MediaItem] {
        try await repository.episodes(seriesID: seriesID, seasonID: seasonID, session: session)
    }
}

//  FetchSeasonsUseCase.swift
//  MixtapeUseCase
//
//  Created by Jamie Le Souëf on 03/09/2026.
//

import MixtapeDomain

public nonisolated struct FetchSeasonsUseCase: Sendable {
    private let repository: any LibraryRepositoryProtocol

    public init(repository: any LibraryRepositoryProtocol) {
        self.repository = repository
    }

    public func callAsFunction(seriesID: String, session: UserSession) async throws -> [MediaItem] {
        try await repository.seasons(seriesID: seriesID, session: session)
    }
}

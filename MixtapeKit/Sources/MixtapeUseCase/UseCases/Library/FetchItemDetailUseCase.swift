//  FetchItemDetailUseCase.swift
//  MixtapeUseCase
//
//  Created by Jamie Le Souëf on 03/09/2026.
//

import MixtapeDomain

public nonisolated struct FetchItemDetailUseCase: Sendable {
    private let repository: any LibraryRepositoryProtocol

    public init(repository: any LibraryRepositoryProtocol) {
        self.repository = repository
    }

    public func callAsFunction(id: String, session: UserSession) async throws -> MediaItem {
        try await repository.item(id: id, session: session)
    }
}

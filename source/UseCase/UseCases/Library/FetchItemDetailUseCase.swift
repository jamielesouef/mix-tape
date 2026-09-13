//  FetchItemDetailUseCase.swift
//  mixtape
//
//  Created by Jamie Le Souëf on 03/09/2026.
//

nonisolated struct FetchItemDetailUseCase: Sendable {
    private let repository: any LibraryRepositoryProtocol

    init(repository: any LibraryRepositoryProtocol) {
        self.repository = repository
    }

    func callAsFunction(id: String, session: UserSession) async throws -> MediaItem {
        try await repository.item(id: id, session: session)
    }
}

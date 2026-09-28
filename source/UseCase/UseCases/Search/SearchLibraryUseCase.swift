//  SearchLibraryUseCase.swift
//  mixtape
//
//  Created by Jamie Le Souëf on 28/09/2026.
//

struct SearchLibraryUseCase: Sendable {
    private let repository: any SearchRepositoryProtocol

    init(repository: any SearchRepositoryProtocol) {
        self.repository = repository
    }

    func callAsFunction(query: String, session: UserSession) async throws -> SearchResult {
        try await repository.search(query: query, session: session)
    }
}

//  FetchLibrariesUseCase.swift
//  mixtape
//
//  Created by Jamie Le Souëf on 03/09/2026.
//

nonisolated struct FetchLibrariesUseCase: Sendable {
    private let repository: any LibraryRepositoryProtocol

    init(repository: any LibraryRepositoryProtocol) {
        self.repository = repository
    }

    func callAsFunction(session: UserSession) async throws -> [Library] {
        try await repository.libraries(session: session).filter { $0.kind != .unsupported }
    }
}

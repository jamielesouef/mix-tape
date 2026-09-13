//  FetchLibrariesUseCase.swift
//  MixtapeUseCase
//
//  Created by Jamie Le Souëf on 03/09/2026.
//

import MixtapeDomain

public nonisolated struct FetchLibrariesUseCase: Sendable {
    private let repository: any LibraryRepositoryProtocol

    public init(repository: any LibraryRepositoryProtocol) {
        self.repository = repository
    }

    public func callAsFunction(session: UserSession) async throws -> [Library] {
        try await repository.libraries(session: session).filter { $0.kind != .unsupported }
    }
}

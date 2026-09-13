//  FetchContinueWatchingUseCase.swift
//  mixtape
//
//  Created by Jamie Le Souëf on 03/09/2026.
//

public nonisolated struct FetchContinueWatchingUseCase: Sendable {
    private let repository: any LibraryRepositoryProtocol

    public init(repository: any LibraryRepositoryProtocol) {
        self.repository = repository
    }

    public func callAsFunction(session: UserSession) async throws -> [MediaItem] {
        try await repository.continueWatching(session: session)
    }
}

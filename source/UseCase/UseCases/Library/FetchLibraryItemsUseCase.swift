//  FetchLibraryItemsUseCase.swift
//  mixtape
//
//  Created by Jamie Le Souëf on 03/09/2026.
//

nonisolated struct FetchLibraryItemsUseCase: Sendable {
    private let repository: any LibraryRepositoryProtocol

    init(repository: any LibraryRepositoryProtocol) {
        self.repository = repository
    }

    func callAsFunction(libraryID: String, kind: MediaKind, page: PageRequest, session: UserSession) async throws -> Page<MediaItem> {
        try await repository.items(in: libraryID, kind: kind, page: page, session: session)
    }
}

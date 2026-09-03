//  FetchLibraryItemsUseCase.swift
//  MixtapeUseCase
//
//  Created by Jamie Le Souëf on 03/09/2026.
//

import MixtapeDomain

/// One page of a library's items.
public nonisolated struct FetchLibraryItemsUseCase: Sendable {
    private let repository: any LibraryRepositoryProtocol

    public init(repository: any LibraryRepositoryProtocol) {
        self.repository = repository
    }

    public func callAsFunction(libraryID: String, kind: MediaKind, page: PageRequest, session: UserSession) async throws -> Page<MediaItem> {
        try await repository.items(in: libraryID, kind: kind, page: page, session: session)
    }
}

//  PollQuickConnectUseCase.swift
//  MixtapeUseCase
//
//  Created by Jamie Le Souëf on 03/09/2026.
//

import MixtapeDomain

/// One poll of `/QuickConnect/Connect`. Once the server reports the code approved it performs
/// the token exchange itself and persists the session (decision 21). `nil` means not yet approved.
public nonisolated struct PollQuickConnectUseCase: Sendable {
    private let repository: any AuthRepositoryProtocol
    private let store: any SessionStoreProtocol

    public init(repository: any AuthRepositoryProtocol, store: any SessionStoreProtocol) {
        self.repository = repository
        self.store = store
    }

    public func callAsFunction(secret: String, server: ServerIdentity) async throws -> UserSession? {
        guard try await repository.quickConnectState(secret: secret, server: server) else { return nil }
        let session = try await repository.authenticateWithQuickConnect(secret: secret, server: server)
        try store.save(session)
        return session
    }
}

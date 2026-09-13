//  SignInWithPasswordUseCase.swift
//  mixtape
//
//  Created by Jamie Le Souëf on 03/09/2026.
//

public nonisolated struct SignInWithPasswordUseCase: Sendable {
    private let repository: any AuthRepositoryProtocol
    private let store: any SessionStoreProtocol

    public init(repository: any AuthRepositoryProtocol, store: any SessionStoreProtocol) {
        self.repository = repository
        self.store = store
    }

    public func callAsFunction(userName: String, password: String, server: ServerIdentity) async throws -> UserSession {
        let session = try await repository.authenticate(userName: userName, password: password, server: server)
        try store.save(session)
        return session
    }
}

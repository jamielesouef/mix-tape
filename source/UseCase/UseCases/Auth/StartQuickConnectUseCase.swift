//  StartQuickConnectUseCase.swift
//  mixtape
//
//  Created by Jamie Le Souëf on 03/09/2026.
//

public nonisolated struct StartQuickConnectUseCase: Sendable {
    private let repository: any AuthRepositoryProtocol

    public init(repository: any AuthRepositoryProtocol) {
        self.repository = repository
    }

    public func callAsFunction(server: ServerIdentity) async throws -> QuickConnectHandshake {
        guard try await repository.isQuickConnectEnabled(server: server) else {
            throw MixtapeError.quickConnectUnavailable
        }
        return try await repository.initiateQuickConnect(server: server)
    }
}

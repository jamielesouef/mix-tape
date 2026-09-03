//  SignOutUseCase.swift
//  MixtapeUseCase
//
//  Created by Jamie Le Souëf on 03/09/2026.
//

/// Clears the persisted session. No server call.
public nonisolated struct SignOutUseCase: Sendable {
    private let store: any SessionStoreProtocol

    public init(store: any SessionStoreProtocol) {
        self.store = store
    }

    public func callAsFunction() throws {
        try store.clear()
    }
}

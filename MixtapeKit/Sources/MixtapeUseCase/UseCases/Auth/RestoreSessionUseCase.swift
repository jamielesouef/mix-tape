//  RestoreSessionUseCase.swift
//  MixtapeUseCase
//
//  Created by Jamie Le Souëf on 03/09/2026.
//

import MixtapeDomain

/// → the persisted `UserSession`, if any.
public nonisolated struct RestoreSessionUseCase: Sendable {
    private let store: any SessionStoreProtocol

    public init(store: any SessionStoreProtocol) {
        self.store = store
    }

    public func callAsFunction() throws -> UserSession? {
        try store.load()
    }
}

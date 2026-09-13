//  RestoreSessionUseCase.swift
//  mixtape
//
//  Created by Jamie Le Souëf on 03/09/2026.
//

nonisolated struct RestoreSessionUseCase: Sendable {
    private let store: any SessionStoreProtocol

    init(store: any SessionStoreProtocol) {
        self.store = store
    }

    func callAsFunction() throws -> UserSession? {
        try store.load()
    }
}

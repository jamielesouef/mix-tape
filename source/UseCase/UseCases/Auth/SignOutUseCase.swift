//  SignOutUseCase.swift
//  mixtape
//
//  Created by Jamie Le Souëf on 03/09/2026.
//

nonisolated struct SignOutUseCase: Sendable {
    private let store: any SessionStoreProtocol

    init(store: any SessionStoreProtocol) {
        self.store = store
    }

    func callAsFunction() throws {
        try store.clear()
    }
}

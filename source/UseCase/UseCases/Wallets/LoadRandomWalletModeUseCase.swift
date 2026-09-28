//  LoadRandomWalletModeUseCase.swift
//  mixtape
//
//  Created by Jamie Le Souëf on 28/09/2026.
//

struct LoadRandomWalletModeUseCase: Sendable {
    private let store: any WalletsStoreProtocol

    init(store: any WalletsStoreProtocol) {
        self.store = store
    }

    func callAsFunction() throws -> RandomWalletMode? {
        try store.randomWalletMode()
    }
}

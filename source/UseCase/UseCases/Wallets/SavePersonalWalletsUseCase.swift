//  SavePersonalWalletsUseCase.swift
//  mixtape
//
//  Created by Jamie Le Souëf on 28/09/2026.
//

struct SavePersonalWalletsUseCase: Sendable {
    private let store: any WalletsStoreProtocol

    init(store: any WalletsStoreProtocol) {
        self.store = store
    }

    func callAsFunction(_ wallets: [Wallet]) throws {
        try store.savePersonalWallets(wallets)
    }
}

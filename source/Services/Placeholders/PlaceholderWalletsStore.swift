//  PlaceholderWalletsStore.swift
//  mixtape
//
//  Created by Jamie Le Souëf on 28/09/2026.
//

struct PlaceholderWalletsStore: WalletsStoreProtocol {
    func personalWallets() throws -> [Wallet] {
        []
    }

    func savePersonalWallets(_: [Wallet]) throws {}

    func randomWalletMode() throws -> RandomWalletMode? {
        nil
    }

    func saveRandomWalletMode(_: RandomWalletMode) throws {}
}

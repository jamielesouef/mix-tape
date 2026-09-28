//  WalletsStoreProtocol.swift
//  mixtape
//
//  Created by Jamie Le Souëf on 28/09/2026.
//

nonisolated protocol WalletsStoreProtocol: Sendable {
    func personalWallets() throws -> [Wallet]
    func savePersonalWallets(_ wallets: [Wallet]) throws
    func randomWalletMode() throws -> RandomWalletMode?
    func saveRandomWalletMode(_ mode: RandomWalletMode) throws
}

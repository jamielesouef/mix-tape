//  SaveRandomWalletModeUseCase.swift
//  mixtape
//
//  Created by Jamie Le Souëf on 28/09/2026.
//

struct SaveRandomWalletModeUseCase: Sendable {
    private let store: any WalletsStoreProtocol

    init(store: any WalletsStoreProtocol) {
        self.store = store
    }

    func callAsFunction(_ mode: RandomWalletMode) throws {
        try store.saveRandomWalletMode(mode)
    }
}

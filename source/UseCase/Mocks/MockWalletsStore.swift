//  MockWalletsStore.swift
//  mixtape
//
//  Created by Jamie Le Souëf on 28/09/2026.
//

import Foundation

#if DEBUG

    final class MockWalletsStore: WalletsStoreProtocol, @unchecked Sendable {
        private let lock = NSLock()
        private var wallets: [Wallet]
        private var mode: RandomWalletMode?

        init(wallets: [Wallet] = [], mode: RandomWalletMode? = nil) {
            self.wallets = wallets
            self.mode = mode
        }

        func personalWallets() throws -> [Wallet] {
            lock.withLock { wallets }
        }

        func savePersonalWallets(_ wallets: [Wallet]) throws {
            lock.withLock { self.wallets = wallets }
        }

        func randomWalletMode() throws -> RandomWalletMode? {
            lock.withLock { mode }
        }

        func saveRandomWalletMode(_ mode: RandomWalletMode) throws {
            lock.withLock { self.mode = mode }
        }
    }
#endif

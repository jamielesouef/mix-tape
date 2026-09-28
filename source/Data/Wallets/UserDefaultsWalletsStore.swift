//  UserDefaultsWalletsStore.swift
//  mixtape
//
//  Created by Jamie Le Souëf on 28/09/2026.
//

import Foundation

/// `UserDefaults` is documented thread-safe for concurrent reads and writes, so vouching for
/// its `Sendable` conformance here reflects that guarantee rather than silencing a warning.
struct UserDefaultsWalletsStore: WalletsStoreProtocol, @unchecked Sendable {
    private static let walletsKey = "mixtape.personalWallets"
    private static let randomModeKey = "mixtape.randomWalletMode"

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func personalWallets() throws -> [Wallet] {
        guard let data = defaults.data(forKey: Self.walletsKey) else {
            return []
        }

        let records = try JSONDecoder().decode([Record].self, from: data)

        return records.map { Wallet(id: $0.id, name: $0.name, kind: .personal, albumIDs: $0.albumIDs) }
    }

    func savePersonalWallets(_ wallets: [Wallet]) throws {
        let records = wallets.map { Record(id: $0.id, name: $0.name, albumIDs: $0.albumIDs) }

        try defaults.set(JSONEncoder().encode(records), forKey: Self.walletsKey)
    }

    func randomWalletMode() throws -> RandomWalletMode? {
        guard let raw = defaults.string(forKey: Self.randomModeKey) else {
            return nil
        }

        return RandomWalletMode(rawValue: raw)
    }

    func saveRandomWalletMode(_ mode: RandomWalletMode) throws {
        defaults.set(mode.rawValue, forKey: Self.randomModeKey)
    }

    // MARK: - Private

    private struct Record: Codable {
        let id: String
        let name: String
        let albumIDs: [String]
    }
}

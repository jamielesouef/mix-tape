//  KeychainSessionStore.swift
//  MixtapeData
//
//  Created by Jamie Le Souëf on 03/09/2026.
//

import Foundation
import MixtapeDomain
import MixtapeInfrastructure
import MixtapeUseCase

public nonisolated struct KeychainSessionStore: SessionStoreProtocol {
    private static let sessionAccount = "session"
    private static let deviceIDAccount = "deviceId"

    private let store: KeychainStore

    public init(store: KeychainStore = KeychainStore(service: "mobi.jamie.mixtape")) {
        self.store = store
    }

    public func load() throws -> UserSession? {
        guard let data = try store.data(account: Self.sessionAccount) else { return nil }
        return try JSONDecoder().decode(StoredSessionDTO.self, from: data).session
    }

    public func save(_ session: UserSession) throws {
        try store.set(JSONEncoder().encode(StoredSessionDTO(session)), account: Self.sessionAccount)
    }

    public func clear() throws {
        try store.delete(account: Self.sessionAccount)
    }

    public func deviceID() throws -> String {
        if let data = try store.data(account: Self.deviceIDAccount), let existing = String(data: data, encoding: .utf8) {
            return existing
        }
        let fresh = UUID().uuidString
        try store.set(Data(fresh.utf8), account: Self.deviceIDAccount)
        return fresh
    }
}

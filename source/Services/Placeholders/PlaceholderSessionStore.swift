//  PlaceholderSessionStore.swift
//  mixtape
//
//  Created by Jamie Le Souëf on 04/09/2026.
//

nonisolated struct PlaceholderSessionStore: SessionStoreProtocol {
    func load() throws -> UserSession? {
        nil
    }

    func save(_: UserSession) throws {}

    func clear() throws {}
}

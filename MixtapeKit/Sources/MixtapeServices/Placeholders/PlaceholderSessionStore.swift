//  PlaceholderSessionStore.swift
//  MixtapeServices
//
//  Created by Jamie Le Souëf on 04/09/2026.
//

import MixtapeDomain
import MixtapeUseCase

nonisolated struct PlaceholderSessionStore: SessionStoreProtocol {
    func load() throws -> UserSession? {
        nil
    }

    func save(_: UserSession) throws {}

    func clear() throws {}
}

//  PlaceholderSessionStore.swift
//  MixtapeServices
//
//  Created by Jamie Le Souëf on 04/09/2026.
//

import MixtapeDomain
import MixtapeUseCase

/// The release-build session store behind `SessionService.placeholder` (slice 013): holds nothing
/// and remembers nothing, so the placeholder service can only ever be signed out.
nonisolated struct PlaceholderSessionStore: SessionStoreProtocol {
    func load() throws -> UserSession? {
        nil
    }

    func save(_: UserSession) throws {}

    func clear() throws {}
}

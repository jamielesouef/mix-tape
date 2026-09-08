//  PlaceholderAuthRepository.swift
//  MixtapeServices
//
//  Created by Jamie Le Souëf on 04/09/2026.
//

import Foundation
import MixtapeDomain
import MixtapeUseCase

/// The release-build collaborator behind `SessionService.placeholder` (slice 013). Every call
/// fails as unreachable: a placeholder is never the service a running app talks to, and the
/// `Mock*` factories that stand in for it in Debug are not built into release.
nonisolated struct PlaceholderAuthRepository: AuthRepositoryProtocol {
    func serverIdentity(at _: URL) async throws -> ServerIdentity {
        throw MixtapeError.serverUnreachable
    }

    func authenticate(userName _: String, password _: String, server _: ServerIdentity) async throws -> UserSession {
        throw MixtapeError.serverUnreachable
    }

    func isQuickConnectEnabled(server _: ServerIdentity) async throws -> Bool {
        throw MixtapeError.serverUnreachable
    }

    func initiateQuickConnect(server _: ServerIdentity) async throws -> QuickConnectHandshake {
        throw MixtapeError.serverUnreachable
    }

    func quickConnectState(secret _: String, server _: ServerIdentity) async throws -> Bool {
        throw MixtapeError.serverUnreachable
    }

    func authenticateWithQuickConnect(secret _: String, server _: ServerIdentity) async throws -> UserSession {
        throw MixtapeError.serverUnreachable
    }
}

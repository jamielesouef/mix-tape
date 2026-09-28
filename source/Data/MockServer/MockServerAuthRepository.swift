//  MockServerAuthRepository.swift
//  mixtape
//
//  Created by Jamie Le Souëf on 28/09/2026.
//

import Foundation

/// Stands in for `JellyfinAuthRepository` behind the same `AuthRepositoryProtocol` seam —
/// any server address validates, any non-empty username signs in, and Quick Connect
/// auto-approves after a short delay via `MockServerQuickConnectState`.
struct MockServerAuthRepository: AuthRepositoryProtocol {
    private static let userID = "mock-user"
    private static let deviceID = "mock-device"
    private static let accessToken = "mock-token"

    func serverIdentity(at url: URL) async throws -> ServerIdentity {
        ServerIdentity(id: "mock-server", name: "mixtape (mock)", version: "10.11.11", baseURL: url)
    }

    func authenticate(
        userName: String,
        password: String,
        server: ServerIdentity
    ) async throws -> UserSession {
        guard userName.trimmingCharacters(in: .whitespaces).isEmpty == false else {
            throw MixtapeError.invalidCredentials
        }

        return session(userName: userName, server: server)
    }

    func isQuickConnectEnabled(server _: ServerIdentity) async throws -> Bool {
        true
    }

    func initiateQuickConnect(server _: ServerIdentity) async throws -> QuickConnectHandshake {
        let secret = UUID().uuidString
        let code = String(format: "%06d", Int.random(in: 0 ..< 1_000_000))

        await MockServerQuickConnectState.shared.begin(secret: secret)

        return QuickConnectHandshake(secret: secret, code: code)
    }

    func quickConnectState(secret: String, server _: ServerIdentity) async throws -> Bool {
        try await MockServerQuickConnectState.shared.isApproved(secret: secret)
    }

    func authenticateWithQuickConnect(
        secret _: String,
        server: ServerIdentity
    ) async throws -> UserSession {
        session(userName: "mixtape", server: server)
    }

    // MARK: - Private

    private func session(userName: String, server: ServerIdentity) -> UserSession {
        UserSession(
            serverURL: server.baseURL,
            userID: Self.userID,
            userName: userName,
            accessToken: Self.accessToken,
            deviceID: Self.deviceID
        )
    }
}

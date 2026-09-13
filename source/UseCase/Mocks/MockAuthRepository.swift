//  MockAuthRepository.swift
//  mixtape
//
//  Created by Jamie Le Souëf on 03/09/2026.
//

import Foundation

#if DEBUG
    import Foundation

    nonisolated struct MockAuthRepository: AuthRepositoryProtocol {
        var serverIdentityResult: @Sendable (URL) async throws -> ServerIdentity
        var authenticateResult: @Sendable (String, String, ServerIdentity) async throws -> UserSession
        var isQuickConnectEnabledResult: @Sendable (ServerIdentity) async throws -> Bool
        var initiateQuickConnectResult: @Sendable (ServerIdentity) async throws -> QuickConnectHandshake
        var quickConnectStateResult: @Sendable (String, ServerIdentity) async throws -> Bool
        var authenticateWithQuickConnectResult: @Sendable (String, ServerIdentity) async throws -> UserSession

        static let sampleServer = ServerIdentity(
            id: "server-1", name: "mixtape", version: "10.11.11",
            baseURL: URL(string: "http://localhost:8096")!,
        )
        static let sampleSession = UserSession(
            serverURL: sampleServer.baseURL, userID: "user-1", userName: "jamie", accessToken: "token", deviceID: "device-1",
        )

        init(
            serverIdentityResult: @escaping @Sendable (URL) async throws -> ServerIdentity = { _ in sampleServer },
            authenticateResult: @escaping @Sendable (String, String, ServerIdentity) async throws -> UserSession = { _, _, _ in sampleSession },
            isQuickConnectEnabledResult: @escaping @Sendable (ServerIdentity) async throws -> Bool = { _ in true },
            initiateQuickConnectResult: @escaping @Sendable (ServerIdentity) async throws -> QuickConnectHandshake = { _ in
                QuickConnectHandshake(secret: "secret", code: "123456")
            },
            quickConnectStateResult: @escaping @Sendable (String, ServerIdentity) async throws -> Bool = { _, _ in true },
            authenticateWithQuickConnectResult: @escaping @Sendable (String, ServerIdentity) async throws -> UserSession = { _, _ in sampleSession },
        ) {
            self.serverIdentityResult = serverIdentityResult
            self.authenticateResult = authenticateResult
            self.isQuickConnectEnabledResult = isQuickConnectEnabledResult
            self.initiateQuickConnectResult = initiateQuickConnectResult
            self.quickConnectStateResult = quickConnectStateResult
            self.authenticateWithQuickConnectResult = authenticateWithQuickConnectResult
        }

        func serverIdentity(at url: URL) async throws -> ServerIdentity {
            try await serverIdentityResult(url)
        }

        func authenticate(userName: String, password: String, server: ServerIdentity) async throws -> UserSession {
            try await authenticateResult(userName, password, server)
        }

        func isQuickConnectEnabled(server: ServerIdentity) async throws -> Bool {
            try await isQuickConnectEnabledResult(server)
        }

        func initiateQuickConnect(server: ServerIdentity) async throws -> QuickConnectHandshake {
            try await initiateQuickConnectResult(server)
        }

        func quickConnectState(secret: String, server: ServerIdentity) async throws -> Bool {
            try await quickConnectStateResult(secret, server)
        }

        func authenticateWithQuickConnect(secret: String, server: ServerIdentity) async throws -> UserSession {
            try await authenticateWithQuickConnectResult(secret, server)
        }
    }
#endif

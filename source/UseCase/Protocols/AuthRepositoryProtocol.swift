//  AuthRepositoryProtocol.swift
//  mixtape
//
//  Created by Jamie Le Souëf on 03/09/2026.
//

import Foundation

public nonisolated protocol AuthRepositoryProtocol: Sendable {
    func serverIdentity(at url: URL) async throws -> ServerIdentity
    func authenticate(userName: String, password: String, server: ServerIdentity) async throws -> UserSession
    func isQuickConnectEnabled(server: ServerIdentity) async throws -> Bool
    func initiateQuickConnect(server: ServerIdentity) async throws -> QuickConnectHandshake
    func quickConnectState(secret: String, server: ServerIdentity) async throws -> Bool
    func authenticateWithQuickConnect(secret: String, server: ServerIdentity) async throws -> UserSession
}

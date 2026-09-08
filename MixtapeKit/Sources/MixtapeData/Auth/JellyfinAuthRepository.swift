//  JellyfinAuthRepository.swift
//  MixtapeData
//
//  Created by Jamie Le Souëf on 03/09/2026.
//

import Foundation
import MixtapeDomain
import MixtapeInfrastructure
import MixtapeUseCase

/// Engineering doc §8 "Auth". Stateless; the stable `DeviceId` is injected so the Quick Connect
/// flow carries it before any session exists.
public nonisolated struct JellyfinAuthRepository: AuthRepositoryProtocol {
    private let client: JellyfinHTTPClient
    private let deviceID: String
    private let appVersion: String

    public init(client: JellyfinHTTPClient, deviceID: String, appVersion: String) {
        self.client = client
        self.deviceID = deviceID
        self.appVersion = appVersion
    }

    public func serverIdentity(at url: URL) async throws -> ServerIdentity {
        let dto: PublicSystemInfoDTO = try await client.get("/System/Info/Public", auth: context(baseURL: url))
        return try AuthMapper.serverIdentity(from: dto, baseURL: url)
    }

    public func authenticate(userName: String, password: String, server: ServerIdentity) async throws -> UserSession {
        let dto: AuthenticationResultDTO = try await client.post(
            "/Users/AuthenticateByName",
            body: AuthenticateUserByNameBody(username: userName, pw: password),
            auth: context(baseURL: server.baseURL),
        )
        return try AuthMapper.userSession(from: dto, serverURL: server.baseURL, deviceID: deviceID)
    }

    public func isQuickConnectEnabled(server: ServerIdentity) async throws -> Bool {
        try await client.get("/QuickConnect/Enabled", auth: context(baseURL: server.baseURL))
    }

    /// `POST`, per decision 5.
    public func initiateQuickConnect(server: ServerIdentity) async throws -> QuickConnectHandshake {
        let dto: QuickConnectResultDTO = try await client.post(
            "/QuickConnect/Initiate", body: EmptyBody(), auth: context(baseURL: server.baseURL),
        )
        return try AuthMapper.handshake(from: dto)
    }

    public func quickConnectState(secret: String, server: ServerIdentity) async throws -> Bool {
        let dto: QuickConnectResultDTO = try await client.get(
            "/QuickConnect/Connect",
            query: [URLQueryItem(name: "secret", value: secret)],
            auth: context(baseURL: server.baseURL),
        )
        return dto.authenticated ?? false
    }

    public func authenticateWithQuickConnect(secret: String, server: ServerIdentity) async throws -> UserSession {
        let dto: AuthenticationResultDTO = try await client.post(
            "/Users/AuthenticateWithQuickConnect",
            body: QuickConnectSecretBody(secret: secret),
            auth: context(baseURL: server.baseURL),
        )
        return try AuthMapper.userSession(from: dto, serverURL: server.baseURL, deviceID: deviceID)
    }

    private func context(baseURL: URL) -> AuthContext {
        AuthContext(baseURL: baseURL, deviceID: deviceID, appVersion: appVersion, token: nil)
    }
}

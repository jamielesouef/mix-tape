//  AuthMapper.swift
//  MixtapeData
//
//  Created by Jamie Le Souëf on 03/09/2026.
//

import Foundation
import MixtapeDomain

nonisolated enum AuthMapper {
    static func serverIdentity(from dto: PublicSystemInfoDTO, baseURL: URL) throws -> ServerIdentity {
        guard let id = dto.id, let name = dto.serverName, let version = dto.version else {
            throw MixtapeError.notAJellyfinServer
        }
        return ServerIdentity(id: id, name: name, version: version, baseURL: baseURL)
    }

    static func userSession(from dto: AuthenticationResultDTO, serverURL: URL, deviceID: String) throws -> UserSession {
        guard let token = dto.accessToken, let userID = dto.user?.id else { throw MixtapeError.decoding }
        return UserSession(serverURL: serverURL, userID: userID, userName: dto.user?.name ?? "", accessToken: token, deviceID: deviceID)
    }

    static func handshake(from dto: QuickConnectResultDTO) throws -> QuickConnectHandshake {
        guard let secret = dto.secret, let code = dto.code else { throw MixtapeError.decoding }
        return QuickConnectHandshake(secret: secret, code: code)
    }
}

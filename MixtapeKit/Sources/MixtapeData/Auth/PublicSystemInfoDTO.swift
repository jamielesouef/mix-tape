//  PublicSystemInfoDTO.swift
//  MixtapeData
//
//  Created by Jamie Le Souëf on 03/09/2026.
//

nonisolated struct PublicSystemInfoDTO: Decodable {
    let id: String?
    let serverName: String?
    let version: String?

    enum CodingKeys: String, CodingKey {
        case id = "Id"
        case serverName = "ServerName"
        case version = "Version"
    }
}

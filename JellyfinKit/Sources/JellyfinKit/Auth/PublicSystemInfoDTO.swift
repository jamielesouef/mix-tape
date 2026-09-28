//  PublicSystemInfoDTO.swift
//  JellyfinKit
//
//  Created by Jamie Le Souëf on 03/09/2026.
//

public struct PublicSystemInfoDTO: Decodable, Sendable {
    public let id: String?
    public let serverName: String?
    public let version: String?

    enum CodingKeys: String, CodingKey {
        case id = "Id"
        case serverName = "ServerName"
        case version = "Version"
    }
}

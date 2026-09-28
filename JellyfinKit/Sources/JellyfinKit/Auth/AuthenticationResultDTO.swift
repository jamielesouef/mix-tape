//  AuthenticationResultDTO.swift
//  JellyfinKit
//
//  Created by Jamie Le Souëf on 03/09/2026.
//

public struct AuthenticationResultDTO: Decodable, Sendable {
    public let accessToken: String?
    public let user: UserDTO?

    enum CodingKeys: String, CodingKey {
        case accessToken = "AccessToken"
        case user = "User"
    }
}

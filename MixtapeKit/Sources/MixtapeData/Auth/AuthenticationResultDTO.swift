//  AuthenticationResultDTO.swift
//  MixtapeData
//
//  Created by Jamie Le Souëf on 03/09/2026.
//

nonisolated struct AuthenticationResultDTO: Decodable {
    let accessToken: String?
    let user: UserDTO?

    enum CodingKeys: String, CodingKey {
        case accessToken = "AccessToken"
        case user = "User"
    }
}

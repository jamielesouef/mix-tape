//  AuthenticateUserByNameBody.swift
//  mixtape
//
//  Created by Jamie Le Souëf on 03/09/2026.
//

struct AuthenticateUserByNameBody: Encodable {
    let username: String
    let password: String

    enum CodingKeys: String, CodingKey {
        case username = "Username"
        case password = "Pw"
    }
}

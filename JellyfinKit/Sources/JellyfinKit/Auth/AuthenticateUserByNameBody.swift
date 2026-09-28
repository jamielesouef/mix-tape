//  AuthenticateUserByNameBody.swift
//  JellyfinKit
//
//  Created by Jamie Le Souëf on 03/09/2026.
//

public struct AuthenticateUserByNameBody: Encodable, Sendable {
    public let username: String
    public let password: String

    public init(username: String, password: String) {
        self.username = username
        self.password = password
    }

    enum CodingKeys: String, CodingKey {
        case username = "Username"
        case password = "Pw"
    }
}

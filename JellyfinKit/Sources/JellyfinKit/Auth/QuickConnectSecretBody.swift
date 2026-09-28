//  QuickConnectSecretBody.swift
//  JellyfinKit
//
//  Created by Jamie Le Souëf on 03/09/2026.
//

public struct QuickConnectSecretBody: Encodable, Sendable {
    public let secret: String

    public init(secret: String) {
        self.secret = secret
    }

    enum CodingKeys: String, CodingKey {
        case secret = "Secret"
    }
}

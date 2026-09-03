//  QuickConnectHandshake.swift
//  MixtapeDomain
//
//  Created by Jamie Le Souëf on 03/09/2026.
//

public nonisolated struct QuickConnectHandshake: Sendable, Equatable {
    public let secret: String
    public let code: String

    public init(secret: String, code: String) {
        self.secret = secret
        self.code = code
    }
}

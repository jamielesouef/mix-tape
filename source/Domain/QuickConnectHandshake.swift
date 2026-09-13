//  QuickConnectHandshake.swift
//  mixtape
//
//  Created by Jamie Le Souëf on 03/09/2026.
//

nonisolated struct QuickConnectHandshake: Sendable, Equatable {
    let secret: String
    let code: String

    init(secret: String, code: String) {
        self.secret = secret
        self.code = code
    }
}

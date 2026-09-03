//  QuickConnectHandshake.swift
//  MixtapeDomain
//
//  Created by Jamie Le Souëf on 03/09/2026.
//

nonisolated struct QuickConnectHandshake: Sendable, Equatable {
    let secret: String
    let code: String
}

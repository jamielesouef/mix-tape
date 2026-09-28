//  RandomWalletMode.swift
//  mixtape
//
//  Created by Jamie Le Souëf on 28/09/2026.
//

enum RandomWalletMode: String, Sendable, Hashable, CaseIterable, Codable {
    case fullyRandom
    case favouringLeastPlayed
}

//  WalletKind.swift
//  mixtape
//
//  Created by Jamie Le Souëf on 28/09/2026.
//

enum WalletKind: Sendable, Hashable {
    case personal
    case library(id: String)
    case genre(String)
    case mostPlayed
    case random(RandomWalletMode)
    case downloaded
}

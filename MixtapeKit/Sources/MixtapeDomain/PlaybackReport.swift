//  PlaybackReport.swift
//  MixtapeDomain
//
//  Created by Jamie Le Souëf on 03/09/2026.
//

nonisolated struct PlaybackReport: Sendable, Equatable {
    let itemID: String
    let mediaSourceID: String
    let playSessionID: String
    let position: Duration
    let isPaused: Bool
    let method: PlaybackMethod
    let playMethod: PlayMethod
}

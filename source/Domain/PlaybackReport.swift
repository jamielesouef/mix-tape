//  PlaybackReport.swift
//  mixtape
//
//  Created by Jamie Le Souëf on 03/09/2026.
//

struct PlaybackReport: Sendable, Equatable {
    let itemID: String
    let mediaSourceID: String
    let playSessionID: String
    let position: Duration
    let isPaused: Bool
    let playMethod: PlayMethod
}

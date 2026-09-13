//  PlaybackReport.swift
//  mixtape
//
//  Created by Jamie Le Souëf on 03/09/2026.
//

nonisolated struct PlaybackReport: Sendable, Equatable {
    let itemID: String
    let mediaSourceID: String
    let playSessionID: String
    let position: Duration
    let isPaused: Bool
    let playMethod: PlayMethod

    init(itemID: String, mediaSourceID: String, playSessionID: String, position: Duration, isPaused: Bool, playMethod: PlayMethod) {
        self.itemID = itemID
        self.mediaSourceID = mediaSourceID
        self.playSessionID = playSessionID
        self.position = position
        self.isPaused = isPaused
        self.playMethod = playMethod
    }
}

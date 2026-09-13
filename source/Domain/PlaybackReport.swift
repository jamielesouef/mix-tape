//  PlaybackReport.swift
//  mixtape
//
//  Created by Jamie Le Souëf on 03/09/2026.
//

public nonisolated struct PlaybackReport: Sendable, Equatable {
    public let itemID: String
    public let mediaSourceID: String
    public let playSessionID: String
    public let position: Duration
    public let isPaused: Bool
    public let method: PlaybackMethod
    public let playMethod: PlayMethod

    public init(itemID: String, mediaSourceID: String, playSessionID: String, position: Duration, isPaused: Bool, method: PlaybackMethod, playMethod: PlayMethod) {
        self.itemID = itemID
        self.mediaSourceID = mediaSourceID
        self.playSessionID = playSessionID
        self.position = position
        self.isPaused = isPaused
        self.method = method
        self.playMethod = playMethod
    }
}

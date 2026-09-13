//  PlaybackPlan.swift
//  mixtape
//
//  Created by Jamie Le Souëf on 03/09/2026.
//

import Foundation

public nonisolated struct PlaybackPlan: Sendable, Equatable {
    public let itemID: String
    public let mediaSourceID: String
    public let playSessionID: String
    public let method: PlaybackMethod
    public let playMethod: PlayMethod
    public let streamURL: URL
    public let startPosition: Duration
    public let totalDuration: Duration?

    public init(itemID: String, mediaSourceID: String, playSessionID: String, method: PlaybackMethod, playMethod: PlayMethod, streamURL: URL, startPosition: Duration, totalDuration: Duration?) {
        self.itemID = itemID
        self.mediaSourceID = mediaSourceID
        self.playSessionID = playSessionID
        self.method = method
        self.playMethod = playMethod
        self.streamURL = streamURL
        self.startPosition = startPosition
        self.totalDuration = totalDuration
    }
}

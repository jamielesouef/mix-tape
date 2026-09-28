//  PlaybackReportBody.swift
//  JellyfinKit
//
//  Created by Jamie Le Souëf on 03/09/2026.
//

public struct PlaybackReportBody: Encodable, Sendable {
    public let itemId: String
    public let mediaSourceId: String
    public let playSessionId: String
    public let positionTicks: Int64
    public let isPaused: Bool
    public let canSeek = true
    public let playMethod: String

    public init(
        itemId: String,
        mediaSourceId: String,
        playSessionId: String,
        positionTicks: Int64,
        isPaused: Bool,
        playMethod: String
    ) {
        self.itemId = itemId
        self.mediaSourceId = mediaSourceId
        self.playSessionId = playSessionId
        self.positionTicks = positionTicks
        self.isPaused = isPaused
        self.playMethod = playMethod
    }

    enum CodingKeys: String, CodingKey {
        case itemId = "ItemId"
        case mediaSourceId = "MediaSourceId"
        case playSessionId = "PlaySessionId"
        case positionTicks = "PositionTicks"
        case isPaused = "IsPaused"
        case canSeek = "CanSeek"
        case playMethod = "PlayMethod"
    }
}

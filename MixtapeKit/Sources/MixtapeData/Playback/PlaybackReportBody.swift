//  PlaybackReportBody.swift
//  MixtapeData
//
//  Created by Jamie Le Souëf on 03/09/2026.
//

nonisolated struct PlaybackReportBody: Encodable {
    let itemId: String
    let mediaSourceId: String
    let playSessionId: String
    let positionTicks: Int64
    let isPaused: Bool
    let canSeek = true
    let playMethod: String

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

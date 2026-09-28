//  UserItemDataDTO.swift
//  JellyfinKit
//
//  Created by Jamie Le Souëf on 03/09/2026.
//

public struct UserItemDataDTO: Decodable, Sendable {
    public let playbackPositionTicks: Int64?
    public let playCount: Int?

    enum CodingKeys: String, CodingKey {
        case playbackPositionTicks = "PlaybackPositionTicks"
        case playCount = "PlayCount"
    }
}

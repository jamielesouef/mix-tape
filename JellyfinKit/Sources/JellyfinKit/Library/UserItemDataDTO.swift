//  UserItemDataDTO.swift
//  JellyfinKit
//
//  Created by Jamie Le Souëf on 03/09/2026.
//

public struct UserItemDataDTO: Decodable, Sendable {
    public let playbackPositionTicks: Int64?

    enum CodingKeys: String, CodingKey {
        case playbackPositionTicks = "PlaybackPositionTicks"
    }
}

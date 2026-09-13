//  UserItemDataDTO.swift
//  mixtape
//
//  Created by Jamie Le Souëf on 03/09/2026.
//

nonisolated struct UserItemDataDTO: Decodable {
    let playbackPositionTicks: Int64?
    let played: Bool?

    enum CodingKeys: String, CodingKey {
        case playbackPositionTicks = "PlaybackPositionTicks"
        case played = "Played"
    }
}

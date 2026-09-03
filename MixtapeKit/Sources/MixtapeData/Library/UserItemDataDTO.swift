//  UserItemDataDTO.swift
//  MixtapeData
//
//  Created by Jamie Le Souëf on 03/09/2026.
//

/// `UserItemDataDto`. Only the keys this server actually sends are read (decision 8).
nonisolated struct UserItemDataDTO: Decodable {
    let playbackPositionTicks: Int64?
    let played: Bool?

    enum CodingKeys: String, CodingKey {
        case playbackPositionTicks = "PlaybackPositionTicks"
        case played = "Played"
    }
}

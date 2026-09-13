//  PlaybackInfoResponseDTO.swift
//  mixtape
//
//  Created by Jamie Le Souëf on 03/09/2026.
//

nonisolated struct PlaybackInfoResponseDTO: Decodable {
    let mediaSources: [MediaSourceInfoDTO]?
    let playSessionId: String?

    enum CodingKeys: String, CodingKey {
        case mediaSources = "MediaSources"
        case playSessionId = "PlaySessionId"
    }
}

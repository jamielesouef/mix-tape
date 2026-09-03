//  PlaybackInfoResponseDTO.swift
//  MixtapeData
//
//  Created by Jamie Le Souëf on 03/09/2026.
//

/// `PlaybackInfoResponse`. `ErrorCode` is not read (decision 26): no first usable source is `.noPlayableSource`.
nonisolated struct PlaybackInfoResponseDTO: Decodable {
    let mediaSources: [MediaSourceInfoDTO]?
    let playSessionId: String?

    enum CodingKeys: String, CodingKey {
        case mediaSources = "MediaSources"
        case playSessionId = "PlaySessionId"
    }
}

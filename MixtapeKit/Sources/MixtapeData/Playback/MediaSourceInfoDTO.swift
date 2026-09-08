//  MediaSourceInfoDTO.swift
//  MixtapeData
//
//  Created by Jamie Le Souëf on 03/09/2026.
//

/// `MediaSourceInfo` from a `PlaybackInfo` response.
nonisolated struct MediaSourceInfoDTO: Decodable {
    let id: String?
    let container: String?
    let supportsDirectPlay: Bool?
    let supportsDirectStream: Bool?
    let transcodingUrl: String?
    let runTimeTicks: Int64?
    let mediaStreams: [MediaStreamDTO]?

    enum CodingKeys: String, CodingKey {
        case id = "Id"
        case container = "Container"
        case supportsDirectPlay = "SupportsDirectPlay"
        case supportsDirectStream = "SupportsDirectStream"
        case transcodingUrl = "TranscodingUrl"
        case runTimeTicks = "RunTimeTicks"
        case mediaStreams = "MediaStreams"
    }
}

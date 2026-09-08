//  MediaStreamDTO.swift
//  MixtapeData
//
//  Created by Jamie Le Souëf on 03/09/2026.
//

/// `MediaStream`: only the codec and the stream type are read.
nonisolated struct MediaStreamDTO: Decodable {
    let codec: String?
    let type: String?

    enum CodingKeys: String, CodingKey {
        case codec = "Codec"
        case type = "Type"
    }
}

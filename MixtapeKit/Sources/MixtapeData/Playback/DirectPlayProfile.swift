//  DirectPlayProfile.swift
//  MixtapeData
//
//  Created by Jamie Le Souëf on 03/09/2026.
//

/// One `DirectPlayProfile` entry of the device profile (engineering doc §8).
public nonisolated struct DirectPlayProfile: Encodable, Sendable, Equatable {
    public let container: String
    public let type: String
    public let videoCodec: String
    public let audioCodec: String

    public init(container: String, type: String = "Video", videoCodec: String, audioCodec: String) {
        self.container = container
        self.type = type
        self.videoCodec = videoCodec
        self.audioCodec = audioCodec
    }

    enum CodingKeys: String, CodingKey {
        case container = "Container"
        case type = "Type"
        case videoCodec = "VideoCodec"
        case audioCodec = "AudioCodec"
    }
}

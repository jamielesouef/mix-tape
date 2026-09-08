//  TranscodingProfile.swift
//  MixtapeData
//
//  Created by Jamie Le Souëf on 03/09/2026.
//

/// The one HLS fallback profile (engineering doc §8).
public nonisolated struct TranscodingProfile: Encodable, Sendable, Equatable {
    public let container: String
    public let type: String
    public let videoCodec: String
    public let audioCodec: String
    public let protocolName: String
    public let context: String

    public init(container: String = "ts", type: String = "Video", videoCodec: String = "h264", audioCodec: String = "aac", protocolName: String = "hls", context: String = "Streaming") {
        self.container = container
        self.type = type
        self.videoCodec = videoCodec
        self.audioCodec = audioCodec
        self.protocolName = protocolName
        self.context = context
    }

    enum CodingKeys: String, CodingKey {
        case container = "Container"
        case type = "Type"
        case videoCodec = "VideoCodec"
        case audioCodec = "AudioCodec"
        case protocolName = "Protocol"
        case context = "Context"
    }
}

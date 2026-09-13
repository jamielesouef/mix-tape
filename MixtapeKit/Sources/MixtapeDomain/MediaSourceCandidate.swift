//  MediaSourceCandidate.swift
//  MixtapeDomain
//
//  Created by Jamie Le Souëf on 03/09/2026.
//

public nonisolated struct MediaSourceCandidate: Sendable, Equatable {
    public let id: String
    public let container: String
    public let videoCodec: String?
    public let audioCodec: String?
    public let supportsDirectPlay: Bool
    public let supportsDirectStream: Bool
    public let transcodingUrl: String?
    public let runTimeTicks: Int64?

    public init(id: String, container: String, videoCodec: String?, audioCodec: String?, supportsDirectPlay: Bool, supportsDirectStream: Bool, transcodingUrl: String?, runTimeTicks: Int64?) {
        self.id = id
        self.container = container
        self.videoCodec = videoCodec
        self.audioCodec = audioCodec
        self.supportsDirectPlay = supportsDirectPlay
        self.supportsDirectStream = supportsDirectStream
        self.transcodingUrl = transcodingUrl
        self.runTimeTicks = runTimeTicks
    }
}

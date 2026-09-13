//  VideoSourceResolution.swift
//  mixtape
//
//  Created by Jamie Le Souëf on 03/09/2026.
//

public nonisolated struct VideoSourceResolution: Sendable, Equatable {
    public let playSessionID: String
    public let sources: [MediaSourceCandidate]

    public init(playSessionID: String, sources: [MediaSourceCandidate]) {
        self.playSessionID = playSessionID
        self.sources = sources
    }
}

//  VideoSourceResolution.swift
//  MixtapeDomain
//
//  Created by Jamie Le Souëf on 03/09/2026.
//

/// What one `PlaybackInfo` response yields before method selection: the play session the server
/// opened and the sources it offered (decision 12; slice 006).
public nonisolated struct VideoSourceResolution: Sendable, Equatable {
    public let playSessionID: String
    public let sources: [MediaSourceCandidate]

    public init(playSessionID: String, sources: [MediaSourceCandidate]) {
        self.playSessionID = playSessionID
        self.sources = sources
    }
}

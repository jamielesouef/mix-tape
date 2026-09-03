//  AudioStream.swift
//  MixtapeDomain
//
//  Created by Jamie Le Souëf on 03/09/2026.
//

import Foundation

/// What `BuildAudioStreamURLUseCase` returns: the stream URL and the wire `PlayMethod` to report
/// beside it (decision 40). Music never builds a `PlaybackPlan`.
public nonisolated struct AudioStream: Sendable, Equatable {
    public let url: URL
    public let playMethod: PlayMethod

    public init(url: URL, playMethod: PlayMethod) {
        self.url = url
        self.playMethod = playMethod
    }
}

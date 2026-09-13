//  PlaybackMethod.swift
//  MixtapeDomain
//
//  Created by Jamie Le Souëf on 03/09/2026.
//

public nonisolated enum PlaybackMethod: Sendable, Equatable {
    case directAVPlayer
    case directVLC
    case transcodeHLS
}

//  PlayMethod.swift
//  MixtapeDomain
//
//  Created by Jamie Le Souëf on 03/09/2026.
//

/// Jellyfin's wire `PlayMethod`, reported back to the server (decision 11).
public nonisolated enum PlayMethod: Sendable, Equatable {
    case directPlay, directStream, transcode
}

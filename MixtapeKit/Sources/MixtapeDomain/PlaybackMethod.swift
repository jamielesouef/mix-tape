//  PlaybackMethod.swift
//  MixtapeDomain
//
//  Created by Jamie Le Souëf on 03/09/2026.
//

/// Which local player plays the item (decision 11 keeps this distinct from `PlayMethod`).
public nonisolated enum PlaybackMethod: Sendable, Equatable {
    /// Native container and codecs; AVPlayer plays the static stream.
    case directAVPlayer
    /// Container or codec AVPlayer refuses; VLCKit plays the static stream.
    case directVLC
    /// Server-side transcode; AVPlayer plays the HLS playlist.
    case transcodeHLS
}

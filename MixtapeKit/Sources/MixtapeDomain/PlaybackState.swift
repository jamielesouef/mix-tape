//  PlaybackState.swift
//  MixtapeDomain
//
//  Created by Jamie Le Souëf on 03/09/2026.
//

/// Server-reported playback state for an item. `isWatched` is the server's `UserData.Played`
/// as mapped (decision 8); the 0.9 rule lives in `reachesWatchedThreshold` for reporting time.
nonisolated struct PlaybackState: Sendable, Equatable {
    let position: Duration
    let isWatched: Bool

    var hasResumePoint: Bool {
        position > .seconds(0)
    }
}

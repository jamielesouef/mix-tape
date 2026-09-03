//  PlaybackState.swift
//  MixtapeDomain
//
//  Created by Jamie Le Souëf on 03/09/2026.
//

/// Server-reported playback state for an item. `isWatched` is the server's `UserData.Played`
/// as mapped (decision 8); the 0.9 rule lives in `reachesWatchedThreshold` for reporting time.
public nonisolated struct PlaybackState: Sendable, Equatable {
    public let position: Duration
    public let isWatched: Bool

    public var hasResumePoint: Bool {
        position > .seconds(0)
    }

    public init(position: Duration, isWatched: Bool) {
        self.position = position
        self.isWatched = isWatched
    }
}

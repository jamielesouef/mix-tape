//  PlaybackState.swift
//  mixtape
//
//  Created by Jamie Le Souëf on 03/09/2026.
//

public nonisolated struct PlaybackState: Sendable, Hashable {
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

//  PlaybackState+WatchedThreshold.swift
//  mixtape
//
//  Created by Jamie Le Souëf on 03/09/2026.
//

public extension PlaybackState {
    nonisolated static func reachesWatchedThreshold(position: Duration, duration: Duration) -> Bool {
        guard duration > .zero else { return false }
        return position * 10 >= duration * 9
    }
}

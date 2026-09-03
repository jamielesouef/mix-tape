//  PlaybackState+WatchedThreshold.swift
//  MixtapeDomain
//
//  Created by Jamie Le Souëf on 03/09/2026.
//

extension PlaybackState {
    /// The reporting-time watched rule: `position / duration >= 0.9`, in exact integer
    /// arithmetic. A zero or negative duration never counts as watched.
    nonisolated static func reachesWatchedThreshold(position: Duration, duration: Duration) -> Bool {
        guard duration > .zero else { return false }
        return position * 10 >= duration * 9
    }
}

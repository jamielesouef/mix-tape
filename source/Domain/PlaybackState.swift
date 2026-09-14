//  PlaybackState.swift
//  mixtape
//
//  Created by Jamie Le Souëf on 03/09/2026.
//

struct PlaybackState: Sendable, Hashable {
    let position: Duration

    var hasResumePoint: Bool {
        position > .seconds(0)
    }
}

//  MediaItem+Progress.swift
//  MixtapePresentation
//
//  Created by Jamie Le Souëf on 03/09/2026.
//

import MixtapeDomain

extension MediaItem {
    nonisolated var progressFraction: Double? {
        guard let runtime, runtime > .zero, playback.hasResumePoint else { return nil }
        return min(playback.position / runtime, 1)
    }
}

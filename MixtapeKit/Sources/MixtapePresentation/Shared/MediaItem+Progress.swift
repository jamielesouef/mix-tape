//  MediaItem+Progress.swift
//  MixtapePresentation
//
//  Created by Jamie Le Souëf on 03/09/2026.
//

import MixtapeDomain

extension MediaItem {
    /// Resume position as a fraction of the runtime, for progress bars. `nil` without a runtime or a position.
    nonisolated var progressFraction: Double? {
        guard let runtime, runtime > .zero, playback.hasResumePoint else { return nil }
        return min(playback.position / runtime, 1)
    }
}

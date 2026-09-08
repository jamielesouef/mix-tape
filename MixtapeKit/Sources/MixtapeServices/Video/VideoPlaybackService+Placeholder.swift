//  VideoPlaybackService+Placeholder.swift
//  MixtapeServices
//
//  Created by Jamie Le Souëf on 03/09/2026.
//

import MixtapeUseCase

public extension VideoPlaybackService {
    /// `@Entry` default. Never used by a running app — the composition root always injects one.
    /// Debug builds use the preview mock; release builds, which carry no `Mock*` type (slice 013),
    /// build the same service over the inert `Placeholder*` collaborators.
    static let placeholder: VideoPlaybackService = {
        #if DEBUG
            return MockVideoPlaybackService.idle()
        #else
            let repository = PlaceholderPlaybackRepository()
            return VideoPlaybackService(
                resolveVideo: ResolveVideoPlaybackUseCase(repository: repository),
                reportStart: ReportPlaybackStartUseCase(repository: repository),
                reportProgress: ReportPlaybackProgressUseCase(repository: repository),
                reportStopped: ReportPlaybackStoppedUseCase(repository: repository),
                sessionService: .placeholder,
                makeController: { _ in nil },
            )
        #endif
    }()
}

//  VideoPlaybackService+Placeholder.swift
//  mixtape
//
//  Created by Jamie Le Souëf on 03/09/2026.
//

public extension VideoPlaybackService {
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

//  MockVideoPlaybackService.swift
//  MixtapeServices
//
//  Created by Jamie Le Souëf on 03/09/2026.
//

import Foundation
import MixtapeDomain
import MixtapeUseCase

/// Preview and placeholder factories: real `VideoPlaybackService` instances over the mock
/// repository and `MockVideoPlayerController`, started in the state the preview is about.
public enum MockVideoPlaybackService {
    public static let samplePlan = PlaybackPlan(
        itemID: "movie-1", mediaSourceID: "source-1", playSessionID: "psid-1", method: .directAVPlayer, playMethod: .directPlay,
        streamURL: URL(string: "mock://stream/movie-1")!, // constant
        startPosition: .zero, totalDuration: .seconds(21),
    )

    public static func make(
        repository: MockPlaybackRepository = MockPlaybackRepository(),
        sessionService: SessionService = MockSessionService.signedIn(),
        item: MediaItem? = nil,
        plan: PlaybackPlan? = nil,
        status: PlayerStatus = .idle,
    ) -> VideoPlaybackService {
        VideoPlaybackService(
            resolveVideo: ResolveVideoPlaybackUseCase(repository: repository),
            reportStart: ReportPlaybackStartUseCase(repository: repository),
            reportProgress: ReportPlaybackProgressUseCase(repository: repository),
            reportStopped: ReportPlaybackStoppedUseCase(repository: repository),
            sessionService: sessionService,
            makeController: { _ in MockVideoPlayerController() },
            item: item,
            plan: plan,
            status: status,
        )
    }

    public static func idle() -> VideoPlaybackService {
        make()
    }

    public static func playing() -> VideoPlaybackService {
        make(item: MockMedia.movies[0], plan: samplePlan, status: .playing)
    }

    public static func preparing() -> VideoPlaybackService {
        make(item: MockMedia.movies[0], status: .preparing)
    }

    public static func failed(_ error: MixtapeError = .noPlayableSource) -> VideoPlaybackService {
        make(item: MockMedia.movies[0], status: .failed(error))
    }
}

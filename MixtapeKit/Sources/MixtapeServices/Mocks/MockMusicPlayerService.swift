//  MockMusicPlayerService.swift
//  MixtapeServices
//
//  Created by Jamie Le Souëf on 03/09/2026.
//

#if DEBUG
    import MixtapeDomain
    import MixtapeUseCase

    /// Preview and placeholder factories: real `MusicPlayerService` instances over the mock repository
    /// and a silent controller, started in the state the preview is about.
    public enum MockMusicPlayerService {
        public static func make(
            repository: MockPlaybackRepository = MockPlaybackRepository(),
            sessionService: SessionService = MockSessionService.signedIn(),
        ) -> MusicPlayerService {
            MusicPlayerService(
                controller: MockAudioPlayerController(),
                buildAudioStreamURL: BuildAudioStreamURLUseCase(repository: repository),
                reportStart: ReportPlaybackStartUseCase(repository: repository),
                reportProgress: ReportPlaybackProgressUseCase(repository: repository),
                reportStopped: ReportPlaybackStoppedUseCase(repository: repository),
                sessionService: sessionService,
            )
        }

        public static func idle() -> MusicPlayerService {
            make()
        }

        /// Playing the sample album from its first track.
        public static func playing() -> MusicPlayerService {
            let service = make()
            Task { await service.play(album: MockMedia.albums[0], tracks: MockMedia.tracks, startingAt: 0) }
            return service
        }
    }
#endif

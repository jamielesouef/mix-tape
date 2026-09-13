//  MockMusicPlayerService.swift
//  mixtape
//
//  Created by Jamie Le Souëf on 03/09/2026.
//

#if DEBUG

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

        public static func playing() -> MusicPlayerService {
            let service = make()
            Task { await service.play(album: MockMedia.albums[0], tracks: MockMedia.tracks, startingAt: 0) }
            return service
        }
    }
#endif

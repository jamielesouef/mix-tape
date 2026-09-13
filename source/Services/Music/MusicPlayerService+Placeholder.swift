//  MusicPlayerService+Placeholder.swift
//  mixtape
//
//  Created by Jamie Le Souëf on 03/09/2026.
//

extension MusicPlayerService {
    static let placeholder: MusicPlayerService = {
        #if DEBUG
            return MockMusicPlayerService.idle()
        #else
            let repository = PlaceholderPlaybackRepository()
            return MusicPlayerService(
                controller: PlaceholderAudioPlayerController(),
                buildAudioStreamURL: BuildAudioStreamURLUseCase(repository: repository),
                reportStart: ReportPlaybackStartUseCase(repository: repository),
                reportProgress: ReportPlaybackProgressUseCase(repository: repository),
                reportStopped: ReportPlaybackStoppedUseCase(repository: repository),
                sessionService: .placeholder,
            )
        #endif
    }()
}

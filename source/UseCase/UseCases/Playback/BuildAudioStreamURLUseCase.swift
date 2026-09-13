//  BuildAudioStreamURLUseCase.swift
//  mixtape
//
//  Created by Jamie Le Souëf on 03/09/2026.
//

nonisolated struct BuildAudioStreamURLUseCase: Sendable {
    private let repository: any PlaybackRepositoryProtocol

    init(repository: any PlaybackRepositoryProtocol) {
        self.repository = repository
    }

    func callAsFunction(track: MediaItem, session: UserSession, playSessionID: String) -> AudioStream {
        repository.audioStream(track: track, session: session, playSessionID: playSessionID)
    }
}

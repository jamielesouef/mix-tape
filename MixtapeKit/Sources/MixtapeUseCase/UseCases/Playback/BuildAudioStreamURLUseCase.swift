//  BuildAudioStreamURLUseCase.swift
//  MixtapeUseCase
//
//  Created by Jamie Le Souëf on 03/09/2026.
//

import MixtapeDomain

/// Track → `AudioStream` (URL + wire `PlayMethod`), per decision 40. Delegates to the repository,
/// which is the one place that both builds the URL and knows whether it will transcode (decision 23).
public nonisolated struct BuildAudioStreamURLUseCase: Sendable {
    private let repository: any PlaybackRepositoryProtocol

    public init(repository: any PlaybackRepositoryProtocol) {
        self.repository = repository
    }

    public func callAsFunction(track: MediaItem, session: UserSession, playSessionID: String) -> AudioStream {
        repository.audioStream(track: track, session: session, playSessionID: playSessionID)
    }
}

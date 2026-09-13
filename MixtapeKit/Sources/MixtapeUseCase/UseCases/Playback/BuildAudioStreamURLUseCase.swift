//  BuildAudioStreamURLUseCase.swift
//  MixtapeUseCase
//
//  Created by Jamie Le Souëf on 03/09/2026.
//

import MixtapeDomain

public nonisolated struct BuildAudioStreamURLUseCase: Sendable {
    private let repository: any PlaybackRepositoryProtocol

    public init(repository: any PlaybackRepositoryProtocol) {
        self.repository = repository
    }

    public func callAsFunction(track: MediaItem, session: UserSession, playSessionID: String) -> AudioStream {
        repository.audioStream(track: track, session: session, playSessionID: playSessionID)
    }
}

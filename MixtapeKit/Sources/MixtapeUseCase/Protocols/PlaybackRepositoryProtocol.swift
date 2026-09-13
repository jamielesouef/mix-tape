//  PlaybackRepositoryProtocol.swift
//  MixtapeUseCase
//
//  Created by Jamie Le Souëf on 03/09/2026.
//

import MixtapeDomain

public nonisolated protocol PlaybackRepositoryProtocol: Sendable {
    func resolveVideo(itemID: String, startAt: Duration, session: UserSession) async throws -> VideoSourceResolution
    func audioStream(track: MediaItem, session: UserSession, playSessionID: String) -> AudioStream
    func reportStart(_ report: PlaybackReport, session: UserSession) async throws
    func reportProgress(_ report: PlaybackReport, session: UserSession) async throws
    func reportStopped(_ report: PlaybackReport, session: UserSession) async throws
}

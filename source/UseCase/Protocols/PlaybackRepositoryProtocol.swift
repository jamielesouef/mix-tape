//  PlaybackRepositoryProtocol.swift
//  mixtape
//
//  Created by Jamie Le Souëf on 03/09/2026.
//

nonisolated protocol PlaybackRepositoryProtocol: Sendable {
    func audioStream(track: MediaItem, session: UserSession, playSessionID: String) -> AudioStream
    func reportStart(_ report: PlaybackReport, session: UserSession) async throws
    func reportProgress(_ report: PlaybackReport, session: UserSession) async throws
    func reportStopped(_ report: PlaybackReport, session: UserSession) async throws
}

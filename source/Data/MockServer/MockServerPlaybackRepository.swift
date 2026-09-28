//  MockServerPlaybackRepository.swift
//  mixtape
//
//  Created by Jamie Le Souëf on 28/09/2026.
//

import Foundation

/// Stands in for `JellyfinPlaybackRepository` behind `PlaybackRepositoryProtocol`. Every
/// track, regardless of which mock track is asked for, streams the same bundled sample —
/// `file_example_MP3_700KB.mp3` — so playback, the mini player, and Now Playing all have
/// real audio to drive against without a server.
struct MockServerPlaybackRepository: PlaybackRepositoryProtocol {
    func audioStream(track _: MediaItem, session _: UserSession, playSessionID _: String) -> AudioStream {
        AudioStream(url: Self.sampleAudioURL, playMethod: .directPlay)
    }

    func reportStart(_: PlaybackReport, session _: UserSession) async throws {}
    func reportProgress(_: PlaybackReport, session _: UserSession) async throws {}
    func reportStopped(_: PlaybackReport, session _: UserSession) async throws {}

    // MARK: - Private

    static let sampleAudioURL = Bundle.main
        .url(
            forResource: "file_example_MP3_700KB",
            withExtension: "mp3"
        )! // Bundled resource; verified present by MockServerPlaybackRepositoryTests.
}

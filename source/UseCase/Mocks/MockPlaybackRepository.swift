//  MockPlaybackRepository.swift
//  mixtape
//
//  Created by Jamie Le Souëf on 03/09/2026.
//

import Foundation

#if DEBUG
    import Foundation

    nonisolated struct MockPlaybackRepository: PlaybackRepositoryProtocol {
        var audioStreamResult: @Sendable (MediaItem, UserSession, String) -> AudioStream
        var reportStartResult: @Sendable (PlaybackReport, UserSession) async throws -> Void
        var reportProgressResult: @Sendable (PlaybackReport, UserSession) async throws -> Void
        var reportStoppedResult: @Sendable (PlaybackReport, UserSession) async throws -> Void

        init(
            audioStreamResult: @escaping @Sendable (MediaItem, UserSession, String) -> AudioStream = { track, _, _ in
                AudioStream(url: URL(string: "mock://audio/\(track.id)")!, playMethod: isNativeAudioContainer(track.container) ? .directPlay : .transcode)
            },
            reportStartResult: @escaping @Sendable (PlaybackReport, UserSession) async throws -> Void = { _, _ in },
            reportProgressResult: @escaping @Sendable (PlaybackReport, UserSession) async throws -> Void = { _, _ in },
            reportStoppedResult: @escaping @Sendable (PlaybackReport, UserSession) async throws -> Void = { _, _ in },
        ) {
            self.audioStreamResult = audioStreamResult
            self.reportStartResult = reportStartResult
            self.reportProgressResult = reportProgressResult
            self.reportStoppedResult = reportStoppedResult
        }

        func audioStream(track: MediaItem, session: UserSession, playSessionID: String) -> AudioStream {
            audioStreamResult(track, session, playSessionID)
        }

        func reportStart(_ report: PlaybackReport, session: UserSession) async throws {
            try await reportStartResult(report, session)
        }

        func reportProgress(_ report: PlaybackReport, session: UserSession) async throws {
            try await reportProgressResult(report, session)
        }

        func reportStopped(_ report: PlaybackReport, session: UserSession) async throws {
            try await reportStoppedResult(report, session)
        }
    }
#endif

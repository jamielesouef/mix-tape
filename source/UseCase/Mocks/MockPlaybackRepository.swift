//  MockPlaybackRepository.swift
//  mixtape
//
//  Created by Jamie Le Souëf on 03/09/2026.
//

import Foundation

#if DEBUG

    nonisolated struct MockPlaybackRepository: PlaybackRepositoryProtocol {
        typealias AudioStreamResult = @Sendable (MediaItem, UserSession, String) -> AudioStream
        typealias ReportResult = @Sendable (PlaybackReport, UserSession) async throws -> Void

        var audioStreamResult: AudioStreamResult
        var reportStartResult: ReportResult
        var reportProgressResult: ReportResult
        var reportStoppedResult: ReportResult

        init(
            audioStreamResult: @escaping AudioStreamResult = Self.sampleAudioStream,
            reportStartResult: @escaping ReportResult = { _, _ in },
            reportProgressResult: @escaping ReportResult = { _, _ in },
            reportStoppedResult: @escaping ReportResult = { _, _ in }
        ) {
            self.audioStreamResult = audioStreamResult
            self.reportStartResult = reportStartResult
            self.reportProgressResult = reportProgressResult
            self.reportStoppedResult = reportStoppedResult
        }

        func audioStream(
            track: MediaItem,
            session: UserSession,
            playSessionID: String
        ) -> AudioStream {
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

        // MARK: - Sample data

        /// A fake stream URL carrying the play method the real repository would choose for
        /// that container, so callers can assert on direct play versus transcode.
        static let sampleAudioStream: AudioStreamResult = { track, _, _ in
            AudioStream(
                // swiftlint:disable:next force_unwrapping
                url: URL(string: "mock://audio/\(track.id)")!, // literal URL, cannot fail
                playMethod: isNativeAudioContainer(track.container) ? .directPlay : .transcode
            )
        }
    }
#endif

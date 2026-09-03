//  MockPlaybackRepository.swift
//  MixtapeUseCase
//
//  Created by Jamie Le Souëf on 03/09/2026.
//

import Foundation
import MixtapeDomain

/// Closure-driven test double. Defaults resolve every item to one AVPlayer-native source.
public nonisolated struct MockPlaybackRepository: PlaybackRepositoryProtocol {
    public var resolveVideoResult: @Sendable (String, Duration, UserSession) async throws -> VideoSourceResolution
    public var audioStreamResult: @Sendable (MediaItem, UserSession) -> AudioStream
    public var reportStartResult: @Sendable (PlaybackReport, UserSession) async throws -> Void
    public var reportProgressResult: @Sendable (PlaybackReport, UserSession) async throws -> Void
    public var reportStoppedResult: @Sendable (PlaybackReport, UserSession) async throws -> Void

    public static let nativeSource = MediaSourceCandidate(
        id: "source-1", container: "mov", videoCodec: "h264", audioCodec: nil,
        supportsDirectPlay: true, supportsDirectStream: true, transcodingUrl: nil, runTimeTicks: 207_797_330,
    )
    public static let sampleResolution = VideoSourceResolution(playSessionID: "psid-1", sources: [nativeSource])

    public init(
        resolveVideoResult: @escaping @Sendable (String, Duration, UserSession) async throws -> VideoSourceResolution = { _, _, _ in sampleResolution },
        audioStreamResult: @escaping @Sendable (MediaItem, UserSession) -> AudioStream = { track, _ in
            AudioStream(url: URL(string: "mock://audio/\(track.id)")!, playMethod: isNativeAudioContainer(track.container) ? .directPlay : .transcode)
        },
        reportStartResult: @escaping @Sendable (PlaybackReport, UserSession) async throws -> Void = { _, _ in },
        reportProgressResult: @escaping @Sendable (PlaybackReport, UserSession) async throws -> Void = { _, _ in },
        reportStoppedResult: @escaping @Sendable (PlaybackReport, UserSession) async throws -> Void = { _, _ in },
    ) {
        self.resolveVideoResult = resolveVideoResult
        self.audioStreamResult = audioStreamResult
        self.reportStartResult = reportStartResult
        self.reportProgressResult = reportProgressResult
        self.reportStoppedResult = reportStoppedResult
    }

    public func resolveVideo(itemID: String, startAt: Duration, session: UserSession) async throws -> VideoSourceResolution {
        try await resolveVideoResult(itemID, startAt, session)
    }

    public func audioStream(track: MediaItem, session: UserSession) -> AudioStream {
        audioStreamResult(track, session)
    }

    public func reportStart(_ report: PlaybackReport, session: UserSession) async throws {
        try await reportStartResult(report, session)
    }

    public func reportProgress(_ report: PlaybackReport, session: UserSession) async throws {
        try await reportProgressResult(report, session)
    }

    public func reportStopped(_ report: PlaybackReport, session: UserSession) async throws {
        try await reportStoppedResult(report, session)
    }
}

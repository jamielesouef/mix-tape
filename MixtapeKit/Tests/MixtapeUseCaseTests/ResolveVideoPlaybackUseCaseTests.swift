//  ResolveVideoPlaybackUseCaseTests.swift
//  MixtapeUseCaseTests
//
//  Created by Jamie Le Souëf on 03/09/2026.
//

import Foundation
import MixtapeDomain
@testable import MixtapeUseCase
import Testing

@Suite(.tags(.useCase))
struct ResolveVideoPlaybackUseCaseTests {
    private let session = MockAuthRepository.sampleSession

    private func source(
        container: String, video: String? = "h264", audio: String? = "aac",
        directPlay: Bool = true, directStream: Bool = true, transcodingUrl: String? = nil, ticks: Int64? = 484_050_000,
    ) -> MediaSourceCandidate {
        MediaSourceCandidate(
            id: "src", container: container, videoCodec: video, audioCodec: audio,
            supportsDirectPlay: directPlay, supportsDirectStream: directStream, transcodingUrl: transcodingUrl, runTimeTicks: ticks,
        )
    }

    private func resolve(_ sources: [MediaSourceCandidate], startAt: Duration = .zero) async throws -> PlaybackPlan {
        let repository = MockPlaybackRepository(resolveVideoResult: { _, _, _ in VideoSourceResolution(playSessionID: "psid-9", sources: sources) })
        return try await ResolveVideoPlaybackUseCase(repository: repository)(itemID: "item-1", startAt: startAt, session: session)
    }

    @Test func `native mov with no audio track resolves to direct AVPlayer`() async throws {
        let plan = try await resolve([source(container: "mov", audio: nil)])
        #expect(plan.method == .directAVPlayer)
        #expect(plan.playMethod == .directPlay)
        #expect(plan.mediaSourceID == "src")
        #expect(plan.playSessionID == "psid-9")
        #expect(plan.totalDuration == Duration(ticks: 484_050_000))
    }

    @Test func `the stream url carries the api key device id and play session`() async throws {
        let plan = try await resolve([source(container: "mp4")])
        let components = try #require(URLComponents(url: plan.streamURL, resolvingAgainstBaseURL: false))
        let query = Dictionary(uniqueKeysWithValues: (components.queryItems ?? []).map { ($0.name, $0.value ?? "") })
        #expect(components.path == "/Videos/item-1/stream")
        #expect(query["static"] == "true")
        #expect(query["mediaSourceId"] == "src")
        #expect(query["playSessionId"] == "psid-9")
        #expect(query["deviceId"] == session.deviceID)
        #expect(query["ApiKey"] == session.accessToken)
        #expect(plan.streamURL.absoluteString.hasPrefix(session.serverURL.absoluteString))
    }

    @Test func `mkv resolves to direct VLC`() async throws {
        let plan = try await resolve([source(container: "mkv", video: "hevc", audio: "dts")])
        #expect(plan.method == .directVLC)
        #expect(plan.playMethod == .directPlay)
    }

    @Test func `mkv with no audio is still VLC`() async throws {
        #expect(try await resolve([source(container: "mkv", audio: nil)]).method == .directVLC)
    }

    @Test func `direct stream only reports DirectStream`() async throws {
        let plan = try await resolve([source(container: "mp4", directPlay: false, directStream: true)])
        #expect(plan.method == .directAVPlayer)
        #expect(plan.playMethod == .directStream)
    }

    @Test func `a transcoding url passes through verbatim as HLS`() async throws {
        let path = "/videos/item-1/master.m3u8?&DeviceId=abc&MediaSourceId=src&VideoCodec=h264&PlaySessionId=psid-9&ApiKey=tok&Tag=t1&TranscodeReasons=ContainerNotSupported"
        let plan = try await resolve([source(container: "mkv", directPlay: false, directStream: false, transcodingUrl: path)])
        #expect(plan.method == .transcodeHLS)
        #expect(plan.playMethod == .transcode)
        #expect(plan.streamURL.absoluteString == session.serverURL.absoluteString + path)
    }

    @Test func `no sources is no playable source`() async {
        await #expect(throws: MixtapeError.noPlayableSource) { try await resolve([]) }
    }

    @Test func `a source with no direct flags and no transcoding url is no playable source`() async {
        await #expect(throws: MixtapeError.noPlayableSource) {
            try await resolve([source(container: "mkv", directPlay: false, directStream: false)])
        }
    }

    @Test func `the first source wins and the start position is kept`() async throws {
        let plan = try await resolve([source(container: "mp4"), source(container: "mkv")], startAt: .seconds(30))
        #expect(plan.method == .directAVPlayer)
        #expect(plan.startPosition == .seconds(30))
    }

    @Test(arguments: [MixtapeError.sessionExpired, .serverUnreachable])
    func `repository errors propagate`(error: MixtapeError) async {
        let repository = MockPlaybackRepository(resolveVideoResult: { _, _, _ in throw error })
        await #expect(throws: error) {
            try await ResolveVideoPlaybackUseCase(repository: repository)(itemID: "item-1", startAt: .zero, session: session)
        }
    }
}

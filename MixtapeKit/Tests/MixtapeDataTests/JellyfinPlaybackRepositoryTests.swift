//  JellyfinPlaybackRepositoryTests.swift
//  MixtapeDataTests
//
//  Created by Jamie Le Souëf on 03/09/2026.
//

import Foundation
@testable import MixtapeData
import MixtapeDomain
import MixtapeInfrastructure
import Testing

@Suite(.tags(.repository))
struct JellyfinPlaybackRepositoryTests {
    private let stub = StubServer()
    private func repository(profile: DeviceProfile = .permissive) -> JellyfinPlaybackRepository {
        JellyfinPlaybackRepository(client: JellyfinHTTPClient(session: stub.session, deviceName: "Test iPhone"), appVersion: "1.0", deviceProfile: profile)
    }

    private let session = UserSession(
        serverURL: URL(string: "http://localhost:8096")!, // test constant
        userID: "user-1", userName: "jamie", accessToken: "tok-1", deviceID: "device-1",
    )

    @Test func `avatar resolves to one native source with no audio stream`() async throws {
        try stub.respond(status: 200, body: Fixture.data("playback-info-avatar-direct"))
        let resolution = try await repository().resolveVideo(itemID: "avatar", startAt: .zero, session: session)
        #expect(resolution.playSessionID.isEmpty == false)
        let source = try #require(resolution.sources.first)
        #expect(source.container == "mov")
        #expect(source.videoCodec == "h264")
        #expect(source.audioCodec == nil)
        #expect(source.supportsDirectPlay)
        #expect(source.supportsDirectStream)
        #expect(source.transcodingUrl == nil)
        #expect(source.runTimeTicks == 207_797_330)
        #expect(isAVPlayerNative(container: source.container, videoCodec: source.videoCodec, audioCodec: source.audioCodec))
    }

    @Test func `the forced transcode response carries the transcoding url`() async throws {
        try stub.respond(status: 200, body: Fixture.data("playback-info-f1-transcode"))
        let source = try #require(try await repository(profile: .forceTranscode).resolveVideo(itemID: "f1", startAt: .zero, session: session).sources.first)
        #expect(source.container == "mkv")
        #expect(source.audioCodec == "aac")
        #expect(source.supportsDirectPlay == false)
        #expect(source.supportsDirectStream == false)
        #expect(source.transcodingUrl?.hasPrefix("/videos/") == true)
        #expect(source.transcodingUrl?.contains("master.m3u8") == true)
    }

    @Test func `the request posts the device profile with the user id`() async throws {
        try stub.respond(status: 200, body: Fixture.data("playback-info-f1-direct"))
        _ = try await repository().resolveVideo(itemID: "f1", startAt: .seconds(30), session: session)
        #expect(stub.lastRequest?.httpMethod == "POST")
        #expect(stub.lastRequest?.url?.path() == "/Items/f1/PlaybackInfo")
        #expect(stub.lastRequest?.url?.query() == "userId=user-1")
        let body = try #require(stub.lastBody())
        #expect(body.contains(#""Container":"mp4,m4v,mov,mkv,webm""#))
        #expect(body.contains(#""VideoCodec":"h264,hevc,vp9,av1""#))
        #expect(body.contains(#""Protocol":"hls""#))
        #expect(body.contains(#""StartTimeTicks":300000000"#))
        #expect(body.contains(#""EnableTranscoding":true"#))
    }

    @Test func `a response without a play session is a decoding error`() async {
        stub.respond(status: 200, json: #"{"MediaSources":[]}"#)
        await #expect(throws: MixtapeError.decoding) {
            try await repository().resolveVideo(itemID: "x", startAt: .zero, session: session)
        }
    }

    @Test func `report start posts the shared body`() async throws {
        stub.respond(status: 204)
        let report = PlaybackReport(itemID: "item-1", mediaSourceID: "src", playSessionID: "psid", position: .seconds(30), isPaused: false, method: .transcodeHLS, playMethod: .transcode)
        try await repository().reportStart(report, session: session)
        #expect(stub.lastRequest?.url?.path() == "/Sessions/Playing")
        #expect(stub.lastBody() == #"{"CanSeek":true,"IsPaused":false,"ItemId":"item-1","MediaSourceId":"src","PlayMethod":"Transcode","PlaySessionId":"psid","PositionTicks":300000000}"#)
    }

    @Test func `report start rethrows a server failure`() async {
        stub.respond(status: 503)
        let report = PlaybackReport(itemID: "item-1", mediaSourceID: "src", playSessionID: "psid", position: .zero, isPaused: false, method: .directAVPlayer, playMethod: .directPlay)
        await #expect(throws: MixtapeError.self) {
            try await repository().reportStart(report, session: session)
        }
    }
}

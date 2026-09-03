//  JellyfinAudioStreamTests.swift
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
struct JellyfinAudioStreamTests {
    private let session = UserSession(
        serverURL: URL(string: "http://localhost:8096")!, // test constant
        userID: "user-1", userName: "jamie", accessToken: "tok-1", deviceID: "device-1",
    )

    private func repository() -> JellyfinPlaybackRepository {
        JellyfinPlaybackRepository(client: JellyfinHTTPClient(session: StubServer().session, deviceName: "Test iPhone"), appVersion: "1.0", deviceProfile: .permissive)
    }

    private func track(id: String, container: String?) -> MediaItem {
        MediaItem(
            id: id, name: "Song", kind: .audio, overview: nil, productionYear: nil, runtime: .seconds(200), indexNumber: 1, parentIndexNumber: 1,
            seriesName: nil, albumArtist: "Artist", primaryImageTag: nil, backdropImageTag: nil, parentPrimaryImageTag: "a1", albumID: "album-1", container: container,
            playback: PlaybackState(position: .zero, isWatched: false),
        )
    }

    @Test func `the universal url carries the container list, ApiKey and no bitrate cap`() throws {
        let stream = repository().audioStream(track: track(id: "t1", container: "flac"), session: session)
        let components = try #require(URLComponents(url: stream.url, resolvingAgainstBaseURL: false))
        let query = Dictionary(uniqueKeysWithValues: (components.queryItems ?? []).map { ($0.name, $0.value ?? "") })
        #expect(components.path == "/Audio/t1/universal")
        #expect(query["userId"] == "user-1")
        #expect(query["deviceId"] == "device-1")
        #expect(query["container"] == "flac,alac,m4a,mp3,aac,wav,aiff")
        #expect(query["transcodingContainer"] == "ts")
        #expect(query["transcodingProtocol"] == "hls")
        #expect(query["audioCodec"] == "aac")
        #expect(query["ApiKey"] == "tok-1")
        // decision 43: no bitrate cap parameter at all.
        #expect(query["maxStreamingBitrate"] == nil)
        #expect(stream.playMethod == .directPlay)
    }

    @Test func `an exotic container reports transcode`() {
        #expect(repository().audioStream(track: track(id: "t2", container: "opus"), session: session).playMethod == .transcode)
    }
}

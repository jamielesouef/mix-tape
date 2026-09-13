//  JellyfinPlaybackRepositoryTests.swift
//  mixtape
//
//  Created by Jamie Le Souëf on 03/09/2026.
//

import Foundation
@testable import Mixtape
import Testing

@Suite(.tags(.repository))
struct JellyfinPlaybackRepositoryTests {
    private let stub = StubServer()
    private func repository() -> JellyfinPlaybackRepository {
        JellyfinPlaybackRepository(client: JellyfinHTTPClient(session: stub.session, deviceName: "Test iPhone"), appVersion: "1.0")
    }

    private let session = UserSession(
        serverURL: URL(string: "http://localhost:8096")!,
        userID: "user-1", userName: "jamie", accessToken: "tok-1", deviceID: "device-1",
    )

    @Test func `report start posts the shared body`() async throws {
        stub.respond(status: 204)
        let report = PlaybackReport(
            itemID: "item-1", mediaSourceID: "src", playSessionID: "psid",
            position: .seconds(30), isPaused: false, playMethod: .transcode,
        )
        try await repository().reportStart(report, session: session)
        #expect(stub.lastRequest?.url?.path() == "/Sessions/Playing")
        #expect(stub.lastBody() == #"{"CanSeek":true,"IsPaused":false,"ItemId":"item-1","MediaSourceId":"src","PlayMethod":"Transcode","PlaySessionId":"psid","PositionTicks":300000000}"#)
    }

    @Test func `report start rethrows a server failure`() async {
        stub.respond(status: 503)
        let report = PlaybackReport(
            itemID: "item-1", mediaSourceID: "src", playSessionID: "psid",
            position: .zero, isPaused: false, playMethod: .directPlay,
        )
        await #expect(throws: MixtapeError.self) {
            try await repository().reportStart(report, session: session)
        }
    }
}

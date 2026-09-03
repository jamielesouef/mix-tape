//  JellyfinAuthRepositoryTests.swift
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
struct JellyfinAuthRepositoryTests {
    private let stub = StubServer()
    private var repository: JellyfinAuthRepository {
        JellyfinAuthRepository(
            client: JellyfinHTTPClient(session: stub.session, deviceName: "Test iPhone"),
            deviceID: "device-1",
            appVersion: "1.0",
        )
    }

    private let baseURL = URL(string: "http://localhost:8096")! // test constant
    private var server: ServerIdentity {
        ServerIdentity(id: "srv", name: "mixtape", version: "10.11.11", baseURL: baseURL)
    }

    private let authResult = #"{"AccessToken":"tok-1","User":{"Id":"user-1","Name":"jamie"},"ServerId":"srv"}"#

    @Test func `server identity maps the public info`() async throws {
        stub.respond(status: 200, body: Data(#"{"Id":"srv","ServerName":"mixtape","Version":"10.11.11","LocalAddress":"http://x"}"#.utf8))
        let identity = try await repository.serverIdentity(at: baseURL)
        #expect(identity == server)
        #expect(stub.lastRequest?.url?.path() == "/System/Info/Public")
        #expect(stub.lastRequest?.value(forHTTPHeaderField: "Authorization")?.contains("Token=") == false)
    }

    @Test(arguments: [
        #"{"ServerName":"mixtape","Version":"10.11.11"}"#,
        #"{"Id":"srv","Version":"10.11.11"}"#,
        #"{"Id":"srv","ServerName":"mixtape","Version":null}"#,
    ])
    func `null identity field is not A jellyfin server`(json: String) async {
        stub.respond(status: 200, body: Data(json.utf8))
        await #expect(throws: MixtapeError.notAJellyfinServer) {
            try await repository.serverIdentity(at: baseURL)
        }
    }

    @Test func `authenticate sends username and pw and maps the session`() async throws {
        stub.respond(status: 200, body: Data(authResult.utf8))
        let session = try await repository.authenticate(userName: "jamie", password: "pw", server: server)
        #expect(session == UserSession(serverURL: baseURL, userID: "user-1", userName: "jamie", accessToken: "tok-1", deviceID: "device-1"))
        #expect(stub.lastRequest?.url?.path() == "/Users/AuthenticateByName")
        #expect(stub.lastBody() == #"{"Username":"jamie","Pw":"pw"}"#)
    }

    @Test func `authenticate without A token is A decoding error`() async {
        stub.respond(status: 200, body: Data(#"{"User":{"Id":"user-1","Name":"jamie"}}"#.utf8))
        await #expect(throws: MixtapeError.decoding) {
            try await repository.authenticate(userName: "jamie", password: "pw", server: server)
        }
    }

    @Test(arguments: [("true", true), ("false", false)])
    func `quick connect enabled decodes A bare boolean`(json: String, expected: Bool) async throws {
        stub.respond(status: 200, body: Data(json.utf8))
        #expect(try await repository.isQuickConnectEnabled(server: server) == expected)
        #expect(stub.lastRequest?.value(forHTTPHeaderField: "Authorization")?.hasPrefix("MediaBrowser ") == true)
    }

    @Test func `initiate is A post carrying the device id`() async throws {
        stub.respond(status: 200, body: Data(#"{"Authenticated":false,"Secret":"s3cret","Code":"426349"}"#.utf8))
        let handshake = try await repository.initiateQuickConnect(server: server)
        #expect(handshake == QuickConnectHandshake(secret: "s3cret", code: "426349"))
        #expect(stub.lastRequest?.httpMethod == "POST")
        #expect(stub.lastRequest?.url?.path() == "/QuickConnect/Initiate")
        #expect(stub.lastRequest?.value(forHTTPHeaderField: "Authorization")?.contains(#"DeviceId="device-1""#) == true)
    }

    @Test func `quick connect state reads authenticated`() async throws {
        stub.respond(status: 200, body: Data(#"{"Authenticated":true,"Secret":"s3cret","Code":"426349"}"#.utf8))
        #expect(try await repository.quickConnectState(secret: "s3cret", server: server))
        #expect(stub.lastRequest?.url?.query() == "secret=s3cret")
        stub.respond(status: 200, body: Data(#"{"Authenticated":false}"#.utf8))
        #expect(try await repository.quickConnectState(secret: "s3cret", server: server) == false)
    }

    @Test func `authenticate with quick connect sends the secret`() async throws {
        stub.respond(status: 200, body: Data(authResult.utf8))
        let session = try await repository.authenticateWithQuickConnect(secret: "s3cret", server: server)
        #expect(session.accessToken == "tok-1")
        #expect(stub.lastRequest?.url?.path() == "/Users/AuthenticateWithQuickConnect")
        #expect(stub.lastBody() == #"{"Secret":"s3cret"}"#)
    }
}

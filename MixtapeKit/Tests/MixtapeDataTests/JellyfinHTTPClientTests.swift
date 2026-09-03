//  JellyfinHTTPClientTests.swift
//  MixtapeDataTests
//
//  Created by Jamie Le Souëf on 03/09/2026.
//

import Foundation
import MixtapeDomain
@testable import MixtapeInfrastructure
import Testing

@Suite(.serialized, .tags(.repository))
struct JellyfinHTTPClientTests {
    private let client = JellyfinHTTPClient(session: StubURLProtocol.session(), deviceName: "Test iPhone")
    private let base = URL(string: "http://localhost:8096")! // test constant
    private var signedIn: AuthContext {
        AuthContext(baseURL: base, deviceID: "device-1", appVersion: "1.0", token: "tok")
    }

    private var signedOut: AuthContext {
        AuthContext(baseURL: base, deviceID: "device-1", appVersion: "1.0", token: nil)
    }

    private func get(_ path: String, auth: AuthContext? = nil) async throws -> PascalCaseFixture {
        try await client.get(path, auth: auth ?? signedIn)
    }

    private func error(_ path: String) async -> MixtapeError? {
        do { _ = try await get(path); return nil } catch let error as MixtapeError { return error } catch { return nil }
    }

    // MARK: Status-code table

    @Test(arguments: [
        ("/Users/AuthenticateByName", MixtapeError.invalidCredentials),
        ("/Users/AuthenticateWithQuickConnect", .invalidCredentials),
        ("/QuickConnect/Enabled", .quickConnectUnavailable),
        ("/QuickConnect/Initiate", .quickConnectUnavailable),
        ("/Items", .sessionExpired),
        ("/UserItems/Resume", .sessionExpired),
    ])
    func unauthorised(path: String, expected: MixtapeError) async {
        StubURLProtocol.respond(status: 401)
        #expect(await error(path) == expected)
    }

    @Test(arguments: [400, 403, 404, 405, 415, 500, 503])
    func `other failures are transport`(status: Int) async {
        StubURLProtocol.respond(status: status)
        guard case .transport = await error("/Items") else {
            Issue.record("\(status) did not map to .transport")
            return
        }
    }

    @Test func `two hundred range is success for fire and forget`() async throws {
        StubURLProtocol.respond(status: 204)
        try await client.post("/Sessions/Playing/Stopped", body: EmptyBody(), auth: signedIn)
        #expect(StubURLProtocol.lastRequest?.httpMethod == "POST")
    }

    @Test(arguments: [URLError.Code.cannotFindHost, .cannotConnectToHost, .timedOut])
    func `unreachable codes`(code: URLError.Code) async {
        StubURLProtocol.fail(code)
        #expect(await error("/System/Info/Public") == .serverUnreachable)
    }

    @Test func `other URL errors are transport`() async {
        StubURLProtocol.fail(.networkConnectionLost)
        guard case .transport = await error("/Items") else {
            Issue.record("networkConnectionLost did not map to .transport")
            return
        }
    }

    @Test func `undecodable body is decoding error`() async {
        StubURLProtocol.respond(status: 200, body: Data("not json".utf8))
        #expect(await error("/System/Info/Public") == .decoding)
    }

    // MARK: Header

    @Test func `header with token is exact`() async throws {
        StubURLProtocol.respond(status: 200, body: Data(#"{"ServerName":"mixtape","Version":"10.11.11"}"#.utf8))
        _ = try await get("/System/Info", auth: signedIn)
        let header = StubURLProtocol.lastRequest?.value(forHTTPHeaderField: "Authorization")
        #expect(header == #"MediaBrowser Client="mixtape", Device="Test iPhone", DeviceId="device-1", Version="1.0", Token="tok""#)
        #expect(StubURLProtocol.lastRequest?.value(forHTTPHeaderField: "X-Emby-Authorization") == nil)
    }

    @Test func `header without token omits the component`() async throws {
        StubURLProtocol.respond(status: 200, body: Data(#"{"ServerName":"mixtape","Version":"10.11.11"}"#.utf8))
        _ = try await get("/System/Info/Public", auth: signedOut)
        let header = StubURLProtocol.lastRequest?.value(forHTTPHeaderField: "Authorization")
        #expect(header == #"MediaBrowser Client="mixtape", Device="Test iPhone", DeviceId="device-1", Version="1.0""#)
    }

    // MARK: Request assembly and decoding

    @Test func `pascal case decodes through explicit coding keys`() async throws {
        StubURLProtocol.respond(status: 200, body: Data(#"{"ServerName":"mixtape","Version":"10.11.11","Id":"abc"}"#.utf8))
        let decoded = try await get("/System/Info/Public")
        #expect(decoded == PascalCaseFixture(serverName: "mixtape", version: "10.11.11"))
    }

    @Test func `path and query are appended to the base URL`() async throws {
        StubURLProtocol.respond(status: 200, body: Data(#"{"ServerName":"m","Version":"v"}"#.utf8))
        let query = [URLQueryItem(name: "userId", value: "u1"), URLQueryItem(name: "limit", value: "20")]
        _ = try await client.get("/Items", query: query, auth: signedIn) as PascalCaseFixture
        #expect(StubURLProtocol.lastRequest?.url?.absoluteString == "http://localhost:8096/Items?userId=u1&limit=20")
        #expect(StubURLProtocol.lastRequest?.httpMethod == "GET")
    }

    @Test func `post encodes the body as JSON`() async throws {
        struct Body: Encodable { let Username: String } // PascalCase key by name, as a DTO's CodingKeys would
        StubURLProtocol.respond(status: 200, body: Data(#"{"ServerName":"m","Version":"v"}"#.utf8))
        _ = try await client.post("/Users/AuthenticateByName", body: Body(Username: "jamie"), auth: signedOut) as PascalCaseFixture
        let request = StubURLProtocol.lastRequest
        #expect(request?.value(forHTTPHeaderField: "Content-Type") == "application/json")
        let sent = request?.httpBody ?? (request?.httpBodyStream).map { stream -> Data in
            stream.open(); defer { stream.close() }
            var data = Data(); var buffer = [UInt8](repeating: 0, count: 1024)
            while stream.hasBytesAvailable {
                let n = stream.read(&buffer, maxLength: buffer.count); if n <= 0 {
                    break
                }; data.append(buffer, count: n)
            }
            return data
        }
        #expect(sent.map { String(decoding: $0, as: UTF8.self) } == #"{"Username":"jamie"}"#)
    }
}

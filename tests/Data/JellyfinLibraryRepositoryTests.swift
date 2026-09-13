//  JellyfinLibraryRepositoryTests.swift
//  mixtape
//
//  Created by Jamie Le Souëf on 03/09/2026.
//

import Foundation
@testable import Mixtape
import Testing

@Suite(.tags(.repository))
struct JellyfinLibraryRepositoryTests {
    private let stub = StubServer()
    private var repository: JellyfinLibraryRepository {
        JellyfinLibraryRepository(client: JellyfinHTTPClient(session: stub.session, deviceName: "Test iPhone"), appVersion: "1.0")
    }

    private let session = UserSession(
        serverURL: URL(string: "http://localhost:8096")!,
        userID: "user-1", userName: "jamie", accessToken: "tok-1", deviceID: "device-1",
    )

    private var query: [String: String] {
        let items = URLComponents(url: stub.lastRequest!.url!, resolvingAgainstBaseURL: false)!.queryItems ?? []
        return Dictionary(uniqueKeysWithValues: items.map { ($0.name, $0.value ?? "") })
    }

    @Test func `libraries map collection types and send the user id and token`() async throws {
        try stub.respond(status: 200, body: Fixture.data("user-views"))
        let libraries = try await repository.libraries(session: session)
        #expect(libraries.map(\.kind) == [.unsupported, .music])
        #expect(libraries.map(\.name) == ["Movies", "Music"])
        #expect(libraries.allSatisfy { $0.imageTag != nil })
        #expect(stub.lastRequest?.url?.path() == "/UserViews")
        #expect(query["userId"] == "user-1")
        #expect(stub.lastRequest?.value(forHTTPHeaderField: "Authorization")?.contains(#"Token="tok-1""#) == true)
    }

    @Test func `unsupported collection types map to unsupported`() async throws {
        stub.respond(status: 200, json: #"{"Items":[{"Id":"b","Name":"Books","Type":"CollectionFolder","CollectionType":"books"},{"Id":"f","Name":"Folder","Type":"CollectionFolder"}],"TotalRecordCount":2}"#)
        let libraries = try await repository.libraries(session: session)
        #expect(libraries.map(\.kind) == [.unsupported, .unsupported])
    }

    @Test func `album page maps album artist and year`() async throws {
        try stub.respond(status: 200, body: Fixture.data("items-albums"))
        let page = try await repository.items(in: "lib-music", kind: .musicAlbum, page: PageRequest(startIndex: 0, limit: 60), session: session)
        #expect(page.totalCount == 5)
        #expect(page.items.first?.kind == .musicAlbum)
        #expect(page.items.first?.albumArtist == "Sleep Token")
        #expect(page.items.first?.productionYear == 2025)
        #expect(query["includeItemTypes"] == "MusicAlbum")
    }

    @Test func `tracks carry the album id and album art and are sorted by disc and track`() async throws {
        try stub.respond(status: 200, body: Fixture.data("items-tracks"))
        let tracks = try await repository.tracks(albumID: "album-1", session: session)
        #expect(tracks.count == 10)
        let first = try #require(tracks.first)
        #expect(first.kind == .audio)
        #expect(first.indexNumber == 1)
        #expect(first.parentIndexNumber == 1)
        #expect(first.primaryImageTag == nil)
        #expect(first.albumID != nil)
        #expect(first.parentPrimaryImageTag != nil)
        #expect(first.displayTitle == "1. Look To Windward")
        let q = query
        #expect(q["parentId"] == "album-1")
        #expect(q["includeItemTypes"] == "Audio")
        #expect(q["sortBy"] == "ParentIndexNumber,IndexNumber,SortName")
    }

    @Test func `item detail maps the resume position and keeps fields`() async throws {
        stub.respond(status: 200, json: #"{"Id":"album-1","Name":"Even In Arcadia","Type":"MusicAlbum","UserData":{"PlaybackPositionTicks":300000000}}"#)
        let item = try await repository.item(id: "album-1", session: session)
        #expect(item.name == "Even In Arcadia")
        #expect(item.playback.position == .seconds(30))
        #expect(item.playback.hasResumePoint)
        #expect(stub.lastRequest?.url?.path() == "/Items/album-1")
        #expect(query["fields"] == "Overview,MediaSources")
    }

    @Test func `unknown item type on detail is a decoding error`() async {
        stub.respond(status: 200, json: #"{"Id":"v","Name":"Clip","Type":"Video"}"#)
        await #expect(throws: MixtapeError.decoding) {
            try await repository.item(id: "v", session: session)
        }
    }

    @Test func `a 401 on a library call is session expiry`() async {
        stub.respond(status: 401)
        await #expect(throws: MixtapeError.sessionExpired) {
            try await repository.libraries(session: session)
        }
    }
}

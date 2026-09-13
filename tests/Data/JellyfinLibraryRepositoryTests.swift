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
        #expect(libraries.map(\.kind) == [.movies, .music])
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

    @Test func `movie page maps items and sends the corrected items query`() async throws {
        try stub.respond(status: 200, body: Fixture.data("items-movies"))
        let page = try await repository.items(in: "lib-1", kind: .movie, page: PageRequest(startIndex: 60, limit: 60), session: session)
        #expect(page.totalCount == 2)
        #expect(page.startIndex == 0)
        #expect(page.items.map(\.name) == ["Avatar: Fire and Ash", "F1"])
        let f1 = page.items[1]
        #expect(f1.kind == .movie)
        #expect(f1.productionYear == 2025)
        #expect(f1.runtime == Duration(ticks: 484_050_000))
        #expect(f1.primaryImageTag != nil)
        #expect(f1.backdropImageTag != nil)
        #expect(f1.playback.isWatched == false)
        #expect(stub.lastRequest?.url?.path() == "/Items")
        let q = query
        #expect(q["userId"] == "user-1")
        #expect(q["parentId"] == "lib-1")
        #expect(q["includeItemTypes"] == "Movie")
        #expect(q["recursive"] == "true")
        #expect(q["sortBy"] == "SortName")
        #expect(q["startIndex"] == "60")
        #expect(q["limit"] == "60")
        #expect(q["enableImageTypes"] == "Primary,Backdrop")
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
        try stub.respond(status: 200, body: Fixture.data("item-detail-movie"))
        let item = try await repository.item(id: "f1", session: session)
        #expect(item.name == "F1")
        #expect(item.playback.position == .seconds(30))
        #expect(item.playback.hasResumePoint)
        #expect(stub.lastRequest?.url?.path() == "/Items/f1")
        #expect(query["fields"] == "Overview,MediaSources")
    }

    @Test func `continue watching calls user items resume`() async throws {
        try stub.respond(status: 200, body: Fixture.data("user-items-resume"))
        let items = try await repository.continueWatching(session: session)
        #expect(items.map(\.name) == ["F1"])
        #expect(items.first?.playback.position == .seconds(30))
        #expect(stub.lastRequest?.url?.path() == "/UserItems/Resume")
        let q = query
        #expect(q["userId"] == "user-1")
        #expect(q["mediaTypes"] == "Video")
        #expect(q["limit"] == "12")
    }

    @Test func `seasons map from the hand-authored fixture`() async throws {
        try stub.respond(status: 200, body: Fixture.data("shows-seasons.hand-authored"))
        let seasons = try await repository.seasons(seriesID: "series-0001", session: session)
        #expect(seasons.map(\.kind) == [.season, .season])
        #expect(seasons.map(\.indexNumber) == [1, 2])
        #expect(seasons[1].playback.isWatched)
        #expect(stub.lastRequest?.url?.path() == "/Shows/series-0001/Seasons")
        #expect(query["userId"] == "user-1")
    }

    @Test func `episodes send both ids and the explicit sort`() async throws {
        try stub.respond(status: 200, body: Fixture.data("shows-episodes.hand-authored"))
        let episodes = try await repository.episodes(seriesID: "series-0001", seasonID: "season-0001", session: session)
        #expect(episodes.map(\.displayTitle) == ["S1E1 · Pilot", "S1E2 · Second"])
        #expect(episodes[0].playback.position == .seconds(600))
        #expect(episodes[0].seriesName == "The Show")
        #expect(stub.lastRequest?.url?.path() == "/Shows/series-0001/Episodes")
        let q = query
        #expect(q["seasonId"] == "season-0001")
        #expect(q["sortBy"] == "ParentIndexNumber,IndexNumber")
        #expect(q["userId"] == "user-1")
    }

    @Test func `unknown item types are dropped from a list`() async throws {
        stub.respond(status: 200, json: #"{"Items":[{"Id":"v","Name":"Clip","Type":"Video"},{"Id":"m","Name":"Film","Type":"Movie"}],"TotalRecordCount":2,"StartIndex":0}"#)
        let items = try await repository.continueWatching(session: session)
        #expect(items.map(\.id) == ["m"])
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

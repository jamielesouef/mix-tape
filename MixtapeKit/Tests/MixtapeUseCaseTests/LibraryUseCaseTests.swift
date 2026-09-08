//  LibraryUseCaseTests.swift
//  MixtapeUseCaseTests
//
//  Created by Jamie Le Souëf on 03/09/2026.
//

import MixtapeDomain
@testable import MixtapeUseCase
import Testing

@Suite(.tags(.useCase))
struct LibraryUseCaseTests {
    private let session = MockAuthRepository.sampleSession

    @Test func `fetch libraries filters unsupported`() async throws {
        let libraries = try await FetchLibrariesUseCase(repository: MockLibraryRepository())(session: session)
        #expect(libraries.map(\.kind) == [.movies, .tvShows, .music])
    }

    @Test func `fetch library items passes library kind and page through`() async throws {
        let recorder = Recorder()
        let repository = MockLibraryRepository(itemsResult: { id, kind, page, _ in
            recorder.append("\(id) \(kind) \(page.startIndex) \(page.limit)")
            return Page(items: [], totalCount: 0, startIndex: page.startIndex)
        })
        let page = try await FetchLibraryItemsUseCase(repository: repository)(libraryID: "lib", kind: .series, page: PageRequest(startIndex: 60, limit: 60), session: session)
        #expect(page.startIndex == 60)
        #expect(recorder.urls == ["lib series 60 60"])
    }

    @Test func `fetch item detail returns the item`() async throws {
        let item = try await FetchItemDetailUseCase(repository: MockLibraryRepository())(id: "album-1", session: session)
        #expect(item.id == "album-1")
    }

    @Test func `fetch seasons passes the series id`() async throws {
        let recorder = Recorder()
        let repository = MockLibraryRepository(seasonsResult: { id, _ in
            recorder.append(id)
            return MockLibraryRepository.sampleSeasons
        })
        _ = try await FetchSeasonsUseCase(repository: repository)(seriesID: "series-1", session: session)
        #expect(recorder.urls == ["series-1"])
    }

    @Test func `fetch episodes passes both ids`() async throws {
        let recorder = Recorder()
        let repository = MockLibraryRepository(episodesResult: { series, season, _ in
            recorder.append("\(series)/\(season)")
            return MockLibraryRepository.sampleEpisodes
        })
        let episodes = try await FetchEpisodesUseCase(repository: repository)(seriesID: "series-1", seasonID: "season-2", session: session)
        #expect(episodes.count == 2)
        #expect(recorder.urls == ["series-1/season-2"])
    }

    @Test func `fetch album tracks passes the album id`() async throws {
        let recorder = Recorder()
        let repository = MockLibraryRepository(tracksResult: { id, _ in
            recorder.append(id)
            return MockLibraryRepository.sampleTracks
        })
        let tracks = try await FetchAlbumTracksUseCase(repository: repository)(albumID: "album-1", session: session)
        #expect(tracks.count == 2)
        #expect(recorder.urls == ["album-1"])
    }

    @Test func `fetch continue watching returns the resume row`() async throws {
        let items = try await FetchContinueWatchingUseCase(repository: MockLibraryRepository())(session: session)
        #expect(items.map(\.id) == ["movie-2", "episode-2"])
    }

    @Test(arguments: [MixtapeError.sessionExpired, .serverUnreachable])
    func `repository errors propagate unchanged`(error: MixtapeError) async {
        let repository = MockLibraryRepository(
            librariesResult: { _ in throw error },
            itemsResult: { _, _, _, _ in throw error },
            continueWatchingResult: { _ in throw error },
        )
        await #expect(throws: error) { try await FetchLibrariesUseCase(repository: repository)(session: session) }
        await #expect(throws: error) {
            try await FetchLibraryItemsUseCase(repository: repository)(libraryID: "lib", kind: .movie, page: PageRequest(startIndex: 0, limit: 60), session: session)
        }
        await #expect(throws: error) { try await FetchContinueWatchingUseCase(repository: repository)(session: session) }
    }
}

//  LibraryServiceTests.swift
//  MixtapeServicesTests
//
//  Created by Jamie Le Souëf on 03/09/2026.
//

import Foundation
import MixtapeDomain
@testable import MixtapeServices
import MixtapeUseCase
import Testing

@Suite(.tags(.service))
@MainActor
struct LibraryServiceTests {
    private let movies = MockLibraryRepository.sampleLibraries[0]

    private func makeService(repository: MockLibraryRepository = MockLibraryRepository(), sessionService: SessionService = MockSessionService.signedIn()) -> LibraryService {
        MockLibraryService.make(repository: repository, sessionService: sessionService)
    }

    /// A repository whose items call returns `count` synthetic movies per page and records each request.
    private func pagingRepository(pageSizes: [Int], total: Int, recorder: Recorder) -> MockLibraryRepository {
        let calls = Counter()
        return MockLibraryRepository(itemsResult: { _, _, page, _ in
            let call = calls.next()
            recorder.append("\(page.startIndex)/\(page.limit)")
            let count = call < pageSizes.count ? pageSizes[call] : 0
            let items = (0 ..< count).map { offset in Self.movie("m\(page.startIndex + offset)") }
            return Page(items: items, totalCount: total, startIndex: page.startIndex)
        })
    }

    @Test func `load home loads libraries and continue watching`() async {
        let service = makeService()
        await service.loadHome()
        #expect(service.libraries == .loaded(MockLibraryRepository.sampleLibraries.filter { $0.kind != .unsupported }))
        #expect(service.continueWatching == .loaded(MockLibraryRepository.sampleContinueWatching))
    }

    @Test func `load home failure lands in failed`() async {
        let service = makeService(repository: MockLibraryRepository(continueWatchingResult: { _ in throw MixtapeError.serverUnreachable }))
        await service.loadHome()
        #expect(service.libraries.isLoaded)
        #expect(service.continueWatching == .failed(.serverUnreachable))
    }

    @Test func `load library requests the first page of sixty`() async {
        let recorder = Recorder()
        let service = makeService(repository: pagingRepository(pageSizes: [60], total: 120, recorder: recorder))
        await service.loadLibrary(id: movies.id)
        #expect(recorder.urls == ["0/60"])
        guard case let .loaded(page) = service.pages[movies.id] else { Issue.record("not loaded"); return }
        #expect(page.items.count == 60)
        #expect(page.totalCount == 120)
    }

    @Test func `load more advances start index by the returned count and appends`() async {
        let recorder = Recorder()
        let service = makeService(repository: pagingRepository(pageSizes: [60, 60], total: 120, recorder: recorder))
        await service.loadLibrary(id: movies.id)
        await service.loadMore(libraryID: movies.id)
        #expect(recorder.urls == ["0/60", "60/60"])
        guard case let .loaded(page) = service.pages[movies.id] else { Issue.record("not loaded"); return }
        #expect(page.items.count == 120)
        #expect(page.items.last?.id == "m119")
        #expect(page.startIndex == 0)
    }

    @Test func `a short page stops further loading`() async {
        let recorder = Recorder()
        let service = makeService(repository: pagingRepository(pageSizes: [60, 12], total: 72, recorder: recorder))
        await service.loadLibrary(id: movies.id)
        await service.loadMore(libraryID: movies.id)
        await service.loadMore(libraryID: movies.id)
        await service.loadMore(libraryID: movies.id)
        #expect(recorder.urls == ["0/60", "60/60"])
        guard case let .loaded(page) = service.pages[movies.id] else { Issue.record("not loaded"); return }
        #expect(page.items.count == 72)
    }

    @Test func `a full first page that is the whole library stops loading`() async {
        let recorder = Recorder()
        let service = makeService(repository: pagingRepository(pageSizes: [60], total: 60, recorder: recorder))
        await service.loadLibrary(id: movies.id)
        await service.loadMore(libraryID: movies.id)
        #expect(recorder.urls == ["0/60"])
    }

    @Test func `load more is a no-op while a load is in flight`() async {
        let recorder = Recorder()
        let gate = Gate()
        let repository = MockLibraryRepository(itemsResult: { _, _, page, _ in
            recorder.append("\(page.startIndex)")
            await gate.wait()
            return Page(items: (0 ..< 60).map { Self.movie("m\($0 + page.startIndex)") }, totalCount: 600, startIndex: page.startIndex)
        })
        let service = makeService(repository: repository)
        await service.loadLibrary(id: movies.id)
        gate.close()
        let first = Task { await service.loadMore(libraryID: movies.id) }
        await Task.yield()
        await service.loadMore(libraryID: movies.id) // returns at once: the first is still in flight
        gate.open()
        await first.value
        #expect(recorder.urls == ["0", "60"])
    }

    @Test func `load library is a no-op when the page is already loaded`() async {
        let recorder = Recorder()
        let service = makeService(repository: pagingRepository(pageSizes: [60, 60], total: 120, recorder: recorder))
        await service.loadLibrary(id: movies.id)
        await service.loadLibrary(id: movies.id)
        #expect(recorder.urls == ["0/60"])
    }

    @Test func `load library failure lands in failed and retry reloads`() async {
        let attempts = Counter()
        let repository = MockLibraryRepository(itemsResult: { _, _, page, _ in
            if attempts.next() == 0 {
                throw MixtapeError.serverUnreachable
            }
            return Page(items: [Self.movie("m0")], totalCount: 1, startIndex: page.startIndex)
        })
        let service = makeService(repository: repository)
        await service.loadLibrary(id: movies.id)
        #expect(service.pages[movies.id] == .failed(.serverUnreachable))
        await service.loadLibrary(id: movies.id)
        #expect(service.pages[movies.id]?.isLoaded == true)
    }

    @Test func `session expiry is handed to the session service`() async {
        let sessionService = MockSessionService.signedIn()
        let service = makeService(repository: MockLibraryRepository(librariesResult: { _ in throw MixtapeError.sessionExpired }), sessionService: sessionService)
        await service.loadHome()
        #expect(service.libraries == .failed(.sessionExpired))
        #expect(sessionService.state == .signedOut)
        #expect(sessionService.error == .sessionExpired)
    }

    @Test func `nothing loads without a signed-in session`() async {
        let recorder = Recorder()
        let service = makeService(repository: pagingRepository(pageSizes: [60], total: 60, recorder: recorder), sessionService: MockSessionService.signedOut())
        await service.loadHome()
        await service.loadLibrary(id: movies.id)
        #expect(service.libraries == .idle)
        #expect(recorder.urls.isEmpty)
    }

    @Test func `refresh drops the page cache and reloads home`() async {
        let recorder = Recorder()
        let service = makeService(repository: pagingRepository(pageSizes: [60, 60], total: 120, recorder: recorder))
        await service.loadLibrary(id: movies.id)
        await service.refresh()
        #expect(service.pages.isEmpty)
        #expect(service.libraries.isLoaded)
        #expect(service.continueWatching.isLoaded)
    }

    @Test func `tracks and detail are cached per id`() async {
        let recorder = Recorder()
        let repository = MockLibraryRepository(
            itemResult: { id, _ in
                recorder.append("detail \(id)")
                return MockLibraryRepository.sampleMovies[1]
            },
            tracksResult: { id, _ in
                recorder.append("tracks \(id)")
                return MockLibraryRepository.sampleTracks
            },
        )
        let service = makeService(repository: repository)
        await service.loadTracks(albumID: "album-1")
        await service.loadTracks(albumID: "album-1")
        await service.loadDetail(id: "movie-2")
        #expect(service.tracks["album-1"] == .loaded(MockLibraryRepository.sampleTracks))
        #expect(service.details["movie-2"] == .loaded(MockLibraryRepository.sampleMovies[1]))
        #expect(recorder.urls == ["tracks album-1", "detail movie-2"])
    }

    private nonisolated static func movie(_ id: String) -> MediaItem {
        MediaItem(
            id: id, name: id, kind: .movie, overview: nil, productionYear: nil, runtime: nil, indexNumber: nil, parentIndexNumber: nil,
            seriesName: nil, albumArtist: nil, primaryImageTag: nil, backdropImageTag: nil, parentPrimaryImageTag: nil,
            playback: PlaybackState(position: .zero, isWatched: false),
        )
    }
}

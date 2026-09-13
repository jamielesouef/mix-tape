//  LibraryServiceTests.swift
//  mixtape
//
//  Created by Jamie Le Souëf on 03/09/2026.
//

import Foundation
import Testing
@testable import Mixtape

@Suite(.tags(.service))
@MainActor
struct LibraryServiceTests {
    private let library = MockLibraryRepository.sampleLibraries[0]

    @Test
    func `load home loads libraries`() async {
        let service = LibraryServiceFixture.makeService()
        await service.loadHome()
        #expect(service
            .libraries ==
            .loaded(MockLibraryRepository.sampleLibraries.filter { $0.kind != .unsupported }))
    }

    @Test
    func `load home failure lands in failed`() async {
        let service = LibraryServiceFixture
            .makeService(repository: MockLibraryRepository(librariesResult: { _ in
                throw MixtapeError.serverUnreachable
            }))
        await service.loadHome()
        #expect(service.libraries == .failed(.serverUnreachable))
    }

    @Test
    func `load library requests the first page of sixty`() async {
        let recorder = Recorder()
        let service = LibraryServiceFixture
            .makeService(repository: LibraryServiceFixture.pagingRepository(
                pageSizes: [60],
                total: 120,
                recorder: recorder
            ))
        await service.loadLibrary(id: library.id)
        #expect(recorder.urls == ["0/60"])
        guard case let .loaded(page) = service.pages[library.id] else {
            Issue.record("not loaded")
            return
        }

        #expect(page.items.count == 60)
        #expect(page.totalCount == 120)
    }

    @Test
    func `load more advances start index by the returned count and appends`() async {
        let recorder = Recorder()
        let service = LibraryServiceFixture
            .makeService(repository: LibraryServiceFixture.pagingRepository(
                pageSizes: [60, 60],
                total: 120,
                recorder: recorder
            ))
        await service.loadLibrary(id: library.id)
        await service.loadMore(libraryID: library.id)
        #expect(recorder.urls == ["0/60", "60/60"])
        guard case let .loaded(page) = service.pages[library.id] else {
            Issue.record("not loaded")
            return
        }

        #expect(page.items.count == 120)
        #expect(page.items.last?.id == "m119")
        #expect(page.startIndex == 0)
    }

    @Test
    func `a short page stops further loading`() async {
        let recorder = Recorder()
        let service = LibraryServiceFixture
            .makeService(repository: LibraryServiceFixture.pagingRepository(
                pageSizes: [60, 12],
                total: 72,
                recorder: recorder
            ))
        await service.loadLibrary(id: library.id)
        await service.loadMore(libraryID: library.id)
        await service.loadMore(libraryID: library.id)
        await service.loadMore(libraryID: library.id)
        #expect(recorder.urls == ["0/60", "60/60"])
        guard case let .loaded(page) = service.pages[library.id] else {
            Issue.record("not loaded")
            return
        }

        #expect(page.items.count == 72)
    }

    @Test
    func `a full first page that is the whole library stops loading`() async {
        let recorder = Recorder()
        let service = LibraryServiceFixture
            .makeService(repository: LibraryServiceFixture.pagingRepository(
                pageSizes: [60],
                total: 60,
                recorder: recorder
            ))
        await service.loadLibrary(id: library.id)
        await service.loadMore(libraryID: library.id)
        #expect(recorder.urls == ["0/60"])
    }

    @Test
    func `load more is a no-op while a load is in flight`() async {
        let recorder = Recorder()
        let gate = Gate()
        let repository = MockLibraryRepository(itemsResult: { _, _, page, _ in
            recorder.append("\(page.startIndex)")
            await gate.wait()
            return Page(
                items: (0 ..< 60).map { LibraryServiceFixture.album("m\($0 + page.startIndex)") },
                totalCount: 600,
                startIndex: page.startIndex
            )
        })
        let service = LibraryServiceFixture.makeService(repository: repository)
        await service.loadLibrary(id: library.id)
        gate.close()
        let first = Task { await service.loadMore(libraryID: library.id) }
        await Task.yield()
        await service.loadMore(libraryID: library.id)
        gate.open()
        await first.value
        #expect(recorder.urls == ["0", "60"])
    }

    @Test
    func `load library is a no-op when the page is already loaded`() async {
        let recorder = Recorder()
        let service = LibraryServiceFixture
            .makeService(repository: LibraryServiceFixture.pagingRepository(
                pageSizes: [60, 60],
                total: 120,
                recorder: recorder
            ))
        await service.loadLibrary(id: library.id)
        await service.loadLibrary(id: library.id)
        #expect(recorder.urls == ["0/60"])
    }

    @Test
    func `load library failure lands in failed and retry reloads`() async {
        let attempts = Counter()
        let repository = MockLibraryRepository(itemsResult: { _, _, page, _ in
            if attempts.next() == 0 {
                throw MixtapeError.serverUnreachable
            }
            return Page(
                items: [LibraryServiceFixture.album("m0")],
                totalCount: 1,
                startIndex: page.startIndex
            )
        })
        let service = LibraryServiceFixture.makeService(repository: repository)
        await service.loadLibrary(id: library.id)
        #expect(service.pages[library.id] == .failed(.serverUnreachable))
        await service.loadLibrary(id: library.id)
        #expect(service.pages[library.id]?.isLoaded == true)
    }

    @Test
    func `session expiry is handed to the session service`() async {
        let sessionService = MockSessionService.signedIn()
        let service = LibraryServiceFixture.makeService(
            repository: MockLibraryRepository(librariesResult: { _ in
                throw MixtapeError.sessionExpired
            }),
            sessionService: sessionService
        )
        sessionService.onSessionEnded = { _ in service.endSession() }
        await service.loadHome()
        #expect(service.libraries == .idle)
        #expect(sessionService.state == .signedOut)
        #expect(sessionService.error == .sessionExpired)
    }

    @Test
    func `nothing loads without a signed-in session`() async {
        let recorder = Recorder()
        let service = LibraryServiceFixture.makeService(
            repository: LibraryServiceFixture.pagingRepository(
                pageSizes: [60],
                total: 60,
                recorder: recorder
            ),
            sessionService: MockSessionService.signedOut()
        )
        await service.loadHome()
        await service.loadLibrary(id: library.id)
        #expect(service.libraries == .idle)
        #expect(recorder.urls.isEmpty)
    }

    @Test
    func `refresh drops the page cache and reloads home`() async {
        let recorder = Recorder()
        let service = LibraryServiceFixture
            .makeService(repository: LibraryServiceFixture.pagingRepository(
                pageSizes: [60, 60],
                total: 120,
                recorder: recorder
            ))
        await service.loadLibrary(id: library.id)
        await service.refresh()
        #expect(service.pages.isEmpty)
        #expect(service.libraries.isLoaded)
    }

    @Test
    func `tracks and detail are cached per id`() async {
        let recorder = Recorder()
        let repository = MockLibraryRepository(
            itemResult: { id, _ in
                recorder.append("detail \(id)")
                return MockLibraryRepository.sampleAlbums[1]
            },
            tracksResult: { id, _ in
                recorder.append("tracks \(id)")
                return MockLibraryRepository.sampleTracks
            }
        )
        let service = LibraryServiceFixture.makeService(repository: repository)
        await service.loadTracks(albumID: "album-1")
        await service.loadTracks(albumID: "album-1")
        await service.loadDetail(id: "album-2")
        #expect(service.tracks["album-1"] == .loaded(MockLibraryRepository.sampleTracks))
        #expect(service.details["album-2"] == .loaded(MockLibraryRepository.sampleAlbums[1]))
        #expect(recorder.urls == ["tracks album-1", "detail album-2"])
    }
}

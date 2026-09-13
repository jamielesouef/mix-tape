//  LibraryServiceTests.swift
//  mixtape
//
//  Created by Jamie Le Souëf on 03/09/2026.
//

import Foundation
@testable import Mixtape
import Testing

@Suite(.tags(.service))
@MainActor
struct LibraryServiceTests {
    private let library = MockLibraryRepository.sampleLibraries[0]

    private func makeService(repository: MockLibraryRepository = MockLibraryRepository(), sessionService: SessionService = MockSessionService.signedIn()) -> LibraryService {
        MockLibraryService.make(repository: repository, sessionService: sessionService)
    }

    private func pagingRepository(pageSizes: [Int], total: Int, recorder: Recorder) -> MockLibraryRepository {
        let calls = Counter()
        return MockLibraryRepository(itemsResult: { _, _, page, _ in
            let call = calls.next()
            recorder.append("\(page.startIndex)/\(page.limit)")
            let count = call < pageSizes.count ? pageSizes[call] : 0
            let items = (0 ..< count).map { offset in Self.album("m\(page.startIndex + offset)") }
            return Page(items: items, totalCount: total, startIndex: page.startIndex)
        })
    }

    @Test func `load home loads libraries`() async {
        let service = makeService()
        await service.loadHome()
        #expect(service.libraries == .loaded(MockLibraryRepository.sampleLibraries.filter { $0.kind != .unsupported }))
    }

    @Test func `load home failure lands in failed`() async {
        let service = makeService(repository: MockLibraryRepository(librariesResult: { _ in throw MixtapeError.serverUnreachable }))
        await service.loadHome()
        #expect(service.libraries == .failed(.serverUnreachable))
    }

    @Test func `load library requests the first page of sixty`() async {
        let recorder = Recorder()
        let service = makeService(repository: pagingRepository(pageSizes: [60], total: 120, recorder: recorder))
        await service.loadLibrary(id: library.id)
        #expect(recorder.urls == ["0/60"])
        guard case let .loaded(page) = service.pages[library.id] else { Issue.record("not loaded"); return }
        #expect(page.items.count == 60)
        #expect(page.totalCount == 120)
    }

    @Test func `load more advances start index by the returned count and appends`() async {
        let recorder = Recorder()
        let service = makeService(repository: pagingRepository(pageSizes: [60, 60], total: 120, recorder: recorder))
        await service.loadLibrary(id: library.id)
        await service.loadMore(libraryID: library.id)
        #expect(recorder.urls == ["0/60", "60/60"])
        guard case let .loaded(page) = service.pages[library.id] else { Issue.record("not loaded"); return }
        #expect(page.items.count == 120)
        #expect(page.items.last?.id == "m119")
        #expect(page.startIndex == 0)
    }

    @Test func `a short page stops further loading`() async {
        let recorder = Recorder()
        let service = makeService(repository: pagingRepository(pageSizes: [60, 12], total: 72, recorder: recorder))
        await service.loadLibrary(id: library.id)
        await service.loadMore(libraryID: library.id)
        await service.loadMore(libraryID: library.id)
        await service.loadMore(libraryID: library.id)
        #expect(recorder.urls == ["0/60", "60/60"])
        guard case let .loaded(page) = service.pages[library.id] else { Issue.record("not loaded"); return }
        #expect(page.items.count == 72)
    }

    @Test func `a full first page that is the whole library stops loading`() async {
        let recorder = Recorder()
        let service = makeService(repository: pagingRepository(pageSizes: [60], total: 60, recorder: recorder))
        await service.loadLibrary(id: library.id)
        await service.loadMore(libraryID: library.id)
        #expect(recorder.urls == ["0/60"])
    }

    @Test func `load more is a no-op while a load is in flight`() async {
        let recorder = Recorder()
        let gate = Gate()
        let repository = MockLibraryRepository(itemsResult: { _, _, page, _ in
            recorder.append("\(page.startIndex)")
            await gate.wait()
            return Page(items: (0 ..< 60).map { Self.album("m\($0 + page.startIndex)") }, totalCount: 600, startIndex: page.startIndex)
        })
        let service = makeService(repository: repository)
        await service.loadLibrary(id: library.id)
        gate.close()
        let first = Task { await service.loadMore(libraryID: library.id) }
        await Task.yield()
        await service.loadMore(libraryID: library.id)
        gate.open()
        await first.value
        #expect(recorder.urls == ["0", "60"])
    }

    @Test func `load library is a no-op when the page is already loaded`() async {
        let recorder = Recorder()
        let service = makeService(repository: pagingRepository(pageSizes: [60, 60], total: 120, recorder: recorder))
        await service.loadLibrary(id: library.id)
        await service.loadLibrary(id: library.id)
        #expect(recorder.urls == ["0/60"])
    }

    @Test func `load library failure lands in failed and retry reloads`() async {
        let attempts = Counter()
        let repository = MockLibraryRepository(itemsResult: { _, _, page, _ in
            if attempts.next() == 0 {
                throw MixtapeError.serverUnreachable
            }
            return Page(items: [Self.album("m0")], totalCount: 1, startIndex: page.startIndex)
        })
        let service = makeService(repository: repository)
        await service.loadLibrary(id: library.id)
        #expect(service.pages[library.id] == .failed(.serverUnreachable))
        await service.loadLibrary(id: library.id)
        #expect(service.pages[library.id]?.isLoaded == true)
    }

    @Test func `session expiry is handed to the session service`() async {
        let sessionService = MockSessionService.signedIn()
        let service = makeService(repository: MockLibraryRepository(librariesResult: { _ in throw MixtapeError.sessionExpired }), sessionService: sessionService)
        sessionService.onSessionEnded = { _ in service.endSession() }
        await service.loadHome()
        #expect(service.libraries == .idle)
        #expect(sessionService.state == .signedOut)
        #expect(sessionService.error == .sessionExpired)
    }

    @Test func `nothing loads without a signed-in session`() async {
        let recorder = Recorder()
        let service = makeService(repository: pagingRepository(pageSizes: [60], total: 60, recorder: recorder), sessionService: MockSessionService.signedOut())
        await service.loadHome()
        await service.loadLibrary(id: library.id)
        #expect(service.libraries == .idle)
        #expect(recorder.urls.isEmpty)
    }

    @Test func `refresh drops the page cache and reloads home`() async {
        let recorder = Recorder()
        let service = makeService(repository: pagingRepository(pageSizes: [60, 60], total: 120, recorder: recorder))
        await service.loadLibrary(id: library.id)
        await service.refresh()
        #expect(service.pages.isEmpty)
        #expect(service.libraries.isLoaded)
    }

    @Test func `tracks and detail are cached per id`() async {
        let recorder = Recorder()
        let repository = MockLibraryRepository(
            itemResult: { id, _ in
                recorder.append("detail \(id)")
                return MockLibraryRepository.sampleAlbums[1]
            },
            tracksResult: { id, _ in
                recorder.append("tracks \(id)")
                return MockLibraryRepository.sampleTracks
            },
        )
        let service = makeService(repository: repository)
        await service.loadTracks(albumID: "album-1")
        await service.loadTracks(albumID: "album-1")
        await service.loadDetail(id: "album-2")
        #expect(service.tracks["album-1"] == .loaded(MockLibraryRepository.sampleTracks))
        #expect(service.details["album-2"] == .loaded(MockLibraryRepository.sampleAlbums[1]))
        #expect(recorder.urls == ["tracks album-1", "detail album-2"])
    }

    // MARK: Slice 020 — session-owned teardown

    @Test func `sign-out clears the cross-user cache and the next sign-in fetches fresh data`() async {
        let server = MockAuthRepository.sampleServer
        let userA = MockAuthRepository.sampleSession
        let userB = UserSession(serverURL: server.baseURL, userID: "user-2", userName: "riley", accessToken: "token-2", deviceID: "device-2")
        let authRepository = MockAuthRepository(authenticateResult: { userName, _, _ in userName == "riley" ? userB : userA })
        let store = MockSessionStore()
        let sessionService = SessionService(
            validateServer: ValidateServerUseCase(repository: authRepository),
            signInWithPassword: SignInWithPasswordUseCase(repository: authRepository, store: store),
            startQuickConnect: StartQuickConnectUseCase(repository: authRepository),
            pollQuickConnect: PollQuickConnectUseCase(repository: authRepository, store: store),
            restoreSession: RestoreSessionUseCase(store: store),
            signOut: SignOutUseCase(store: store),
            serverIdentity: server,
        )
        let calls = Recorder()
        let repository = MockLibraryRepository(librariesResult: { session in
            calls.append(session.userID)
            return MockLibraryRepository.sampleLibraries
        })
        let service = makeService(repository: repository, sessionService: sessionService)
        sessionService.onSessionEnded = { _ in service.endSession() }

        await sessionService.signIn(userName: "jamie", password: "pw")
        await service.loadLibrary(id: library.id)
        #expect(service.pages[library.id]?.isLoaded == true)

        sessionService.signOut()
        #expect(service.pages.isEmpty)
        #expect(service.libraries == .idle)

        await sessionService.validateServer(urlText: "localhost:8096")
        await sessionService.signIn(userName: "riley", password: "pw")
        await service.loadHome()
        #expect(calls.urls.filter { $0 == userB.userID }.count == 1)
        #expect(service.libraries.isLoaded)
    }

    @Test func `an externally triggered session end mid fetch never writes a stale page`() async {
        let gate = Gate()
        gate.close()
        let started = Recorder()
        let repository = MockLibraryRepository(itemsResult: { _, _, page, _ in
            started.append("started")
            await gate.wait()
            return Page(items: [Self.album("m0")], totalCount: 1, startIndex: page.startIndex)
        })
        let sessionService = MockSessionService.signedIn()
        let service = makeService(repository: repository, sessionService: sessionService)
        sessionService.onSessionEnded = { _ in service.endSession() }
        let load = Task { await service.loadLibrary(id: library.id) }
        #expect(await eventually { started.urls == ["started"] })
        sessionService.signOut()
        gate.open()
        await load.value
        #expect(service.pages[library.id] == nil)
    }

    @Test func `a session-expiry thrown from the fetch itself never repopulates the cleared cache`() async {
        let sessionService = MockSessionService.signedIn()
        let repository = MockLibraryRepository(itemsResult: { _, _, _, _ in throw MixtapeError.sessionExpired })
        let service = makeService(repository: repository, sessionService: sessionService)
        sessionService.onSessionEnded = { _ in service.endSession() }
        await service.loadLibrary(id: library.id)
        #expect(service.pages[library.id] == nil)
        #expect(sessionService.state == .signedOut)
    }

    // MARK: Slice 023 — pagination failure, refresh invalidation, track coalescing

    @Test func `loadMore failure leaves the loaded page intact and surfaces via pageLoadError`() async {
        let attempts = Counter()
        let repository = MockLibraryRepository(itemsResult: { _, _, page, _ in
            if attempts.next() == 0 {
                return Page(items: (0 ..< 60).map { Self.album("m\($0)") }, totalCount: 120, startIndex: page.startIndex)
            }
            throw MixtapeError.serverUnreachable
        })
        let service = makeService(repository: repository)
        await service.loadLibrary(id: library.id)
        await service.loadMore(libraryID: library.id)
        guard case let .loaded(page) = service.pages[library.id] else { Issue.record("not loaded"); return }
        #expect(page.items.count == 60)
        #expect(service.pageLoadError[library.id] == .serverUnreachable)
    }

    @Test func `refresh while loadLibrary is in flight does not let the stale response repopulate the cleared cache`() async {
        let gate = Gate()
        gate.close()
        let started = Recorder()
        let repository = MockLibraryRepository(itemsResult: { _, _, page, _ in
            started.append("started")
            await gate.wait()
            return Page(items: [Self.album("m0")], totalCount: 1, startIndex: page.startIndex)
        })
        let service = makeService(repository: repository)
        let load = Task { await service.loadLibrary(id: library.id) }
        #expect(await eventually { started.urls == ["started"] })
        await service.refresh()
        gate.open()
        await load.value
        #expect(service.pages[library.id] == nil)
    }

    @Test func `concurrent loadTracks requests for the same album fire one network call`() async {
        let recorder = Recorder()
        let gate = Gate()
        gate.close()
        let repository = MockLibraryRepository(tracksResult: { id, _ in
            recorder.append(id)
            await gate.wait()
            return MockLibraryRepository.sampleTracks
        })
        let service = makeService(repository: repository)
        let first = Task { await service.loadTracks(albumID: "album-1") }
        await Task.yield()
        await service.loadTracks(albumID: "album-1")
        gate.open()
        await first.value
        #expect(recorder.urls == ["album-1"])
    }

    private nonisolated static func album(_ id: String) -> MediaItem {
        MediaItem(
            id: id, name: id, kind: .musicAlbum, overview: nil, productionYear: nil, runtime: nil, indexNumber: nil, parentIndexNumber: nil,
            albumArtist: nil, primaryImageTag: nil, backdropImageTag: nil, parentPrimaryImageTag: nil,
            playback: PlaybackState(position: .zero),
        )
    }
}

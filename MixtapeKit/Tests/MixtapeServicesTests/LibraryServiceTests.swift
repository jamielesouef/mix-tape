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
        // Slice 020: wired the way `AppContainer` wires it, so the epoch guard's skipped `.failed`
        // write (decision log row 4) is observed as the `endSession()` reset it lands on, not as
        // whatever `.failed(.sessionExpired)` used to look like pre-020.
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
        await service.loadLibrary(id: movies.id) // AC20a
        #expect(service.pages[movies.id]?.isLoaded == true)

        sessionService.signOut()
        #expect(service.pages.isEmpty)
        #expect(service.libraries == .idle)

        await sessionService.validateServer(urlText: "localhost:8096") // signOut() cleared serverIdentity
        await sessionService.signIn(userName: "riley", password: "pw") // AC20b
        await service.loadHome()
        #expect(calls.urls.filter { $0 == userB.userID }.count == 1)
        #expect(service.libraries.isLoaded) // the epoch guard let B's write land, not "already loaded"
    }

    @Test func `an externally triggered session end mid fetch never writes a stale page`() async {
        let gate = Gate()
        gate.close()
        let started = Recorder()
        let repository = MockLibraryRepository(itemsResult: { _, _, page, _ in
            started.append("started")
            await gate.wait()
            return Page(items: [Self.movie("m0")], totalCount: 1, startIndex: page.startIndex)
        })
        let sessionService = MockSessionService.signedIn()
        let service = makeService(repository: repository, sessionService: sessionService)
        sessionService.onSessionEnded = { _ in service.endSession() }
        let load = Task { await service.loadLibrary(id: movies.id) }
        #expect(await eventually { started.urls == ["started"] }) // proves the fetch is genuinely in flight
        sessionService.signOut() // external to this fetch: not its own catch block
        gate.open()
        await load.value
        #expect(service.pages[movies.id] == nil)
    }

    @Test func `a session-expiry thrown from the fetch itself never repopulates the cleared cache`() async {
        let sessionService = MockSessionService.signedIn()
        let repository = MockLibraryRepository(itemsResult: { _, _, _, _ in throw MixtapeError.sessionExpired })
        let service = makeService(repository: repository, sessionService: sessionService)
        sessionService.onSessionEnded = { _ in service.endSession() }
        await service.loadLibrary(id: movies.id)
        #expect(service.pages[movies.id] == nil)
        #expect(sessionService.state == .signedOut)
    }

    private nonisolated static func movie(_ id: String) -> MediaItem {
        MediaItem(
            id: id, name: id, kind: .movie, overview: nil, productionYear: nil, runtime: nil, indexNumber: nil, parentIndexNumber: nil,
            seriesName: nil, albumArtist: nil, primaryImageTag: nil, backdropImageTag: nil, parentPrimaryImageTag: nil,
            playback: PlaybackState(position: .zero, isWatched: false),
        )
    }
}

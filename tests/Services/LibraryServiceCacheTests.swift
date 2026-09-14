//  LibraryServiceCacheTests.swift
//  mixtape
//
//  Created by Jamie Le Souëf on 13/09/2026.
//

import Foundation
import Testing
@testable import Mixtape

@Suite(.tags(.service))
@MainActor
struct LibraryServiceCacheTests {
    private let library = MockLibraryRepository.sampleLibraries[0]

    // MARK: Slice 020 — session-owned teardown

    @Test
    func `sign-out clears the cross-user cache and the next sign-in fetches fresh data`() async {
        let server = MockAuthRepository.sampleServer
        let userA = MockAuthRepository.sampleSession
        let userB = UserSession(
            serverURL: server.baseURL,
            userID: "user-2",
            userName: "riley",
            accessToken: "token-2",
            deviceID: "device-2"
        )
        let authRepository = MockAuthRepository(authenticateResult: { userName, _, _ in
            userName == "riley" ? userB : userA
        })
        let store = MockSessionStore()
        let sessionService = SessionService(
            validateServer: ValidateServerUseCase(repository: authRepository),
            signInWithPassword: SignInWithPasswordUseCase(repository: authRepository, store: store),
            startQuickConnect: StartQuickConnectUseCase(repository: authRepository),
            pollQuickConnect: PollQuickConnectUseCase(repository: authRepository, store: store),
            restoreSession: RestoreSessionUseCase(store: store),
            signOut: SignOutUseCase(store: store),
            serverIdentity: server
        )
        let calls = Recorder()
        let repository = MockLibraryRepository(librariesResult: { session in
            calls.append(session.userID)
            return MockLibraryRepository.sampleLibraries
        })
        let service = LibraryServiceFixture.makeService(
            repository: repository,
            sessionService: sessionService
        )
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

    @Test
    func `an externally triggered session end mid fetch never writes a stale page`() async {
        let gate = Gate()
        gate.close()
        let started = Recorder()
        let repository = MockLibraryRepository(itemsResult: { _, _, page, _ in
            started.append("started")
            await gate.wait()
            return Page(
                items: [LibraryServiceFixture.album("m0")],
                totalCount: 1,
                startIndex: page.startIndex
            )
        })
        let sessionService = MockSessionService.signedIn()
        let service = LibraryServiceFixture.makeService(
            repository: repository,
            sessionService: sessionService
        )
        sessionService.onSessionEnded = { _ in service.endSession() }
        let load = Task { await service.loadLibrary(id: library.id) }
        #expect(await eventually { started.urls == ["started"] })
        sessionService.signOut()
        gate.open()
        await load.value
        #expect(service.pages[library.id] == nil)
    }

    @Test
    func `a session-expiry thrown from the fetch itself never repopulates the cleared cache`(
    ) async {
        let sessionService = MockSessionService.signedIn()
        let repository = MockLibraryRepository(itemsResult: { _, _, _, _ in
            throw MixtapeError.sessionExpired
        })
        let service = LibraryServiceFixture.makeService(
            repository: repository,
            sessionService: sessionService
        )
        sessionService.onSessionEnded = { _ in service.endSession() }
        await service.loadLibrary(id: library.id)
        #expect(service.pages[library.id] == nil)
        #expect(sessionService.state == .signedOut)
    }

    // MARK: Slice 023 — pagination failure, refresh invalidation, track coalescing

    @Test
    func `loadMore failure leaves the loaded page intact and surfaces via pageLoadError`() async {
        let attempts = Counter()
        let repository = MockLibraryRepository(itemsResult: { _, _, page, _ in
            if attempts.next() == 0 {
                return Page(
                    items: (0 ..< 60).map { LibraryServiceFixture.album("m\($0)") },
                    totalCount: 120,
                    startIndex: page.startIndex
                )
            }
            throw MixtapeError.serverUnreachable
        })
        let service = LibraryServiceFixture.makeService(repository: repository)
        await service.loadLibrary(id: library.id)
        await service.loadMore(libraryID: library.id)
        guard case let .loaded(page) = service.pages[library.id] else {
            Issue.record("not loaded")
            return
        }

        #expect(page.items.count == 60)
        #expect(service.pageLoadError[library.id] == .serverUnreachable)
    }

    @Test
    func `refresh while loadLibrary is in flight does not let the stale response repopulate the cleared cache`(
    ) async {
        let gate = Gate()
        gate.close()
        let started = Recorder()
        let repository = MockLibraryRepository(itemsResult: { _, _, page, _ in
            started.append("started")
            await gate.wait()
            return Page(
                items: [LibraryServiceFixture.album("m0")],
                totalCount: 1,
                startIndex: page.startIndex
            )
        })
        let service = LibraryServiceFixture.makeService(repository: repository)
        let load = Task { await service.loadLibrary(id: library.id) }
        #expect(await eventually { started.urls == ["started"] })
        await service.refresh()
        gate.open()
        await load.value
        #expect(service.pages[library.id] == nil)
    }

    @Test
    func `concurrent loadTracks requests for the same album fire one network call`() async {
        let recorder = Recorder()
        let gate = Gate()
        gate.close()
        let repository = MockLibraryRepository(tracksResult: { id, _ in
            recorder.append(id)
            await gate.wait()
            return MockLibraryRepository.sampleTracks
        })
        let service = LibraryServiceFixture.makeService(repository: repository)
        let first = Task { await service.loadTracks(albumID: "album-1") }
        await Task.yield()
        await service.loadTracks(albumID: "album-1")
        gate.open()
        await first.value
        #expect(recorder.urls == ["album-1"])
    }
}

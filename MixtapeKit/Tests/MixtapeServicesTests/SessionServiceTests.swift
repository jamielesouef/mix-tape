//  SessionServiceTests.swift
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
struct SessionServiceTests {
    private let server = MockAuthRepository.sampleServer
    private let session = MockAuthRepository.sampleSession

    private func makeService(
        repository: MockAuthRepository = MockAuthRepository(),
        store: MockSessionStore = MockSessionStore(),
        clock: StubClock = StubClock(),
        serverIdentity: ServerIdentity? = nil,
    ) -> SessionService {
        SessionService(
            validateServer: ValidateServerUseCase(repository: repository),
            signInWithPassword: SignInWithPasswordUseCase(repository: repository, store: store),
            startQuickConnect: StartQuickConnectUseCase(repository: repository),
            pollQuickConnect: PollQuickConnectUseCase(repository: repository, store: store),
            restoreSession: RestoreSessionUseCase(store: store),
            signOut: SignOutUseCase(store: store),
            clock: clock,
            serverIdentity: serverIdentity,
        )
    }

    // MARK: Restore

    @Test func `restore lands signed in when A stored session exists`() async {
        let service = makeService(store: MockSessionStore(session: session))
        await service.restore()
        #expect(service.state == .signedIn(session))
    }

    @Test func `restore lands signed out without A stored session`() async {
        let service = makeService()
        await service.restore()
        #expect(service.state == .signedOut)
    }

    @Test func `restore lands signed out when the store fails`() async {
        let service = makeService(store: MockSessionStore(failure: MixtapeError.transport("keychain")))
        await service.restore()
        #expect(service.state == .signedOut)
        #expect(service.error == .transport("keychain"))
    }

    // MARK: Server validation and password sign-in

    @Test func `validate server sets the identity or the error`() async {
        let service = makeService()
        await service.validateServer(urlText: "localhost:8096")
        #expect(service.serverIdentity == server)
        #expect(service.error == nil)

        let failing = makeService(repository: MockAuthRepository(serverIdentityResult: { _ in throw MixtapeError.notAJellyfinServer }))
        await failing.validateServer(urlText: "example.com")
        #expect(failing.serverIdentity == nil)
        #expect(failing.error == .notAJellyfinServer)
    }

    @Test func `clear server returns to server entry with nothing carried over`() async {
        let service = makeService(repository: MockAuthRepository(serverIdentityResult: { _ in throw MixtapeError.notAJellyfinServer }))
        await service.validateServer(urlText: "example.com")
        #expect(service.error == .notAJellyfinServer)
        let validated = makeService()
        await validated.validateServer(urlText: "localhost:8096")
        #expect(validated.serverIdentity == server)
        validated.clearServer()
        #expect(validated.serverIdentity == nil)
        #expect(validated.error == nil)
        #expect(validated.quickConnect == .idle)
    }

    @Test func `sign in transitions to signed in`() async {
        let store = MockSessionStore()
        let service = makeService(store: store, serverIdentity: server)
        await service.signIn(userName: "jamie", password: "pw")
        #expect(service.state == .signedIn(session))
        #expect(store.session == session)
    }

    @Test func `wrong password keeps the server and reports invalid credentials`() async {
        let repository = MockAuthRepository(authenticateResult: { _, _, _ in throw MixtapeError.invalidCredentials })
        let service = makeService(repository: repository, serverIdentity: server)
        await service.restore()
        await service.signIn(userName: "jamie", password: "wrong")
        #expect(service.state == .signedOut)
        #expect(service.error == .invalidCredentials)
        #expect(service.serverIdentity == server)
    }

    @Test func `session expiry clears the store and returns to signed out`() async {
        let store = MockSessionStore(session: session)
        let repository = MockAuthRepository(authenticateResult: { _, _, _ in throw MixtapeError.sessionExpired })
        let service = makeService(repository: repository, store: store, serverIdentity: server)
        await service.restore()
        #expect(service.state == .signedIn(session))
        await service.signIn(userName: "jamie", password: "pw")
        #expect(service.state == .signedOut)
        #expect(store.session == nil)
        #expect(service.error == .sessionExpired)
        #expect(service.serverIdentity == server)
    }

    @Test func `sign out clears everything`() async {
        let store = MockSessionStore(session: session)
        let service = makeService(store: store, serverIdentity: server)
        await service.restore()
        service.signOut()
        #expect(service.state == .signedOut)
        #expect(service.serverIdentity == nil)
        #expect(store.session == nil)
    }

    // MARK: Quick Connect

    @Test func `quick connect shows the code then signs in on approval`() async {
        let approvals = ApprovalSequence([false, false, true])
        let repository = MockAuthRepository(quickConnectStateResult: { _, _ in approvals.next() })
        let clock = StubClock()
        let store = MockSessionStore()
        let service = makeService(repository: repository, store: store, clock: clock, serverIdentity: server)
        await service.startQuickConnect()
        #expect(service.quickConnect == .waiting(code: "123456"))
        await service.pollTask?.value
        #expect(service.state == .signedIn(session))
        #expect(service.quickConnect == .idle)
        #expect(store.session == session)
        #expect(clock.sleeps == [.seconds(5), .seconds(5), .seconds(5)])
    }

    @Test func `quick connect expires after five minutes`() async {
        let repository = MockAuthRepository(quickConnectStateResult: { _, _ in false })
        let clock = StubClock()
        let service = makeService(repository: repository, clock: clock, serverIdentity: server)
        await service.startQuickConnect()
        await service.pollTask?.value
        #expect(service.quickConnect == .failed(.quickConnectExpired))
        #expect(service.state == .loading) // untouched: expiry never changes the session state
        #expect(clock.sleeps.count == 60)
        #expect(clock.now.offset == .seconds(300))
    }

    @Test func `cancel stops polling and returns to idle`() async {
        let repository = MockAuthRepository(quickConnectStateResult: { _, _ in
            try await Task.sleep(for: .seconds(1000))
            return false
        })
        let service = makeService(repository: repository, serverIdentity: server)
        await service.startQuickConnect()
        let task = service.pollTask
        service.cancelQuickConnect()
        await task?.value
        #expect(service.quickConnect == .idle)
        #expect(service.state == .loading)
    }

    @Test func `quick connect unavailable is reported on the quick connect state`() async {
        let repository = MockAuthRepository(isQuickConnectEnabledResult: { _ in false })
        let service = makeService(repository: repository, serverIdentity: server)
        await service.startQuickConnect()
        #expect(service.quickConnect == .failed(.quickConnectUnavailable))
        #expect(service.pollTask == nil)
    }

    @Test func `poll failure is reported and stops polling`() async {
        let repository = MockAuthRepository(quickConnectStateResult: { _, _ in throw MixtapeError.transport("404") })
        let clock = StubClock()
        let service = makeService(repository: repository, clock: clock, serverIdentity: server)
        await service.startQuickConnect()
        await service.pollTask?.value
        #expect(service.quickConnect == .failed(.transport("404")))
        #expect(clock.sleeps.count == 1)
    }
}

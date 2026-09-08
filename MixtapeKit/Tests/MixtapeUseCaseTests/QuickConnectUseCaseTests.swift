//  QuickConnectUseCaseTests.swift
//  MixtapeUseCaseTests
//
//  Created by Jamie Le Souëf on 03/09/2026.
//

import MixtapeDomain
@testable import MixtapeUseCase
import Testing

@Suite(.tags(.useCase))
struct QuickConnectUseCaseTests {
    private let server = MockAuthRepository.sampleServer

    @Test func `start returns the handshake when enabled`() async throws {
        let handshake = try await StartQuickConnectUseCase(repository: MockAuthRepository())(server: server)
        #expect(handshake == QuickConnectHandshake(secret: "secret", code: "123456"))
    }

    @Test func `start throws unavailable when the server says disabled`() async {
        let repository = MockAuthRepository(isQuickConnectEnabledResult: { _ in false })
        await #expect(throws: MixtapeError.quickConnectUnavailable) {
            try await StartQuickConnectUseCase(repository: repository)(server: server)
        }
    }

    @Test(arguments: [MixtapeError.serverUnreachable, .sessionExpired, .quickConnectUnavailable])
    func `start propagates repository failures`(error: MixtapeError) async {
        let repository = MockAuthRepository(initiateQuickConnectResult: { _ in throw error })
        await #expect(throws: error) {
            try await StartQuickConnectUseCase(repository: repository)(server: server)
        }
    }

    @Test func `poll returns nil while unapproved and exchanges once approved`() async throws {
        let store = MockSessionStore()
        let pending = MockAuthRepository(quickConnectStateResult: { _, _ in false })
        let pendingResult = try await PollQuickConnectUseCase(repository: pending, store: store)(secret: "secret", server: server)
        #expect(pendingResult == nil)
        #expect(store.session == nil)

        let approved = MockAuthRepository(quickConnectStateResult: { _, _ in true })
        let session = try await PollQuickConnectUseCase(repository: approved, store: store)(secret: "secret", server: server)
        #expect(session == MockAuthRepository.sampleSession)
        #expect(store.session == session)
    }

    @Test(arguments: [MixtapeError.serverUnreachable, .sessionExpired, .transport("404")])
    func `poll propagates failures`(error: MixtapeError) async {
        let repository = MockAuthRepository(quickConnectStateResult: { _, _ in throw error })
        await #expect(throws: error) {
            try await PollQuickConnectUseCase(repository: repository, store: MockSessionStore())(secret: "secret", server: server)
        }
    }
}

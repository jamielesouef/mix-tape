//  SessionStoreUseCaseTests.swift
//  mixtape
//
//  Created by Jamie Le Souëf on 03/09/2026.
//

@testable import Mixtape
import Testing

@Suite(.tags(.useCase))
struct SessionStoreUseCaseTests {
    @Test func `restore returns the stored session or nil`() throws {
        #expect(try RestoreSessionUseCase(store: MockSessionStore())() == nil)
        let store = MockSessionStore(session: MockAuthRepository.sampleSession)
        #expect(try RestoreSessionUseCase(store: store)() == MockAuthRepository.sampleSession)
    }

    @Test func `restore propagates store failures`() {
        let store = MockSessionStore(failure: MixtapeError.transport("keychain"))
        #expect(throws: MixtapeError.transport("keychain")) {
            try RestoreSessionUseCase(store: store)()
        }
    }

    @Test func `sign out clears the store`() throws {
        let store = MockSessionStore(session: MockAuthRepository.sampleSession)
        try SignOutUseCase(store: store)()
        #expect(store.session == nil)
    }
}

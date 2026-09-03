//  SignInWithPasswordUseCaseTests.swift
//  MixtapeUseCaseTests
//
//  Created by Jamie Le Souëf on 03/09/2026.
//

import MixtapeDomain
@testable import MixtapeUseCase
import Testing

@Suite(.tags(.useCase))
struct SignInWithPasswordUseCaseTests {
    private let server = MockAuthRepository.sampleServer

    @Test func `success returns and persists the session`() async throws {
        let store = MockSessionStore()
        let useCase = SignInWithPasswordUseCase(repository: MockAuthRepository(), store: store)
        let session = try await useCase(userName: "jamie", password: "pw", server: server)
        #expect(session == MockAuthRepository.sampleSession)
        #expect(store.session == session)
    }

    @Test(arguments: [MixtapeError.invalidCredentials, .sessionExpired, .serverUnreachable])
    func `failures propagate and persist nothing`(error: MixtapeError) async {
        let store = MockSessionStore()
        let repository = MockAuthRepository(authenticateResult: { _, _, _ in throw error })
        await #expect(throws: error) {
            try await SignInWithPasswordUseCase(repository: repository, store: store)(userName: "jamie", password: "pw", server: server)
        }
        #expect(store.session == nil)
    }
}

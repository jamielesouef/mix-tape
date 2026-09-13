//  ValidateServerUseCaseTests.swift
//  mixtape
//
//  Created by Jamie Le Souëf on 03/09/2026.
//

import Foundation
@testable import Mixtape
import Testing

@Suite(.tags(.useCase))
struct ValidateServerUseCaseTests {
    private func recordingRepository(failing: Set<String> = [], failure: MixtapeError = .transport("tls")) -> (MockAuthRepository, Recorder) {
        let recorder = Recorder()
        let repository = MockAuthRepository(serverIdentityResult: { url in
            recorder.append(url.absoluteString)
            if failing.contains(url.scheme ?? "") {
                throw failure
            }
            return ServerIdentity(id: "id", name: "mixtape", version: "10.11.11", baseURL: url)
        })
        return (repository, recorder)
    }

    @Test func `schemeless input tries HTTPS first`() async throws {
        let (repository, recorder) = recordingRepository()
        let identity = try await ValidateServerUseCase(repository: repository)(urlText: "localhost:8096")
        #expect(recorder.urls == ["https://localhost:8096"])
        #expect(identity.baseURL.absoluteString == "https://localhost:8096")
    }

    @Test func `schemeless input falls back to HTTP on any HTTPS failure`() async throws {
        let (repository, recorder) = recordingRepository(failing: ["https"], failure: .transport("secure connection failed"))
        let identity = try await ValidateServerUseCase(repository: repository)(urlText: " localhost:8096/ ")
        #expect(recorder.urls == ["https://localhost:8096", "http://localhost:8096"])
        #expect(identity.baseURL.absoluteString == "http://localhost:8096")
    }

    @Test func `explicit scheme is used as given without fallback`() async {
        let (repository, recorder) = recordingRepository(failing: ["http"], failure: .serverUnreachable)
        await #expect(throws: MixtapeError.serverUnreachable) {
            try await ValidateServerUseCase(repository: repository)(urlText: "http://nas.local:8096///")
        }
        #expect(recorder.urls == ["http://nas.local:8096"])
    }

    @Test func `not A jellyfin server propagates`() async {
        let repository = MockAuthRepository(serverIdentityResult: { _ in throw MixtapeError.notAJellyfinServer })
        await #expect(throws: MixtapeError.notAJellyfinServer) {
            try await ValidateServerUseCase(repository: repository)(urlText: "https://example.com")
        }
    }

    @Test func `empty input is unreachable`() async {
        let (repository, _) = recordingRepository()
        await #expect(throws: MixtapeError.serverUnreachable) {
            try await ValidateServerUseCase(repository: repository)(urlText: "   ")
        }
    }
}

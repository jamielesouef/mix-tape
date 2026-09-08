//  MixtapeErrorTests.swift
//  MixtapeDomainTests
//
//  Created by Jamie Le Souëf on 03/09/2026.
//

@testable import MixtapeDomain
import Testing

@Suite(.tags(.domain))
struct MixtapeErrorTests {
    /// The exhaustive switch is the test: a missing or extra case fails to compile (decision 9 — no `.forbidden`).
    @Test(arguments: [
        MixtapeError.serverUnreachable, .notAJellyfinServer, .invalidCredentials, .quickConnectUnavailable,
        .quickConnectExpired, .sessionExpired, .noPlayableSource, .transport("x"), .decoding,
    ])
    func `has exactly the specified cases`(error: MixtapeError) {
        let recognised = switch error {
        case .serverUnreachable, .notAJellyfinServer, .invalidCredentials, .quickConnectUnavailable,
             .quickConnectExpired, .sessionExpired, .noPlayableSource, .transport, .decoding:
            true
        }
        #expect(recognised)
    }
}

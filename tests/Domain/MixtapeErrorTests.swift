//  MixtapeErrorTests.swift
//  mixtape
//
//  Created by Jamie Le Souëf on 03/09/2026.
//

@testable import Mixtape
import Testing

@Suite(.tags(.domain))
struct MixtapeErrorTests {
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

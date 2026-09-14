//  MixtapeErrorTests.swift
//  mixtape
//
//  Created by Jamie Le Souëf on 03/09/2026.
//

import Testing
@testable import Mixtape

@Suite(.tags(.domain))
struct MixtapeErrorTests {
    @Test(arguments: [
        MixtapeError.serverUnreachable,
        .notAJellyfinServer,
        .invalidCredentials,
        .quickConnectUnavailable,
        .quickConnectExpired,
        .sessionExpired,
        .noPlayableSource,
        .transport("x"),
        .decoding
    ])
    func `has exactly the specified cases`(error: MixtapeError) {
        let recognised =
            switch error {
            case .serverUnreachable,
                 .notAJellyfinServer,
                 .invalidCredentials,
                 .quickConnectUnavailable,
                 .quickConnectExpired,
                 .sessionExpired,
                 .noPlayableSource,
                 .transport,
                 .decoding:
                true
            }
        #expect(recognised)
    }

    @Test
    func `mapping passes an existing MixtapeError through unchanged`() {
        #expect(MixtapeError.mapping(from: MixtapeError.sessionExpired) == .sessionExpired)
    }

    @Test
    func `mapping wraps any other error as transport with its description`() {
        struct SomeError: Error, CustomStringConvertible {
            var description: String {
                "boom"
            }
        }

        let mapped = MixtapeError.mapping(from: SomeError())

        #expect(mapped == .transport(SomeError().localizedDescription))
    }
}

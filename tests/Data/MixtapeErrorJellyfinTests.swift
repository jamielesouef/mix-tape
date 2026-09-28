//  MixtapeErrorJellyfinTests.swift
//  mixtape
//
//  Created by Jamie Le Souëf on 28/09/2026.
//

import Foundation
import JellyfinKit
import Testing
@testable import Mixtape

@Suite(.tags(.repository))
struct MixtapeErrorJellyfinTests {
    @Test(arguments: [
        (JellyfinError.serverUnreachable, MixtapeError.serverUnreachable),
        (.invalidCredentials, .invalidCredentials),
        (.quickConnectUnavailable, .quickConnectUnavailable),
        (.unauthorized, .sessionExpired),
        (.transport("Not Found"), .transport("Not Found")),
        (.decoding, .decoding)
    ])
    func `server failures read as domain errors`(error: JellyfinError, expected: MixtapeError) {
        #expect(MixtapeError(error) == expected)
    }

    @Test
    func `translation rethrows a server failure as a domain error`() async {
        await #expect(throws: MixtapeError.sessionExpired) {
            try await translatingJellyfinErrors { () async throws -> Int in
                throw JellyfinError.unauthorized
            }
        }
    }

    @Test
    func `translation passes other errors through`() async {
        await #expect(throws: CancellationError.self) {
            try await translatingJellyfinErrors { () async throws -> Int in
                throw CancellationError()
            }
        }
    }
}

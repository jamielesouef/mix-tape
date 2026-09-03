//  MixtapeDomainTargetTests.swift
//  MixtapeDomainTests
//
//  Created by Jamie Le Souëf on 03/09/2026.
//

@testable import MixtapeDomain
import Testing

@Suite(.tags(.domain))
struct MixtapeDomainTargetTests {
    @Test func `target links and runs`() {
        #expect(Bool(true))
    }
}

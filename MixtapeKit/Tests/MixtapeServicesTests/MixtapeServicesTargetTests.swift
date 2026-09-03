//  MixtapeServicesTargetTests.swift
//  MixtapeServicesTests
//
//  Created by Jamie Le Souëf on 03/09/2026.
//

@testable import MixtapeServices
import Testing

@Suite(.tags(.service))
struct MixtapeServicesTargetTests {
    @Test func `target links and runs`() {
        #expect(Bool(true))
    }
}

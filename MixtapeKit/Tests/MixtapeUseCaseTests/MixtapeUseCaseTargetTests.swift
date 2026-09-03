//  MixtapeUseCaseTargetTests.swift
//  MixtapeUseCaseTests
//
//  Created by Jamie Le Souëf on 03/09/2026.
//

@testable import MixtapeUseCase
import Testing

@Suite(.tags(.useCase))
struct MixtapeUseCaseTargetTests {
    @Test func `target links and runs`() {
        #expect(Bool(true))
    }
}

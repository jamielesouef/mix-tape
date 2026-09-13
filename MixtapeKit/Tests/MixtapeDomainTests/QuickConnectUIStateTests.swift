//  QuickConnectUIStateTests.swift
//  MixtapeDomainTests
//
//  Created by Jamie Le Souëf on 03/09/2026.
//

@testable import MixtapeDomain
import Testing

@Suite(.tags(.domain))
struct QuickConnectUIStateTests {
    @Test(arguments: [QuickConnectUIState.idle, .waiting(code: "123456"), .failed(.quickConnectExpired)])
    func `has exactly three cases`(state: QuickConnectUIState) {
        let recognised = switch state {
        case .idle, .waiting, .failed: true
        }
        #expect(recognised)
    }
}

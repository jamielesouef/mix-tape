//  DurationTicksTests.swift
//  mixtape
//
//  Created by Jamie Le Souëf on 03/09/2026.
//

@testable import Mixtape
import Testing

@Suite(.tags(.domain))
struct DurationTicksTests {
    @Test func `whole seconds round trip`() {
        #expect(Duration.seconds(30).ticks == 300_000_000)
        #expect(Duration(ticks: 300_000_000) == .seconds(30))
    }

    @Test func `sub second positions round trip`() {
        let ticks: Int64 = 484_123_456
        #expect(Duration(ticks: ticks).ticks == ticks)
        #expect(Duration.milliseconds(1500).ticks == 15_000_000)
    }

    @Test func `zero is zero`() {
        #expect(Duration.zero.ticks == 0)
        #expect(Duration(ticks: 0) == .zero)
    }
}

//  TickStateTests.swift
//  mixtape
//
//  Created by Jamie Le Souëf on 14/09/2026.
//

import Testing
@testable import Mixtape

@Suite(.tags(.service))
struct TickStateTests {
    private let interval: Duration = .seconds(5)
    private let reportInterval: Duration = .seconds(10)
    private let stallThreshold = 3

    @Test
    func `a tick before the report interval only refreshes`() {
        var state = TickState()

        let tick = state.advance(
            position: .seconds(1),
            interval: interval,
            reportInterval: reportInterval,
            stallThreshold: stallThreshold
        )

        #expect(tick == .refresh)
    }

    @Test
    func `a tick reaching the report interval refreshes and reports`() {
        var state = TickState()

        _ = state.advance(
            position: .seconds(1),
            interval: interval,
            reportInterval: reportInterval,
            stallThreshold: stallThreshold
        )
        let tick = state.advance(
            position: .seconds(2),
            interval: interval,
            reportInterval: reportInterval,
            stallThreshold: stallThreshold
        )

        #expect(tick == .refreshAndReport)
    }

    @Test
    func `position stuck at zero never arms the stall watchdog`() {
        var state = TickState()
        var lastTick: PlaybackProgressTicker.Tick?

        for _ in 0 ..< (stallThreshold + 5) {
            lastTick = state.advance(
                position: .zero,
                interval: interval,
                reportInterval: reportInterval,
                stallThreshold: stallThreshold
            )
        }

        #expect(lastTick != .stalled)
    }

    @Test
    func `position stuck after advancing past zero reports stalled`() {
        var state = TickState()

        _ = state.advance(
            position: .seconds(1),
            interval: interval,
            reportInterval: reportInterval,
            stallThreshold: stallThreshold
        )

        var lastTick: PlaybackProgressTicker.Tick?
        for _ in 0 ..< stallThreshold {
            lastTick = state.advance(
                position: .seconds(1),
                interval: interval,
                reportInterval: reportInterval,
                stallThreshold: stallThreshold
            )
        }

        #expect(lastTick == .stalled)
    }

    @Test
    func `position that keeps advancing never stalls`() {
        var state = TickState()
        var lastTick: PlaybackProgressTicker.Tick?

        for second in 1 ... (stallThreshold + 5) {
            lastTick = state.advance(
                position: .seconds(second),
                interval: interval,
                reportInterval: reportInterval,
                stallThreshold: stallThreshold
            )
        }

        #expect(lastTick != .stalled)
    }
}

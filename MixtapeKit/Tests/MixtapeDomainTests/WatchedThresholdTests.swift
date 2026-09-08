//  WatchedThresholdTests.swift
//  MixtapeDomainTests
//
//  Created by Jamie Le Souëf on 03/09/2026.
//

@testable import MixtapeDomain
import Testing

@Suite(.tags(.domain))
struct WatchedThresholdTests {
    private let duration = Duration.seconds(1000)

    @Test(arguments: [
        (Duration.milliseconds(899_000), false),
        (Duration.milliseconds(900_000), true),
        (Duration.milliseconds(901_000), true),
    ])
    func `threshold at 90 percent`(position: Duration, expected: Bool) {
        #expect(PlaybackState.reachesWatchedThreshold(position: position, duration: duration) == expected)
    }

    @Test func `zero duration is never watched`() {
        #expect(PlaybackState.reachesWatchedThreshold(position: .seconds(5), duration: .zero) == false)
    }

    @Test func `has resume point only when positive`() {
        #expect(PlaybackState(position: .zero, isWatched: false).hasResumePoint == false)
        #expect(PlaybackState(position: .seconds(1), isWatched: false).hasResumePoint)
    }
}

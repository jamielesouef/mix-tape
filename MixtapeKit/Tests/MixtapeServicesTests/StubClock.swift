//  StubClock.swift
//  MixtapeServicesTests
//
//  Created by Jamie Le Souëf on 03/09/2026.
//

import Foundation

/// A virtual clock: `sleep(until:)` advances `now` to the deadline and returns at once, so a
/// 5-minute poll loop runs in microseconds and every sleep is recorded for assertion.
final class StubClock: Clock, @unchecked Sendable {
    struct Instant: InstantProtocol {
        var offset: Duration

        func advanced(by duration: Duration) -> Instant {
            Instant(offset: offset + duration)
        }

        func duration(to other: Instant) -> Duration {
            other.offset - offset
        }

        static func < (lhs: Instant, rhs: Instant) -> Bool {
            lhs.offset < rhs.offset
        }
    }

    private let lock = NSLock()
    private var current = Instant(offset: .zero)
    private var recorded: [Duration] = []

    var now: Instant {
        lock.withLock { current }
    }

    var minimumResolution: Duration {
        .nanoseconds(1)
    }

    var sleeps: [Duration] {
        lock.withLock { recorded }
    }

    func sleep(until deadline: Instant, tolerance _: Duration?) async throws {
        try Task.checkCancellation()
        lock.withLock {
            recorded.append(current.duration(to: deadline))
            if deadline > current {
                current = deadline
            }
        }
        await Task.yield()
    }
}

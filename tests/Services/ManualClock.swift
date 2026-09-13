//  ManualClock.swift
//  mixtape
//
//  Created by Jamie Le Souëf on 03/09/2026.
//

import Foundation
@testable import Mixtape

final class ManualClock: Clock, @unchecked Sendable {
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
    private var pending: [CheckedContinuation<Void, Error>] = []

    var now: Instant {
        lock.withLock { current }
    }

    var minimumResolution: Duration {
        .nanoseconds(1)
    }

    func sleep(until deadline: Instant, tolerance _: Duration?) async throws {
        try await withCheckedThrowingContinuation { continuation in
            lock.withLock {
                current = deadline
                pending.append(continuation)
            }
        }
    }

    func tick() async {
        let deadline = ContinuousClock.now + .seconds(2)
        while ContinuousClock.now < deadline {
            if let continuation = lock.withLock({ pending.isEmpty ? nil : pending.removeFirst() }) {
                continuation.resume()
                await Task.yield()
                return
            }
            await Task.yield()
        }
    }

    var sleeperCount: Int {
        lock.withLock { pending.count }
    }
}

//  ReportLog.swift
//  MixtapeServicesTests
//
//  Created by Jamie Le Souëf on 03/09/2026.
//

import Foundation

/// Thread-safe ordered log of report descriptions for the reporting-cadence tests.
final class ReportLog: @unchecked Sendable {
    private let lock = NSLock()
    private var values: [String] = []
    private var waiters: [(count: Int, continuation: CheckedContinuation<Void, Never>)] = []

    func append(_ value: String) {
        let toResume: [CheckedContinuation<Void, Never>] = lock.withLock {
            values.append(value)
            let ready = waiters.filter { values.count >= $0.count }
            waiters.removeAll { values.count >= $0.count }
            return ready.map(\.continuation)
        }
        for continuation in toResume {
            continuation.resume()
        }
    }

    var entries: [String] {
        lock.withLock { values }
    }

    /// Suspends until `entries.count` reaches `count`, resumed by `append` itself the moment the
    /// production code's report actually lands — no polling window to lose (Triage 25, slice 021
    /// decision log).
    func waitForCount(_ count: Int) async {
        let alreadyThere: Bool = lock.withLock { values.count >= count }
        if alreadyThere {
            return
        }
        await withCheckedContinuation { continuation in
            let stillWaiting: Bool = lock.withLock {
                if values.count >= count {
                    return false
                }
                waiters.append((count, continuation))
                return true
            }
            if stillWaiting == false {
                continuation.resume()
            }
        }
    }
}

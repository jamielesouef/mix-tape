//  Gate.swift
//  mixtape
//
//  Created by Jamie Le Souëf on 03/09/2026.
//

import Foundation
@testable import Mixtape

final class Gate: @unchecked Sendable {
    private let lock = NSLock()
    private var isOpen = true
    private var waiters: [CheckedContinuation<Void, Never>] = []

    func close() {
        lock.withLock { isOpen = false }
    }

    func open() {
        let resumed: [CheckedContinuation<Void, Never>] = lock.withLock {
            isOpen = true
            defer { waiters.removeAll() }
            return waiters
        }
        for waiter in resumed {
            waiter.resume()
        }
    }

    func wait() async {
        await withCheckedContinuation { continuation in
            let shouldWait: Bool = lock.withLock {
                if isOpen {
                    return false
                }
                waiters.append(continuation)
                return true
            }
            if shouldWait == false {
                continuation.resume()
            }
        }
    }
}

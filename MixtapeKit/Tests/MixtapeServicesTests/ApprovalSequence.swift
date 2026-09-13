//  ApprovalSequence.swift
//  MixtapeServicesTests
//
//  Created by Jamie Le Souëf on 03/09/2026.
//

import Foundation

final class ApprovalSequence: @unchecked Sendable {
    private let lock = NSLock()
    private var values: [Bool]

    init(_ values: [Bool]) {
        self.values = values
    }

    func next() -> Bool {
        lock.withLock {
            let value = values.first ?? false
            if values.count > 1 {
                values.removeFirst()
            }
            return value
        }
    }
}

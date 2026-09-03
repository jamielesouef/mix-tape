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

    func append(_ value: String) {
        lock.withLock { values.append(value) }
    }

    var entries: [String] {
        lock.withLock { values }
    }
}

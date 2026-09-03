//  Recorder.swift
//  MixtapeUseCaseTests
//
//  Created by Jamie Le Souëf on 03/09/2026.
//

import Foundation

/// Thread-safe list of strings a mock closure can append to.
final class Recorder: @unchecked Sendable {
    private let lock = NSLock()
    private var values: [String] = []

    func append(_ value: String) {
        lock.withLock { values.append(value) }
    }

    var urls: [String] {
        lock.withLock { values }
    }
}

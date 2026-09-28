//  MockServerQuickConnectState.swift
//  mixtape
//
//  Created by Jamie Le Souëf on 28/09/2026.
//

import Foundation

/// Tracks in-flight Quick Connect handshakes for `MockServerAuthRepository`. A real server
/// approves a code when a second device confirms it; this stands in by auto-approving once
/// `approvalDelay` has passed, and expiring the code after `expiry`.
actor MockServerQuickConnectState {
    static let shared = MockServerQuickConnectState()

    private static let approvalDelay: Duration = .seconds(4)
    private static let expiry: Duration = .seconds(90)

    private var initiatedAt: [String: ContinuousClock.Instant] = [:]
    private let clock = ContinuousClock()

    func begin(secret: String) {
        initiatedAt[secret] = clock.now
    }

    func isApproved(secret: String) throws -> Bool {
        guard let startedAt = initiatedAt[secret] else {
            throw MixtapeError.quickConnectExpired
        }

        let elapsed = clock.now - startedAt

        guard elapsed < Self.expiry else {
            initiatedAt[secret] = nil
            throw MixtapeError.quickConnectExpired
        }

        return elapsed >= Self.approvalDelay
    }
}

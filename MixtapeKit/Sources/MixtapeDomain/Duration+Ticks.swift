//  Duration+Ticks.swift
//  MixtapeDomain
//
//  Created by Jamie Le Souëf on 03/09/2026.
//

/// Jellyfin ticks: one tick is 100 ns, so `ticks = seconds * 10_000_000`.
/// Used only in Domain and Data.
public extension Duration {
    nonisolated static let ticksPerSecond: Int64 = 10_000_000
    private nonisolated static let attosecondsPerTick: Int64 = 100_000_000_000

    nonisolated var ticks: Int64 {
        let parts = components
        return parts.seconds * Self.ticksPerSecond + parts.attoseconds / Self.attosecondsPerTick
    }

    nonisolated init(ticks: Int64) {
        let seconds = ticks / Self.ticksPerSecond
        let remainder = ticks % Self.ticksPerSecond
        self = .seconds(seconds) + .nanoseconds(remainder * 100)
    }
}

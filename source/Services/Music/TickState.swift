//  TickState.swift
//  mixtape
//
//  Created by Jamie Le Souëf on 14/09/2026.
//

/// The pure cadence decision behind `PlaybackProgressTicker`: given the position at this tick,
/// works out whether playback has stalled and whether this tick is due to report progress.
///
/// Holds no clock and does no I/O — `PlaybackProgressTicker` owns the timing and dispatch;
/// this only tracks the running totals a tick's verdict depends on.
struct TickState {
    private var elapsedSinceReport: Duration = .zero
    private var lastPosition: Duration = .zero
    private var hasAdvanced = false
    private var staleTicks = 0

    /// Advances one tick given the current position, returning its verdict.
    ///
    /// The stall watchdog arms only once `position` has moved past zero at least once, so
    /// the buffering that precedes the first frame is never mistaken for a stall.
    mutating func advance(
        position: Duration,
        interval: Duration,
        reportInterval: Duration,
        stallThreshold: Int
    ) -> PlaybackProgressTicker.Tick {
        if position > .zero {
            hasAdvanced = true
        }

        if hasAdvanced {
            staleTicks = position == lastPosition ? staleTicks + 1 : 0
        }

        lastPosition = position

        guard staleTicks < stallThreshold else {
            return .stalled
        }

        elapsedSinceReport += interval

        guard elapsedSinceReport >= reportInterval else {
            return .refresh
        }

        elapsedSinceReport = .zero
        return .refreshAndReport
    }
}

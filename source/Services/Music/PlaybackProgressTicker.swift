//  PlaybackProgressTicker.swift
//  mixtape
//
//  Created by Jamie Le Souëf on 13/09/2026.
//

/// The while-playing cadence: a now-playing refresh on every tick, a progress report every few
/// ticks, and a stalled verdict when the position stops advancing.
///
/// The stall watchdog arms only once the position has moved at least once, so the buffering
/// that precedes the first frame is never mistaken for a stall.
@MainActor
final class PlaybackProgressTicker {
    /// What one tick asks of the player.
    enum Tick {
        case refresh
        case refreshAndReport
        case stalled
    }

    private let clock: any Clock<Duration>
    private let interval: Duration
    private let reportInterval: Duration
    private let stallThreshold: Int

    private var task: Task<Void, Never>?

    init(
        clock: any Clock<Duration>,
        interval: Duration,
        reportInterval: Duration,
        stallThreshold: Int
    ) {
        self.clock = clock
        self.interval = interval
        self.reportInterval = reportInterval
        self.stallThreshold = stallThreshold
    }

    isolated deinit {
        task?.cancel()
    }

    /// Replaces any running ticker with a fresh one.
    ///
    /// `position` returns nil when the track it was started for is no longer the one playing,
    /// which skips the tick without disarming the watchdog or the report cadence.
    func start(
        position: @escaping @MainActor () -> Duration?,
        handle: @escaping @MainActor (Tick) async -> Void
    ) {
        task?.cancel()

        task = Task { [clock, interval, reportInterval, stallThreshold] in
            var tickState = TickState()

            while true {
                do {
                    try await clock.sleep(for: interval)
                } catch {
                    return
                }

                guard Task.isCancelled == false else {
                    return
                }
                guard let current = position() else {
                    continue
                }

                let tick = tickState.advance(
                    position: current,
                    interval: interval,
                    reportInterval: reportInterval,
                    stallThreshold: stallThreshold
                )

                await handle(tick)

                if tick == .stalled {
                    return
                }
            }
        }
    }

    func cancel() {
        task?.cancel()
        task = nil
    }
}

//  VideoPlaybackService.swift
//  MixtapeServices
//
//  Created by Jamie Le Souëf on 03/09/2026.
//

import MixtapeDomain
import MixtapeInfrastructure
import MixtapeUseCase
import Observation
import SwiftUI

/// Engineering doc §6. Owns the `VideoPlayerControlling` chosen from `plan.method` through the
/// injected factory (decision 36 is the only reason Services sees Infrastructure). Reports the
/// session to Jellyfin: start on play (decision 37), progress every 10 s while playing plus on
/// pause and on seek, and stopped on stop — never more often (§6).
@Observable
public final class VideoPlaybackService {
    public static let progressInterval: Duration = .seconds(10)

    public private(set) var item: MediaItem?
    public private(set) var plan: PlaybackPlan?
    public private(set) var status: PlayerStatus = .idle
    public private(set) var position: Duration = .zero
    public private(set) var duration: Duration?

    @ObservationIgnored private var controller: (any VideoPlayerControlling)?
    @ObservationIgnored private var progressTask: Task<Void, Never>?
    /// Slice 021: which playback operation is current. Minted at the top of `play()` and inside
    /// `tearDown`, so a stale `resolveVideo` completion or controller callback from an operation
    /// that has since moved on can never touch a newer or stopped state (decision log).
    @ObservationIgnored private var currentGeneration = OperationGeneration()
    /// Slice 021: off-path reports for this player are chained through this one reference so a
    /// rapid double-skip cannot deliver a later item's start to the server before an earlier
    /// item's stop (decision log).
    @ObservationIgnored private var reportTask: Task<Void, Never>?
    private let resolveVideo: ResolveVideoPlaybackUseCase
    private let reportStart: ReportPlaybackStartUseCase
    private let reportProgress: ReportPlaybackProgressUseCase
    private let reportStopped: ReportPlaybackStoppedUseCase
    private let makeController: (PlaybackMethod) -> (any VideoPlayerControlling)?
    private let sessionService: SessionService
    private let clock: any Clock<Duration>
    /// Reloaded after a session stops so Home's Continue Watching reflects it (slice 008). Weak so
    /// the two services do not retain each other.
    @ObservationIgnored private weak var libraryService: LibraryService?

    public init(
        resolveVideo: ResolveVideoPlaybackUseCase,
        reportStart: ReportPlaybackStartUseCase,
        reportProgress: ReportPlaybackProgressUseCase,
        reportStopped: ReportPlaybackStoppedUseCase,
        sessionService: SessionService,
        makeController: @escaping (PlaybackMethod) -> (any VideoPlayerControlling)?,
        libraryService: LibraryService? = nil,
        clock: any Clock<Duration> = ContinuousClock(),
        item: MediaItem? = nil,
        plan: PlaybackPlan? = nil,
        status: PlayerStatus = .idle,
    ) {
        self.resolveVideo = resolveVideo
        self.reportStart = reportStart
        self.reportProgress = reportProgress
        self.reportStopped = reportStopped
        self.sessionService = sessionService
        self.makeController = makeController
        self.libraryService = libraryService
        self.clock = clock
        self.item = item
        self.plan = plan
        self.status = status
    }

    deinit {
        progressTask?.cancel()
    }

    /// The player's own view, for `VideoPlayerScreen` to host. `nil` until a controller exists.
    public var playerView: AnyView? {
        controller?.makeView()
    }

    public var isActive: Bool {
        status != .idle
    }

    /// Resolves, reports the start, loads and plays. `startAt` is `.zero` for Play and the
    /// item's server position for Resume. Slice 021: every closure this installs, and the
    /// resolution failure path, are guarded by the generation minted here — a stale completion
    /// from an operation this call has since replaced can no longer touch state.
    public func play(item: MediaItem, startAt: Duration) async {
        guard let session else { return }
        let generation = OperationGeneration()
        currentGeneration = generation
        controller?.teardown()
        controller = nil
        progressTask?.cancel()
        self.item = item
        plan = nil
        status = .preparing
        position = startAt
        duration = item.runtime
        do {
            let plan = try await resolveVideo(itemID: item.id, startAt: startAt, session: session)
            guard status == .preparing, generation == currentGeneration else { return } // stopped or replaced while resolving
            self.plan = plan
            duration = plan.totalDuration ?? item.runtime
            guard let controller = makeController(plan.method) else {
                status = .failed(.noPlayableSource)
                return
            }
            self.controller = controller
            controller.onPositionChange = { [weak self] position in
                guard let self, generation == currentGeneration else { return }
                self.position = position
            }
            controller.onTransportEvent = { [weak self] event in
                guard let self, generation == currentGeneration else { return }
                handleTransport(event)
            }
            controller.onEnded = { [weak self] in
                guard let self, generation == currentGeneration else { return }
                Task { await self.stop() }
            }
            controller.onFailure = { [weak self] error in
                guard let self, generation == currentGeneration else { return }
                status = .failed(error)
            }
            controller.load(url: plan.streamURL, startAt: startAt, headers: [:])
            controller.play()
            status = .playing
            let startReport = report(plan: plan, position: startAt, isPaused: false)
            enqueueReport { [reportStart] in await reportStart(startReport, session: session) }
            await reportTask?.value
            guard generation == currentGeneration else { return } // stopped while the start report was in flight
            startProgressReporting(generation: generation)
        } catch {
            guard generation == currentGeneration else { return }
            status = .failed(handle(error))
        }
    }

    /// Forwards to the player. `status` and the report follow from the player's own transport
    /// event, the same way as a pause from AVKit's controls or the VLC overlay (slice 014).
    public func togglePlayPause() {
        guard let controller else { return }
        switch status {
        case .playing: controller.pause()
        case .paused: controller.play()
        case .idle, .preparing, .failed: break
        }
    }

    public func seek(to target: Duration) {
        guard status == .playing || status == .paused else { return }
        controller?.seek(to: target)
    }

    /// §6 "on pause, on seek completion": one report per transition, whoever drove it. Idempotent —
    /// a player that announces a state it is already in produces nothing, so the heartbeat's
    /// `status == .playing` guard is the only pause-awareness it needs.
    private func handleTransport(_ event: VideoTransportEvent) {
        switch event {
        case .paused:
            guard status == .playing else { return }
            status = .paused
            reportOnce(isPaused: true)
        case .resumed:
            guard status == .paused else { return }
            status = .playing
            reportOnce(isPaused: false)
        case let .seeked(target):
            guard status == .playing || status == .paused else { return }
            position = target
            reportOnce(isPaused: status == .paused)
        }
    }

    /// Tears the player down, sends the stopped report, refreshes Home, and returns to `.idle`.
    public func stop() async {
        let session = session
        let hadPlan = plan != nil && session != nil
        tearDown(reportingTo: session)
        guard hadPlan else { return }
        await reportTask?.value
        await libraryService?.refresh()
    }

    /// Slice 020: `AppContainer`'s fan-out calls this synchronously when session `endedSession`
    /// ends — sign-out or expiry. `controller.teardown()` and the `.idle` transition happen before
    /// this returns; a best-effort stopped report for whatever was playing is enqueued off-path
    /// (slice 021) against `endedSession` (not `self.session`, already nil by the time the report
    /// use case runs) rather than blocking the caller on the network — same shape as
    /// `MusicPlayerService.endSession(_:)` (decision log). No `libraryService?.refresh()` here:
    /// unlike `stop()`, this is not a "finished watching" event.
    public func endSession(_ endedSession: UserSession) {
        tearDown(reportingTo: endedSession)
    }

    /// `true` when the last-known position reaches the watched threshold for the current runtime.
    var reachesWatchedThreshold: Bool {
        guard let duration else { return false }
        return PlaybackState.reachesWatchedThreshold(position: position, duration: duration)
    }

    /// Tears playback down to `.idle`, mints a fresh generation so no stale resolution or
    /// controller callback from the operation just ended can touch state again, and enqueues the
    /// stopped report (if there is one) on the chain rather than awaiting it — shared by `stop()`
    /// and `endSession()` (slice 021 decision log). A position at or past 90% of the runtime
    /// (decision 8) is reported as the full duration so Jellyfin marks the item watched; below
    /// that it is reported verbatim as the resume point.
    private func tearDown(reportingTo session: UserSession?) {
        progressTask?.cancel()
        progressTask = nil
        currentGeneration = OperationGeneration()
        let plan = plan
        let stoppedPosition = stopReportPosition()
        controller?.teardown()
        controller = nil
        status = .idle
        self.plan = nil
        item = nil
        position = .zero
        duration = nil
        guard let plan, let session else { return }
        let stoppedReport = report(plan: plan, position: stoppedPosition, isPaused: false)
        enqueueReport { [reportStopped] in await reportStopped(stoppedReport, session: session) }
    }

    private func stopReportPosition() -> Duration {
        if reachesWatchedThreshold, let duration {
            return duration
        }
        return position
    }

    /// Slice 021: also checks the operation generation, not only `status`, before sending —
    /// a progress task started for an operation that has since been replaced or stopped sends
    /// nothing.
    private func startProgressReporting(generation: OperationGeneration) {
        progressTask?.cancel()
        progressTask = Task { [weak self] in
            while true {
                guard let clock = self?.clock else { return }
                do {
                    try await clock.sleep(for: Self.progressInterval)
                } catch {
                    return // cancelled
                }
                guard let self, Task.isCancelled == false else { return }
                guard status == .playing, generation == currentGeneration, let plan, let session else { continue }
                await reportProgress(report(plan: plan, position: position, isPaused: false), session: session)
            }
        }
    }

    /// One progress report for a discrete event (pause, resume, seek). No-op without a live plan.
    private func reportOnce(isPaused: Bool) {
        guard let plan, let session else { return }
        Task { await reportProgress(report(plan: plan, position: position, isPaused: isPaused), session: session) }
    }

    /// Chains one more off-path report after whatever is already pending, so reports for this
    /// player land at the server in the order their operations happened (slice 021 decision log).
    private func enqueueReport(_ send: @escaping () async -> Void) {
        let previous = reportTask
        reportTask = Task {
            await previous?.value
            await send()
        }
    }

    private func report(plan: PlaybackPlan, position: Duration, isPaused: Bool) -> PlaybackReport {
        PlaybackReport(
            itemID: plan.itemID, mediaSourceID: plan.mediaSourceID, playSessionID: plan.playSessionID,
            position: position, isPaused: isPaused, method: plan.method, playMethod: plan.playMethod,
        )
    }

    private var session: UserSession? {
        if case let .signedIn(session) = sessionService.state {
            return session
        }
        return nil
    }

    private func handle(_ error: any Error) -> MixtapeError {
        let mapped = (error as? MixtapeError) ?? .transport(error.localizedDescription)
        if mapped == .sessionExpired {
            sessionService.handleSessionExpiry()
        }
        return mapped
    }
}

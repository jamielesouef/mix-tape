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
    /// item's server position for Resume.
    public func play(item: MediaItem, startAt: Duration) async {
        guard let session else { return }
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
            guard status == .preparing, self.item?.id == item.id else { return } // stopped while resolving
            self.plan = plan
            duration = plan.totalDuration ?? item.runtime
            guard let controller = makeController(plan.method) else {
                status = .failed(.noPlayableSource)
                return
            }
            self.controller = controller
            controller.onPositionChange = { [weak self] position in self?.position = position }
            controller.onTransportEvent = { [weak self] event in self?.handleTransport(event) }
            controller.onEnded = { [weak self] in
                Task { await self?.stop() }
            }
            controller.onFailure = { [weak self] error in self?.status = .failed(error) }
            controller.load(url: plan.streamURL, startAt: startAt, headers: [:])
            controller.play()
            status = .playing
            await reportStart(report(plan: plan, position: startAt, isPaused: false), session: session)
            startProgressReporting()
        } catch {
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
    /// A position at or past 90% of the runtime (decision 8) is reported as the full duration so
    /// Jellyfin marks the item watched; below that it is reported verbatim as the resume point.
    public func stop() async {
        progressTask?.cancel()
        progressTask = nil
        let plan = plan
        let session = session
        let stoppedPosition = stopReportPosition()
        controller?.teardown()
        controller = nil
        status = .idle
        self.plan = nil
        item = nil
        position = .zero
        duration = nil
        if let plan, let session {
            await reportStopped(report(plan: plan, position: stoppedPosition, isPaused: false), session: session)
            await libraryService?.refresh()
        }
    }

    /// Slice 020: `SessionService`'s fan-out calls this synchronously when session `endedSession`
    /// ends — sign-out or expiry. `controller.teardown()` and the `.idle` transition happen before
    /// this returns; a best-effort stopped report for whatever was playing fires on `endedSession`
    /// (not `self.session`, already nil by the time the report use case runs) rather than blocking
    /// the caller on the network — same shape as `MusicPlayerService.endSession(_:)` (decision log).
    /// No `libraryService?.refresh()` here: unlike `stop()`, this is not a "finished watching" event.
    public func endSession(_ endedSession: UserSession) {
        progressTask?.cancel()
        progressTask = nil
        let pendingReport = plan.map { report(plan: $0, position: stopReportPosition(), isPaused: false) }
        controller?.teardown()
        controller = nil
        status = .idle
        plan = nil
        item = nil
        position = .zero
        duration = nil
        guard let pendingReport else { return }
        Task { [reportStopped] in await reportStopped(pendingReport, session: endedSession) }
    }

    /// `true` when the last-known position reaches the watched threshold for the current runtime.
    var reachesWatchedThreshold: Bool {
        guard let duration else { return false }
        return PlaybackState.reachesWatchedThreshold(position: position, duration: duration)
    }

    private func stopReportPosition() -> Duration {
        if reachesWatchedThreshold, let duration {
            return duration
        }
        return position
    }

    private func startProgressReporting() {
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
                guard status == .playing, let plan, let session else { continue }
                await reportProgress(report(plan: plan, position: position, isPaused: false), session: session)
            }
        }
    }

    /// One progress report for a discrete event (pause, resume, seek). No-op without a live plan.
    private func reportOnce(isPaused: Bool) {
        guard let plan, let session else { return }
        Task { await reportProgress(report(plan: plan, position: position, isPaused: isPaused), session: session) }
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

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
    @ObservationIgnored private var currentGeneration = OperationGeneration()
    @ObservationIgnored private var reportTask: Task<Void, Never>?
    private let resolveVideo: ResolveVideoPlaybackUseCase
    private let reportStart: ReportPlaybackStartUseCase
    private let reportProgress: ReportPlaybackProgressUseCase
    private let reportStopped: ReportPlaybackStoppedUseCase
    private let makeController: (PlaybackMethod) -> (any VideoPlayerControlling)?
    private let sessionService: SessionService
    private let clock: any Clock<Duration>
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

    public var playerView: AnyView? {
        controller?.makeView()
    }

    public var isActive: Bool {
        status != .idle
    }

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
            guard status == .preparing, generation == currentGeneration else { return }
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
            guard generation == currentGeneration else { return }
            startProgressReporting(generation: generation)
        } catch {
            guard generation == currentGeneration else { return }
            status = .failed(handle(error))
        }
    }

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

    public func stop() async {
        let session = session
        let hadPlan = plan != nil && session != nil
        tearDown(reportingTo: session)
        guard hadPlan else { return }
        await reportTask?.value
        await libraryService?.refresh()
    }

    public func endSession(_ endedSession: UserSession) {
        tearDown(reportingTo: endedSession)
    }

    var reachesWatchedThreshold: Bool {
        guard let duration else { return false }
        return PlaybackState.reachesWatchedThreshold(position: position, duration: duration)
    }

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

    private func startProgressReporting(generation: OperationGeneration) {
        progressTask?.cancel()
        progressTask = Task { [weak self] in
            while true {
                guard let clock = self?.clock else { return }
                do {
                    try await clock.sleep(for: Self.progressInterval)
                } catch {
                    return
                }
                guard let self, Task.isCancelled == false else { return }
                guard status == .playing, generation == currentGeneration, let plan, let session else { continue }
                await reportProgress(report(plan: plan, position: position, isPaused: false), session: session)
            }
        }
    }

    private func reportOnce(isPaused: Bool) {
        guard let plan, let session else { return }
        Task { await reportProgress(report(plan: plan, position: position, isPaused: isPaused), session: session) }
    }

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

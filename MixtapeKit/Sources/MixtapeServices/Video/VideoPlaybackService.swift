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
/// injected factory (decision 36 is the only reason Services sees Infrastructure). Sends the start
/// report once per `play` (decision 37); progress and stopped reports are slice 008.
@Observable
public final class VideoPlaybackService {
    public private(set) var item: MediaItem?
    public private(set) var plan: PlaybackPlan?
    public private(set) var status: PlayerStatus = .idle
    public private(set) var position: Duration = .zero
    public private(set) var duration: Duration?

    @ObservationIgnored private var controller: (any VideoPlayerControlling)?
    private let resolveVideo: ResolveVideoPlaybackUseCase
    private let reportStart: ReportPlaybackStartUseCase
    private let makeController: (PlaybackMethod) -> (any VideoPlayerControlling)?
    private let sessionService: SessionService

    public init(
        resolveVideo: ResolveVideoPlaybackUseCase,
        reportStart: ReportPlaybackStartUseCase,
        sessionService: SessionService,
        makeController: @escaping (PlaybackMethod) -> (any VideoPlayerControlling)?,
        item: MediaItem? = nil,
        plan: PlaybackPlan? = nil,
        status: PlayerStatus = .idle,
    ) {
        self.resolveVideo = resolveVideo
        self.reportStart = reportStart
        self.sessionService = sessionService
        self.makeController = makeController
        self.item = item
        self.plan = plan
        self.status = status
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
            controller.onEnded = { [weak self] in
                Task { await self?.stop() }
            }
            controller.onFailure = { [weak self] error in self?.status = .failed(error) }
            controller.load(url: plan.streamURL, startAt: startAt, headers: [:])
            controller.play()
            status = .playing
            await reportStart(report(for: plan, position: startAt, isPaused: false), session: session)
        } catch {
            status = .failed(handle(error))
        }
    }

    public func togglePlayPause() {
        guard let controller else { return }
        switch status {
        case .playing:
            controller.pause()
            status = .paused
        case .paused:
            controller.play()
            status = .playing
        case .idle, .preparing, .failed:
            break
        }
    }

    public func seek(to target: Duration) {
        guard let controller else { return }
        controller.seek(to: target)
        position = target
    }

    /// Tears the player down and returns to `.idle`, which dismisses the player screen.
    public func stop() async {
        controller?.teardown()
        controller = nil
        status = .idle
        plan = nil
        item = nil
        position = .zero
        duration = nil
    }

    private func report(for plan: PlaybackPlan, position: Duration, isPaused: Bool) -> PlaybackReport {
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

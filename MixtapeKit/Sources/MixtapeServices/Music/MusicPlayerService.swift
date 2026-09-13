//  MusicPlayerService.swift
//  MixtapeServices
//
//  Created by Jamie Le Souëf on 03/09/2026.
//

import Foundation
import MixtapeDomain
import MixtapeInfrastructure
import MixtapeUseCase
import Observation
import UIKit

@Observable
public final class MusicPlayerService {
    public static let progressInterval: Duration = .seconds(10)
    public static let nowPlayingInterval: Duration = .seconds(5)
    public static let stallTickThreshold = 3

    public private(set) var album: MediaItem?
    public private(set) var queue: [MediaItem] = []
    public private(set) var currentIndex: Int?
    public private(set) var status: PlayerStatus = .idle
    public private(set) var position: Duration = .zero
    public private(set) var finishedAlbumID: String?

    public var current: MediaItem? {
        guard let currentIndex, queue.indices.contains(currentIndex) else { return nil }
        return queue[currentIndex]
    }

    public var hasNextTrack: Bool {
        guard let currentIndex else { return false }
        return currentIndex + 1 < queue.count
    }

    @ObservationIgnored private var progressTask: Task<Void, Never>?
    @ObservationIgnored private var currentGeneration = OperationGeneration()
    @ObservationIgnored private var reportTask: Task<Void, Never>?
    @ObservationIgnored private var claimedFinishID: String?
    @ObservationIgnored private var playSessionID = UUID().uuidString
    @ObservationIgnored private var artwork: UIImage?
    private let controller: any AudioPlayerControlling
    private let buildAudioStreamURL: BuildAudioStreamURLUseCase
    private let reportStart: ReportPlaybackStartUseCase
    private let reportProgress: ReportPlaybackProgressUseCase
    private let reportStopped: ReportPlaybackStoppedUseCase
    private let sessionService: SessionService
    private let clock: any Clock<Duration>
    private let artworkProvider: (@Sendable (MediaItem) async -> UIImage?)?

    public init(
        controller: any AudioPlayerControlling,
        buildAudioStreamURL: BuildAudioStreamURLUseCase,
        reportStart: ReportPlaybackStartUseCase,
        reportProgress: ReportPlaybackProgressUseCase,
        reportStopped: ReportPlaybackStoppedUseCase,
        sessionService: SessionService,
        clock: any Clock<Duration> = ContinuousClock(),
        artworkProvider: (@Sendable (MediaItem) async -> UIImage?)? = nil,
    ) {
        self.controller = controller
        self.buildAudioStreamURL = buildAudioStreamURL
        self.reportStart = reportStart
        self.reportProgress = reportProgress
        self.reportStopped = reportStopped
        self.sessionService = sessionService
        self.clock = clock
        self.artworkProvider = artworkProvider
        controller.onEnded = { [weak self] in self?.trackDidEnd() }
        controller.onFailure = { [weak self] error in self?.handleFailure(error) }
        controller.onPositionChange = { [weak self] position in self?.position = position }
        controller.onRemotePlay = { [weak self] in self?.resume() }
        controller.onRemotePause = { [weak self] in self?.pause() }
        controller.onRemoteNext = { [weak self] in Task { await self?.next() } }
        controller.onRemotePrevious = { [weak self] in Task { await self?.previous() } }
        controller.onRemoteSeek = { [weak self] position in self?.seek(to: position) }
    }

    deinit {
        progressTask?.cancel()
    }

    public var isActive: Bool {
        status != .idle
    }

    public func play(album: MediaItem, tracks: [MediaItem], startingAt index: Int) async {
        guard tracks.isEmpty == false, tracks.indices.contains(index) else { return }
        enqueueStoppedReportForCurrent()
        self.album = album
        queue = tracks
        finishedAlbumID = nil
        claimedFinishID = nil
        await start(index: index)
    }

    public func togglePlayPause() {
        switch status {
        case .playing: pause()
        case .paused: resume()
        case .idle, .preparing, .failed: break
        }
    }

    public func next() async {
        guard let currentIndex else { return }
        enqueueStoppedReportForCurrent()
        if currentIndex + 1 < queue.count {
            await start(index: currentIndex + 1)
        } else {
            finish()
        }
    }

    public func previous() async {
        guard let currentIndex else { return }
        if position > .seconds(3) {
            seek(to: .zero)
            return
        }
        guard currentIndex > 0 else {
            seek(to: .zero)
            return
        }
        enqueueStoppedReportForCurrent()
        await start(index: currentIndex - 1)
    }

    public func seek(to requested: Duration) {
        let target = max(.zero, requested)
        controller.seek(to: target)
        position = target
        reportOnce(isPaused: status == .paused)
        refreshNowPlaying()
    }

    public func stop() async {
        tearDown(reportingTo: session)
        await reportTask?.value
    }

    public func claimFinish(albumID: String) -> Bool {
        guard finishedAlbumID == albumID, claimedFinishID == nil else { return false }
        claimedFinishID = albumID
        return true
    }

    public func acknowledgeFinish() {
        finishedAlbumID = nil
        claimedFinishID = nil
    }

    public func endSession(_ endedSession: UserSession) {
        tearDown(reportingTo: endedSession)
    }

    // MARK: - Private

    private func tearDown(reportingTo session: UserSession?) {
        progressTask?.cancel()
        progressTask = nil
        currentGeneration = OperationGeneration()
        if let track = current, let session {
            let stream = buildAudioStreamURL(track: track, session: session, playSessionID: playSessionID)
            let stoppedReport = report(for: track, position: position, isPaused: false, stream: stream)
            enqueueReport { [reportStopped] in await reportStopped(stoppedReport, session: session) }
        }
        controller.stop()
        status = .idle
        album = nil
        queue = []
        currentIndex = nil
        position = .zero
        finishedAlbumID = nil
        claimedFinishID = nil
    }

    private func start(index: Int) async {
        guard let session, queue.indices.contains(index) else { return }
        progressTask?.cancel()
        let generation = OperationGeneration()
        currentGeneration = generation
        currentIndex = index
        position = .zero
        playSessionID = UUID().uuidString
        artwork = nil
        status = .preparing
        let track = queue[index]
        let stream = buildAudioStreamURL(track: track, session: session, playSessionID: playSessionID)
        controller.load(url: stream.url)
        controller.play()
        controller.setNextTrackEnabled(index + 1 < queue.count)
        status = .playing
        let startReport = report(for: track, position: .zero, isPaused: false, stream: stream)
        enqueueReport { [reportStart] in await reportStart(startReport, session: session) }
        startProgressReporting(track: track, stream: stream, generation: generation)
        await refreshNowPlayingAsync(generation: generation)
    }

    private func handleFailure(_ error: MixtapeError) {
        status = .failed(error)
    }

    private func pause() {
        guard status == .playing else { return }
        controller.pause()
        status = .paused
        reportOnce(isPaused: true)
        refreshNowPlaying()
    }

    private func resume() {
        guard status == .paused else { return }
        controller.play()
        status = .playing
        reportOnce(isPaused: false)
        refreshNowPlaying()
    }

    private func trackDidEnd() {
        let endingTrackID = current?.id
        let generation = currentGeneration
        Task { [weak self] in
            guard let self, generation == currentGeneration, let currentIndex, current?.id == endingTrackID else { return }
            enqueueStoppedReportForCurrent()
            if currentIndex + 1 < queue.count {
                await start(index: currentIndex + 1)
            } else {
                finish()
            }
        }
    }

    private func finish() {
        progressTask?.cancel()
        progressTask = nil
        currentGeneration = OperationGeneration()
        controller.stop()
        status = .idle
        position = .zero
        claimedFinishID = nil
        finishedAlbumID = album?.id
        currentIndex = nil
    }

    private func startProgressReporting(track: MediaItem, stream: AudioStream, generation: OperationGeneration) {
        progressTask?.cancel()
        progressTask = Task { [weak self] in
            var elapsed: Duration = .zero
            var lastPosition: Duration = .zero
            var hasAdvanced = false
            var staleTicks = 0
            while true {
                guard let clock = self?.clock else { return }
                do {
                    try await clock.sleep(for: Self.nowPlayingInterval)
                } catch {
                    return
                }
                guard let self, Task.isCancelled == false else { return }
                guard status == .playing, generation == currentGeneration, current?.id == track.id, let session else { continue }
                if position > .zero {
                    hasAdvanced = true
                }
                if hasAdvanced {
                    staleTicks = position == lastPosition ? staleTicks + 1 : 0
                }
                lastPosition = position
                guard staleTicks < Self.stallTickThreshold else {
                    handleFailure(.transport("Playback stalled: position has not advanced"))
                    return
                }
                refreshNowPlaying()
                elapsed += Self.nowPlayingInterval
                guard elapsed >= Self.progressInterval else { continue }
                elapsed = .zero
                await reportProgress(report(for: track, position: position, isPaused: false, stream: stream), session: session)
            }
        }
    }

    private func reportOnce(isPaused: Bool) {
        guard let track = current, let session else { return }
        let stream = buildAudioStreamURL(track: track, session: session, playSessionID: playSessionID)
        Task { await reportProgress(report(for: track, position: position, isPaused: isPaused, stream: stream), session: session) }
    }

    private func enqueueStoppedReportForCurrent() {
        guard let track = current, let session else { return }
        let stream = buildAudioStreamURL(track: track, session: session, playSessionID: playSessionID)
        let stoppedReport = report(for: track, position: position, isPaused: false, stream: stream)
        enqueueReport { [reportStopped] in await reportStopped(stoppedReport, session: session) }
    }

    private func enqueueReport(_ send: @escaping () async -> Void) {
        let previous = reportTask
        reportTask = Task {
            await previous?.value
            await send()
        }
    }

    private func report(for track: MediaItem, position: Duration, isPaused: Bool, stream: AudioStream) -> PlaybackReport {
        PlaybackReport(
            itemID: track.id, mediaSourceID: track.id, playSessionID: playSessionID,
            position: position, isPaused: isPaused, method: .directAVPlayer, playMethod: stream.playMethod,
        )
    }

    private func refreshNowPlaying() {
        controller.updateNowPlaying(nowPlayingInfo(artwork: artwork))
    }

    private func refreshNowPlayingAsync(generation: OperationGeneration) async {
        if let track = current, let artworkProvider {
            let fetched = await artworkProvider(track)
            guard generation == currentGeneration else { return }
            artwork = fetched
        }
        guard generation == currentGeneration else { return }
        refreshNowPlaying()
    }

    private func nowPlayingInfo(artwork: UIImage?) -> NowPlayingInfo {
        NowPlayingInfo(
            title: current?.name ?? "",
            artist: current?.albumArtist ?? album?.albumArtist ?? "",
            albumTitle: album?.name ?? "",
            artwork: artwork,
            duration: current?.runtime,
            position: position,
            isPlaying: status == .playing,
        )
    }

    private var session: UserSession? {
        if case let .signedIn(session) = sessionService.state {
            return session
        }
        return nil
    }
}

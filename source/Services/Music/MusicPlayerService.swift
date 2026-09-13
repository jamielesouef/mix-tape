//  MusicPlayerService.swift
//  mixtape
//
//  Created by Jamie Le Souëf on 03/09/2026.
//

import Observation
import UIKit

@MainActor
@Observable
final class MusicPlayerService {
    static let progressInterval: Duration = .seconds(10)
    static let nowPlayingInterval: Duration = .seconds(5)
    static let stallTickThreshold = 3

    /// Pressing previous this far into a track restarts it rather than stepping back a track.
    static let restartWindow: Duration = .seconds(3)

    // MARK: - Properties

    private(set) var album: MediaItem?
    private(set) var queue: [MediaItem] = []
    private(set) var currentIndex: Int?
    private(set) var status: PlayerStatus = .idle
    private(set) var position: Duration = .zero
    private(set) var finishedAlbumID: String?

    // MARK: - Computed properties

    var current: MediaItem? {
        guard let currentIndex, queue.indices.contains(currentIndex) else {
            return nil
        }

        return queue[currentIndex]
    }

    var hasNextTrack: Bool {
        guard let currentIndex else {
            return false
        }

        return currentIndex + 1 < queue.count
    }

    var isActive: Bool {
        status != .idle
    }

    @ObservationIgnored private var currentGeneration = OperationGeneration()
    @ObservationIgnored private var claimedFinishID: String?
    private let controller: any AudioPlayerControlling
    private let reporter: PlaybackReporter
    private let ticker: PlaybackProgressTicker
    private let nowPlaying: NowPlayingCoordinator
    private let sessionService: SessionService

    // MARK: - Initialization

    init(
        controller: any AudioPlayerControlling,
        buildAudioStreamURL: BuildAudioStreamURLUseCase,
        reportStart: ReportPlaybackStartUseCase,
        reportProgress: ReportPlaybackProgressUseCase,
        reportStopped: ReportPlaybackStoppedUseCase,
        sessionService: SessionService,
        clock: any Clock<Duration> = ContinuousClock(),
        artworkProvider: (@Sendable (MediaItem) async -> UIImage?)? = nil
    ) {
        self.controller = controller
        self.sessionService = sessionService

        reporter = PlaybackReporter(
            buildAudioStreamURL: buildAudioStreamURL,
            reportStart: reportStart,
            reportProgress: reportProgress,
            reportStopped: reportStopped
        )
        ticker = PlaybackProgressTicker(
            clock: clock,
            interval: Self.nowPlayingInterval,
            reportInterval: Self.progressInterval,
            stallThreshold: Self.stallTickThreshold
        )
        nowPlaying = NowPlayingCoordinator(
            controller: controller,
            artworkProvider: artworkProvider
        )

        controller.onEnded = { [weak self] in self?.trackDidEnd() }
        controller.onFailure = { [weak self] error in self?.handleFailure(error) }
        controller.onPositionChange = { [weak self] position in self?.position = position }
        controller.onRemotePlay = { [weak self] in self?.resume() }
        controller.onRemotePause = { [weak self] in self?.pause() }
        controller.onRemoteNext = { [weak self] in Task { await self?.next() } }
        controller.onRemotePrevious = { [weak self] in Task { await self?.previous() } }
        controller.onRemoteSeek = { [weak self] position in self?.seek(to: position) }
    }

    // MARK: - Public API

    func play(album: MediaItem, tracks: [MediaItem], startingAt index: Int) async {
        guard tracks.isEmpty == false, tracks.indices.contains(index) else {
            return
        }

        enqueueStoppedReportForCurrent()

        self.album = album
        queue = tracks
        finishedAlbumID = nil
        claimedFinishID = nil

        await start(index: index)
    }

    func togglePlayPause() {
        switch status {
        case .playing: pause()
        case .paused: resume()
        case .idle,
             .preparing,
             .failed: break
        }
    }

    func next() async {
        guard let currentIndex else {
            return
        }

        enqueueStoppedReportForCurrent()

        if currentIndex + 1 < queue.count {
            await start(index: currentIndex + 1)
        } else {
            finish()
        }
    }

    func previous() async {
        guard let currentIndex else {
            return
        }

        let isPastRestartWindow = position > Self.restartWindow

        guard isPastRestartWindow == false, currentIndex > 0 else {
            seek(to: .zero)
            return
        }

        enqueueStoppedReportForCurrent()

        await start(index: currentIndex - 1)
    }

    func seek(to requested: Duration) {
        let target = max(.zero, requested)

        controller.seek(to: target)
        position = target

        reportOnce(isPaused: status == .paused)
        refreshNowPlaying()
    }

    func stop() async {
        tearDown(reportingTo: session)

        await reporter.drain()
    }

    func claimFinish(albumID: String) -> Bool {
        guard finishedAlbumID == albumID, claimedFinishID == nil else {
            return false
        }

        claimedFinishID = albumID
        return true
    }

    func acknowledgeFinish() {
        finishedAlbumID = nil
        claimedFinishID = nil
    }

    func endSession(_ endedSession: UserSession) {
        tearDown(reportingTo: endedSession)
    }
}

// MARK: - Transport

private extension MusicPlayerService {
    func tearDown(reportingTo session: UserSession?) {
        ticker.cancel()
        currentGeneration = OperationGeneration()

        if let track = current, let session {
            reporter.stopped(track: track, position: position, session: session)
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

    func start(index: Int) async {
        guard let session, queue.indices.contains(index) else {
            return
        }

        ticker.cancel()

        let generation = OperationGeneration()
        let track = queue[index]

        currentGeneration = generation
        currentIndex = index
        position = .zero
        status = .preparing

        reporter.beginSession()
        nowPlaying.clearArtwork()

        let stream = reporter.audioStream(for: track, session: session)

        controller.load(url: stream.url)
        controller.play()
        controller.setNextTrackEnabled(index + 1 < queue.count)

        status = .playing

        reporter.started(track: track, position: .zero, stream: stream, session: session)
        startProgressReporting(track: track, generation: generation)

        await refreshNowPlayingAsync(generation: generation)
    }

    func handleFailure(_ error: MixtapeError) {
        status = .failed(error)
    }

    func pause() {
        guard status == .playing else {
            return
        }

        controller.pause()
        status = .paused

        reportOnce(isPaused: true)
        refreshNowPlaying()
    }

    func resume() {
        guard status == .paused else {
            return
        }

        controller.play()
        status = .playing

        reportOnce(isPaused: false)
        refreshNowPlaying()
    }

    func trackDidEnd() {
        let endingTrackID = current?.id
        let generation = currentGeneration

        Task { [weak self] in
            guard
                let self,
                generation == currentGeneration,
                let currentIndex,
                current?.id == endingTrackID
            else {
                return
            }

            enqueueStoppedReportForCurrent()

            if currentIndex + 1 < queue.count {
                await start(index: currentIndex + 1)
            } else {
                finish()
            }
        }
    }

    func finish() {
        ticker.cancel()
        currentGeneration = OperationGeneration()

        controller.stop()

        status = .idle
        position = .zero
        currentIndex = nil
        claimedFinishID = nil
        finishedAlbumID = album?.id
    }

    func startProgressReporting(track: MediaItem, generation: OperationGeneration) {
        ticker.start { [weak self] in
            guard
                let self,
                status == .playing,
                generation == currentGeneration,
                current?.id == track.id,
                session != nil
            else {
                return nil
            }

            return position
        } handle: { [weak self] tick in
            await self?.handle(tick, for: track)
        }
    }

    func handle(_ tick: PlaybackProgressTicker.Tick, for track: MediaItem) async {
        guard tick != .stalled else {
            handleFailure(.transport("Playback stalled: position has not advanced"))
            return
        }

        refreshNowPlaying()

        guard tick == .refreshAndReport, let session else {
            return
        }

        await reporter.progress(track: track, position: position, isPaused: false, session: session)
    }

    func reportOnce(isPaused: Bool) {
        guard let track = current, let session else {
            return
        }

        let reportedPosition = position

        Task { [reporter] in
            await reporter.progress(
                track: track,
                position: reportedPosition,
                isPaused: isPaused,
                session: session
            )
        }
    }

    func enqueueStoppedReportForCurrent() {
        guard let track = current, let session else {
            return
        }

        reporter.stopped(track: track, position: position, session: session)
    }

    func refreshNowPlaying() {
        let isPlaying = status == .playing

        nowPlaying.refresh(track: current, album: album, position: position, isPlaying: isPlaying)
    }

    func refreshNowPlayingAsync(generation: OperationGeneration) async {
        if let track = current {
            await nowPlaying.loadArtwork(for: track) { [weak self] in
                self?.currentGeneration == generation
            }
        }

        guard generation == currentGeneration else {
            return
        }

        refreshNowPlaying()
    }

    var session: UserSession? {
        if case let .signedIn(session) = sessionService.state {
            return session
        }
        return nil
    }
}

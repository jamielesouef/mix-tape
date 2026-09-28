//  MusicPlayerService.swift
//  mixtape
//
//  Created by Jamie Le Souëf on 03/09/2026.
//

import Observation
import UIKit

// swiftlint:disable file_length
// Sole owner of the observable playback queue/status/position — CLAUDE.md's
// single-source-of-truth rule ("the queue is the album") keeps this state on one
// type; splitting it would risk two owners of the same queue.
@MainActor
@Observable
final class MusicPlayerService {
    static let progressInterval: Duration = .seconds(10)
    static let nowPlayingInterval: Duration = .seconds(5)
    static let stallTickThreshold = 3

    /// Pressing previous this far into a track restarts it rather than stepping back a track.
    static let restartWindow: Duration = .seconds(3)

    /// Whether pressing previous restarts the current track rather than stepping back a
    /// track — true past `restartWindow` into the track, or already at the first track.
    static func shouldRestartOnPrevious(position: Duration, index: Int) -> Bool {
        position > restartWindow || index == 0
    }

    // MARK: - Properties

    private(set) var album: MediaItem?
    private(set) var queue: [MediaItem] = []
    private(set) var currentIndex: Int?
    private(set) var status: PlayerStatus = .idle
    private(set) var position: Duration = .zero
    private(set) var finishedAlbumID: String?

    /// The albums after `album` in the wallet order captured when playback started — read
    /// only by `advanceOrFinish` when continuing past the end of an album, per
    /// `WhenAlbumEndsPreference.continueThroughWallet`. Never appended to after play-start:
    /// this is a captured sequence, not a queue a listener can add to.
    private(set) var sequence: [MediaItem] = []

    // MARK: - Computed properties

    var current: MediaItem? {
        guard let currentIndex, queue.indices.contains(currentIndex) else {
            return nil
        }

        return queue[currentIndex]
    }

    /// Whether Next has anywhere to go — a later track in this album, or, in Continue
    /// Through Wallet mode, another album still in the captured sequence.
    var hasNextTrack: Bool {
        guard let currentIndex else {
            return false
        }

        if currentIndex + 1 < queue.count {
            return true
        }

        return settingsService.settings.whenAlbumEnds == .continueThroughWallet
            && sequence.isEmpty == false
    }

    var isActive: Bool {
        status != .idle
    }

    @ObservationIgnored private var currentGeneration = OperationGeneration()
    @ObservationIgnored private var claimedFinishID: String?
    private let controller: any AudioPlayerControlling
    private let telemetry: PlaybackTelemetry
    private let sessionService: SessionService
    private let settingsService: SettingsService
    private let fetchAlbumTracks: FetchAlbumTracksUseCase
    private let localAudioURLProvider: (@Sendable (MediaItem) async -> URL?)?

    // MARK: - Initialization

    init(
        controller: any AudioPlayerControlling,
        buildAudioStreamURL: BuildAudioStreamURLUseCase,
        reportStart: ReportPlaybackStartUseCase,
        reportProgress: ReportPlaybackProgressUseCase,
        reportStopped: ReportPlaybackStoppedUseCase,
        sessionService: SessionService,
        settingsService: SettingsService,
        fetchAlbumTracks: FetchAlbumTracksUseCase,
        clock: any Clock<Duration> = ContinuousClock(),
        artworkProvider: (@Sendable (MediaItem) async -> UIImage?)? = nil,
        localAudioURLProvider: (@Sendable (MediaItem) async -> URL?)? = nil
    ) {
        self.controller = controller
        self.sessionService = sessionService
        self.settingsService = settingsService
        self.fetchAlbumTracks = fetchAlbumTracks
        self.localAudioURLProvider = localAudioURLProvider

        telemetry = PlaybackTelemetry(
            reporter: PlaybackReporter(
                buildAudioStreamURL: buildAudioStreamURL,
                reportStart: reportStart,
                reportProgress: reportProgress,
                reportStopped: reportStopped
            ),
            ticker: PlaybackProgressTicker(
                clock: clock,
                interval: Self.nowPlayingInterval,
                reportInterval: Self.progressInterval,
                stallThreshold: Self.stallTickThreshold
            ),
            nowPlaying: NowPlayingCoordinator(
                controller: controller,
                artworkProvider: artworkProvider
            )
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

    /// - Parameter sequence: The albums after `album` in the wallet it was played from, in
    ///   wallet order. Captured once, here, so a later regenerate or re-sort of that wallet
    ///   cannot change a sequence already in flight. Empty when the album was not played from
    ///   a wallet (search results, for instance) — there is nothing to continue into.
    func play(
        album: MediaItem,
        tracks: [MediaItem],
        startingAt index: Int,
        sequence: [MediaItem] = []
    ) async {
        guard tracks.isEmpty == false, tracks.indices.contains(index) else {
            return
        }

        enqueueStoppedReportForCurrent()

        self.album = album
        queue = tracks
        self.sequence = sequence
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

        await advanceOrFinish(from: currentIndex)
    }

    func previous() async {
        guard let currentIndex else {
            return
        }
        guard Self.shouldRestartOnPrevious(position: position, index: currentIndex) == false else {
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

        await telemetry.drain()
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
        telemetry.reportStopped(track: current, position: position, session: session)

        resetPlayback(clearingQueue: true)
    }

    func start(index: Int) async {
        guard let session, queue.indices.contains(index) else {
            return
        }

        telemetry.stopTicking()

        let generation = OperationGeneration()
        let track = queue[index]

        currentGeneration = generation
        currentIndex = index
        position = .zero
        status = .preparing

        telemetry.beginSession()
        telemetry.clearArtwork()

        let stream = await downloadedStream(for: track) ?? telemetry.audioStream(for: track, session: session)

        controller.load(url: stream.url)
        controller.play()
        controller.setNextTrackEnabled(hasNextTrack)

        status = .playing

        telemetry.reportStarted(track: track, position: .zero, stream: stream, session: session)
        startProgressReporting(track: track, generation: generation)

        await refreshNowPlayingAsync(generation: generation)
    }

    /// Advances to the track after `index`; ends the album when it was the last one, unless
    /// `WhenAlbumEndsPreference.continueThroughWallet` and the captured sequence has another
    /// album, in which case that album starts from its own first track instead.
    func advanceOrFinish(from index: Int) async {
        enqueueStoppedReportForCurrent()

        if index + 1 < queue.count {
            await start(index: index + 1)
            return
        }

        guard let next = await popNextAlbumIfContinuing() else {
            finish()
            return
        }

        album = next.album
        queue = next.tracks
        claimedFinishID = nil

        await start(index: 0)
    }

    /// A downloaded track plays from disk, offline or not, per "use downloaded audio
    /// automatically when available" — checked ahead of the network stream, never as a
    /// fallback from it.
    func downloadedStream(for track: MediaItem) async -> AudioStream? {
        guard let localAudioURLProvider, let url = await localAudioURLProvider(track) else {
            return nil
        }

        return AudioStream(url: url, playMethod: .directPlay)
    }

    /// Fetches the next album's tracks and removes it from `sequence` only when it will
    /// actually be played — a fetch failure leaves `sequence` untouched and ends the album
    /// normally instead of silently skipping to the album after.
    func popNextAlbumIfContinuing() async -> (album: MediaItem, tracks: [MediaItem])? {
        guard settingsService.settings.whenAlbumEnds == .continueThroughWallet,
              let session,
              let next = sequence.first,
              let tracks = try? await fetchAlbumTracks(albumID: next.id, session: session),
              tracks.isEmpty == false
        else {
            return nil
        }

        sequence.removeFirst()

        return (next, tracks)
    }

    func handleFailure(_ error: MixtapeError) {
        status = .failed(error)
    }

    func pause() {
        setPaused(true)
    }

    func resume() {
        setPaused(false)
    }

    func setPaused(_ isPaused: Bool) {
        guard status == (isPaused ? .playing : .paused) else {
            return
        }

        if isPaused {
            controller.pause()
        } else {
            controller.play()
        }
        status = isPaused ? .paused : .playing

        reportOnce(isPaused: isPaused)
        refreshNowPlaying()
    }

    func trackDidEnd() {
        let endingTrackID = current?.id
        let generation = currentGeneration

        Task { [weak self] in
            guard let self,
                  generation == currentGeneration,
                  let currentIndex,
                  current?.id == endingTrackID
            else {
                return
            }

            await advanceOrFinish(from: currentIndex)
        }
    }

    func finish() {
        resetPlayback(clearingQueue: false)
    }

    /// Resets playback to idle. A full teardown (explicit stop, sign out) also forgets the
    /// album/queue and any finish marker; an end-of-album finish leaves them in place so the
    /// wallet can read which album just finished via `finishedAlbumID`.
    func resetPlayback(clearingQueue: Bool) {
        telemetry.stopTicking()
        currentGeneration = OperationGeneration()

        controller.stop()

        status = .idle
        position = .zero
        currentIndex = nil
        claimedFinishID = nil
        sequence = []

        if clearingQueue {
            album = nil
            queue = []
            finishedAlbumID = nil
        } else {
            finishedAlbumID = album?.id
        }
    }

    func startProgressReporting(track: MediaItem, generation: OperationGeneration) {
        telemetry.startTicking { [weak self] in
            guard let self,
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

        await telemetry.reportProgress(track: track, position: position, session: session)
    }

    func reportOnce(isPaused: Bool) {
        telemetry.reportOnce(
            track: current,
            position: position,
            isPaused: isPaused,
            session: session
        )
    }

    func enqueueStoppedReportForCurrent() {
        telemetry.reportStopped(track: current, position: position, session: session)
    }

    func refreshNowPlaying() {
        telemetry.refreshNowPlaying(
            track: current,
            album: album,
            position: position,
            isPlaying: status == .playing
        )
    }

    func refreshNowPlayingAsync(generation: OperationGeneration) async {
        if let track = current {
            await telemetry.loadArtwork(for: track) { [weak self] in
                self?.currentGeneration == generation
            }
        }

        guard generation == currentGeneration else {
            return
        }

        refreshNowPlaying()
    }

    var session: UserSession? {
        sessionService.currentSession
    }
}

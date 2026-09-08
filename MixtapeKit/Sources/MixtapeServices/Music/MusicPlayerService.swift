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

/// Engineering doc §6 and §1.1. The queue is **exactly one album**, forever: `play(album:…)` is the
/// only way tracks enter it, and it replaces rather than appends. No shuffle, repeat, append or
/// cross-album autoplay exists. Reports each track to the server with the three use cases from
/// slice 008 (decision 34).
@Observable
public final class MusicPlayerService {
    public static let progressInterval: Duration = .seconds(10)
    /// §6: `MPNowPlayingInfoCenter` is refreshed every 5 s while a track plays (slice 014).
    public static let nowPlayingInterval: Duration = .seconds(5)
    /// Slice 023 (Triage 24's stalled-player half): consecutive `nowPlayingInterval` ticks with no
    /// `position` advancement while `status == .playing`, armed only once `position` has advanced
    /// past zero, before the watchdog treats playback as stalled and fails it.
    public static let stallTickThreshold = 3

    /// Always exactly one album (§1.1).
    public private(set) var album: MediaItem?
    public private(set) var queue: [MediaItem] = []
    public private(set) var currentIndex: Int?
    public private(set) var status: PlayerStatus = .idle
    public private(set) var position: Duration = .zero
    /// Set once when the last track ends; the wallet (slice 010) observes it and calls `acknowledgeFinish()`.
    public private(set) var finishedAlbumID: String?

    public var current: MediaItem? {
        guard let currentIndex, queue.indices.contains(currentIndex) else { return nil }
        return queue[currentIndex]
    }

    /// Whether Next has anywhere to go (§1.1: never past the last track). The same fact the lock
    /// screen gets through `setNextTrackEnabled`, so the in-app control cannot drift from it.
    public var hasNextTrack: Bool {
        guard let currentIndex else { return false }
        return currentIndex + 1 < queue.count
    }

    @ObservationIgnored private var progressTask: Task<Void, Never>?
    /// Slice 021: which playback operation is current. Minted whenever a new operation starts
    /// (`start(index:)`) or ends (`tearDown`), so a stale progress tick or artwork fetch from an
    /// operation that has since moved on can never touch a newer one's state (decision log).
    @ObservationIgnored private var currentGeneration = OperationGeneration()
    /// Slice 021: off-path reports for this player are chained through this one reference so a
    /// rapid double-skip cannot deliver a later track's start to the server before an earlier
    /// track's stop (decision log).
    @ObservationIgnored private var reportTask: Task<Void, Never>?
    /// The finish a wallet has claimed (slice 015). Not observed: claiming is bookkeeping, not state
    /// a view renders.
    @ObservationIgnored private var claimedFinishID: String?
    @ObservationIgnored private var playSessionID = UUID().uuidString
    /// The current track's artwork, kept so the 5 s refresh does not drop it from the lock screen
    /// (slice 019).
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

    /// Replaces the queue with exactly this album's tracks and starts at `index` (§1.1). Whatever
    /// was current before the replacement gets its stopped report sent off-path (slice 021) —
    /// a replacement play does not silently drop the track it interrupted.
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

    /// Next track, or stop at the end — never advance past the last track (§1.1). The local
    /// transition happens first (slice 021); the stopped report for the track being left is
    /// built now, before it is overwritten, and sent off that path.
    public func next() async {
        guard let currentIndex else { return }
        enqueueStoppedReportForCurrent()
        if currentIndex + 1 < queue.count {
            await start(index: currentIndex + 1)
        } else {
            finish()
        }
    }

    /// Restarts the current track above 3 s, steps back below it (§6).
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

    /// The one seam every seek passes through: the in-app scrubber, the lock screen's
    /// `changePlaybackPosition`, `previous()`. Unclamped at the end since slice 018 — Triage 7 was an
    /// `AVPlayer` FLAC timing defect, fixed where the item is made, not a seek race.
    public func seek(to requested: Duration) {
        let target = max(.zero, requested)
        controller.seek(to: target)
        position = target
        reportOnce(isPaused: status == .paused)
        refreshNowPlaying()
    }

    /// Tears the player down and, once its stopped report has landed, refreshes nothing else —
    /// unlike `stop()`'s video counterpart there is no Home list to refresh here.
    public func stop() async {
        tearDown(reportingTo: session)
        await reportTask?.value
    }

    /// The wallet that owns the return sequence for the current finish (slice 015). `true` exactly
    /// once per finish, and only while that finish is live — a wallet asking about an album that
    /// has already been acknowledged, or a different album, gets `false`. Reset by `play`, `stop`,
    /// `finish` and `acknowledgeFinish`.
    public func claimFinish(albumID: String) -> Bool {
        guard finishedAlbumID == albumID, claimedFinishID == nil else { return false }
        claimedFinishID = albumID
        return true
    }

    public func acknowledgeFinish() {
        finishedAlbumID = nil
        claimedFinishID = nil
    }

    /// Slice 020: `AppContainer`'s fan-out calls this synchronously when session `endedSession`
    /// ends — sign-out or expiry. `controller.stop()` and the `.idle` transition happen before this
    /// returns; whatever was playing gets a best-effort stopped report enqueued off-path (slice
    /// 021) against `endedSession` (not `self.session`, already nil by the time the report use case
    /// runs) rather than blocking the caller on the network (decision log).
    public func endSession(_ endedSession: UserSession) {
        tearDown(reportingTo: endedSession)
    }

    // MARK: - Private

    /// Tears playback down to `.idle`, mints a fresh generation so no stale progress tick from the
    /// operation just ended can touch state again, and enqueues the stopped report (if there is
    /// one) on the chain rather than awaiting it — shared by `stop()` and `endSession()` (slice 021
    /// decision log).
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

    /// The one place `status` moves to `.failed` — the controller's own `onFailure` and the
    /// stalled-player watchdog below both route through it, so a stall is reported exactly the way
    /// a genuine transport failure already is (decision log).
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

    /// The last track ended → advance, or finish the album exactly once. Captures the ending
    /// track's identity and generation at the moment `onEnded` fires, not when the `Task` runs, so
    /// a Next pressed while the natural end is still in flight cannot advance twice (Triage 26): by
    /// the time this `Task` runs, `next()` has already minted a new generation and moved on, and the
    /// check below sees it is no longer current.
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

    /// Stops playback, leaves `album`/`queue` in place so the wallet can return to the sleeve, and
    /// sets `finishedAlbumID` exactly once (§1.1, §9.1). No report here — the caller already
    /// enqueued the departing track's stopped report before deciding there was nowhere to advance.
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

    /// One loop on the 5 s now-playing cadence; every second tick is the 10 s progress report, so
    /// both §6 cadences share one task, one clock and one cancellation. Slice 021: also checks the
    /// operation generation, not only `status`/track identity, before touching anything.
    private func startProgressReporting(track: MediaItem, stream: AudioStream, generation: OperationGeneration) {
        progressTask?.cancel()
        progressTask = Task { [weak self] in
            var elapsed: Duration = .zero
            // Triage 24's stalled-player half: sampled once per tick, so this is function-local and
            // resets on every new `start(index:)` without needing an instance-level reset.
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

    /// Builds the stopped report for whatever is current right now and enqueues it on the report
    /// chain. Synchronous and called before the caller's own local transition, so it captures the
    /// departing track's identity, position and session before `start(index:)` overwrites them
    /// (slice 021 — replaces the old `await`ed `reportStoppedForCurrent()`).
    private func enqueueStoppedReportForCurrent() {
        guard let track = current, let session else { return }
        let stream = buildAudioStreamURL(track: track, session: session, playSessionID: playSessionID)
        let stoppedReport = report(for: track, position: position, isPaused: false, stream: stream)
        enqueueReport { [reportStopped] in await reportStopped(stoppedReport, session: session) }
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

    private func report(for track: MediaItem, position: Duration, isPaused: Bool, stream: AudioStream) -> PlaybackReport {
        PlaybackReport(
            itemID: track.id, mediaSourceID: track.id, playSessionID: playSessionID,
            position: position, isPaused: isPaused, method: .directAVPlayer, playMethod: stream.playMethod,
        )
    }

    private func refreshNowPlaying() {
        controller.updateNowPlaying(nowPlayingInfo(artwork: artwork))
    }

    /// Slice 021: re-checks the generation after the artwork fetch — a stale fetch for a track
    /// that has since been replaced can no longer overwrite the lock screen (codex's "stale
    /// artwork request").
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

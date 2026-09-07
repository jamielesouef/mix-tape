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
    /// The finish a wallet has claimed (slice 015). Not observed: claiming is bookkeeping, not state
    /// a view renders.
    @ObservationIgnored private var claimedFinishID: String?
    @ObservationIgnored private var playSessionID = UUID().uuidString
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
        controller.onFailure = { [weak self] error in self?.status = .failed(error) }
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

    /// Replaces the queue with exactly this album's tracks and starts at `index` (§1.1).
    public func play(album: MediaItem, tracks: [MediaItem], startingAt index: Int) async {
        guard tracks.isEmpty == false, tracks.indices.contains(index) else { return }
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

    /// Next track, or stop at the end — never advance past the last track (§1.1).
    public func next() async {
        guard let currentIndex else { return }
        await reportStoppedForCurrent()
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
        await reportStoppedForCurrent()
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

    public func stop() async {
        progressTask?.cancel()
        progressTask = nil
        await reportStoppedForCurrent()
        controller.stop()
        status = .idle
        album = nil
        queue = []
        currentIndex = nil
        position = .zero
        finishedAlbumID = nil
        claimedFinishID = nil
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

    // MARK: - Private

    private func start(index: Int) async {
        guard let session, queue.indices.contains(index) else { return }
        progressTask?.cancel()
        currentIndex = index
        position = .zero
        playSessionID = UUID().uuidString
        status = .preparing
        let track = queue[index]
        let stream = buildAudioStreamURL(track: track, session: session)
        controller.load(url: stream.url)
        controller.play()
        controller.setNextTrackEnabled(index + 1 < queue.count)
        status = .playing
        await refreshNowPlayingAsync()
        await reportStart(report(for: track, position: .zero, isPaused: false, stream: stream), session: session)
        startProgressReporting(track: track, stream: stream)
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

    /// The last track ended → advance, or finish the album exactly once.
    private func trackDidEnd() {
        Task { [weak self] in
            guard let self, let currentIndex else { return }
            await reportStoppedForCurrent()
            if currentIndex + 1 < queue.count {
                await start(index: currentIndex + 1)
            } else {
                finish()
            }
        }
    }

    /// Stops playback, leaves `album`/`queue` in place so the wallet can return to the sleeve, and
    /// sets `finishedAlbumID` exactly once (§1.1, §9.1).
    private func finish() {
        progressTask?.cancel()
        progressTask = nil
        controller.stop()
        status = .idle
        position = .zero
        claimedFinishID = nil
        finishedAlbumID = album?.id
        currentIndex = nil
    }

    /// One loop on the 5 s now-playing cadence; every second tick is the 10 s progress report, so
    /// both §6 cadences share one task, one clock and one cancellation.
    private func startProgressReporting(track: MediaItem, stream: AudioStream) {
        progressTask?.cancel()
        progressTask = Task { [weak self] in
            var elapsed: Duration = .zero
            while true {
                guard let clock = self?.clock else { return }
                do {
                    try await clock.sleep(for: Self.nowPlayingInterval)
                } catch {
                    return
                }
                guard let self, Task.isCancelled == false else { return }
                guard status == .playing, current?.id == track.id, let session else { continue }
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
        let stream = buildAudioStreamURL(track: track, session: session)
        Task { await reportProgress(report(for: track, position: position, isPaused: isPaused, stream: stream), session: session) }
    }

    private func reportStoppedForCurrent() async {
        guard let track = current, let session else { return }
        let stream = buildAudioStreamURL(track: track, session: session)
        await reportStopped(report(for: track, position: position, isPaused: false, stream: stream), session: session)
    }

    private func report(for track: MediaItem, position: Duration, isPaused: Bool, stream: AudioStream) -> PlaybackReport {
        PlaybackReport(
            itemID: track.id, mediaSourceID: track.id, playSessionID: playSessionID,
            position: position, isPaused: isPaused, method: .directAVPlayer, playMethod: stream.playMethod,
        )
    }

    private func refreshNowPlaying() {
        controller.updateNowPlaying(nowPlayingInfo(artwork: nil))
    }

    private func refreshNowPlayingAsync() async {
        var artwork: UIImage?
        if let track = current, let artworkProvider {
            artwork = await artworkProvider(track)
        }
        controller.updateNowPlaying(nowPlayingInfo(artwork: artwork))
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

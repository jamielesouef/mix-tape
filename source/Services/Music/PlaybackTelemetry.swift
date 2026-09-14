//  PlaybackTelemetry.swift
//  mixtape
//
//  Created by Jamie Le Souëf on 14/09/2026.
//

/// Everything `MusicPlayerService` tells the outside world about what is playing: server
/// reports, the now-playing lock screen surface, and the while-playing tick cadence.
///
/// Owns the three collaborators that each do one piece of this — `PlaybackReporter`,
/// `PlaybackProgressTicker`, `NowPlayingCoordinator` — so `MusicPlayerService` itself only
/// holds playback state and transport decisions, not the mechanics of reporting them.
@MainActor
final class PlaybackTelemetry {
    private let reporter: PlaybackReporter
    private let ticker: PlaybackProgressTicker
    private let nowPlaying: NowPlayingCoordinator

    init(
        reporter: PlaybackReporter,
        ticker: PlaybackProgressTicker,
        nowPlaying: NowPlayingCoordinator
    ) {
        self.reporter = reporter
        self.ticker = ticker
        self.nowPlaying = nowPlaying
    }

    // MARK: - Session lifecycle

    func beginSession() {
        reporter.beginSession()
    }

    func audioStream(for track: MediaItem, session: UserSession) -> AudioStream {
        reporter.audioStream(for: track, session: session)
    }

    func reportStarted(
        track: MediaItem,
        position: Duration,
        stream: AudioStream,
        session: UserSession
    ) {
        reporter.started(track: track, position: position, stream: stream, session: session)
    }

    /// No-ops when there is no current track or no signed-in session to report against.
    func reportStopped(track: MediaItem?, position: Duration, session: UserSession?) {
        guard let track, let session else {
            return
        }

        reporter.stopped(track: track, position: position, session: session)
    }

    /// No-ops when there is no current track or no signed-in session to report against.
    func reportOnce(track: MediaItem?, position: Duration, isPaused: Bool, session: UserSession?) {
        guard let track, let session else {
            return
        }

        Task { [reporter] in
            await reporter.progress(
                track: track,
                position: position,
                isPaused: isPaused,
                session: session
            )
        }
    }

    func reportProgress(track: MediaItem, position: Duration, session: UserSession) async {
        await reporter.progress(track: track, position: position, isPaused: false, session: session)
    }

    /// Waits for the queued start and stopped reports to reach the server.
    func drain() async {
        await reporter.drain()
    }

    // MARK: - Now playing

    func clearArtwork() {
        nowPlaying.clearArtwork()
    }

    func loadArtwork(for track: MediaItem, isStillCurrent: @MainActor () -> Bool) async {
        await nowPlaying.loadArtwork(for: track, isStillCurrent: isStillCurrent)
    }

    func refreshNowPlaying(
        track: MediaItem?,
        album: MediaItem?,
        position: Duration,
        isPlaying: Bool
    ) {
        nowPlaying.refresh(track: track, album: album, position: position, isPlaying: isPlaying)
    }

    // MARK: - Cadence

    func startTicking(
        position: @escaping @MainActor () -> Duration?,
        handle: @escaping @MainActor (PlaybackProgressTicker.Tick) async -> Void
    ) {
        ticker.start(position: position, handle: handle)
    }

    func stopTicking() {
        ticker.cancel()
    }
}

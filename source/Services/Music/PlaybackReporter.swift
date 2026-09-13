//  PlaybackReporter.swift
//  mixtape
//
//  Created by Jamie Le Souëf on 13/09/2026.
//

import Foundation

/// Everything the player tells the server about one play session: the stream it opened, and the
/// start, progress and stopped reports that follow.
///
/// Start and stopped reports are queued behind one another, so a slow request cannot let the
/// server see a later transition before an earlier one. Progress is a heartbeat rather than a
/// transition, so it is sent directly and does not join that queue.
@MainActor
final class PlaybackReporter {
    private(set) var playSessionID = UUID().uuidString

    private let buildAudioStreamURL: BuildAudioStreamURLUseCase
    private let reportStart: ReportPlaybackStartUseCase
    private let reportProgress: ReportPlaybackProgressUseCase
    private let reportStopped: ReportPlaybackStoppedUseCase

    private var queue: Task<Void, Never>?

    init(
        buildAudioStreamURL: BuildAudioStreamURLUseCase,
        reportStart: ReportPlaybackStartUseCase,
        reportProgress: ReportPlaybackProgressUseCase,
        reportStopped: ReportPlaybackStoppedUseCase
    ) {
        self.buildAudioStreamURL = buildAudioStreamURL
        self.reportStart = reportStart
        self.reportProgress = reportProgress
        self.reportStopped = reportStopped
    }

    /// Jellyfin keys a playback session on this id, so every track opens a fresh one.
    func beginSession() {
        playSessionID = UUID().uuidString
    }

    func audioStream(for track: MediaItem, session: UserSession) -> AudioStream {
        buildAudioStreamURL(track: track, session: session, playSessionID: playSessionID)
    }

    func started(
        track: MediaItem,
        position: Duration,
        stream: AudioStream,
        session: UserSession
    ) {
        let report = makeReport(for: track, position: position, isPaused: false, stream: stream)

        enqueue { [reportStart] in await reportStart(report, session: session) }
    }

    func stopped(track: MediaItem, position: Duration, session: UserSession) {
        let stream = audioStream(for: track, session: session)
        let report = makeReport(for: track, position: position, isPaused: false, stream: stream)

        enqueue { [reportStopped] in await reportStopped(report, session: session) }
    }

    func progress(
        track: MediaItem,
        position: Duration,
        isPaused: Bool,
        session: UserSession
    ) async {
        let stream = audioStream(for: track, session: session)
        let report = makeReport(for: track, position: position, isPaused: isPaused, stream: stream)

        await reportProgress(report, session: session)
    }

    /// Waits for the queued start and stopped reports to reach the server.
    func drain() async {
        await queue?.value
    }

    // MARK: - Private

    private func makeReport(
        for track: MediaItem,
        position: Duration,
        isPaused: Bool,
        stream: AudioStream
    ) -> PlaybackReport {
        PlaybackReport(
            itemID: track.id,
            mediaSourceID: track.id,
            playSessionID: playSessionID,
            position: position,
            isPaused: isPaused,
            playMethod: stream.playMethod
        )
    }

    private func enqueue(_ send: @escaping () async -> Void) {
        let previous = queue

        queue = Task {
            await previous?.value
            await send()
        }
    }
}

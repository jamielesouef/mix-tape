//  MusicPlayerFixture.swift
//  mixtape
//
//  Created by Jamie Le Souëf on 13/09/2026.
//

import Foundation
import UIKit
@testable import Mixtape

/// Shared setup for the MusicPlayerService suites, which are split across files by topic.
@MainActor
enum MusicPlayerFixture {
    static func makeService(
        reports: ReportLog = ReportLog(),
        controller: StubAudioPlayerController,
        clock: any Clock<Duration> = ContinuousClock(),
        artworkProvider: (@Sendable (MediaItem) async -> UIImage?)? = nil
    ) -> MusicPlayerService {
        let repository = MockPlaybackRepository(
            reportStartResult: { report, _ in reports.append("start \(report.itemID)") },
            reportProgressResult: { report, _ in
                reports.append("progress \(report.itemID) paused=\(report.isPaused)")
            },
            reportStoppedResult: { report, _ in reports.append("stopped \(report.itemID)") }
        )
        return MusicPlayerService(
            controller: controller,
            buildAudioStreamURL: BuildAudioStreamURLUseCase(repository: repository),
            reportStart: ReportPlaybackStartUseCase(repository: repository),
            reportProgress: ReportPlaybackProgressUseCase(repository: repository),
            reportStopped: ReportPlaybackStoppedUseCase(repository: repository),
            sessionService: MockSessionService.signedIn(),
            clock: clock,
            artworkProvider: artworkProvider
        )
    }

    static func settle() async {
        for _ in 0 ..< 30 {
            await Task.yield()
        }
    }

    static func track(_ id: String, index: Int) -> MediaItem {
        MediaItem(
            id: id,
            name: id,
            kind: .audio,
            overview: nil,
            productionYear: nil,
            runtime: .seconds(200),
            indexNumber: index,
            parentIndexNumber: 1,
            albumArtist: "Test Artist",
            primaryImageTag: nil,
            backdropImageTag: nil,
            parentPrimaryImageTag: nil,
            albumID: "album-x",
            playback: PlaybackState(position: .zero)
        )
    }
}

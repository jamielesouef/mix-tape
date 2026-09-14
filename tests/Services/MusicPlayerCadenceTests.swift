//  MusicPlayerCadenceTests.swift
//  mixtape
//
//  Created by Jamie Le Souëf on 13/09/2026.
//

import Foundation
import Testing
import UIKit
@testable import Mixtape

@Suite(.tags(.service))
@MainActor
struct MusicPlayerCadenceTests {
    private let album = MockLibraryRepository.sampleAlbums[0]
    private let tracks = MockLibraryRepository.sampleTracks

    // MARK: §6 cadences (slice 014)

    @Test
    func `now playing refreshes every five seconds and progress reports every ten`() async {
        let reports = ReportLog()
        let controller = StubAudioPlayerController()
        let clock = ManualClock()
        let cover = UIImage()
        let service = MusicPlayerFixture.makeService(
            reports: reports,
            controller: controller,
            clock: clock,
            artworkProvider: { _ in cover }
        )
        await service.play(album: album, tracks: tracks, startingAt: 0)
        let refreshesAtStart = controller.nowPlayingHistory.count
        #expect(controller.nowPlayingHistory.last?.artwork === cover)
        await clock.tick()
        #expect(await eventually { controller.nowPlayingHistory.count == refreshesAtStart + 1 })
        #expect(controller.nowPlayingHistory.last?.artwork === cover)
        #expect(await eventually { clock.sleeperCount == 1 })
        #expect(reports.entries == ["start \(tracks[0].id)"])
        await clock.tick()
        #expect(await eventually { reports.entries.count == 2 })
        #expect(controller.nowPlayingHistory.count == refreshesAtStart + 2)
        #expect(reports.entries == [
            "start \(tracks[0].id)",
            "progress \(tracks[0].id) paused=false"
        ])
        #expect(controller.nowPlayingHistory.last?.isPlaying == true)
        #expect(controller.nowPlayingHistory.last?.artwork === cover)
        await service.stop()
    }

    // MARK: Slice 023 — audio-session and service hardening

    @Test
    func `AC23h a player that stops advancing position is reported as a stalled failure`() async {
        let controller = StubAudioPlayerController()
        let clock = ManualClock()
        let service = MusicPlayerFixture.makeService(controller: controller, clock: clock)
        await service.play(album: album, tracks: tracks, startingAt: 0)
        controller.onPositionChange?(.seconds(5))
        for _ in 0 ... MusicPlayerService.stallTickThreshold {
            await clock.tick()
        }
        #expect(await eventually {
            if case .failed = service.status {
                true
            } else {
                false
            }
        })
    }

    @Test
    func `AC23h the watchdog stays armed-off during initial buffering before position ever advances`(
    ) async {
        let controller = StubAudioPlayerController()
        let clock = ManualClock()
        let service = MusicPlayerFixture.makeService(controller: controller, clock: clock)
        await service.play(album: album, tracks: tracks, startingAt: 0)
        for _ in 0 ... MusicPlayerService.stallTickThreshold {
            await clock.tick()
        }
        #expect(await eventually { clock.sleeperCount == 1 })
        #expect(service.status == .playing)
    }

    @Test
    func `AC23i a next pressed before the natural-end task runs lands on N plus one, not N plus two`(
    ) async {
        let reports = ReportLog()
        let controller = StubAudioPlayerController()
        let threeTracks = [
            MusicPlayerFixture.track("n0", index: 0),
            MusicPlayerFixture.track("n1", index: 1),
            MusicPlayerFixture.track("n2", index: 2)
        ]
        let service = MusicPlayerFixture.makeService(reports: reports, controller: controller)
        await service.play(album: album, tracks: threeTracks, startingAt: 0)
        controller.finishTrack()
        await service.next()
        await MusicPlayerFixture.settle()
        #expect(service.currentIndex == 1)
        await reports.waitForCount(3)
        #expect(reports.entries == ["start n0", "stopped n0", "start n1"])
    }
}

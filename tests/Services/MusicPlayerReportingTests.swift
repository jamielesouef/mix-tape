//  MusicPlayerReportingTests.swift
//  mixtape
//
//  Created by Jamie Le Souëf on 13/09/2026.
//

import Foundation
import Testing
@testable import Mixtape

@Suite(.tags(.service))
@MainActor
struct MusicPlayerReportingTests {
    private let album = MockLibraryRepository.sampleAlbums[0]
    private let tracks = MockLibraryRepository.sampleTracks

    // MARK: decision 34 reporting

    @Test
    func `each track reports start and the previous track a stop, with no cross-album behaviour`(
    ) async {
        let reports = ReportLog()
        let controller = StubAudioPlayerController()
        let service = MusicPlayerFixture.makeService(reports: reports, controller: controller)
        await service.play(album: album, tracks: tracks, startingAt: 0)
        controller.finishTrack()
        await MusicPlayerFixture.settle()
        controller.finishTrack()
        await MusicPlayerFixture.settle()
        #expect(reports.entries == [
            "start \(tracks[0].id)",
            "stopped \(tracks[0].id)",
            "start \(tracks[1].id)",
            "stopped \(tracks[1].id)"
        ])
        #expect(service.queue == tracks)
    }

    @Test
    func `no report fires for a track that was never played`() async {
        let reports = ReportLog()
        let service = MusicPlayerFixture.makeService(
            reports: reports,
            controller: StubAudioPlayerController()
        )
        #expect(reports.entries.isEmpty)
        await service.stop()
        #expect(reports.entries.isEmpty)
    }

    @Test
    func `nothing plays without a signed-in session`() async {
        let reports = ReportLog()
        let controller = StubAudioPlayerController()
        let repository = MockPlaybackRepository(reportStartResult: { report, _ in
            reports.append("start \(report.itemID)")
        })
        let service = MusicPlayerService(
            controller: controller,
            buildAudioStreamURL: BuildAudioStreamURLUseCase(repository: repository),
            reportStart: ReportPlaybackStartUseCase(repository: repository),
            reportProgress: ReportPlaybackProgressUseCase(repository: repository),
            reportStopped: ReportPlaybackStoppedUseCase(repository: repository),
            sessionService: MockSessionService.signedOut()
        )
        await service.play(album: album, tracks: tracks, startingAt: 0)
        #expect(service.status == .idle)
        #expect(reports.entries.isEmpty)
        #expect(controller.loadedURLs.isEmpty)
    }

    // MARK: Slice 020 — session-owned teardown

    @Test
    func `sign-out mid album stops the player synchronously before the stopped report lands`(
    ) async {
        let gate = Gate()
        gate.close()
        let reports = ReportLog()
        let repository = MockPlaybackRepository(reportStoppedResult: { report, _ in
            await gate.wait()
            reports.append("stopped \(report.itemID)")
        })
        let controller = StubAudioPlayerController()
        let sessionService = MockSessionService.signedIn()
        let service = MusicPlayerService(
            controller: controller,
            buildAudioStreamURL: BuildAudioStreamURLUseCase(repository: repository),
            reportStart: ReportPlaybackStartUseCase(repository: repository),
            reportProgress: ReportPlaybackProgressUseCase(repository: repository),
            reportStopped: ReportPlaybackStoppedUseCase(repository: repository),
            sessionService: sessionService
        )
        sessionService.onSessionEnded = { session in service.endSession(session) }
        await service.play(album: album, tracks: tracks, startingAt: 0)
        #expect(service.status == .playing)
        sessionService.signOut()
        #expect(service.status == .idle)
        #expect(service.album == nil)
        #expect(service.queue.isEmpty)
        #expect(controller.stopCount == 1)
        #expect(reports.entries.isEmpty)
        gate.open()
        #expect(await eventually { reports.entries == ["stopped \(tracks[0].id)"] })
    }

    // MARK: Slice 021 — operation generations

    @Test
    func `AC21c rapid play-next-next serialises the reports in call order and never reverts the displayed track`(
    ) async {
        let gate = Gate()
        gate.close()
        let reports = ReportLog()
        let controller = StubAudioPlayerController()
        let threeTracks = [
            MusicPlayerFixture.track("t0", index: 0),
            MusicPlayerFixture.track("t1", index: 1),
            MusicPlayerFixture.track("t2", index: 2)
        ]
        let repository = MockPlaybackRepository(
            reportStartResult: { report, _ in
                await gate.wait()
                reports.append("start \(report.itemID)")
            },
            reportStoppedResult: { report, _ in
                await gate.wait()
                reports.append("stopped \(report.itemID)")
            }
        )
        let service = MusicPlayerService(
            controller: controller,
            buildAudioStreamURL: BuildAudioStreamURLUseCase(repository: repository),
            reportStart: ReportPlaybackStartUseCase(repository: repository),
            reportProgress: ReportPlaybackProgressUseCase(repository: repository),
            reportStopped: ReportPlaybackStoppedUseCase(repository: repository),
            sessionService: MockSessionService.signedIn()
        )
        await service.play(album: album, tracks: threeTracks, startingAt: 0)
        await service.next()
        await service.next()
        #expect(service.current?.id == "t2")
        #expect(reports.entries.isEmpty)
        gate.open()
        await reports.waitForCount(5)
        #expect(reports.entries == ["start t0", "stopped t0", "start t1", "stopped t1", "start t2"])
        #expect(service.current?.id == "t2")
    }

    @Test
    func `AC21d next completes the local transition before its stopped report lands`() async {
        let gate = Gate()
        gate.close()
        let reports = ReportLog()
        let controller = StubAudioPlayerController()
        let repository = MockPlaybackRepository(reportStoppedResult: { report, _ in
            await gate.wait()
            reports.append("stopped \(report.itemID)")
        })
        let service = MusicPlayerService(
            controller: controller,
            buildAudioStreamURL: BuildAudioStreamURLUseCase(repository: repository),
            reportStart: ReportPlaybackStartUseCase(repository: repository),
            reportProgress: ReportPlaybackProgressUseCase(repository: repository),
            reportStopped: ReportPlaybackStoppedUseCase(repository: repository),
            sessionService: MockSessionService.signedIn()
        )
        await service.play(album: album, tracks: tracks, startingAt: 0)
        await service.next()
        #expect(service.currentIndex == 1)
        #expect(service.status == .playing)
        #expect(controller.loadedURLs.count == 2)
        #expect(reports.entries.isEmpty)
        gate.open()
        await reports.waitForCount(1)
        #expect(reports.entries == ["stopped \(tracks[0].id)"])
    }

    @Test
    func `AC21e a replacement play sends the interrupted album's stopped report before the new album's start`(
    ) async {
        let reports = ReportLog()
        let controller = StubAudioPlayerController()
        let service = MusicPlayerFixture.makeService(reports: reports, controller: controller)
        await service.play(album: album, tracks: tracks, startingAt: 0)
        let otherAlbum = MockLibraryRepository.sampleAlbums[1]
        await service.play(
            album: otherAlbum,
            tracks: [MusicPlayerFixture.track("x0", index: 0)],
            startingAt: 0
        )
        await reports.waitForCount(3)
        #expect(reports.entries == [
            "start \(tracks[0].id)",
            "stopped \(tracks[0].id)",
            "start x0"
        ])
    }
}

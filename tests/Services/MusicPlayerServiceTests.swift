//  MusicPlayerServiceTests.swift
//  mixtape
//
//  Created by Jamie Le Souëf on 03/09/2026.
//

import Foundation
@testable import Mixtape
import Testing
import UIKit

@Suite(.tags(.service))
@MainActor
struct MusicPlayerServiceTests {
    private let album = MockLibraryRepository.sampleAlbums[0]
    private let tracks = MockLibraryRepository.sampleTracks

    private func makeService(reports: ReportLog = ReportLog(), controller: StubAudioPlayerController, clock: any Clock<Duration> = ContinuousClock(), artworkProvider: (@Sendable (MediaItem) async -> UIImage?)? = nil) -> MusicPlayerService {
        let repository = MockPlaybackRepository(
            reportStartResult: { r, _ in reports.append("start \(r.itemID)") },
            reportProgressResult: { r, _ in reports.append("progress \(r.itemID) paused=\(r.isPaused)") },
            reportStoppedResult: { r, _ in reports.append("stopped \(r.itemID)") },
        )
        return MusicPlayerService(
            controller: controller,
            buildAudioStreamURL: BuildAudioStreamURLUseCase(repository: repository),
            reportStart: ReportPlaybackStartUseCase(repository: repository),
            reportProgress: ReportPlaybackProgressUseCase(repository: repository),
            reportStopped: ReportPlaybackStoppedUseCase(repository: repository),
            sessionService: MockSessionService.signedIn(),
            clock: clock,
            artworkProvider: artworkProvider,
        )
    }

    // MARK: §1.1 invariants

    @Test func `play replaces the queue and starts at the given index`() async {
        let service = makeService(controller: StubAudioPlayerController())
        await service.play(album: album, tracks: tracks, startingAt: 1)
        #expect(service.queue == tracks)
        #expect(service.currentIndex == 1)
        #expect(service.current?.id == tracks[1].id)
        #expect(service.status == .playing)
    }

    @Test func `playing a second album replaces the queue rather than appending`() async {
        let service = makeService(controller: StubAudioPlayerController())
        await service.play(album: album, tracks: tracks, startingAt: 0)
        let other = [tracks[0]]
        await service.play(album: MockLibraryRepository.sampleAlbums[1], tracks: other, startingAt: 0)
        #expect(service.queue == other)
        #expect(service.queue.count == 1)
    }

    @Test func `next past the final track stops rather than advancing`() async {
        let service = makeService(controller: StubAudioPlayerController())
        await service.play(album: album, tracks: tracks, startingAt: 1)
        await service.next()
        #expect(service.status == .idle)
        #expect(service.finishedAlbumID == album.id)
        #expect(service.currentIndex == nil)
        #expect(service.queue == tracks)
    }

    @Test func `finishedAlbumID fires exactly once at end of album and clears on acknowledge`() async {
        let controller = StubAudioPlayerController()
        let service = makeService(controller: controller)
        await service.play(album: album, tracks: tracks, startingAt: 0)
        controller.finishTrack()
        await settle()
        #expect(service.currentIndex == 1)
        #expect(service.finishedAlbumID == nil)
        controller.finishTrack()
        await settle()
        #expect(service.finishedAlbumID == album.id)
        service.acknowledgeFinish()
        #expect(service.finishedAlbumID == nil)
    }

    @Test func `previous restarts above three seconds and steps back below`() async {
        let controller = StubAudioPlayerController()
        let service = makeService(controller: controller)
        await service.play(album: album, tracks: tracks, startingAt: 1)
        controller.onPositionChange?(.seconds(5))
        await service.previous()
        #expect(service.currentIndex == 1)
        controller.onPositionChange?(.seconds(1))
        await service.previous()
        #expect(service.currentIndex == 0)
    }

    @Test func `the next-track command is disabled on the final track`() async {
        let controller = StubAudioPlayerController()
        let service = makeService(controller: controller)
        await service.play(album: album, tracks: tracks, startingAt: 0)
        #expect(controller.nextEnabledHistory.last == true)
        controller.finishTrack()
        await settle()
        #expect(controller.nextEnabledHistory.last == false)
    }

    // MARK: decision 34 reporting

    @Test func `each track reports start and the previous track a stop, with no cross-album behaviour`() async {
        let reports = ReportLog()
        let controller = StubAudioPlayerController()
        let service = makeService(reports: reports, controller: controller)
        await service.play(album: album, tracks: tracks, startingAt: 0)
        controller.finishTrack()
        await settle()
        controller.finishTrack()
        await settle()
        #expect(reports.entries == [
            "start \(tracks[0].id)",
            "stopped \(tracks[0].id)",
            "start \(tracks[1].id)",
            "stopped \(tracks[1].id)",
        ])
        #expect(service.queue == tracks)
    }

    @Test func `no report fires for a track that was never played`() async {
        let reports = ReportLog()
        let service = makeService(reports: reports, controller: StubAudioPlayerController())
        #expect(reports.entries.isEmpty)
        await service.stop()
        #expect(reports.entries.isEmpty)
    }

    @Test func `nothing plays without a signed-in session`() async {
        let reports = ReportLog()
        let controller = StubAudioPlayerController()
        let repository = MockPlaybackRepository(reportStartResult: { r, _ in reports.append("start \(r.itemID)") })
        let service = MusicPlayerService(
            controller: controller,
            buildAudioStreamURL: BuildAudioStreamURLUseCase(repository: repository),
            reportStart: ReportPlaybackStartUseCase(repository: repository),
            reportProgress: ReportPlaybackProgressUseCase(repository: repository),
            reportStopped: ReportPlaybackStoppedUseCase(repository: repository),
            sessionService: MockSessionService.signedOut(),
        )
        await service.play(album: album, tracks: tracks, startingAt: 0)
        #expect(service.status == .idle)
        #expect(reports.entries.isEmpty)
        #expect(controller.loadedURLs.isEmpty)
    }

    // MARK: Finish ownership and the final track (slice 015)

    @Test func `a finish is claimed once, only by its live album id, and a later finish can be claimed again`() async {
        let service = makeService(controller: StubAudioPlayerController())
        #expect(service.claimFinish(albumID: album.id) == false)
        await service.play(album: album, tracks: tracks, startingAt: tracks.count - 1)
        await service.next()
        #expect(service.claimFinish(albumID: "some-other-album") == false)
        #expect(service.claimFinish(albumID: album.id) == true)
        #expect(service.claimFinish(albumID: album.id) == false)
        service.acknowledgeFinish()
        #expect(service.claimFinish(albumID: album.id) == false)
        await service.play(album: album, tracks: tracks, startingAt: tracks.count - 1)
        await service.next()
        #expect(service.claimFinish(albumID: album.id) == true)
    }

    @Test func `next has somewhere to go before the final track and nowhere on it`() async {
        let service = makeService(controller: StubAudioPlayerController())
        #expect(service.hasNextTrack == false)
        await service.play(album: album, tracks: tracks, startingAt: 0)
        #expect(service.hasNextTrack == true)
        await service.next()
        #expect(service.currentIndex == tracks.count - 1)
        #expect(service.hasNextTrack == false)
        await service.next()
        #expect(service.hasNextTrack == false)
        #expect(service.queue == tracks)
    }

    @Test func `a seek to the end reaches the controller unclamped`() async {
        let controller = StubAudioPlayerController()
        let service = makeService(controller: controller)
        await service.play(album: album, tracks: tracks, startingAt: 0)
        let runtime = tracks[0].runtime ?? .zero
        service.seek(to: runtime)
        #expect(controller.seeks.last == runtime)
        #expect(service.position == runtime)
        service.seek(to: .seconds(12))
        #expect(controller.seeks.last == .seconds(12))
        service.seek(to: .seconds(-5))
        #expect(controller.seeks.last == .zero)
    }

    // MARK: Slice 020 — session-owned teardown

    @Test func `sign-out mid album stops the player synchronously before the stopped report lands`() async {
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
            sessionService: sessionService,
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

    @Test func `AC21c rapid play-next-next serialises the reports in call order and never reverts the displayed track`() async {
        let gate = Gate()
        gate.close()
        let reports = ReportLog()
        let controller = StubAudioPlayerController()
        let threeTracks = [Self.track("t0", index: 0), Self.track("t1", index: 1), Self.track("t2", index: 2)]
        let repository = MockPlaybackRepository(
            reportStartResult: { r, _ in await gate.wait(); reports.append("start \(r.itemID)") },
            reportStoppedResult: { r, _ in await gate.wait(); reports.append("stopped \(r.itemID)") },
        )
        let service = MusicPlayerService(
            controller: controller,
            buildAudioStreamURL: BuildAudioStreamURLUseCase(repository: repository),
            reportStart: ReportPlaybackStartUseCase(repository: repository),
            reportProgress: ReportPlaybackProgressUseCase(repository: repository),
            reportStopped: ReportPlaybackStoppedUseCase(repository: repository),
            sessionService: MockSessionService.signedIn(),
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

    @Test func `AC21d next completes the local transition before its stopped report lands`() async {
        let gate = Gate()
        gate.close()
        let reports = ReportLog()
        let controller = StubAudioPlayerController()
        let repository = MockPlaybackRepository(reportStoppedResult: { r, _ in
            await gate.wait()
            reports.append("stopped \(r.itemID)")
        })
        let service = MusicPlayerService(
            controller: controller,
            buildAudioStreamURL: BuildAudioStreamURLUseCase(repository: repository),
            reportStart: ReportPlaybackStartUseCase(repository: repository),
            reportProgress: ReportPlaybackProgressUseCase(repository: repository),
            reportStopped: ReportPlaybackStoppedUseCase(repository: repository),
            sessionService: MockSessionService.signedIn(),
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

    @Test func `AC21e a replacement play sends the interrupted album's stopped report before the new album's start`() async {
        let reports = ReportLog()
        let controller = StubAudioPlayerController()
        let service = makeService(reports: reports, controller: controller)
        await service.play(album: album, tracks: tracks, startingAt: 0)
        let otherAlbum = MockLibraryRepository.sampleAlbums[1]
        await service.play(album: otherAlbum, tracks: [Self.track("x0", index: 0)], startingAt: 0)
        await reports.waitForCount(3)
        #expect(reports.entries == [
            "start \(tracks[0].id)",
            "stopped \(tracks[0].id)",
            "start x0",
        ])
    }

    // MARK: §6 cadences (slice 014)

    @Test func `now playing refreshes every five seconds and progress reports every ten`() async {
        let reports = ReportLog()
        let controller = StubAudioPlayerController()
        let clock = ManualClock()
        let cover = UIImage()
        let service = makeService(reports: reports, controller: controller, clock: clock, artworkProvider: { _ in cover })
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
        #expect(reports.entries == ["start \(tracks[0].id)", "progress \(tracks[0].id) paused=false"])
        #expect(controller.nowPlayingHistory.last?.isPlaying == true)
        #expect(controller.nowPlayingHistory.last?.artwork === cover)
        await service.stop()
    }

    // MARK: Slice 023 — audio-session and service hardening

    @Test func `AC23h a player that stops advancing position is reported as a stalled failure`() async {
        let controller = StubAudioPlayerController()
        let clock = ManualClock()
        let service = makeService(controller: controller, clock: clock)
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

    @Test func `AC23h the watchdog stays armed-off during initial buffering before position ever advances`() async {
        let controller = StubAudioPlayerController()
        let clock = ManualClock()
        let service = makeService(controller: controller, clock: clock)
        await service.play(album: album, tracks: tracks, startingAt: 0)
        for _ in 0 ... MusicPlayerService.stallTickThreshold {
            await clock.tick()
        }
        #expect(await eventually { clock.sleeperCount == 1 })
        #expect(service.status == .playing)
    }

    @Test func `AC23i a next pressed before the natural-end task runs lands on N plus one, not N plus two`() async {
        let reports = ReportLog()
        let controller = StubAudioPlayerController()
        let threeTracks = [Self.track("n0", index: 0), Self.track("n1", index: 1), Self.track("n2", index: 2)]
        let service = makeService(reports: reports, controller: controller)
        await service.play(album: album, tracks: threeTracks, startingAt: 0)
        controller.finishTrack()
        await service.next()
        await settle()
        #expect(service.currentIndex == 1)
        await reports.waitForCount(3)
        #expect(reports.entries == ["start n0", "stopped n0", "start n1"])
    }

    private func settle() async {
        for _ in 0 ..< 30 {
            await Task.yield()
        }
    }

    private static func track(_ id: String, index: Int) -> MediaItem {
        MediaItem(
            id: id, name: id, kind: .audio, overview: nil, productionYear: nil, runtime: .seconds(200),
            indexNumber: index, parentIndexNumber: 1, albumArtist: "Test Artist",
            primaryImageTag: nil, backdropImageTag: nil, parentPrimaryImageTag: nil, albumID: "album-x",
            playback: PlaybackState(position: .zero),
        )
    }
}

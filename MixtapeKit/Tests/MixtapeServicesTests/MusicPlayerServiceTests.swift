//  MusicPlayerServiceTests.swift
//  MixtapeServicesTests
//
//  Created by Jamie Le Souëf on 03/09/2026.
//

import Foundation
import MixtapeDomain
@testable import MixtapeServices
import MixtapeUseCase
import Testing

@Suite(.tags(.service))
@MainActor
struct MusicPlayerServiceTests {
    private let album = MockLibraryRepository.sampleAlbums[0]
    private let tracks = MockLibraryRepository.sampleTracks // two tracks

    private func makeService(reports: ReportLog = ReportLog(), controller: StubAudioPlayerController, clock: any Clock<Duration> = ContinuousClock()) -> MusicPlayerService {
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
        await service.play(album: album, tracks: tracks, startingAt: 1) // last of two
        await service.next()
        #expect(service.status == .idle)
        #expect(service.finishedAlbumID == album.id)
        #expect(service.currentIndex == nil)
        // The album and queue stay so the wallet can return to the sleeve.
        #expect(service.queue == tracks)
    }

    @Test func `finishedAlbumID fires exactly once at end of album and clears on acknowledge`() async {
        let controller = StubAudioPlayerController()
        let service = makeService(controller: controller)
        await service.play(album: album, tracks: tracks, startingAt: 0)
        controller.finishTrack() // track 1 ends -> advance to track 2
        await settle()
        #expect(service.currentIndex == 1)
        #expect(service.finishedAlbumID == nil)
        controller.finishTrack() // track 2 ends -> album finished
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
        await service.previous() // > 3 s -> restart, stays on track 2
        #expect(service.currentIndex == 1)
        controller.onPositionChange?(.seconds(1))
        await service.previous() // < 3 s -> step back to track 1
        #expect(service.currentIndex == 0)
    }

    @Test func `the next-track command is disabled on the final track`() async {
        let controller = StubAudioPlayerController()
        let service = makeService(controller: controller)
        await service.play(album: album, tracks: tracks, startingAt: 0)
        #expect(controller.nextEnabledHistory.last == true) // first of two
        controller.finishTrack()
        await settle()
        #expect(controller.nextEnabledHistory.last == false) // last of two
    }

    // MARK: decision 34 reporting

    @Test func `each track reports start and the previous track a stop, with no cross-album behaviour`() async {
        let reports = ReportLog()
        let controller = StubAudioPlayerController()
        let service = makeService(reports: reports, controller: controller)
        await service.play(album: album, tracks: tracks, startingAt: 0)
        controller.finishTrack() // -> track 2
        await settle()
        controller.finishTrack() // -> finished
        await settle()
        #expect(reports.entries == [
            "start \(tracks[0].id)",
            "stopped \(tracks[0].id)",
            "start \(tracks[1].id)",
            "stopped \(tracks[1].id)",
        ])
        // The queue is still exactly one album after a full play.
        #expect(service.queue == tracks)
    }

    @Test func `no report fires for a track that was never played`() async {
        let reports = ReportLog()
        let service = makeService(reports: reports, controller: StubAudioPlayerController())
        // never called play
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
        #expect(service.claimFinish(albumID: album.id) == false) // nothing has finished
        await service.play(album: album, tracks: tracks, startingAt: tracks.count - 1)
        await service.next() // finished
        #expect(service.claimFinish(albumID: "some-other-album") == false)
        #expect(service.claimFinish(albumID: album.id) == true)
        #expect(service.claimFinish(albumID: album.id) == false) // the second wallet
        service.acknowledgeFinish()
        #expect(service.claimFinish(albumID: album.id) == false) // no live finish any more
        await service.play(album: album, tracks: tracks, startingAt: tracks.count - 1)
        await service.next()
        #expect(service.claimFinish(albumID: album.id) == true) // a fresh finish, a fresh claim
    }

    @Test func `next has somewhere to go before the final track and nowhere on it`() async {
        let service = makeService(controller: StubAudioPlayerController())
        #expect(service.hasNextTrack == false)
        await service.play(album: album, tracks: tracks, startingAt: 0)
        #expect(service.hasNextTrack == true)
        await service.next()
        #expect(service.currentIndex == tracks.count - 1)
        #expect(service.hasNextTrack == false)
        await service.next() // ends the album rather than advancing (§1.1)
        #expect(service.hasNextTrack == false)
        #expect(service.queue == tracks)
    }

    @Test func `a seek to or past the end lands short of it by the margin`() async {
        let controller = StubAudioPlayerController()
        let service = makeService(controller: controller)
        await service.play(album: album, tracks: tracks, startingAt: 0)
        let runtime = tracks[0].runtime ?? .zero
        service.seek(to: runtime) // the scrubber dragged to its maximum (Triage 7)
        #expect(controller.seeks.last == runtime - MusicPlayerService.endSeekMargin)
        #expect(service.position == runtime - MusicPlayerService.endSeekMargin)
        service.seek(to: runtime + .seconds(30))
        #expect(controller.seeks.last == runtime - MusicPlayerService.endSeekMargin)
        service.seek(to: .seconds(12)) // an ordinary seek is untouched
        #expect(controller.seeks.last == .seconds(12))
        service.seek(to: .seconds(-5))
        #expect(controller.seeks.last == .zero)
    }

    // MARK: §6 cadences (slice 014)

    @Test func `now playing refreshes every five seconds and progress reports every ten`() async {
        let reports = ReportLog()
        let controller = StubAudioPlayerController()
        let clock = ManualClock()
        let service = makeService(reports: reports, controller: controller, clock: clock)
        await service.play(album: album, tracks: tracks, startingAt: 0)
        let refreshesAtStart = controller.nowPlayingHistory.count
        await clock.tick() // 5 s
        #expect(await eventually { controller.nowPlayingHistory.count == refreshesAtStart + 1 })
        #expect(await eventually { clock.sleeperCount == 1 }) // back asleep without a report
        #expect(reports.entries == ["start \(tracks[0].id)"])
        await clock.tick() // 10 s
        #expect(await eventually { reports.entries.count == 2 })
        #expect(controller.nowPlayingHistory.count == refreshesAtStart + 2)
        #expect(reports.entries == ["start \(tracks[0].id)", "progress \(tracks[0].id) paused=false"])
        #expect(controller.nowPlayingHistory.last?.isPlaying == true)
        await service.stop()
    }

    private func settle() async {
        for _ in 0 ..< 30 {
            await Task.yield()
        }
    }
}

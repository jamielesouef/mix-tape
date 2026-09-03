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

    private func makeService(reports: ReportLog = ReportLog(), controller: StubAudioPlayerController) -> MusicPlayerService {
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

    private func settle() async {
        for _ in 0 ..< 30 {
            await Task.yield()
        }
    }
}

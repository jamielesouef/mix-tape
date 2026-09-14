//  MusicPlayerServiceTests.swift
//  mixtape
//
//  Created by Jamie Le Souëf on 03/09/2026.
//

import Foundation
import Testing
@testable import Mixtape

@Suite(.tags(.service))
@MainActor
struct MusicPlayerServiceTests {
    private let album = MockLibraryRepository.sampleAlbums[0]
    private let tracks = MockLibraryRepository.sampleTracks

    // MARK: §1.1 invariants

    @Test
    func `play replaces the queue and starts at the given index`() async {
        let service = MusicPlayerFixture.makeService(controller: StubAudioPlayerController())
        await service.play(album: album, tracks: tracks, startingAt: 1)
        #expect(service.queue == tracks)
        #expect(service.currentIndex == 1)
        #expect(service.current?.id == tracks[1].id)
        #expect(service.status == .playing)
    }

    @Test
    func `playing a second album replaces the queue rather than appending`() async {
        let service = MusicPlayerFixture.makeService(controller: StubAudioPlayerController())
        await service.play(album: album, tracks: tracks, startingAt: 0)
        let other = [tracks[0]]
        await service.play(
            album: MockLibraryRepository.sampleAlbums[1],
            tracks: other,
            startingAt: 0
        )
        #expect(service.queue == other)
        #expect(service.queue.count == 1)
    }

    @Test
    func `next past the final track stops rather than advancing`() async {
        let service = MusicPlayerFixture.makeService(controller: StubAudioPlayerController())
        await service.play(album: album, tracks: tracks, startingAt: 1)
        await service.next()
        #expect(service.status == .idle)
        #expect(service.finishedAlbumID == album.id)
        #expect(service.currentIndex == nil)
        #expect(service.queue == tracks)
    }

    @Test
    func `finishedAlbumID fires exactly once at end of album and clears on acknowledge`() async {
        let controller = StubAudioPlayerController()
        let service = MusicPlayerFixture.makeService(controller: controller)
        await service.play(album: album, tracks: tracks, startingAt: 0)
        controller.finishTrack()
        await MusicPlayerFixture.settle()
        #expect(service.currentIndex == 1)
        #expect(service.finishedAlbumID == nil)
        controller.finishTrack()
        await MusicPlayerFixture.settle()
        #expect(service.finishedAlbumID == album.id)
        service.acknowledgeFinish()
        #expect(service.finishedAlbumID == nil)
    }

    @Test
    func `previous restarts above three seconds and steps back below`() async {
        let controller = StubAudioPlayerController()
        let service = MusicPlayerFixture.makeService(controller: controller)
        await service.play(album: album, tracks: tracks, startingAt: 1)
        controller.onPositionChange?(.seconds(5))
        await service.previous()
        #expect(service.currentIndex == 1)
        controller.onPositionChange?(.seconds(1))
        await service.previous()
        #expect(service.currentIndex == 0)
    }

    @Test
    func `the next-track command is disabled on the final track`() async {
        let controller = StubAudioPlayerController()
        let service = MusicPlayerFixture.makeService(controller: controller)
        await service.play(album: album, tracks: tracks, startingAt: 0)
        #expect(controller.nextEnabledHistory.last == true)
        controller.finishTrack()
        await MusicPlayerFixture.settle()
        #expect(controller.nextEnabledHistory.last == false)
    }

    // MARK: Finish ownership and the final track (slice 015)

    @Test
    func `a finish is claimed once, only by its live album id, and a later finish can be claimed again`(
    ) async {
        let service = MusicPlayerFixture.makeService(controller: StubAudioPlayerController())
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

    @Test
    func `next has somewhere to go before the final track and nowhere on it`() async {
        let service = MusicPlayerFixture.makeService(controller: StubAudioPlayerController())
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

    @Test
    func `a seek to the end reaches the controller unclamped`() async {
        let controller = StubAudioPlayerController()
        let service = MusicPlayerFixture.makeService(controller: controller)
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
}

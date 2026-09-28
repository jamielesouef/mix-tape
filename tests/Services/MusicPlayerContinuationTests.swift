//  MusicPlayerContinuationTests.swift
//  mixtape
//
//  Created by Jamie Le Souëf on 28/09/2026.
//

import Testing
@testable import Mixtape

@Suite(.tags(.service))
@MainActor
struct MusicPlayerContinuationTests {
    private let albumA = MockLibraryRepository.sampleAlbums[0]
    private let albumB = MockLibraryRepository.sampleAlbums[1]
    private let tracksA = [MusicPlayerFixture.track("continuation-a0", index: 0)]
    private let tracksB = [MusicPlayerFixture.track("continuation-b0", index: 0)]

    @Test
    func `continue through wallet starts the next album in the captured sequence when the current one ends`(
    ) async {
        let albumB = albumB
        let tracksB = tracksB
        let repository = MockLibraryRepository(tracksResult: { albumID, _ in
            albumID == albumB.id ? tracksB : []
        })

        let settings = MockSettingsService.make(
            settings: LocalSettings(whenAlbumEnds: .continueThroughWallet)
        )

        let controller = StubAudioPlayerController()
        let service = MusicPlayerFixture.makeService(
            controller: controller,
            settingsService: settings,
            libraryRepository: repository
        )

        await service.play(album: albumA, tracks: tracksA, startingAt: 0, sequence: [albumB])
        controller.finishTrack()
        await MusicPlayerFixture.settle()

        #expect(service.album == albumB)
        #expect(service.queue == tracksB)
        #expect(service.status == .playing)
        #expect(service.finishedAlbumID == nil)
    }

    @Test
    func `stop after album ends normally even with a captured sequence waiting`() async {
        let controller = StubAudioPlayerController()
        let service = MusicPlayerFixture.makeService(controller: controller)

        await service.play(album: albumA, tracks: tracksA, startingAt: 0, sequence: [albumB])
        controller.finishTrack()
        await MusicPlayerFixture.settle()

        #expect(service.status == .idle)
        #expect(service.finishedAlbumID == albumA.id)
    }

    @Test
    func `continue through wallet ends normally once the captured sequence is exhausted`() async {
        let albumB = albumB
        let tracksB = tracksB
        let repository = MockLibraryRepository(tracksResult: { albumID, _ in
            albumID == albumB.id ? tracksB : []
        })

        let settings = MockSettingsService.make(
            settings: LocalSettings(whenAlbumEnds: .continueThroughWallet)
        )

        let controller = StubAudioPlayerController()
        let service = MusicPlayerFixture.makeService(
            controller: controller,
            settingsService: settings,
            libraryRepository: repository
        )

        await service.play(album: albumA, tracks: tracksA, startingAt: 0, sequence: [albumB])
        controller.finishTrack()
        await MusicPlayerFixture.settle()
        controller.finishTrack()
        await MusicPlayerFixture.settle()

        #expect(service.status == .idle)
        #expect(service.finishedAlbumID == albumB.id)
    }

    @Test
    func `next has somewhere to go past the last track only in continue-through-wallet mode`() async {
        let settings = MockSettingsService.make(
            settings: LocalSettings(whenAlbumEnds: .continueThroughWallet)
        )

        let controller = StubAudioPlayerController()
        let service = MusicPlayerFixture.makeService(controller: controller, settingsService: settings)

        await service.play(album: albumA, tracks: tracksA, startingAt: 0, sequence: [albumB])

        #expect(service.hasNextTrack)
    }
}

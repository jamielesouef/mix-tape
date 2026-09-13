//  MiniPlayerDockingTests.swift
//  MixtapePresentationTests
//
//  Created by Jamie Le Souëf on 04/09/2026.
//

import MixtapeDomain
@testable import MixtapePresentation
import MixtapeServices
import Testing

@Suite(.tags(.presentation))
@MainActor
struct MiniPlayerDockingTests {
    private let album = MockMedia.albums[0]
    private let tracks = MockMedia.tracks

    @Test func `nothing playing shows no dock`() {
        #expect(MiniPlayer.dockedTrack(in: MockMusicPlayerService.idle()) == nil)
    }

    @Test func `the current track is docked while the album plays and while it is paused`() async {
        let music = MockMusicPlayerService.make()
        await music.play(album: album, tracks: tracks, startingAt: 1)
        #expect(MiniPlayer.dockedTrack(in: music) == tracks[1])
        music.togglePlayPause()
        #expect(music.status == .paused)
        #expect(MiniPlayer.dockedTrack(in: music) == tracks[1])
    }

    @Test func `a finished album has no dock even though the service still holds it`() async {
        let music = MockMusicPlayerService.make()
        await music.play(album: album, tracks: tracks, startingAt: tracks.count - 1)
        await music.next()
        #expect(music.finishedAlbumID == album.id)
        #expect(music.album == album)
        #expect(MiniPlayer.dockedTrack(in: music) == nil)
    }
}

//  AlbumPlaybackActionTests.swift
//  mixtape
//
//  Created by Jamie Le Souëf on 28/09/2026.
//

import Testing
@testable import Mixtape

@Suite(.tags(.domain))
struct AlbumPlaybackActionTests {
    @Test
    func `nothing playing always resolves to a plain play, regardless of which album`() {
        let action = AlbumPlaybackAction.resolve(
            displayedAlbumID: "album-1",
            playingAlbumID: nil,
            isActive: false
        )

        #expect(action == .play)
    }

    @Test
    func `viewing the album that is playing resolves to play-pause, never a duplicate play`() {
        let action = AlbumPlaybackAction.resolve(
            displayedAlbumID: "album-1",
            playingAlbumID: "album-1",
            isActive: true
        )

        #expect(action == .playPause)
    }

    @Test
    func `viewing a different album while one is playing resolves to play-replace`() {
        let action = AlbumPlaybackAction.resolve(
            displayedAlbumID: "album-2",
            playingAlbumID: "album-1",
            isActive: true
        )

        #expect(action == .playReplace)
    }
}

//  AlbumPlaybackAction.swift
//  mixtape
//
//  Created by Jamie Le Souëf on 28/09/2026.
//

/// Which primary action Album Detail shows for the album on screen: a plain Play when
/// nothing is playing, Play/Pause when the album on screen is the one playing (never
/// duplicated alongside Play), or Play/Replace when a different album is playing.
enum AlbumPlaybackAction: Sendable, Equatable {
    case play
    case playPause
    case playReplace

    static func resolve(
        displayedAlbumID: String,
        playingAlbumID: String?,
        isActive: Bool
    ) -> AlbumPlaybackAction {
        guard isActive, let playingAlbumID else {
            return .play
        }

        return playingAlbumID == displayedAlbumID ? .playPause : .playReplace
    }
}

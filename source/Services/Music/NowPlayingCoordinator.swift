//  NowPlayingCoordinator.swift
//  mixtape
//
//  Created by Jamie Le Souëf on 13/09/2026.
//

import UIKit

/// Keeps the lock screen and control centre in step with the player, and holds the artwork
/// fetched for the track that is playing.
///
/// Artwork arrives after the track starts, so it is held here and folded into every later
/// refresh rather than being re-fetched for each one.
@MainActor
final class NowPlayingCoordinator {
    private let controller: any AudioPlayerControlling
    private let artworkProvider: (@Sendable (MediaItem) async -> UIImage?)?

    private var artwork: UIImage?

    init(
        controller: any AudioPlayerControlling,
        artworkProvider: (@Sendable (MediaItem) async -> UIImage?)?
    ) {
        self.controller = controller
        self.artworkProvider = artworkProvider
    }

    func clearArtwork() {
        artwork = nil
    }

    /// Fetches artwork and keeps it only if the track it was fetched for is still the one
    /// playing, so a slow fetch cannot paint the previous track's cover over the new one.
    func loadArtwork(for track: MediaItem, isStillCurrent: @MainActor () -> Bool) async {
        let fetched = await artworkProvider?(track)

        guard isStillCurrent() else {
            return
        }

        artwork = fetched
    }

    func refresh(track: MediaItem?, album: MediaItem?, position: Duration, isPlaying: Bool) {
        controller.updateNowPlaying(NowPlayingInfo(
            title: track?.name ?? "",
            artist: track?.albumArtist ?? album?.albumArtist ?? "",
            albumTitle: album?.name ?? "",
            artwork: artwork,
            duration: track?.runtime,
            position: position,
            isPlaying: isPlaying
        ))
    }
}

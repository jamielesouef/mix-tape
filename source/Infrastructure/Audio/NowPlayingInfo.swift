//  NowPlayingInfo.swift
//  mixtape
//
//  Created by Jamie Le Souëf on 03/09/2026.
//

import Foundation
import UIKit

nonisolated struct NowPlayingInfo: Sendable {
    let title: String
    let artist: String
    let albumTitle: String
    let artwork: UIImage?
    let duration: Duration?
    let position: Duration
    let isPlaying: Bool

    init(title: String, artist: String, albumTitle: String, artwork: UIImage?, duration: Duration?, position: Duration, isPlaying: Bool) {
        self.title = title
        self.artist = artist
        self.albumTitle = albumTitle
        self.artwork = artwork
        self.duration = duration
        self.position = position
        self.isPlaying = isPlaying
    }
}

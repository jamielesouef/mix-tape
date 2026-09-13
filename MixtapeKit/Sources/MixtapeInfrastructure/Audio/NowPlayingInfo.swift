//  NowPlayingInfo.swift
//  MixtapeInfrastructure
//
//  Created by Jamie Le Souëf on 03/09/2026.
//

import Foundation
import UIKit

public nonisolated struct NowPlayingInfo: Sendable {
    public let title: String
    public let artist: String
    public let albumTitle: String
    public let artwork: UIImage?
    public let duration: Duration?
    public let position: Duration
    public let isPlaying: Bool

    public init(title: String, artist: String, albumTitle: String, artwork: UIImage?, duration: Duration?, position: Duration, isPlaying: Bool) {
        self.title = title
        self.artist = artist
        self.albumTitle = albumTitle
        self.artwork = artwork
        self.duration = duration
        self.position = position
        self.isPlaying = isPlaying
    }
}

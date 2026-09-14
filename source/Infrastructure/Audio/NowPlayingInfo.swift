//  NowPlayingInfo.swift
//  mixtape
//
//  Created by Jamie Le Souëf on 03/09/2026.
//

import Foundation
import UIKit

struct NowPlayingInfo: Sendable {
    let title: String
    let artist: String
    let albumTitle: String
    let artwork: UIImage?
    let duration: Duration?
    let position: Duration
    let isPlaying: Bool
}

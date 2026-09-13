//  AudioStream.swift
//  mixtape
//
//  Created by Jamie Le Souëf on 03/09/2026.
//

import Foundation

nonisolated struct AudioStream: Sendable, Equatable {
    let url: URL
    let playMethod: PlayMethod

    init(url: URL, playMethod: PlayMethod) {
        self.url = url
        self.playMethod = playMethod
    }
}

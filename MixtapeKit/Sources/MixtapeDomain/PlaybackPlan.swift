//  PlaybackPlan.swift
//  MixtapeDomain
//
//  Created by Jamie Le Souëf on 03/09/2026.
//

import Foundation

nonisolated struct PlaybackPlan: Sendable, Equatable {
    let itemID: String
    let mediaSourceID: String
    let playSessionID: String
    let method: PlaybackMethod
    let playMethod: PlayMethod
    let streamURL: URL
    let startPosition: Duration
    let totalDuration: Duration?
}

//  PlayerStatus.swift
//  mixtape
//
//  Created by Jamie Le Souëf on 03/09/2026.
//

nonisolated enum PlayerStatus: Sendable, Equatable {
    case idle
    case preparing
    case playing
    case paused
    case failed(MixtapeError)
}

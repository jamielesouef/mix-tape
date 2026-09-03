//  PlayerStatus.swift
//  MixtapeDomain
//
//  Created by Jamie Le Souëf on 03/09/2026.
//

nonisolated enum PlayerStatus: Sendable, Equatable {
    case idle, preparing, playing, paused
    case failed(MixtapeError)
}

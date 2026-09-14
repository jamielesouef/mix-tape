//  QuickConnectUIState.swift
//  mixtape
//
//  Created by Jamie Le Souëf on 03/09/2026.
//

nonisolated enum QuickConnectUIState: Sendable, Equatable {
    case idle
    case waiting(code: String)
    case failed(MixtapeError)
}

//  QuickConnectUIState.swift
//  MixtapeDomain
//
//  Created by Jamie Le Souëf on 03/09/2026.
//

public nonisolated enum QuickConnectUIState: Sendable, Equatable {
    case idle
    case waiting(code: String)
    case failed(MixtapeError)
}

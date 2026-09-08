//  LoadState.swift
//  MixtapeDomain
//
//  Created by Jamie Le Souëf on 03/09/2026.
//

public nonisolated enum LoadState<Value: Sendable>: Sendable {
    case idle
    case loading
    case loaded(Value)
    case failed(MixtapeError)
}

extension LoadState: Equatable where Value: Equatable {}

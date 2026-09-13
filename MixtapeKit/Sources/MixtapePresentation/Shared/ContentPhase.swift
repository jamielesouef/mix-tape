//  ContentPhase.swift
//  MixtapePresentation
//
//  Created by Jamie Le Souëf on 04/09/2026.
//

import MixtapeDomain

nonisolated enum ContentPhase<Value: Sendable>: Sendable {
    case loading
    case failed(MixtapeError)
    case empty
    case loaded(Value)

    init(_ state: LoadState<Value>?, isEmpty: (Value) -> Bool) {
        switch state {
        case .none, .idle, .loading:
            self = .loading
        case let .failed(error):
            self = .failed(error)
        case let .loaded(value):
            self = isEmpty(value) ? .empty : .loaded(value)
        }
    }
}

nonisolated extension ContentPhase where Value: Collection {
    init(_ state: LoadState<Value>?) {
        self.init(state) { $0.isEmpty }
    }
}

extension ContentPhase: Equatable where Value: Equatable {}

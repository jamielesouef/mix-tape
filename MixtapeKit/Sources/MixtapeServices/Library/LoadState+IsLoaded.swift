//  LoadState+IsLoaded.swift
//  MixtapeServices
//
//  Created by Jamie Le Souëf on 03/09/2026.
//

import MixtapeDomain

extension LoadState {
    nonisolated var isLoaded: Bool {
        if case .loaded = self {
            return true
        }
        return false
    }
}

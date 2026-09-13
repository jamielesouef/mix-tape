//  LoadState+IsLoaded.swift
//  mixtape
//
//  Created by Jamie Le Souëf on 03/09/2026.
//

extension LoadState {
    nonisolated var isLoaded: Bool {
        if case .loaded = self {
            return true
        }
        return false
    }
}

//  Eventually.swift
//  MixtapeServicesTests
//
//  Created by Jamie Le Souëf on 04/09/2026.
//

@MainActor
func eventually(_ condition: @MainActor () -> Bool) async -> Bool {
    for _ in 0 ..< 2000 {
        if condition() {
            return true
        }
        await Task.yield()
    }
    return condition()
}

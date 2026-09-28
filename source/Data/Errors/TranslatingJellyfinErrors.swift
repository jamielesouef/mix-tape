//  TranslatingJellyfinErrors.swift
//  mixtape
//
//  Created by Jamie Le Souëf on 28/09/2026.
//

import JellyfinKit

/// Runs one call into `JellyfinKit` and rethrows a `JellyfinError` as the `MixtapeError` the
/// repository protocols promise. Any other error, cancellation included, passes through as is.
func translatingJellyfinErrors<T>(_ operation: () async throws -> T) async throws -> T {
    do {
        return try await operation()
    } catch let error as JellyfinError {
        throw MixtapeError(error)
    }
}

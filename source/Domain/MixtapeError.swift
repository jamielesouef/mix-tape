//  MixtapeError.swift
//  mixtape
//
//  Created by Jamie Le Souëf on 03/09/2026.
//

import Foundation

enum MixtapeError: Error, Sendable, Equatable {
    case serverUnreachable
    case notAJellyfinServer
    case invalidCredentials
    case quickConnectUnavailable
    case quickConnectExpired
    case sessionExpired
    case noPlayableSource
    case transport(String)
    case decoding

    /// Maps any thrown error onto this domain's error type, passing an existing
    /// `MixtapeError` through unchanged and wrapping anything else as `.transport`.
    static func mapping(from error: any Error) -> MixtapeError {
        (error as? MixtapeError) ?? .transport(error.localizedDescription)
    }
}

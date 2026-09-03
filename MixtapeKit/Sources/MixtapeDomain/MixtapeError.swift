//  MixtapeError.swift
//  MixtapeDomain
//
//  Created by Jamie Le Souëf on 03/09/2026.
//

public nonisolated enum MixtapeError: Error, Sendable, Equatable {
    case serverUnreachable
    case notAJellyfinServer
    case invalidCredentials
    case quickConnectUnavailable
    case quickConnectExpired
    /// 401 on an authenticated call.
    case sessionExpired
    case noPlayableSource
    /// Human-readable, already localised. Unmapped 4xx and all 5xx land here (decision 9).
    case transport(String)
    case decoding
}

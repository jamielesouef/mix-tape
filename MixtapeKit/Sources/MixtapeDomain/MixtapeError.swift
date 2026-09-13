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
    case sessionExpired
    case noPlayableSource
    case transport(String)
    case decoding
}

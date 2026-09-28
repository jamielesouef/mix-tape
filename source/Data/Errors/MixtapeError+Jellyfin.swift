//  MixtapeError+Jellyfin.swift
//  mixtape
//
//  Created by Jamie Le Souëf on 28/09/2026.
//

import JellyfinKit

extension MixtapeError {
    /// The domain reading of a server failure. A 401 on an ordinary endpoint means the stored
    /// token no longer works, which the app treats as the session having expired.
    init(_ error: JellyfinError) {
        switch error {
        case .serverUnreachable:
            self = .serverUnreachable
        case .invalidCredentials:
            self = .invalidCredentials
        case .quickConnectUnavailable:
            self = .quickConnectUnavailable
        case .unauthorized:
            self = .sessionExpired
        case let .transport(message):
            self = .transport(message)
        case .decoding:
            self = .decoding
        }
    }
}

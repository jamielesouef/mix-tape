//  MixtapeError+Message.swift
//  mixtape
//
//  Created by Jamie Le Souëf on 03/09/2026.
//

extension MixtapeError {
    nonisolated var message: String {
        switch self {
        case .serverUnreachable: "Couldn't reach the server. Check the address and that it's running."
        case .notAJellyfinServer: "That address didn't answer like a Jellyfin server."
        case .invalidCredentials: "Wrong username or password."
        case .quickConnectUnavailable: "Quick Connect isn't enabled on this server."
        case .quickConnectExpired: "The Quick Connect code expired. Try again."
        case .sessionExpired: "Your session expired. Sign in again."
        case .noPlayableSource: "This item has nothing that can be played."
        case let .transport(detail): "Something went wrong: \(detail)"
        case .decoding: "The server sent something unexpected."
        }
    }
}

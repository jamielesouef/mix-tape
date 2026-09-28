//  JellyfinError.swift
//  JellyfinKit
//
//  Created by Jamie Le Souëf on 28/09/2026.
//

/// What went wrong talking to a Jellyfin server, in the server's terms.
///
/// The app translates this into its own domain error at the repository boundary; nothing
/// in this package knows what the app does with it.
public enum JellyfinError: Error, Sendable, Equatable {
    case serverUnreachable
    case invalidCredentials
    case quickConnectUnavailable
    case unauthorized
    case transport(String)
    case decoding
}

//  JellyfinErrorMapper.swift
//  JellyfinKit
//
//  Created by Jamie Le Souëf on 14/09/2026.
//

import Foundation

/// Turns a transport outcome into a `JellyfinError`.
///
/// A 401 means different things on different endpoints — wrong password on a sign-in, an
/// unavailable feature on quick connect, an expired token everywhere else — so the path is
/// part of the mapping rather than an afterthought at the call site.
enum JellyfinErrorMapper {
    static func map(status: Int, path: String) -> JellyfinError? {
        switch status {
        case 200 ... 299:
            nil
        case 401 where credentialPaths.contains(path):
            .invalidCredentials
        case 401 where quickConnectPaths.contains(path):
            .quickConnectUnavailable
        case 401:
            .unauthorized
        default:
            .transport(HTTPURLResponse.localizedString(forStatusCode: status))
        }
    }

    static func map(_ error: URLError) -> JellyfinError {
        switch error.code {
        case .cannotFindHost,
             .cannotConnectToHost,
             .timedOut:
            .serverUnreachable
        default:
            .transport(error.localizedDescription)
        }
    }

    private static let credentialPaths: Set<String> = [
        "/Users/AuthenticateByName",
        "/Users/AuthenticateWithQuickConnect"
    ]
    private static let quickConnectPaths: Set<String> = [
        "/QuickConnect/Enabled",
        "/QuickConnect/Initiate"
    ]
}

//  UserSession.swift
//  MixtapeDomain
//
//  Created by Jamie Le Souëf on 03/09/2026.
//

import Foundation

nonisolated struct UserSession: Sendable, Equatable {
    let serverURL: URL
    let userID: String
    let userName: String
    let accessToken: String
    let deviceID: String
}

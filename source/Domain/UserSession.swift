//  UserSession.swift
//  mixtape
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

    init(serverURL: URL, userID: String, userName: String, accessToken: String, deviceID: String) {
        self.serverURL = serverURL
        self.userID = userID
        self.userName = userName
        self.accessToken = accessToken
        self.deviceID = deviceID
    }
}

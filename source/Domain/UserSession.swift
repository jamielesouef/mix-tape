//  UserSession.swift
//  mixtape
//
//  Created by Jamie Le Souëf on 03/09/2026.
//

import Foundation

public nonisolated struct UserSession: Sendable, Equatable {
    public let serverURL: URL
    public let userID: String
    public let userName: String
    public let accessToken: String
    public let deviceID: String

    public init(serverURL: URL, userID: String, userName: String, accessToken: String, deviceID: String) {
        self.serverURL = serverURL
        self.userID = userID
        self.userName = userName
        self.accessToken = accessToken
        self.deviceID = deviceID
    }
}

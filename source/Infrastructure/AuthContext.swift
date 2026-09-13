//  AuthContext.swift
//  mixtape
//
//  Created by Jamie Le Souëf on 03/09/2026.
//

import Foundation

public nonisolated struct AuthContext: Sendable, Equatable {
    public let baseURL: URL
    public let deviceID: String
    public let appVersion: String
    public let token: String?

    public init(baseURL: URL, deviceID: String, appVersion: String, token: String?) {
        self.baseURL = baseURL
        self.deviceID = deviceID
        self.appVersion = appVersion
        self.token = token
    }
}

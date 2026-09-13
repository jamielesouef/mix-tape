//  AuthContext.swift
//  mixtape
//
//  Created by Jamie Le Souëf on 03/09/2026.
//

import Foundation

nonisolated struct AuthContext: Sendable, Equatable {
    let baseURL: URL
    let deviceID: String
    let appVersion: String
    let token: String?

    init(baseURL: URL, deviceID: String, appVersion: String, token: String?) {
        self.baseURL = baseURL
        self.deviceID = deviceID
        self.appVersion = appVersion
        self.token = token
    }
}

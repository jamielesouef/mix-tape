//  AuthContext.swift
//  MixtapeInfrastructure
//
//  Created by Jamie Le Souëf on 03/09/2026.
//

import Foundation

/// The inputs to the `Authorization: MediaBrowser …` header. A transport concern, so it
/// lives beside the client rather than in Domain (engineering doc §4).
public nonisolated struct AuthContext: Sendable, Equatable {
    public let baseURL: URL
    public let deviceID: String
    public let appVersion: String
    /// `nil` while signing in; the `Token` component is then omitted from the header.
    public let token: String?

    public init(baseURL: URL, deviceID: String, appVersion: String, token: String?) {
        self.baseURL = baseURL
        self.deviceID = deviceID
        self.appVersion = appVersion
        self.token = token
    }
}

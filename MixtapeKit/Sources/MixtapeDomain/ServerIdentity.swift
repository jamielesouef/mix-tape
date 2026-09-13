//  ServerIdentity.swift
//  MixtapeDomain
//
//  Created by Jamie Le Souëf on 03/09/2026.
//

import Foundation

public nonisolated struct ServerIdentity: Sendable, Equatable {
    public let id: String
    public let name: String
    public let version: String
    public let baseURL: URL

    public init(id: String, name: String, version: String, baseURL: URL) {
        self.id = id
        self.name = name
        self.version = version
        self.baseURL = baseURL
    }
}

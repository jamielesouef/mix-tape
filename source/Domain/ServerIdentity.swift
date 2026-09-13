//  ServerIdentity.swift
//  mixtape
//
//  Created by Jamie Le Souëf on 03/09/2026.
//

import Foundation

nonisolated struct ServerIdentity: Sendable, Equatable {
    let id: String
    let name: String
    let version: String
    let baseURL: URL
}

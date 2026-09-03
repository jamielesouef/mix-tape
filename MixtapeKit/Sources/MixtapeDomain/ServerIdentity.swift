//  ServerIdentity.swift
//  MixtapeDomain
//
//  Created by Jamie Le Souëf on 03/09/2026.
//

import Foundation

/// Identity of a Jellyfin server, from `/System/Info/Public`. All three fields are
/// required here; the wire DTO carries the optionality (SPEC-DECISIONS.md decision 31).
nonisolated struct ServerIdentity: Sendable, Equatable {
    let id: String
    let name: String
    let version: String
    let baseURL: URL
}

//  PascalCaseFixture.swift
//  mixtape
//
//  Created by Jamie Le Souëf on 03/09/2026.
//

@testable import Mixtape

struct PascalCaseFixture: Decodable, Equatable {
    let serverName: String
    let version: String

    enum CodingKeys: String, CodingKey {
        case serverName = "ServerName"
        case version = "Version"
    }
}

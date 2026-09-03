//  PascalCaseFixture.swift
//  MixtapeDataTests
//
//  Created by Jamie Le Souëf on 03/09/2026.
//

/// Test-only PascalCase shape with explicit `CodingKeys`, standing in for a production DTO.
struct PascalCaseFixture: Decodable, Equatable {
    let serverName: String
    let version: String

    enum CodingKeys: String, CodingKey {
        case serverName = "ServerName"
        case version = "Version"
    }
}

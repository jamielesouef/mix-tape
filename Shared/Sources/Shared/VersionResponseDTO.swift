// SPDX-License-Identifier: MIT
//
//  VersionResponseDTO.swift
//  Shared
//
//  Created by Jamie Le Souëf on 31/08/2026.
//

public struct VersionResponseDTO: Codable, Sendable, Hashable {
  public let apiVersion: Int
  public let serverVersion: String
  public let claimed: Bool

  public init(apiVersion: Int, serverVersion: String, claimed: Bool) {
    self.apiVersion = apiVersion
    self.serverVersion = serverVersion
    self.claimed = claimed
  }
}

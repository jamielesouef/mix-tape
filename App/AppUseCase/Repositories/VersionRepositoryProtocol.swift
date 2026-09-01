//
//  VersionRepositoryProtocol.swift
//  MixTape
//
//  Created by Jamie Le Souëf on 31/08/2026.
//

protocol VersionRepositoryProtocol {
  func fetchVersion() async throws -> ServerStatus
}

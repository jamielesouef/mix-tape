//
//  FetchServerVersionUseCase.swift
//  MixTape
//
//  Created by Jamie Le Souëf on 31/08/2026.
//

struct FetchServerVersionUseCase {
  let repository: VersionRepositoryProtocol

  func execute() async throws -> ServerStatus {
    try await repository.fetchVersion()
  }
}

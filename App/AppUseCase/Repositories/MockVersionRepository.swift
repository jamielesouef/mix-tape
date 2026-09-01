// SPDX-License-Identifier: MIT
//
//  MockVersionRepository.swift
//  MixTape
//
//  Created by Jamie Le Souëf on 31/08/2026.
//

struct MockVersionRepository: VersionRepositoryProtocol {
  enum Outcome {
    case success(ServerStatus)
    case failure
    case pending
  }

  let outcome: Outcome

  func fetchVersion() async throws -> ServerStatus {
    switch outcome {
    case .success(let status):
      return status
    case .failure:
      throw PreviewError.simulatedFailure
    case .pending:
      // Unreachable: a preview's lifetime never reaches a day, so this never resolves.
      try await Task.sleep(for: .seconds(86_400))
      throw PreviewError.simulatedFailure
    }
  }
}

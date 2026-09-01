//
//  VersionService.swift
//  MixTape
//
//  Created by Jamie Le Souëf on 31/08/2026.
//

import Foundation
import Observation

@MainActor
@Observable
final class VersionService {
  enum State: Equatable {
    case idle
    case loading
    case loaded(ServerStatus)
    case failed(VersionFetchError)
  }

  private(set) var state: State = .idle

  private let useCase: FetchServerVersionUseCase

  init(useCase: FetchServerVersionUseCase) {
    self.useCase = useCase
  }

  func checkVersion() async {
    state = .loading
    do {
      state = .loaded(try await useCase.execute())
    } catch let error as VersionFetchError {
      state = .failed(error)
    } catch {
      state = .failed(.unreachable)
    }
  }
}

extension VersionService {
  static func placeholder() -> VersionService {
    VersionService(
      useCase: FetchServerVersionUseCase(
        repository: MockVersionRepository(outcome: .success(ServerStatus(apiVersion: 1, serverVersion: "", claimed: false)))
      )
    )
  }
}


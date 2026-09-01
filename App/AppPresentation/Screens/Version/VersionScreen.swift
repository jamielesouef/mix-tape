// SPDX-License-Identifier: MIT
//
//  VersionScreen.swift
//  MixTape
//
//  Created by Jamie Le Souëf on 31/08/2026.
//

import SwiftUI

struct VersionScreen: View {
  @Environment(\.versionService) private var versionService

  var body: some View {
    Group {
      switch versionService.state {
      case .idle, .loading:
        ProgressView()
          .accessibilityIdentifier("versionScreen.loading")

      case .loaded(let status):
        VStack(spacing: 8) {
          Text(status.serverVersion)
            .accessibilityIdentifier("versionScreen.serverVersion")
          Text(status.claimed ? "Claimed" : "Not claimed")
            .accessibilityIdentifier("versionScreen.claimed")
        }
        .padding()

      case .failed(let error):
        Text(message(for: error))
          .accessibilityIdentifier("versionScreen.error")
          .padding()
      }
    }
    .task { await versionService.checkVersion() }
  }

  private func message(for error: VersionFetchError) -> String {
    switch error {
    case .unreachable:
      "Could not reach the server."
    case .unexpectedResponse:
      "The server returned an unexpected response."
    }
  }
}

#Preview("Loaded") {
  VersionScreen()
    .environment(
      \.versionService,
      VersionService(
        useCase: FetchServerVersionUseCase(
          repository: MockVersionRepository(
            outcome: .success(ServerStatus(apiVersion: 1, serverVersion: "1.0.0 (dev)", claimed: false))
          )
        )
      )
    )
}

#Preview("Loading") {
  VersionScreen()
    .environment(
      \.versionService,
      VersionService(useCase: FetchServerVersionUseCase(repository: MockVersionRepository(outcome: .pending)))
    )
}

#Preview("Failed") {
  VersionScreen()
    .environment(
      \.versionService,
      VersionService(useCase: FetchServerVersionUseCase(repository: MockVersionRepository(outcome: .failure)))
    )
}

// ci-proof: touches App only, to prove server.yml does not trigger. Never merged.

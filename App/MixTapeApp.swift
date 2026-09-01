// SPDX-License-Identifier: MIT
//
//  MixTapeApp.swift
//  MixTape
//
//  Created by Jamie Le Souëf on 31/08/2026.
//

import SwiftUI

@main
struct MixTapeApp: App {
  @State private var versionService = VersionService(
    useCase: FetchServerVersionUseCase(
      repository: VersionRepository(client: APIClient(baseURL: URL(string: "http://localhost:8080")!)) // literal, always valid
    )
  )

  var body: some Scene {
    WindowGroup {
      VersionScreen()
        .environment(\.versionService, versionService)
    }
  }
}

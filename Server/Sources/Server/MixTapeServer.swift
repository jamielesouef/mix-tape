// SPDX-License-Identifier: AGPL-3.0-only
//
//  MixTapeServer.swift
//  Server
//
//  Created by Jamie Le Souëf on 31/08/2026.
//

import Foundation
import Hummingbird
import Shared

@main
struct MixTapeServer {
  static func main() async throws {
    let configuration = ServerConfiguration()
    let router = Router(context: MixTapeRequestContext.self)

    router.get("version") { _, _ in
      VersionResponseDTO(
        apiVersion: 1,
        serverVersion: "0.1.0",
        claimed: FileManager.default.fileExists(atPath: configuration.ownerFilePath)
      )
    }

    let app = Application(
      router: router,
      configuration: .init(address: .hostname("0.0.0.0", port: 8080))
    )
    try await app.runService()
  }
}

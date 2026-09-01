// SPDX-License-Identifier: AGPL-3.0-only
//
//  ServerConfiguration.swift
//  Server
//
//  Created by Jamie Le Souëf on 31/08/2026.
//

import Foundation

struct ServerConfiguration {
  let dataDirectory: String
  let cacheDirectory: String
  let musicDirectory: String
  let appleBundleID: String
  let tokenSecret: String?

  init(environment: [String: String] = ProcessInfo.processInfo.environment) {
    dataDirectory = environment["MIXTAPE_DATA_DIR"] ?? "./data"
    cacheDirectory = environment["MIXTAPE_CACHE_DIR"] ?? "./cache"
    musicDirectory = environment["MIXTAPE_MUSIC_DIR"] ?? "./music"
    appleBundleID = environment["MIXTAPE_APPLE_BUNDLE_ID"] ?? ""
    tokenSecret = environment["MIXTAPE_TOKEN_SECRET"]
  }

  var ownerFilePath: String {
    "\(dataDirectory)/owner.json"
  }
}

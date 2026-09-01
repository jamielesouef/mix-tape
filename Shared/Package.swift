// swift-tools-version: 6.2
// SPDX-License-Identifier: MIT
//
//  Package.swift
//  Shared
//
//  Created by Jamie Le Souëf on 31/08/2026.
//

import PackageDescription

let package = Package(
  name: "Shared",
  platforms: [.iOS(.v26), .macOS(.v26)],
  products: [
    .library(name: "Shared", targets: ["Shared"])
  ],
  targets: [
    .target(name: "Shared")
  ]
)

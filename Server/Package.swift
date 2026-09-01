// swift-tools-version: 6.2
import PackageDescription

let package = Package(
  name: "Server",
  platforms: [.macOS(.v26)],
  dependencies: [
    .package(url: "https://github.com/hummingbird-project/hummingbird.git", from: "2.0.0"),
    .package(url: "https://github.com/vapor/jwt-kit.git", from: "5.0.0"),
    .package(path: "../Shared"),
  ],
  targets: [
    .executableTarget(
      name: "Server",
      dependencies: [
        .product(name: "Hummingbird", package: "hummingbird"),
        .product(name: "JWTKit", package: "jwt-kit"),
        "Shared",
      ]
    ),
    .testTarget(
      name: "ServerTests",
      dependencies: ["Server"]
    ),
  ]
)

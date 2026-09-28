// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "JellyfinKit",
    platforms: [
        .iOS("26.1")
    ],
    products: [
        .library(name: "JellyfinKit", targets: ["JellyfinKit"]),
        .library(name: "JellyfinKitTestSupport", targets: ["JellyfinKitTestSupport"])
    ],
    targets: [
        .target(name: "JellyfinKit"),
        .target(name: "JellyfinKitTestSupport"),
        .testTarget(
            name: "JellyfinKitTests",
            dependencies: ["JellyfinKit", "JellyfinKitTestSupport"]
        )
    ],
    swiftLanguageModes: [.v6]
)

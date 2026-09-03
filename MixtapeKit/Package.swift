// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "MixtapeKit",
    platforms: [.iOS(.v26), .tvOS(.v26)],
    products: [
        .library(name: "MixtapeDomain", targets: ["MixtapeDomain"]),
        .library(name: "MixtapeUseCase", targets: ["MixtapeUseCase"]),
        .library(name: "MixtapeInfrastructure", targets: ["MixtapeInfrastructure"]),
        .library(name: "MixtapeData", targets: ["MixtapeData"]),
        .library(name: "MixtapeServices", targets: ["MixtapeServices"]),
        .library(name: "MixtapePresentation", targets: ["MixtapePresentation"]),
    ],
    targets: [
        .target(
            name: "MixtapeDomain",
            swiftSettings: [
                .defaultIsolation(MainActor.self),
                .swiftLanguageMode(.v6),
            ],
        ),
        .target(
            name: "MixtapeUseCase",
            dependencies: ["MixtapeDomain"],
            swiftSettings: [
                .defaultIsolation(MainActor.self),
                .swiftLanguageMode(.v6),
            ],
        ),
        .target(
            name: "MixtapeInfrastructure",
            dependencies: ["MixtapeDomain"],
            swiftSettings: [
                .defaultIsolation(MainActor.self),
                .swiftLanguageMode(.v6),
            ],
        ),
        .target(
            name: "MixtapeData",
            dependencies: ["MixtapeUseCase", "MixtapeDomain", "MixtapeInfrastructure"],
            swiftSettings: [
                .defaultIsolation(MainActor.self),
                .swiftLanguageMode(.v6),
            ],
        ),
        .target(
            name: "MixtapeServices",
            dependencies: ["MixtapeUseCase", "MixtapeDomain", "MixtapeInfrastructure"],
            swiftSettings: [
                .defaultIsolation(MainActor.self),
                .swiftLanguageMode(.v6),
            ],
        ),
        .target(
            name: "MixtapePresentation",
            dependencies: ["MixtapeServices", "MixtapeDomain"],
            swiftSettings: [
                .defaultIsolation(MainActor.self),
                .swiftLanguageMode(.v6),
            ],
        ),
        .testTarget(name: "MixtapeDomainTests", dependencies: ["MixtapeDomain"]),
        .testTarget(name: "MixtapeUseCaseTests", dependencies: ["MixtapeUseCase", "MixtapeDomain"]),
        .testTarget(name: "MixtapeServicesTests", dependencies: ["MixtapeServices", "MixtapeInfrastructure", "MixtapeDomain"]),
        .testTarget(
            name: "MixtapeDataTests",
            dependencies: ["MixtapeData", "MixtapeInfrastructure", "MixtapeUseCase", "MixtapeDomain"],
            resources: [.process("Fixtures")],
        ),
    ],
)

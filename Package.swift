// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "BlockInputKit",
    platforms: [
        .macOS("26.0")
    ],
    products: [
        .library(
            name: "BlockInputKit",
            targets: ["BlockInputKit"]
        ),
        .executable(
            name: "BlockInputKitDemo",
            targets: ["BlockInputKitDemo"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/pointfreeco/swift-snapshot-testing", from: "1.17.0")
    ],
    targets: [
        .target(
            name: "BlockInputKit",
            swiftSettings: [
                .enableExperimentalFeature("StrictConcurrency")
            ]
        ),
        .executableTarget(
            name: "BlockInputKitDemo",
            dependencies: ["BlockInputKit"],
            swiftSettings: [
                .enableExperimentalFeature("StrictConcurrency")
            ]
        ),
        .testTarget(
            name: "BlockInputKitTests",
            dependencies: [
                "BlockInputKit",
                .product(name: "SnapshotTesting", package: "swift-snapshot-testing")
            ],
            swiftSettings: [
                .enableExperimentalFeature("StrictConcurrency")
            ]
        )
    ]
)

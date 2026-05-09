// swift-tools-version: 5.10

import PackageDescription

let package = Package(
    name: "LockAndRing",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(
            name: "LockAndRing",
            targets: ["LockAndRing"]
        )
    ],
    dependencies: [],
    targets: [
        .executableTarget(
            name: "LockAndRing",
            path: "LockAndRing"
        ),
        .testTarget(
            name: "LockAndRingTests",
            dependencies: ["LockAndRing"],
            path: "LockAndRingTests"
        )
    ]
)

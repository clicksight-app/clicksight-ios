// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "ClickSight",
    platforms: [
        .iOS(.v15),
        .macOS(.v12)
    ],
    products: [
        .library(
            name: "ClickSight",
            targets: ["ClickSight"]
        ),
    ],
    targets: [
        .target(
            name: "ClickSight",
            path: "Sources/ClickSight"
        ),
        .testTarget(
            name: "ClickSightTests",
            dependencies: ["ClickSight"],
            path: "Tests/ClickSightTests"
        ),
    ]
)

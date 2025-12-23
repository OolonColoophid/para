// swift-tools-version: 5.6
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "para",
    platforms: [
        .macOS(.v12)
    ],
    products: [
        .executable(
            name: "para",
            targets: ["para"]
        ),
        .library(
            name: "ParaKit",
            targets: ["ParaKit"]
        ),
        .executable(
            name: "ParaMenuBar",
            targets: ["ParaMenuBar"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.2.3")
    ],
    targets: [
        // ParaKit Framework - shared business logic
        .target(
            name: "ParaKit",
            dependencies: [],
            path: "ParaKit"
        ),

        // Para CLI
        .executableTarget(
            name: "para",
            dependencies: [
                "ParaKit",
                .product(name: "ArgumentParser", package: "swift-argument-parser")
            ],
            path: "para"
        ),

        // Para Menu Bar App
        .executableTarget(
            name: "ParaMenuBar",
            dependencies: ["ParaKit"],
            path: "ParaMenuBar"
        ),

        // Tests
        .testTarget(
            name: "paraTests",
            dependencies: ["para", "ParaKit"],
            path: "paraTests"
        )
    ]
)

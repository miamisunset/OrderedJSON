// swift-tools-version: 6.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "OrderedJSON",
    platforms: [
        .iOS(.v26),
        .macOS(.v26),
        .tvOS(.v26),
        .watchOS(.v26),
    ],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "OrderedJSON",
            targets: ["OrderedJSON"]
        )
    ],
    dependencies: [
        // For OrderedDictionary - highly recommended
        .package(url: "https://github.com/apple/swift-collections.git", from: "1.5.1"),
        .package(url: "https://github.com/nicklockwood/SwiftFormat", from: "0.61.1"),
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "OrderedJSON",
            dependencies: [
                .product(name: "OrderedCollections", package: "swift-collections")
            ],
            swiftSettings: [
                .enableUpcomingFeature("StrictConcurrency")
            ]
        ),
        .testTarget(
            name: "OrderedJSONTests",
            dependencies: ["OrderedJSON"]
        ),
    ],
    swiftLanguageModes: [.v6]
)

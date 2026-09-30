// swift-tools-version: 6.4

import PackageDescription

let package = Package(
    name: "swift-w3c-xml",
    platforms: [
        .macOS(.v27),
        .iOS(.v27),
        .tvOS(.v27),
        .watchOS(.v27),
        .visionOS(.v27),
    ],
    products: [
        .library(name: "W3C XML", targets: ["W3C XML"])
    ],
    dependencies: [
        .package(url: "https://github.com/swift-molecules/swift-machine.git", branch: "main"),
        .package(url: "https://github.com/swift-atoms/swift-byte.git", branch: "main"),
        .package(url: "https://github.com/swift-atoms/swift-cursor.git", branch: "main", traits: ["Collection"]),
        .package(
            url: "https://github.com/swift-atoms/swift-standard-library-extensions.git",
            branch: "main"
        ),
        .package(
            url: "https://github.com/swift-atoms/swift-parser.git",
            branch: "main", traits: ["Append", "CollectionLeaves", "IteratorLeaves", "Map", "Product", "Skip", "Collection", "Either", "Iterator"]
        ),
        .package(
            url: "https://github.com/swift-molecules/swift-parser-machine.git",
            branch: "main"
        ),
        .package(
            url: "https://github.com/swift-atoms/swift-binary.git",
            branch: "main"
        ),
        .package(
            url: "https://github.com/swift-atoms/swift-ascii.git",
            branch: "main", traits: ["Parser"]),
    ],
    targets: [
        .target(
            name: "W3C XML",
            dependencies: [
                .product(name: "Machine", package: "swift-machine"),
                .product(
                    name: "Standard Library Extensions",
                    package: "swift-standard-library-extensions"
                ),
                .product(name: "Parser", package: "swift-parser"),
                .product(
                    name: "Parser Machine",
                    package: "swift-parser-machine"
                ),
                .product(name: "Binary", package: "swift-binary"),
                .product(name: "ASCII", package: "swift-ascii"),
                .product(name: "Byte", package: "swift-byte"),
                .product(name: "Byte", package: "swift-byte"),
                .product(name: "Cursor", package: "swift-cursor"),
                .product(name: "Cursor", package: "swift-cursor"),
            ]
        ),
        .testTarget(
            name: "W3C XML Tests",
            dependencies: [
                "W3C XML"
            ]
        ),
    ],
    swiftLanguageModes: [.v6]
)

for target in package.targets where ![.system, .binary, .plugin, .macro].contains(target.type) {
    let ecosystem: [SwiftSetting] = [
        .strictMemorySafety(),
        .enableUpcomingFeature("ExistentialAny"),
        .enableUpcomingFeature("InternalImportsByDefault"),
        .enableUpcomingFeature("MemberImportVisibility"),
        .enableUpcomingFeature("NonisolatedNonsendingByDefault"),
        .enableExperimentalFeature("Lifetimes"),
    ]

    let package: [SwiftSetting] = []

    target.swiftSettings = (target.swiftSettings ?? []) + ecosystem + package
}

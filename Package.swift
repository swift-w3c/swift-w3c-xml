// swift-tools-version: 6.2

import PackageDescription

// W3C XML 1.0 (Fifth Edition) - Extensible Markup Language
let package = Package(
    name: "swift-w3c-xml",
    platforms: [
        .macOS(.v26),
        .iOS(.v26),
        .tvOS(.v26),
        .watchOS(.v26),
        .visionOS(.v26)
    ],
    products: [
        .library(name: "W3C XML", targets: ["W3C XML"])
    ],
    dependencies: [
        .package(url: "https://github.com/swift-primitives/swift-standard-library-extensions.git", branch: "main"),
        .package(url: "https://github.com/swift-primitives/swift-parser-primitives.git", branch: "main"),
        .package(url: "https://github.com/swift-primitives/swift-parser-machine-primitives.git", branch: "main"),
        .package(url: "https://github.com/swift-primitives/swift-binary-primitives.git", branch: "main"),
        .package(url: "https://github.com/swift-primitives/swift-ascii-primitives.git", branch: "main")
    ],
    targets: [
        .target(
            name: "W3C XML",
            dependencies: [
                .product(name: "Standard Library Extensions", package: "swift-standard-library-extensions"),
                .product(name: "Parser Primitives", package: "swift-parser-primitives"),
                .product(name: "Parser Machine Primitives", package: "swift-parser-machine-primitives"),
                .product(name: "Binary Primitives", package: "swift-binary-primitives"),
                .product(name: "ASCII Primitives", package: "swift-ascii-primitives")
            ]
        ),
        .executableTarget(
            name: "CrashRepro",
            dependencies: ["W3C XML"]
        ),
        .testTarget(
            name: "W3C XML Tests",
            dependencies: [
                "W3C XML",
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
        .enableExperimentalFeature("SuppressedAssociatedTypes"),
    ]

    let package: [SwiftSetting] = []

    target.swiftSettings = (target.swiftSettings ?? []) + ecosystem + package
}

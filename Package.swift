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
        .package(path: "../../swift-primitives/swift-standard-library-extensions"),
        .package(path: "../../swift-primitives/swift-parsing-primitives"),
        .package(path: "../../swift-primitives/swift-binary-primitives"),
        .package(path: "../../swift-primitives/swift-container-primitives"),
        .package(path: "../../swift-foundations/swift-ascii")
    ],
    targets: [
        .target(
            name: "W3C XML",
            dependencies: [
                .product(name: "Standard Library Extensions", package: "swift-standard-library-extensions"),
                .product(name: "Parsing Primitives", package: "swift-parsing-primitives"),
                .product(name: "Parsing Machine", package: "swift-parsing-primitives"),
                .product(name: "Binary Primitives", package: "swift-binary-primitives"),
                .product(name: "Container Primitives", package: "swift-container-primitives"),
                .product(name: "ASCII", package: "swift-ascii")
            ]
        )
        .executableTarget(
            name: "CrashRepro",
            dependencies: ["W3C XML"]
        )
    ],
    swiftLanguageModes: [.v6]
)

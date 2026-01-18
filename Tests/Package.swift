// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "swift-w3c-xml-tests",
    platforms: [
        .macOS(.v26),
        .iOS(.v26),
        .tvOS(.v26),
        .watchOS(.v26),
        .visionOS(.v26),
    ],
    dependencies: [
        // Parent package
        .package(path: "../"),
        // Testing framework
        .package(path: "../../../swift-foundations/swift-testing"),
        // Test primitives (for test utilities)
        .package(path: "../../../swift-primitives/swift-test-primitives"),
        .package(path: "../../../swift-primitives/swift-parsing-primitives"),
        .package(path: "../../../swift-primitives/swift-parsing-primitives"),
    ],
    targets: [
        .testTarget(
            name: "W3C XML Tests",
            dependencies: [
                .product(name: "W3C XML", package: "swift-w3c-xml"),
                .product(name: "Testing", package: "swift-testing"),
                .product(name: "Test Primitives", package: "swift-test-primitives"),
                .product(name: "Parsing Machine", package: "swift-parsing-primitives"),
                .product(name: "Parsing Primitives", package: "swift-parsing-primitives"),
            ],
            path: "Sources/W3C XML Tests"
        )
    ],
    swiftLanguageModes: [.v6]
)

for target in package.targets where ![.system, .binary, .plugin, .macro].contains(target.type) {
    let settings: [SwiftSetting] = [
        .enableUpcomingFeature("ExistentialAny"),
        .enableUpcomingFeature("InternalImportsByDefault"),
        .enableUpcomingFeature("MemberImportVisibility"),
    ]
    target.swiftSettings = (target.swiftSettings ?? []) + settings
}

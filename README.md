# swift-w3c-xml

![Development Status](https://img.shields.io/badge/status-active--development-blue.svg)

Parsing of XML documents as specified by the W3C XML recommendation.

## Standard Reference

- **W3C**: XML
- **Title**: Extensible Markup Language (XML)

## Installation

Add the package to your `Package.swift` dependencies:

```swift
dependencies: [
    .package(url: "https://github.com/swift-w3c/swift-w3c-xml.git", branch: "main")
]
```

Add the product to a target that needs it:

```swift
.target(
    name: "YourTarget",
    dependencies: [
        .product(name: "W3C XML", package: "swift-w3c-xml")
    ]
)
```

## License

Apache 2.0. See [LICENSE.md](LICENSE.md).

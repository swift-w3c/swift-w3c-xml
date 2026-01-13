/// W3C_XML.Parse.swift
/// swift-w3c-xml
///
/// Combinator-based XML parser namespace and core types.
///
/// This module provides XML parsing using `Parsing.Parser` combinators from
/// swift-parsing-primitives. The key insight enabling arbitrary nesting depth
/// is that `Parsing.Many.Simple` uses iteration (a `while` loop), not recursion.
/// Combined with `Parsing.Lazy` to break type cycles, this allows parsing
/// deeply nested XML without stack overflow.

import Parsing_Primitives

extension W3C_XML {
    /// Namespace for combinator-based XML parsers.
    ///
    /// All parsers in this namespace conform to `Parsing.Parser` and compose
    /// using standard combinators (map, flatMap, OneOf, Many, etc.).
    ///
    /// ## Key Pattern: Many + Lazy for Recursion
    ///
    /// ```swift
    /// // Content parser uses Many (iterative) + Lazy (deferred)
    /// Parsing.Many.Simple {
    ///     Parsing.OneOf {
    ///         Parsing.Lazy { Element(depth: depth.incremented()) }
    ///             .map { W3C_XML.Content.element($0) }
    ///         // ...other content types
    ///     }
    /// }
    /// ```
    ///
    /// The `Many.Simple` combinator collects results in a `while` loop (lines 70-91
    /// of Parsing.Many.Simple.swift). Even when the element parser is wrapped in
    /// `Lazy`, execution stays in this loop - no stack growth proportional to nesting.
    public enum Parse {}
}

// MARK: - Depth Tracking

extension W3C_XML.Parse {
    /// Tracks parsing depth for protection against pathological input.
    ///
    /// Unlike recursive descent parsers where depth is implicit in the call stack,
    /// combinator parsers track depth explicitly. This allows configurable limits
    /// without relying on (potentially exhausted) stack space.
    public struct Depth: Sendable, Hashable {
        /// Current nesting depth (0 = root level).
        public let value: Int

        /// Maximum allowed depth before error.
        public let limit: Int

        /// Creates a depth tracker.
        ///
        /// - Parameters:
        ///   - value: Initial depth (default 0).
        ///   - limit: Maximum depth (default 512).
        @inlinable
        public init(value: Int = 0, limit: Int = 512) {
            self.value = value
            self.limit = limit
        }

        /// Returns a new Depth with incremented value.
        ///
        /// Used when entering a nested element or container.
        @inlinable
        public func incremented() -> Depth {
            Depth(value: value + 1, limit: limit)
        }

        /// Whether the current depth exceeds the limit.
        @inlinable
        public var isExceeded: Bool {
            value > limit
        }
    }
}

// MARK: - Parser Errors

extension W3C_XML.Parse {
    /// Errors from XML parsing.
    public enum Error: Swift.Error, Sendable, Hashable {
        /// Depth limit exceeded.
        case depthExceeded(limit: Int)

        /// Expected specific literal not found.
        case expected(String)

        /// Mismatched element tags.
        case mismatchedTags(open: String, close: String)

        /// Invalid character in name.
        case invalidName

        /// Invalid character reference.
        case invalidCharacterReference(String)

        /// Unknown entity reference.
        case unknownEntity(String)

        /// Unexpected end of input.
        case unexpectedEndOfInput(expected: String)

        /// Duplicate attribute.
        case duplicateAttribute(name: String)

        /// Multiple root elements.
        case multipleRootElements

        /// Missing root element.
        case missingRootElement
    }
}

extension W3C_XML.Parse.Error: CustomStringConvertible {
    public var description: String {
        switch self {
        case .depthExceeded(let limit):
            return "Maximum nesting depth (\(limit)) exceeded"
        case .expected(let what):
            return "Expected \(what)"
        case .mismatchedTags(let open, let close):
            return "Mismatched tags: opened '\(open)' but closed '\(close)'"
        case .invalidName:
            return "Invalid XML name"
        case .invalidCharacterReference(let ref):
            return "Invalid character reference: \(ref)"
        case .unknownEntity(let name):
            return "Unknown entity reference: &\(name);"
        case .unexpectedEndOfInput(let expected):
            return "Unexpected end of input, expected \(expected)"
        case .duplicateAttribute(let name):
            return "Duplicate attribute: \(name)"
        case .multipleRootElements:
            return "Multiple root elements found"
        case .missingRootElement:
            return "Missing root element"
        }
    }
}

// MARK: - Type Aliases for Convenience

extension W3C_XML.Parse {
    /// Standard input type for byte parsing.
    public typealias ByteInput = Parsing.CollectionInput<[UInt8]>
}

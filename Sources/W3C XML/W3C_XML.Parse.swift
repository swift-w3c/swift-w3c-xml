import Byte
import Cursor
import Parser

extension W3C_XML {

    public enum Parse {}
}

extension W3C_XML.Parse {

    public struct Depth: Sendable, Hashable {

        public let value: Int

        public let limit: Int

        @inlinable
        public init(value: Int = 0, limit: Int = 512) {
            self.value = value
            self.limit = limit
        }
    }
}

extension W3C_XML.Parse.Depth {

    @inlinable
    public func incremented() -> Self {
        Self(value: value + 1, limit: limit)
    }

    @inlinable
    public var isExceeded: Bool {
        value > limit
    }
}

extension W3C_XML.Parse {

    public enum Error: Swift::Error, Sendable, Hashable {

        case depthExceeded(limit: Int)

        case expected(String)

        case mismatchedTags(open: String, close: String)

        case invalidName

        case invalidCharacterReference(String)

        case unknownEntity(String)

        case unexpectedEndOfInput(expected: String)

        case duplicateAttribute(name: String)

        case multipleRootElements

        case missingRootElement

        /// A reference to an external or unparsed entity, which is never resolved.
        case externalEntity(String)

        /// An entity whose replacement text references itself, directly or indirectly.
        case recursiveEntity(String)

        /// Entity references nested deeper than ``W3C_XML/Entity/Limits/depth``.
        case entityDepthExceeded(limit: Int)

        /// Entity expansions producing more than ``W3C_XML/Entity/Limits/expandedBytes``.
        case entityExpansionExceeded(limit: Int)
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

        case .externalEntity(let name):
            return "External entity reference is not resolved: &\(name);"

        case .recursiveEntity(let name):
            return "Recursive entity reference: &\(name);"

        case .entityDepthExceeded(let limit):
            return "Entity references nested deeper than \(limit)"

        case .entityExpansionExceeded(let limit):
            return "Entity expansion exceeds \(limit) bytes"
        }
    }
}

extension W3C_XML.Parse {

    public typealias ByteInput = ArraySlice<Byte>
}

public import Byte_Parser_Primitives
import Parser_Primitives

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

    public enum Error: Swift.Error, Sendable, Hashable {

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

extension W3C_XML.Parse {

    public typealias ByteInput = Byte.Input
}

public enum __W3CXMLParserError: Swift.Error, Sendable, Hashable {

    case lexer(__W3CXMLLexerError)

    case unexpectedToken(found: W3C_XML.TokenKind, expected: String, at: W3C_XML.Position)

    case unexpectedEndOfInput(expected: String, at: W3C_XML.Position)

    case mismatchedTags(open: String, close: String, at: W3C_XML.Position)

    case depthExceeded(limit: Int, at: W3C_XML.Position)

    case duplicateAttribute(name: String, at: W3C_XML.Position)

    case missingRootElement(at: W3C_XML.Position)

    case multipleRootElements(at: W3C_XML.Position)
}

extension __W3CXMLParserError: CustomStringConvertible {
    public var description: String {
        switch self {
        case .lexer(let error):
            return "Lexer error: \(error)"

        case .unexpectedToken(let found, let expected, let pos):
            return "Unexpected \(found) at \(pos), expected \(expected)"

        case .unexpectedEndOfInput(let expected, let pos):
            return "Unexpected end of input at \(pos), expected \(expected)"

        case .mismatchedTags(let open, let close, let pos):
            return "Mismatched tags at \(pos): opened '\(open)' but closed '\(close)'"

        case .depthExceeded(let limit, let pos):
            return "Maximum nesting depth (\(limit)) exceeded at \(pos)"

        case .duplicateAttribute(let name, let pos):
            return "Duplicate attribute '\(name)' at \(pos)"

        case .missingRootElement(let pos):
            return "Missing root element at \(pos)"

        case .multipleRootElements(let pos):
            return "Multiple root elements at \(pos)"
        }
    }
}

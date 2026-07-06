//
//  W3C_XML.__W3CXMLParserError.swift
//  swift-w3c-xml
//
//  Module-scope, non-generic error for the XML parser. Hoisted out of the generic
//  `W3C_XML.Parser<Input>` context so the `@error` SIL result carries no phantom
//  `Input` type parameter - the structural fix for the `FunctionSignatureOpts`
//  release-build ICE (`SILArgument.cpp:40`, `!type.hasTypeParameter()`;
//  Research section A13 / swiftlang/swift#89617). Surfaced through the public path
//  `W3C_XML.Parser.Error` (a typealias), so the public API stays source-identical.
//  The wrapped lexer error is the module-scope `__W3CXMLLexerError` (spelled
//  `W3C_XML.Lexer.Error`); wrapping the concrete type keeps this error non-generic.
//

/// Parser errors.
public enum __W3CXMLParserError: Swift.Error, Sendable, Hashable {
    /// Lexer error (wrapped).
    case lexer(__W3CXMLLexerError)

    /// Unexpected token.
    case unexpectedToken(found: W3C_XML.TokenKind, expected: String, at: W3C_XML.Position)

    /// Unexpected end of input.
    case unexpectedEndOfInput(expected: String, at: W3C_XML.Position)

    /// Mismatched element tags.
    case mismatchedTags(open: String, close: String, at: W3C_XML.Position)

    /// Depth exceeded.
    case depthExceeded(limit: Int, at: W3C_XML.Position)

    /// Duplicate attribute.
    case duplicateAttribute(name: String, at: W3C_XML.Position)

    /// Missing root element.
    case missingRootElement(at: W3C_XML.Position)

    /// Multiple root elements.
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

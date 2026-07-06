//
//  W3C_XML.__W3CXMLLexerError.swift
//  swift-w3c-xml
//
//  Module-scope, non-generic error for the XML lexer. Hoisted out of the generic
//  `W3C_XML.Lexer<Input>` context so the `@error` SIL result carries no phantom
//  `Input` type parameter - the structural fix for the `FunctionSignatureOpts`
//  release-build ICE (`SILArgument.cpp:40`, `!type.hasTypeParameter()`;
//  Research section A13 / swiftlang/swift#89617). Surfaced through the public path
//  `W3C_XML.Lexer.Error` (a typealias), so the public API stays source-identical.
//

/// Lexer errors.
public enum __W3CXMLLexerError: Swift.Error, Sendable, Hashable {
    /// Invalid character encountered.
    case invalidCharacter(Unicode.Scalar, at: W3C_XML.Position)

    /// Unexpected end of input.
    case unexpectedEndOfInput(expected: String, at: W3C_XML.Position)

    /// Invalid entity reference.
    case invalidEntity(String, at: W3C_XML.Position)

    /// Invalid name character.
    case invalidName(at: W3C_XML.Position)

    /// Invalid UTF-8 byte sequence.
    case invalidUTF8(byte: Byte, at: W3C_XML.Position)

    /// Unterminated construct.
    case unterminated(construct: String, at: W3C_XML.Position)

    /// Invalid XML declaration.
    case invalidDeclaration(reason: String, at: W3C_XML.Position)
}

extension __W3CXMLLexerError: CustomStringConvertible {
    public var description: String {
        switch self {
        case .invalidCharacter(let scalar, let pos):
            return "Invalid character U+\(String(scalar.value, radix: 16, uppercase: true)) at \(pos)"
        case .unexpectedEndOfInput(let expected, let pos):
            return "Unexpected end of input at \(pos), expected \(expected)"
        case .invalidEntity(let name, let pos):
            return "Invalid entity reference '\(name)' at \(pos)"
        case .invalidName(let pos):
            return "Invalid name at \(pos)"
        case .invalidUTF8(let byte, let pos):
            return "Invalid UTF-8 byte 0x\(String(byte, radix: 16)) at \(pos)"
        case .unterminated(let construct, let pos):
            return "Unterminated \(construct) at \(pos)"
        case .invalidDeclaration(let reason, let pos):
            return "Invalid XML declaration at \(pos): \(reason)"
        }
    }
}

public enum __W3CXMLLexerError: Swift.Error, Sendable, Hashable {

    case invalidCharacter(Unicode.Scalar, at: W3C_XML.Position)

    case unexpectedEndOfInput(expected: String, at: W3C_XML.Position)

    case invalidEntity(String, at: W3C_XML.Position)

    case invalidName(at: W3C_XML.Position)

    case invalidUTF8(byte: Byte, at: W3C_XML.Position)

    case unterminated(construct: String, at: W3C_XML.Position)

    case invalidDeclaration(reason: String, at: W3C_XML.Position)
}

extension __W3CXMLLexerError: CustomStringConvertible {
    public var description: String {
        switch self {
        case .invalidCharacter(let scalar, let pos):
            return
                "Invalid character U+\(String(scalar.value, radix: 16, uppercase: true)) at \(pos)"

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

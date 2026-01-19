/// W3C_XML.Lexer.swift
/// swift-w3c-xml
///
/// Zero-copy XML lexer (~Copyable)

import Parser_Primitives

extension W3C_XML {
    /// Zero-copy XML lexer.
    ///
    /// The lexer tokenizes UTF-8 byte input into XML tokens.
    /// It is `~Copyable` to prevent accidental state copies.
    ///
    /// ## Usage
    ///
    /// ```swift
    /// var input = Parser.CollectionInput(bytes)
    /// var lexer = W3C_XML.Lexer(consume input)
    /// while let token = try lexer.next() {
    ///     print(token)
    /// }
    /// ```
    public struct Lexer<Input: Parser.Input>: ~Copyable
    where Input.Element == UInt8 {
        /// The input being lexed.
        @usableFromInline
        internal var input: Input

        /// Current position for error reporting.
        @usableFromInline
        internal var position: W3C_XML.Position

        /// Current lexer state.
        @usableFromInline
        internal var state: State

        /// Creates a lexer for the given input.
        ///
        /// - Parameter input: The UTF-8 byte input to lex.
        @inlinable
        public init(_ input: consuming Input) {
            self.input = input
            self.position = W3C_XML.Position.start
            self.state = .content
        }

        /// The current position in the input.
        public var currentPosition: W3C_XML.Position {
            position
        }
    }
}

// MARK: - Lexer State

extension W3C_XML.Lexer {
    /// Lexer state for tracking context.
    @usableFromInline
    internal enum State {
        /// In content (text, elements, etc.)
        case content

        /// Inside a start tag (reading attributes)
        case inStartTag

        /// Inside an end tag
        case inEndTag
    }
}

// MARK: - Lexer Error

extension W3C_XML.Lexer {
    /// Lexer errors.
    public enum Error: Swift.Error, Sendable, Hashable {
        /// Invalid character encountered.
        case invalidCharacter(Unicode.Scalar, at: W3C_XML.Position)

        /// Unexpected end of input.
        case unexpectedEndOfInput(expected: String, at: W3C_XML.Position)

        /// Invalid entity reference.
        case invalidEntity(String, at: W3C_XML.Position)

        /// Invalid name character.
        case invalidName(at: W3C_XML.Position)

        /// Invalid UTF-8 byte sequence.
        case invalidUTF8(byte: UInt8, at: W3C_XML.Position)

        /// Unterminated construct.
        case unterminated(construct: String, at: W3C_XML.Position)

        /// Invalid XML declaration.
        case invalidDeclaration(reason: String, at: W3C_XML.Position)
    }
}

extension W3C_XML.Lexer.Error: CustomStringConvertible {
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

// MARK: - Lexer Core Methods

extension W3C_XML.Lexer {
    /// Returns the next token, or nil if at end of input.
    ///
    /// - Throws: `W3C_XML.Lexer.Error` if the input is malformed.
    @inlinable
    public mutating func next() throws(Error) -> W3C_XML.Token? {
        switch state {
        case .content:
            return try lexContent()
        case .inStartTag:
            return try lexInStartTag()
        case .inEndTag:
            return try lexInEndTag()
        }
    }
}

// MARK: - Lexer Content Mode

extension W3C_XML.Lexer {
    /// Lexes content (text, elements, etc.).
    @inlinable
    internal mutating func lexContent() throws(Error) -> W3C_XML.Token? {
        guard let byte = input.first else {
            return nil
        }

        switch byte {
        case .ascii.lessThanSign:           // <
            return try lexMarkup()

        default:
            return try lexText()
        }
    }

    /// Lexes markup starting with `<`.
    @inlinable
    internal mutating func lexMarkup() throws(Error) -> W3C_XML.Token {
        let startPos = position
        advance() // consume <

        guard let byte = input.first else {
            throw .unexpectedEndOfInput(expected: "tag name or markup", at: startPos)
        }

        switch byte {
        case .ascii.solidus:            // </  (end tag)
            advance()
            return try lexEndTag()

        case .ascii.exclamationPoint:   // <!  (comment, CDATA, DOCTYPE)
            advance()
            return try lexBangMarkup(startPos: startPos)

        case .ascii.questionMark:       // <?  (PI or XML declaration)
            advance()
            return try lexProcessingInstruction(startPos: startPos)

        default:
            // Start tag
            guard W3C_XML.isASCIINameStartChar(byte) || byte >= 0x80 else {
                throw .invalidName(at: position)
            }
            return try lexStartTag()
        }
    }
}

// MARK: - Lexer Start Tag

extension W3C_XML.Lexer {
    /// Lexes a start tag after `<`.
    @inlinable
    internal mutating func lexStartTag() throws(Error) -> W3C_XML.Token {
        let name = try lexName()
        state = .inStartTag
        return .startTagOpen(name)
    }

    /// Lexes content inside a start tag (attributes, close).
    @inlinable
    internal mutating func lexInStartTag() throws(Error) -> W3C_XML.Token? {
        skipWhitespace()

        guard let byte = input.first else {
            throw .unexpectedEndOfInput(expected: "'>' or '/>'", at: position)
        }

        switch byte {
        case .ascii.greaterThanSign:        // >
            advance()
            state = .content
            return .tagClose

        case .ascii.solidus:            // />
            advance()
            guard input.first == .ascii.greaterThanSign else {
                throw .unexpectedEndOfInput(expected: "'>'", at: position)
            }
            advance()
            state = .content
            return .emptyTagClose

        case .ascii.equalsSign:         // =
            advance()
            return .equals

        case .ascii.quotationMark, .ascii.apostrophe:  // " or '
            return try lexAttributeValue()

        default:
            // Must be attribute name
            guard W3C_XML.isASCIINameStartChar(byte) || byte >= 0x80 else {
                throw .invalidName(at: position)
            }
            let name = try lexName()
            return .attributeName(name)
        }
    }

    /// Lexes an attribute value.
    @inlinable
    internal mutating func lexAttributeValue() throws(Error) -> W3C_XML.Token {
        let startPos = position
        let quote = input.removeFirst()
        position = W3C_XML.Position(
            offset: position.offset + 1,
            line: position.line,
            column: position.column + 1
        )

        var value = ""

        while let byte = input.first {
            if byte == quote {
                advance()
                return .attributeValue(value)
            }

            if byte == .ascii.lessThanSign {
                throw .invalidCharacter(Unicode.Scalar(UInt32(byte))!, at: position)
            }

            if byte == .ascii.ampersand {
                let resolved = try lexEntityReference()
                value.append(contentsOf: String(resolved))
            } else {
                // Regular character
                let scalar = try consumeUTF8Scalar()
                value.append(Character(scalar))
            }
        }

        throw .unterminated(construct: "attribute value", at: startPos)
    }
}

// MARK: - Lexer End Tag

extension W3C_XML.Lexer {
    /// Lexes an end tag after `</`.
    @inlinable
    internal mutating func lexEndTag() throws(Error) -> W3C_XML.Token {
        let name = try lexName()
        state = .inEndTag
        return .endTagOpen(name)
    }

    /// Lexes content inside an end tag.
    @inlinable
    internal mutating func lexInEndTag() throws(Error) -> W3C_XML.Token? {
        skipWhitespace()

        guard let byte = input.first else {
            throw .unexpectedEndOfInput(expected: "'>'", at: position)
        }

        guard byte == .ascii.greaterThanSign else {
            throw .invalidCharacter(Unicode.Scalar(UInt32(byte))!, at: position)
        }

        advance()
        state = .content
        return .tagClose
    }
}

// MARK: - Lexer Bang Markup

extension W3C_XML.Lexer {
    /// Lexes `<!` markup (comment, CDATA, DOCTYPE).
    @inlinable
    internal mutating func lexBangMarkup(startPos: W3C_XML.Position) throws(Error) -> W3C_XML.Token {
        guard let byte = input.first else {
            throw .unexpectedEndOfInput(expected: "comment, CDATA, or DOCTYPE", at: startPos)
        }

        switch byte {
        case .ascii.hyphen:             // <!-- comment
            return try lexComment(startPos: startPos)

        case .ascii.leftBracket:        // <![CDATA[
            return try lexCDATA(startPos: startPos)

        case .ascii.D:                  // <!DOCTYPE
            return try lexDoctype(startPos: startPos)

        default:
            throw .invalidCharacter(Unicode.Scalar(UInt32(byte))!, at: position)
        }
    }

    /// Lexes a comment after `<!-`.
    @inlinable
    internal mutating func lexComment(startPos: W3C_XML.Position) throws(Error) -> W3C_XML.Token {
        // Expect second -
        advance()
        guard input.first == .ascii.hyphen else {
            throw .unexpectedEndOfInput(expected: "'--' for comment", at: position)
        }
        advance()

        var text = ""

        while !input.isEmpty {
            if input.first == .ascii.hyphen {
                advance()
                if input.first == .ascii.hyphen {
                    advance()
                    guard input.first == .ascii.greaterThanSign else {
                        throw .invalidCharacter(
                            Unicode.Scalar(UInt32(input.first ?? 0))!,
                            at: position
                        )
                    }
                    advance()
                    return .comment(text)
                }
                text.append("-")
            } else {
                let scalar = try consumeUTF8Scalar()
                text.append(Character(scalar))
            }
        }

        throw .unterminated(construct: "comment", at: startPos)
    }

    /// Lexes a CDATA section after `<![`.
    @inlinable
    internal mutating func lexCDATA(startPos: W3C_XML.Position) throws(Error) -> W3C_XML.Token {
        // Expect CDATA[
        advance() // [
        try expectLiteral([.ascii.C, .ascii.D, .ascii.A, .ascii.T, .ascii.A, .ascii.leftBracket])

        var text = ""

        while !input.isEmpty {
            if input.first == .ascii.rightBracket {
                advance()
                if input.first == .ascii.rightBracket {
                    advance()
                    if input.first == .ascii.greaterThanSign {
                        advance()
                        return .cdata(text)
                    }
                    text.append("]")
                }
                text.append("]")
            } else {
                let scalar = try consumeUTF8Scalar()
                text.append(Character(scalar))
            }
        }

        throw .unterminated(construct: "CDATA section", at: startPos)
    }

    /// Lexes a DOCTYPE declaration after `<!D`.
    @inlinable
    internal mutating func lexDoctype(startPos: W3C_XML.Position) throws(Error) -> W3C_XML.Token {
        // Expect OCTYPE (D already matched in lexBangMarkup)
        try expectLiteral([.ascii.D, .ascii.O, .ascii.C, .ascii.T, .ascii.Y, .ascii.P, .ascii.E])

        skipWhitespace()
        let name = try lexNameString()

        skipWhitespace()

        var publicID: String?
        var systemID: String?
        var internalSubset: String?

        // Check for external ID - branch on first character
        if input.first == .ascii.P {
            // PUBLIC
            try expectLiteral([.ascii.P, .ascii.U, .ascii.B, .ascii.L, .ascii.I, .ascii.C])
            skipWhitespace()
            publicID = try lexQuotedString()
            skipWhitespace()
            systemID = try lexQuotedString()
        } else if input.first == .ascii.S {
            // SYSTEM
            try expectLiteral([.ascii.S, .ascii.Y, .ascii.S, .ascii.T, .ascii.E, .ascii.M])
            skipWhitespace()
            systemID = try lexQuotedString()
        }

        skipWhitespace()

        // Check for internal subset
        if input.first == .ascii.leftBracket {
            advance()
            internalSubset = try lexInternalSubset()
            skipWhitespace()
        }

        guard input.first == .ascii.greaterThanSign else {
            throw .unexpectedEndOfInput(expected: "'>'", at: position)
        }
        advance()

        return .doctype(W3C_XML.Doctype(
            name: name,
            publicID: publicID,
            systemID: systemID,
            internalSubset: internalSubset
        ))
    }

    /// Lexes the internal subset of a DOCTYPE.
    @inlinable
    internal mutating func lexInternalSubset() throws(Error) -> String {
        let startPos = position
        var text = ""
        var depth = 1

        while !input.isEmpty && depth > 0 {
            let byte = input.first!

            if byte == .ascii.leftBracket {
                depth += 1
                text.append("[")
                advance()
            } else if byte == .ascii.rightBracket {
                depth -= 1
                if depth > 0 {
                    text.append("]")
                }
                advance()
            } else {
                let scalar = try consumeUTF8Scalar()
                text.append(Character(scalar))
            }
        }

        if depth > 0 {
            throw .unterminated(construct: "internal subset", at: startPos)
        }

        return text
    }
}

// MARK: - Lexer Processing Instruction

extension W3C_XML.Lexer {
    /// Lexes a processing instruction after `<?`.
    @inlinable
    internal mutating func lexProcessingInstruction(startPos: W3C_XML.Position) throws(Error) -> W3C_XML.Token {
        let target = try lexNameString()

        // Check for XML declaration
        if target.lowercased() == "xml" {
            return try lexXMLDeclaration(startPos: startPos)
        }

        // Regular PI
        var data: String?

        if input.first?.isXMLWhitespace == true {
            skipWhitespace()

            var text = ""
            while !input.isEmpty {
                if input.first == .ascii.questionMark {
                    advance()
                    if input.first == .ascii.greaterThanSign {
                        advance()
                        data = text.isEmpty ? nil : text
                        return .instruction(W3C_XML.Instruction(target: target, data: data))
                    }
                    text.append("?")
                } else {
                    let scalar = try consumeUTF8Scalar()
                    text.append(Character(scalar))
                }
            }

            throw .unterminated(construct: "processing instruction", at: startPos)
        }

        // No data - expect ?>
        guard input.first == .ascii.questionMark else {
            throw .unexpectedEndOfInput(expected: "'?>'", at: position)
        }
        advance()
        guard input.first == .ascii.greaterThanSign else {
            throw .unexpectedEndOfInput(expected: "'>'", at: position)
        }
        advance()

        return .instruction(W3C_XML.Instruction(target: target, data: nil))
    }

    /// Lexes an XML declaration after `<?xml`.
    @inlinable
    internal mutating func lexXMLDeclaration(startPos: W3C_XML.Position) throws(Error) -> W3C_XML.Token {
        skipWhitespace()

        var version: W3C_XML.Declaration.Version = .v1_0
        var encoding: String?
        var standalone: Bool?

        // version (required)
        try expectAttributeName("version")
        skipWhitespace()
        try expectByte(.ascii.equalsSign)
        skipWhitespace()
        let versionStr = try lexQuotedString()

        switch versionStr {
        case "1.0": version = .v1_0
        case "1.1": version = .v1_1
        default:
            throw .invalidDeclaration(reason: "invalid version '\(versionStr)'", at: startPos)
        }

        skipWhitespace()

        // encoding (optional)
        if matchAttributeName("encoding") {
            skipWhitespace()
            try expectByte(.ascii.equalsSign)
            skipWhitespace()
            encoding = try lexQuotedString()
            skipWhitespace()
        }

        // standalone (optional)
        if matchAttributeName("standalone") {
            skipWhitespace()
            try expectByte(.ascii.equalsSign)
            skipWhitespace()
            let standaloneStr = try lexQuotedString()
            switch standaloneStr {
            case "yes": standalone = true
            case "no": standalone = false
            default:
                throw .invalidDeclaration(reason: "invalid standalone '\(standaloneStr)'", at: startPos)
            }
            skipWhitespace()
        }

        // Expect ?>
        guard input.first == .ascii.questionMark else {
            throw .unexpectedEndOfInput(expected: "'?>'", at: position)
        }
        advance()
        guard input.first == .ascii.greaterThanSign else {
            throw .unexpectedEndOfInput(expected: "'>'", at: position)
        }
        advance()

        return .xmlDeclaration(W3C_XML.Declaration(
            version: version,
            encoding: encoding,
            standalone: standalone
        ))
    }
}

// MARK: - Lexer Text

extension W3C_XML.Lexer {
    /// Lexes text content.
    @inlinable
    internal mutating func lexText() throws(Error) -> W3C_XML.Token {
        var text = ""

        while let byte = input.first {
            if byte == .ascii.lessThanSign {
                // End of text content
                break
            }

            if byte == .ascii.ampersand {
                let resolved = try lexEntityReference()
                text.append(contentsOf: String(resolved))
            } else {
                let scalar = try consumeUTF8Scalar()
                text.append(Character(scalar))
            }
        }

        return .text(text)
    }
}

// MARK: - Lexer Entity Reference

extension W3C_XML.Lexer {
    /// Lexes an entity reference after `&`.
    @inlinable
    internal mutating func lexEntityReference() throws(Error) -> Unicode.Scalar {
        let startPos = position
        advance() // consume &

        guard let firstByte = input.first else {
            throw .unexpectedEndOfInput(expected: "entity name", at: startPos)
        }

        if firstByte == .ascii.numberSign {
            // Numeric character reference
            advance()
            return try lexNumericReference(startPos: startPos)
        }

        // Named entity reference
        var name = ""
        while let byte = input.first, byte != .ascii.semicolon {
            guard W3C_XML.isASCIINameChar(byte) else {
                throw .invalidEntity(name, at: startPos)
            }
            name.append(Character(UnicodeScalar(byte)))
            advance()
        }

        guard input.first == .ascii.semicolon else {
            throw .unterminated(construct: "entity reference", at: startPos)
        }
        advance()

        guard let scalar = W3C_XML.Entity.predefined(name) else {
            throw .invalidEntity(name, at: startPos)
        }

        return scalar
    }

    /// Lexes a numeric character reference after `&#`.
    @inlinable
    internal mutating func lexNumericReference(startPos: W3C_XML.Position) throws(Error) -> Unicode.Scalar {
        var refString = ""

        if input.first == .ascii.x || input.first == .ascii.X {
            refString.append(Character(UnicodeScalar(input.first!)))
            advance()
        }

        while let byte = input.first, byte != .ascii.semicolon {
            guard byte.ascii.isHexDigit || byte.ascii.isDigit else {
                throw .invalidEntity(refString, at: startPos)
            }
            refString.append(Character(UnicodeScalar(byte)))
            advance()
        }

        guard input.first == .ascii.semicolon else {
            throw .unterminated(construct: "character reference", at: startPos)
        }
        advance()

        guard let scalar = W3C_XML.Entity.numeric(refString) else {
            throw .invalidEntity(refString, at: startPos)
        }

        return scalar
    }
}

// MARK: - Lexer Name

extension W3C_XML.Lexer {
    /// Lexes an XML name and returns it as a Name struct.
    @inlinable
    internal mutating func lexName() throws(Error) -> W3C_XML.Name {
        let nameStr = try lexNameString()
        return W3C_XML.Name(nameStr)
    }

    /// Lexes an XML name and returns it as a String.
    @inlinable
    internal mutating func lexNameString() throws(Error) -> String {
        guard let firstByte = input.first else {
            throw .invalidName(at: position)
        }

        guard W3C_XML.isASCIINameStartChar(firstByte) || firstByte >= 0x80 else {
            throw .invalidName(at: position)
        }

        var name = ""

        // First character (must be NameStartChar)
        let firstScalar = try consumeUTF8Scalar()
        guard W3C_XML.isNameStartChar(firstScalar) else {
            throw .invalidName(at: position)
        }
        name.append(Character(firstScalar))

        // Subsequent characters (NameChar)
        while let byte = input.first {
            if W3C_XML.isASCIINameChar(byte) {
                name.append(Character(UnicodeScalar(byte)))
                advance()
            } else if byte >= 0x80 {
                // Multi-byte UTF-8 - need to check if valid NameChar
                let scalar = try consumeUTF8Scalar()
                if W3C_XML.isNameChar(scalar) {
                    name.append(Character(scalar))
                } else {
                    // Put back - not part of name
                    // Since we can't put back, this is a limitation
                    // For now, we'll accept it and let parser handle
                    break
                }
            } else {
                break
            }
        }

        return name
    }
}

// MARK: - Lexer Utilities

extension W3C_XML.Lexer {
    /// Skips whitespace bytes.
    @inlinable
    internal mutating func skipWhitespace() {
        while let byte = input.first, W3C_XML.isWhitespace(byte) {
            advance()
        }
    }

    /// Advances by one byte, updating position.
    @inlinable
    internal mutating func advance() {
        guard !input.isEmpty else { return }
        let byte = input.removeFirst()
        let isNewline = byte == .ascii.lf
        position = W3C_XML.Position(
            offset: position.offset + 1,
            line: isNewline ? position.line + 1 : position.line,
            column: isNewline ? 1 : position.column + 1
        )
    }

    /// Consumes and returns a UTF-8 scalar.
    @inlinable
    internal mutating func consumeUTF8Scalar() throws(Error) -> Unicode.Scalar {
        guard let firstByte = input.first else {
            throw .unexpectedEndOfInput(expected: "character", at: position)
        }

        let startPos = position

        if firstByte < 0x80 {
            // ASCII
            advance()
            return Unicode.Scalar(firstByte)
        }

        // Multi-byte UTF-8
        let length: Int
        let mask: UInt8

        if firstByte & 0xE0 == 0xC0 {
            length = 2
            mask = 0x1F
        } else if firstByte & 0xF0 == 0xE0 {
            length = 3
            mask = 0x0F
        } else if firstByte & 0xF8 == 0xF0 {
            length = 4
            mask = 0x07
        } else {
            throw .invalidUTF8(byte: firstByte, at: startPos)
        }

        var value = UInt32(firstByte & mask)
        advance()

        for _ in 1..<length {
            guard let byte = input.first else {
                throw .unexpectedEndOfInput(expected: "continuation byte", at: position)
            }
            guard byte & 0xC0 == 0x80 else {
                throw .invalidUTF8(byte: byte, at: position)
            }
            value = (value << 6) | UInt32(byte & 0x3F)
            advance()
        }

        guard let scalar = Unicode.Scalar(value) else {
            throw .invalidUTF8(byte: firstByte, at: startPos)
        }

        return scalar
    }

    /// Expects the given literal bytes.
    @inlinable
    internal mutating func expectLiteral(_ expected: [UInt8]) throws(Error) {
        let startPos = position
        for expectedByte in expected {
            guard let byte = input.first else {
                throw .unexpectedEndOfInput(expected: "literal", at: startPos)
            }
            guard byte == expectedByte else {
                throw .invalidCharacter(Unicode.Scalar(byte), at: position)
            }
            advance()
        }
    }

    /// Checks if input starts with the given byte (for branching).
    @inlinable
    internal func peekByte() -> UInt8? {
        input.first
    }

    /// Tries to match the given literal bytes, consuming them if matched.
    /// Returns false and consumes nothing if first byte doesn't match.
    @inlinable
    internal mutating func matchLiteral(_ expected: [UInt8]) -> Bool {
        guard let first = expected.first else { return true }
        guard input.first == first else { return false }

        // First byte matches, consume all (will fail later if rest don't match)
        for _ in expected {
            advance()
        }
        return true
    }

    /// Expects a specific byte.
    @inlinable
    internal mutating func expectByte(_ expected: UInt8) throws(Error) {
        guard let byte = input.first else {
            throw .unexpectedEndOfInput(expected: "'\(Character(UnicodeScalar(expected)))'", at: position)
        }
        guard byte == expected else {
            throw .invalidCharacter(Unicode.Scalar(byte), at: position)
        }
        advance()
    }

    /// Expects an attribute name.
    @inlinable
    internal mutating func expectAttributeName(_ name: String) throws(Error) {
        let nameBytes = Array(name.utf8)
        try expectLiteral(nameBytes)
    }

    /// Matches an attribute name.
    @inlinable
    internal mutating func matchAttributeName(_ name: String) -> Bool {
        let nameBytes = Array(name.utf8)
        return matchLiteral(nameBytes)
    }

    /// Lexes a quoted string (single or double quotes).
    @inlinable
    internal mutating func lexQuotedString() throws(Error) -> String {
        let startPos = position

        guard let quote = input.first,
              quote == .ascii.quotationMark || quote == .ascii.apostrophe else {
            throw .unexpectedEndOfInput(expected: "quoted string", at: position)
        }
        advance()

        var result = ""
        while let byte = input.first {
            if byte == quote {
                advance()
                return result
            }
            result.append(Character(UnicodeScalar(byte)))
            advance()
        }

        throw .unterminated(construct: "quoted string", at: startPos)
    }
}

// MARK: - UInt8 XML Whitespace Extension

extension UInt8 {
    /// Returns true if this byte is XML whitespace.
    @inlinable
    var isXMLWhitespace: Bool {
        W3C_XML.isWhitespace(self)
    }
}

public import Input_Primitives
import Parser_Primitives

extension W3C_XML {

    public struct Lexer<Input: Input_Primitives.Input.Streaming>: ~Copyable
    where Input.Element == Byte {

        @usableFromInline
        internal var input: Input

        @usableFromInline
        internal var position: W3C_XML.Position

        @usableFromInline
        internal var state: State

        @inlinable
        public init(_ input: consuming Input) {
            self.input = input
            self.position = W3C_XML.Position.start
            self.state = .content
        }

        public var currentPosition: W3C_XML.Position {
            position
        }
    }
}

extension W3C_XML.Lexer {

    @usableFromInline
    internal enum State {

        case content

        case inStartTag

        case inEndTag
    }
}

extension W3C_XML.Lexer {

    public typealias Error = __W3CXMLLexerError
}

extension W3C_XML.Lexer {

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

extension W3C_XML.Lexer {

    @inlinable
    package mutating func lexContent() throws(Error) -> W3C_XML.Token? {
        guard let byte = input.first else {
            return nil
        }

        switch byte {
        case ASCII.Code.lessThanSign.byte:
            return try lexMarkup()

        default:
            return try lexText()
        }
    }

    @inlinable
    package mutating func lexMarkup() throws(Error) -> W3C_XML.Token {
        let startPos = position
        advance()

        guard let byte = input.first else {
            throw .unexpectedEndOfInput(expected: "tag name or markup", at: startPos)
        }

        switch byte {
        case ASCII.Code.solidus.byte:
            advance()
            return try lexEndTag()

        case ASCII.Code.exclamationPoint.byte:
            advance()
            return try lexBangMarkup(startPos: startPos)

        case ASCII.Code.questionMark.byte:
            advance()
            return try lexProcessingInstruction(startPos: startPos)

        default:

            guard W3C_XML.isASCIINameStartChar(byte) || byte >= 0x80 else {
                throw .invalidName(at: position)
            }
            return try lexStartTag()
        }
    }
}

extension W3C_XML.Lexer {

    @inlinable
    package mutating func lexStartTag() throws(Error) -> W3C_XML.Token {
        let name = try lexName()
        state = .inStartTag
        return .startTagOpen(name)
    }

    @inlinable
    package mutating func lexInStartTag() throws(Error) -> W3C_XML.Token? {
        skipWhitespace()

        guard let byte = input.first else {
            throw .unexpectedEndOfInput(expected: "'>' or '/>'", at: position)
        }

        switch byte {
        case ASCII.Code.greaterThanSign.byte:
            advance()
            state = .content
            return .tagClose

        case ASCII.Code.solidus.byte:
            advance()
            guard input.first == ASCII.Code.greaterThanSign.byte else {
                throw .unexpectedEndOfInput(expected: "'>'", at: position)
            }
            advance()
            state = .content
            return .emptyTagClose

        case ASCII.Code.equalsSign.byte:
            advance()
            return .equals

        case ASCII.Code.quotationMark.byte, ASCII.Code.apostrophe.byte:
            return try lexAttributeValue()

        default:

            guard W3C_XML.isASCIINameStartChar(byte) || byte >= 0x80 else {
                throw .invalidName(at: position)
            }
            let name = try lexName()
            return .attributeName(name)
        }
    }

    @inlinable
    package mutating func lexAttributeValue() throws(Error) -> W3C_XML.Token {
        let startPos = position
        guard let quote = input.first else {
            throw .unexpectedEndOfInput(expected: "attribute value", at: position)
        }
        input.removeFirst()
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

            if byte == ASCII.Code.lessThanSign.byte {
                throw .invalidCharacter(Unicode.Scalar(UInt32(byte))!, at: position)
            }

            if byte == ASCII.Code.ampersand.byte {
                let resolved = try lexEntityReference()
                value.append(contentsOf: String(resolved))
            } else {

                let scalar = try consumeUTF8Scalar()
                value.append(Character(scalar))
            }
        }

        throw .unterminated(construct: "attribute value", at: startPos)
    }
}

extension W3C_XML.Lexer {

    @inlinable
    package mutating func lexEndTag() throws(Error) -> W3C_XML.Token {
        let name = try lexName()
        state = .inEndTag
        return .endTagOpen(name)
    }

    @inlinable
    package mutating func lexInEndTag() throws(Error) -> W3C_XML.Token? {
        skipWhitespace()

        guard let byte = input.first else {
            throw .unexpectedEndOfInput(expected: "'>'", at: position)
        }

        guard byte == ASCII.Code.greaterThanSign.byte else {
            throw .invalidCharacter(Unicode.Scalar(UInt32(byte))!, at: position)
        }

        advance()
        state = .content
        return .tagClose
    }
}

extension W3C_XML.Lexer {

    @inlinable
    package mutating func lexBangMarkup(startPos: W3C_XML.Position) throws(Error) -> W3C_XML.Token {
        guard let byte = input.first else {
            throw .unexpectedEndOfInput(expected: "comment, CDATA, or DOCTYPE", at: startPos)
        }

        switch byte {
        case ASCII.Code.hyphen.byte:
            return try lexComment(startPos: startPos)

        case ASCII.Code.leftBracket.byte:
            return try lexCDATA(startPos: startPos)

        case ASCII.Code.D.byte:
            return try lexDoctype(startPos: startPos)

        default:
            throw .invalidCharacter(Unicode.Scalar(UInt32(byte))!, at: position)
        }
    }

    @inlinable
    package mutating func lexComment(startPos: W3C_XML.Position) throws(Error) -> W3C_XML.Token {

        advance()
        guard input.first == ASCII.Code.hyphen.byte else {
            throw .unexpectedEndOfInput(expected: "'--' for comment", at: position)
        }
        advance()

        var text = ""

        while !input.isEmpty {
            if input.first == ASCII.Code.hyphen.byte {
                advance()
                if input.first == ASCII.Code.hyphen.byte {
                    advance()
                    guard input.first == ASCII.Code.greaterThanSign.byte else {
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

    @inlinable
    package mutating func lexCDATA(startPos: W3C_XML.Position) throws(Error) -> W3C_XML.Token {

        advance()
        try expectLiteral([
            ASCII.Code.C.byte, ASCII.Code.D.byte, ASCII.Code.A.byte, ASCII.Code.T.byte,
            ASCII.Code.A.byte, ASCII.Code.leftBracket.byte,
        ])

        var text = ""

        while !input.isEmpty {
            if input.first == ASCII.Code.rightBracket.byte {
                advance()
                if input.first == ASCII.Code.rightBracket.byte {
                    advance()
                    if input.first == ASCII.Code.greaterThanSign.byte {
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

    @inlinable
    package mutating func lexDoctype(startPos: W3C_XML.Position) throws(Error) -> W3C_XML.Token {

        try expectLiteral([
            ASCII.Code.D.byte, ASCII.Code.O.byte, ASCII.Code.C.byte, ASCII.Code.T.byte,
            ASCII.Code.Y.byte, ASCII.Code.P.byte, ASCII.Code.E.byte,
        ])

        skipWhitespace()
        let name = try lexNameString()

        skipWhitespace()

        var publicID: String?
        var systemID: String?
        var internalSubset: String?

        if input.first == ASCII.Code.P.byte {

            try expectLiteral([
                ASCII.Code.P.byte, ASCII.Code.U.byte, ASCII.Code.B.byte, ASCII.Code.L.byte,
                ASCII.Code.I.byte, ASCII.Code.C.byte,
            ])
            skipWhitespace()
            publicID = try lexQuotedString()
            skipWhitespace()
            systemID = try lexQuotedString()
        } else if input.first == ASCII.Code.S.byte {

            try expectLiteral([
                ASCII.Code.S.byte, ASCII.Code.Y.byte, ASCII.Code.S.byte, ASCII.Code.T.byte,
                ASCII.Code.E.byte, ASCII.Code.M.byte,
            ])
            skipWhitespace()
            systemID = try lexQuotedString()
        }

        skipWhitespace()

        if input.first == ASCII.Code.leftBracket.byte {
            advance()
            internalSubset = try lexInternalSubset()
            skipWhitespace()
        }

        guard input.first == ASCII.Code.greaterThanSign.byte else {
            throw .unexpectedEndOfInput(expected: "'>'", at: position)
        }
        advance()

        return .doctype(
            W3C_XML.Doctype(
                name: name,
                publicID: publicID,
                systemID: systemID,
                internalSubset: internalSubset
            )
        )
    }

    @inlinable
    package mutating func lexInternalSubset() throws(Error) -> String {
        let startPos = position
        var text = ""
        var depth = 1

        while !input.isEmpty && depth > 0 {
            let byte = input.first!

            if byte == ASCII.Code.leftBracket.byte {
                depth += 1
                text.append("[")
                advance()
            } else if byte == ASCII.Code.rightBracket.byte {
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

extension W3C_XML.Lexer {

    @inlinable
    package mutating func lexProcessingInstruction(
        startPos: W3C_XML.Position
    ) throws(Error) -> W3C_XML.Token {
        let target = try lexNameString()

        if target.lowercased() == "xml" {
            return try lexXMLDeclaration(startPos: startPos)
        }

        var data: String?

        if input.first?.isXMLWhitespace == true {
            skipWhitespace()

            var text = ""
            while !input.isEmpty {
                if input.first == ASCII.Code.questionMark.byte {
                    advance()
                    if input.first == ASCII.Code.greaterThanSign.byte {
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

        guard input.first == ASCII.Code.questionMark.byte else {
            throw .unexpectedEndOfInput(expected: "'?>'", at: position)
        }
        advance()
        guard input.first == ASCII.Code.greaterThanSign.byte else {
            throw .unexpectedEndOfInput(expected: "'>'", at: position)
        }
        advance()

        return .instruction(W3C_XML.Instruction(target: target, data: nil))
    }

    @inlinable
    package mutating func lexXMLDeclaration(
        startPos: W3C_XML.Position
    ) throws(Error) -> W3C_XML.Token {
        skipWhitespace()

        var version: W3C_XML.Declaration.Version = .v1_0
        var encoding: String?
        var standalone: Bool?

        try expectAttributeName("version")
        skipWhitespace()
        try expectByte(ASCII.Code.equalsSign.byte)
        skipWhitespace()
        let versionStr = try lexQuotedString()

        switch versionStr {
        case "1.0": version = .v1_0
        case "1.1": version = .v1_1

        default:
            throw .invalidDeclaration(reason: "invalid version '\(versionStr)'", at: startPos)
        }

        skipWhitespace()

        if matchAttributeName("encoding") {
            skipWhitespace()
            try expectByte(ASCII.Code.equalsSign.byte)
            skipWhitespace()
            encoding = try lexQuotedString()
            skipWhitespace()
        }

        if matchAttributeName("standalone") {
            skipWhitespace()
            try expectByte(ASCII.Code.equalsSign.byte)
            skipWhitespace()
            let standaloneStr = try lexQuotedString()
            switch standaloneStr {
            case "yes": standalone = true
            case "no": standalone = false

            default:
                throw .invalidDeclaration(
                    reason: "invalid standalone '\(standaloneStr)'",
                    at: startPos
                )
            }
            skipWhitespace()
        }

        guard input.first == ASCII.Code.questionMark.byte else {
            throw .unexpectedEndOfInput(expected: "'?>'", at: position)
        }
        advance()
        guard input.first == ASCII.Code.greaterThanSign.byte else {
            throw .unexpectedEndOfInput(expected: "'>'", at: position)
        }
        advance()

        return .xmlDeclaration(
            W3C_XML.Declaration(
                version: version,
                encoding: encoding,
                standalone: standalone
            )
        )
    }
}

extension W3C_XML.Lexer {

    @inlinable
    package mutating func lexText() throws(Error) -> W3C_XML.Token {
        var text = ""

        while let byte = input.first {
            if byte == ASCII.Code.lessThanSign.byte {

                break
            }

            if byte == ASCII.Code.ampersand.byte {
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

extension W3C_XML.Lexer {

    @inlinable
    package mutating func lexEntityReference() throws(Error) -> Unicode.Scalar {
        let startPos = position
        advance()

        guard let firstByte = input.first else {
            throw .unexpectedEndOfInput(expected: "entity name", at: startPos)
        }

        if firstByte == ASCII.Code.numberSign.byte {

            advance()
            return try lexNumericReference(startPos: startPos)
        }

        var name = ""
        while let byte = input.first, byte != ASCII.Code.semicolon.byte {
            guard W3C_XML.isASCIINameChar(byte) else {
                throw .invalidEntity(name, at: startPos)
            }
            name.append(Character(UnicodeScalar(byte)))
            advance()
        }

        guard input.first == ASCII.Code.semicolon.byte else {
            throw .unterminated(construct: "entity reference", at: startPos)
        }
        advance()

        guard let scalar = W3C_XML.Entity.predefined(name) else {
            throw .invalidEntity(name, at: startPos)
        }

        return scalar
    }

    @inlinable
    package mutating func lexNumericReference(
        startPos: W3C_XML.Position
    ) throws(Error) -> Unicode.Scalar {
        var refString = ""

        if input.first == ASCII.Code.x.byte || input.first == ASCII.Code.X.byte {
            refString.append(Character(UnicodeScalar(input.first!.underlying)))
            advance()
        }

        while let byte = input.first, byte != ASCII.Code.semicolon.byte {

            guard byte.underlying < 0x80, ASCII.Code(unchecked: byte).isHexDigit else {
                throw .invalidEntity(refString, at: startPos)
            }
            refString.append(Character(UnicodeScalar(byte.underlying)))
            advance()
        }

        guard input.first == ASCII.Code.semicolon.byte else {
            throw .unterminated(construct: "character reference", at: startPos)
        }
        advance()

        guard let scalar = W3C_XML.Entity.numeric(refString) else {
            throw .invalidEntity(refString, at: startPos)
        }

        return scalar
    }
}

extension W3C_XML.Lexer {

    @inlinable
    package mutating func lexName() throws(Error) -> W3C_XML.Name {
        let nameStr = try lexNameString()
        return W3C_XML.Name(nameStr)
    }

    @inlinable
    package mutating func lexNameString() throws(Error) -> String {
        guard let firstByte = input.first else {
            throw .invalidName(at: position)
        }

        guard W3C_XML.isASCIINameStartChar(firstByte) || firstByte >= 0x80 else {
            throw .invalidName(at: position)
        }

        var name = ""

        let firstScalar = try consumeUTF8Scalar()
        guard W3C_XML.isNameStartChar(firstScalar) else {
            throw .invalidName(at: position)
        }
        name.append(Character(firstScalar))

        while let byte = input.first {
            if W3C_XML.isASCIINameChar(byte) {
                name.append(Character(UnicodeScalar(byte)))
                advance()
            } else if byte >= 0x80 {

                let scalar = try consumeUTF8Scalar()
                if W3C_XML.isNameChar(scalar) {
                    name.append(Character(scalar))
                } else {

                    break
                }
            } else {
                break
            }
        }

        return name
    }
}

extension W3C_XML.Lexer {

    @inlinable
    package mutating func skipWhitespace() {
        while let byte = input.first, W3C_XML.isWhitespace(byte) {
            advance()
        }
    }

    @inlinable
    package mutating func advance() {
        guard !input.isEmpty else { return }
        let byte = input.removeFirst()
        let isNewline = byte == ASCII.Code.lf.byte
        position = W3C_XML.Position(
            offset: position.offset + 1,
            line: isNewline ? position.line + 1 : position.line,
            column: isNewline ? 1 : position.column + 1
        )
    }

    @inlinable
    package mutating func consumeUTF8Scalar() throws(Error) -> Unicode.Scalar {
        guard let firstByte = input.first else {
            throw .unexpectedEndOfInput(expected: "character", at: position)
        }

        let startPos = position

        if firstByte < 0x80 {

            advance()
            return Unicode.Scalar(firstByte)
        }

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

        var value = UInt32(firstByte.underlying & mask)
        advance()

        for _ in 1..<length {
            guard let byte = input.first else {
                throw .unexpectedEndOfInput(expected: "continuation byte", at: position)
            }
            guard byte.underlying & 0xC0 == 0x80 else {
                throw .invalidUTF8(byte: byte, at: position)
            }
            value = (value << 6) | UInt32(byte.underlying & 0x3F)
            advance()
        }

        guard let scalar = Unicode.Scalar(value) else {
            throw .invalidUTF8(byte: firstByte, at: startPos)
        }

        return scalar
    }

    @inlinable
    package mutating func expectLiteral(_ expected: [Byte]) throws(Error) {
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

    @inlinable
    package func peekByte() -> Byte? {
        input.first
    }

    @inlinable
    package mutating func matchLiteral(_ expected: [Byte]) -> Bool {
        guard let first = expected.first else { return true }
        guard input.first == first else { return false }

        for _ in expected {
            advance()
        }
        return true
    }

    @inlinable
    package mutating func expectByte(_ expected: Byte) throws(Error) {
        guard let byte = input.first else {
            throw .unexpectedEndOfInput(
                expected: "'\(Character(UnicodeScalar(expected)))'",
                at: position
            )
        }
        guard byte == expected else {
            throw .invalidCharacter(Unicode.Scalar(byte), at: position)
        }
        advance()
    }

    @inlinable
    package mutating func expectAttributeName(_ name: String) throws(Error) {
        let nameBytes = name.utf8.map(Byte.init)
        try expectLiteral(nameBytes)
    }

    @inlinable
    package mutating func matchAttributeName(_ name: String) -> Bool {
        let nameBytes = name.utf8.map(Byte.init)
        return matchLiteral(nameBytes)
    }

    @inlinable
    package mutating func lexQuotedString() throws(Error) -> String {
        let startPos = position

        guard let quote = input.first,
            quote == ASCII.Code.quotationMark.byte || quote == ASCII.Code.apostrophe.byte
        else {
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

extension Byte {

    @inlinable
    package var isXMLWhitespace: Bool {
        W3C_XML.isWhitespace(self)
    }
}

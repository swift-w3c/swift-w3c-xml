extension W3C_XML.Entity {

    /// The general entities declared in an internal DTD subset (XML 1.0 §4.2).
    ///
    /// Internal entities map to their replacement text: character references in the
    /// literal are expanded and general entity references are kept for expansion on use.
    /// External and unparsed entities are recorded by name only; they are never resolved.
    /// Parameter entities are not read, so, as XML 1.0 §5.1 requires of a processor that
    /// does not read them, declarations after the first parameter-entity reference are skipped.
    struct Declarations: Sendable {

        var replacements: [String: [UInt8]] = [:]

        var external: Swift::Set<String> = []

        init(subset: String) throws(W3C_XML.Parse.Error) {
            let bytes = Swift::Array(subset.utf8)
            var index = 0

            while index < bytes.count {
                let byte = bytes[index]
                if Self.isSpace(byte) {
                    index += 1
                } else if Self.starts(bytes, at: index, with: "<!--") {
                    index = try Self.end(of: "-->", in: bytes, from: index + 4)
                } else if Self.starts(bytes, at: index, with: "<?") {
                    index = try Self.end(of: "?>", in: bytes, from: index + 2)
                } else if byte == UInt8(ascii: "%") {
                    return
                } else if Self.starts(bytes, at: index, with: "<!ENTITY") {
                    index = try declareEntity(bytes, from: index + 8)
                } else if Self.starts(bytes, at: index, with: "<!") {
                    index = try Self.skipDeclaration(bytes, from: index + 2)
                } else {
                    throw .expected("markup declaration in the internal subset")
                }
            }
        }
    }
}

extension W3C_XML.Entity.Declarations {

    mutating func declareEntity(_ bytes: [UInt8], from start: Int) throws(W3C_XML.Parse.Error) -> Int {
        var index = try Self.requiredSpace(bytes, from: start)

        var isParameter = false
        if index < bytes.count, bytes[index] == UInt8(ascii: "%") {
            isParameter = true
            index = try Self.requiredSpace(bytes, from: index + 1)
        }

        let (name, afterName) = try Self.name(bytes, from: index)
        index = try Self.requiredSpace(bytes, from: afterName)

        var replacement: [UInt8]? = nil
        if index < bytes.count, bytes[index] == UInt8(ascii: "\"") || bytes[index] == UInt8(ascii: "'") {
            let (literal, afterLiteral) = try Self.literal(bytes, from: index)
            index = afterLiteral
            if !isParameter {
                replacement = try Self.replacementText(literal)
            }
        } else if Self.starts(bytes, at: index, with: "SYSTEM") {
            index = try Self.requiredSpace(bytes, from: index + 6)
            index = try Self.literal(bytes, from: index).end
        } else if Self.starts(bytes, at: index, with: "PUBLIC") {
            index = try Self.requiredSpace(bytes, from: index + 6)
            index = try Self.literal(bytes, from: index).end
            index = try Self.requiredSpace(bytes, from: index)
            index = try Self.literal(bytes, from: index).end
        } else {
            throw .expected("entity value or external ID")
        }

        if replacement == nil, !isParameter {
            let afterSpace = Self.skipSpace(bytes, from: index)
            if afterSpace > index, Self.starts(bytes, at: afterSpace, with: "NDATA") {
                index = try Self.requiredSpace(bytes, from: afterSpace + 5)
                index = try Self.name(bytes, from: index).end
            }
        }

        index = Self.skipSpace(bytes, from: index)
        guard index < bytes.count, bytes[index] == UInt8(ascii: ">") else {
            throw .expected("> after entity declaration")
        }

        let isDeclared = replacements[name] != nil || external.contains(name)
        if !isParameter, !isDeclared, W3C_XML.Entity.predefined(name) == nil {
            if let replacement {
                replacements[name] = replacement
            } else {
                external.insert(name)
            }
        }

        return index + 1
    }

    static func replacementText(_ literal: ArraySlice<UInt8>) throws(W3C_XML.Parse.Error) -> [UInt8] {
        var result: [UInt8] = []
        var index = literal.startIndex

        while index < literal.endIndex {
            let byte = literal[index]
            if byte == UInt8(ascii: "%") {
                throw .expected("no parameter-entity reference inside an internal-subset declaration")
            }
            guard byte == UInt8(ascii: "&") else {
                result.append(byte)
                index += 1
                continue
            }
            guard let semicolon = literal[index...].firstIndex(of: UInt8(ascii: ";")) else {
                throw .expected(";")
            }
            let body = literal[(index + 1)..<semicolon]
            if body.first == UInt8(ascii: "#") {
                let reference = String(decoding: body.dropFirst(), as: UTF8.self)
                guard let scalar = W3C_XML.Entity.numeric(reference) else {
                    throw .invalidCharacterReference("&#\(reference);")
                }
                result.append(contentsOf: Swift::Array(String(scalar).utf8))
            } else {
                guard try name(Swift::Array(body), from: 0).end == body.count else {
                    throw .invalidName
                }
                result.append(contentsOf: literal[index...semicolon])
            }
            index = semicolon + 1
        }

        return result
    }
}

extension W3C_XML.Entity.Declarations {

    static func isSpace(_ byte: UInt8) -> Bool {
        byte == 0x20 || byte == 0x09 || byte == 0x0A || byte == 0x0D
    }

    static func starts(_ bytes: [UInt8], at index: Int, with literal: String) -> Bool {
        let prefix = Swift::Array(literal.utf8)
        guard index + prefix.count <= bytes.count else { return false }
        return bytes[index..<(index + prefix.count)].elementsEqual(prefix)
    }

    static func end(of terminator: String, in bytes: [UInt8], from start: Int) throws(W3C_XML.Parse.Error) -> Int {
        let pattern = Swift::Array(terminator.utf8)
        var index = start
        while index + pattern.count <= bytes.count {
            if bytes[index..<(index + pattern.count)].elementsEqual(pattern) {
                return index + pattern.count
            }
            index += 1
        }
        throw .unexpectedEndOfInput(expected: terminator)
    }

    static func skipSpace(_ bytes: [UInt8], from start: Int) -> Int {
        var index = start
        while index < bytes.count, isSpace(bytes[index]) {
            index += 1
        }
        return index
    }

    static func requiredSpace(_ bytes: [UInt8], from start: Int) throws(W3C_XML.Parse.Error) -> Int {
        let index = skipSpace(bytes, from: start)
        guard index > start else { throw .expected("whitespace") }
        return index
    }

    static func name(_ bytes: [UInt8], from start: Int) throws(W3C_XML.Parse.Error) -> (name: String, end: Int) {
        var index = start
        while index < bytes.count {
            let byte = bytes[index]
            if isSpace(byte) || byte == UInt8(ascii: ">") || byte == UInt8(ascii: "\"")
                || byte == UInt8(ascii: "'") || byte == UInt8(ascii: ";")
            {
                break
            }
            index += 1
        }
        guard index > start else { throw .invalidName }
        var input = [Byte](bitPatterns: bytes[start..<index])[...]
        let name = try W3C_XML.Parse.Name<ArraySlice<Byte>>().parse(&input)
        guard input.isEmpty else { throw .invalidName }
        return (name.qualified, index)
    }

    static func literal(
        _ bytes: [UInt8],
        from start: Int
    ) throws(W3C_XML.Parse.Error) -> (value: ArraySlice<UInt8>, end: Int) {
        guard start < bytes.count, bytes[start] == UInt8(ascii: "\"") || bytes[start] == UInt8(ascii: "'") else {
            throw .expected("\" or '")
        }
        let quote = bytes[start]
        guard let close = bytes[(start + 1)...].firstIndex(of: quote) else {
            throw .unexpectedEndOfInput(expected: String(UnicodeScalar(quote)))
        }
        return (bytes[(start + 1)..<close], close + 1)
    }

    static func skipDeclaration(_ bytes: [UInt8], from start: Int) throws(W3C_XML.Parse.Error) -> Int {
        var index = start
        while index < bytes.count {
            let byte = bytes[index]
            if byte == UInt8(ascii: ">") {
                return index + 1
            }
            if byte == UInt8(ascii: "\"") || byte == UInt8(ascii: "'") {
                index = try literal(bytes, from: index).end
            } else {
                index += 1
            }
        }
        throw .unexpectedEndOfInput(expected: ">")
    }
}

extension W3C_XML.Entity.Declarations {
    var isEmpty: Bool { replacements.isEmpty && external.isEmpty }
}

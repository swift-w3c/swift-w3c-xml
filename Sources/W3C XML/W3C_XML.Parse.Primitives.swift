/// W3C_XML.Parse.Primitives.swift
/// swift-w3c-xml
///
/// Primitive parsers for XML character classes and names.

import Parser_Primitives

// MARK: - Whitespace Parser

extension W3C_XML.Parse {
    /// Parses XML whitespace (Production [3]: S).
    ///
    /// Consumes zero or more whitespace characters (space, tab, CR, LF).
    /// Always succeeds, even if no whitespace is present.
    public struct Whitespace<Input: Parser_Primitives.Parser.Input.Streaming>: Parser_Primitives.Parser.`Protocol`, Sendable
    where Input: Sendable, Input.Element == UInt8 {
        public typealias Output = Void
        public typealias Failure = Never

        @inlinable
        public init() {}

        @inlinable
        public func parse(_ input: inout Input) -> Void {
            while let byte = input.first, W3C_XML.isWhitespace(byte) {
                _ = input.removeFirst()
            }
        }
    }

    /// Parses required XML whitespace (at least one character).
    public struct RequiredWhitespace<Input: Parser_Primitives.Parser.Input.Streaming>: Parser_Primitives.Parser.`Protocol`, Sendable
    where Input: Sendable, Input.Element == UInt8 {
        public typealias Output = Void
        public typealias Failure = W3C_XML.Parse.Error

        @inlinable
        public init() {}

        @inlinable
        public func parse(_ input: inout Input) throws(Failure) -> Void {
            guard let byte = input.first, W3C_XML.isWhitespace(byte) else {
                throw .expected("whitespace")
            }
            _ = input.removeFirst()
            while let byte = input.first, W3C_XML.isWhitespace(byte) {
                _ = input.removeFirst()
            }
        }
    }
}

// MARK: - Name Parser

extension W3C_XML.Parse {
    /// Parses an XML Name (Production [5]).
    ///
    /// ```
    /// Name ::= NameStartChar (NameChar)*
    /// ```
    ///
    /// Returns a `W3C_XML.Name` with prefix and local parts if a colon is present.
    public struct Name<Input: Parser_Primitives.Parser.Input.Streaming>: Parser_Primitives.Parser.`Protocol`, Sendable
    where Input: Sendable, Input.Element == UInt8 {
        public typealias Output = W3C_XML.Name
        public typealias Failure = W3C_XML.Parse.Error

        @inlinable
        public init() {}

        @inlinable
        public func parse(_ input: inout Input) throws(Failure) -> Output {
            var bytes: [UInt8] = []

            // First character must be NameStartChar
            guard let first = input.first else {
                throw .unexpectedEndOfInput(expected: "name")
            }

            // Fast path for ASCII
            if W3C_XML.isASCIINameStartChar(first) {
                bytes.append(input.removeFirst())
            } else {
                // Check for multi-byte UTF-8 NameStartChar
                let scalar = try consumeUTF8Scalar(&input, bytes: &bytes, checkStart: true)
                guard W3C_XML.isNameStartChar(scalar) else {
                    throw .invalidName
                }
            }

            // Remaining characters must be NameChar
            while let byte = input.first {
                if W3C_XML.isASCIINameChar(byte) {
                    bytes.append(input.removeFirst())
                } else if byte >= 0x80 {
                    // Multi-byte UTF-8
                    let savedInput = input
                    let savedBytes = bytes
                    do {
                        let scalar = try consumeUTF8Scalar(&input, bytes: &bytes, checkStart: false)
                        guard W3C_XML.isNameChar(scalar) else {
                            input = savedInput
                            bytes = savedBytes
                            break
                        }
                    } catch {
                        input = savedInput
                        bytes = savedBytes
                        break
                    }
                } else {
                    break
                }
            }

            guard !bytes.isEmpty else {
                throw .invalidName
            }

            // Convert to string and split on colon
            let qualified = String(decoding: bytes, as: UTF8.self)
            return W3C_XML.Name(qualified)
        }

        /// Consumes a UTF-8 scalar from input, appending bytes to buffer.
        @inlinable
        func consumeUTF8Scalar(
            _ input: inout Input,
            bytes: inout [UInt8],
            checkStart: Bool
        ) throws(Failure) -> Unicode.Scalar {
            guard let first = input.first else {
                throw .unexpectedEndOfInput(expected: "character")
            }

            let byteCount: Int
            let value: UInt32

            if first < 0x80 {
                // ASCII
                bytes.append(input.removeFirst())
                return Unicode.Scalar(first)
            } else if first & 0xE0 == 0xC0 {
                // 2-byte sequence
                byteCount = 2
                value = UInt32(first & 0x1F)
            } else if first & 0xF0 == 0xE0 {
                // 3-byte sequence
                byteCount = 3
                value = UInt32(first & 0x0F)
            } else if first & 0xF8 == 0xF0 {
                // 4-byte sequence
                byteCount = 4
                value = UInt32(first & 0x07)
            } else {
                throw .invalidName
            }

            bytes.append(input.removeFirst())
            var scalarValue = value

            for _ in 1..<byteCount {
                guard let cont = input.first, cont & 0xC0 == 0x80 else {
                    throw .invalidName
                }
                scalarValue = (scalarValue << 6) | UInt32(cont & 0x3F)
                bytes.append(input.removeFirst())
            }

            guard let scalar = Unicode.Scalar(scalarValue) else {
                throw .invalidName
            }

            return scalar
        }
    }
}

// MARK: - Reference Parser

extension W3C_XML.Parse {
    /// Parses an entity or character reference.
    ///
    /// Productions [66]-[68]:
    /// ```
    /// Reference ::= EntityRef | CharRef
    /// EntityRef ::= '&' Name ';'
    /// CharRef ::= '&#' [0-9]+ ';' | '&#x' [0-9a-fA-F]+ ';'
    /// ```
    ///
    /// Returns the resolved character(s) as a String.
    public struct Reference<Input: Parser_Primitives.Parser.Input.Streaming>: Parser_Primitives.Parser.`Protocol`, Sendable
    where Input: Sendable, Input.Element == UInt8 {
        public typealias Output = String
        public typealias Failure = W3C_XML.Parse.Error

        @inlinable
        public init() {}

        @inlinable
        public func parse(_ input: inout Input) throws(Failure) -> Output {
            // Expect '&'
            guard input.first == .ascii.ampersand else {
                throw .expected("&")
            }
            _ = input.removeFirst()

            guard let next = input.first else {
                throw .unexpectedEndOfInput(expected: "entity or character reference")
            }

            if next == .ascii.numberSign {
                // Character reference
                _ = input.removeFirst()
                return try parseCharRef(&input)
            } else {
                // Entity reference
                return try parseEntityRef(&input)
            }
        }

        @inlinable
        func parseCharRef(_ input: inout Input) throws(Failure) -> String {
            var isHex = false

            if input.first == .ascii.x || input.first == .ascii.X {
                isHex = true
                _ = input.removeFirst()
            }

            var value: UInt32 = 0
            var hasDigits = false

            while let byte = input.first, byte != .ascii.semicolon {
                hasDigits = true
                if isHex {
                    if byte >= .ascii.`0` && byte <= .ascii.`9` {
                        value = value * 16 + UInt32(byte - .ascii.`0`)
                    } else if byte >= .ascii.a && byte <= .ascii.f {
                        value = value * 16 + UInt32(byte - .ascii.a + 10)
                    } else if byte >= .ascii.A && byte <= .ascii.F {
                        value = value * 16 + UInt32(byte - .ascii.A + 10)
                    } else {
                        throw .invalidCharacterReference(isHex ? "&#x..." : "&#...")
                    }
                } else {
                    if byte >= .ascii.`0` && byte <= .ascii.`9` {
                        value = value * 10 + UInt32(byte - .ascii.`0`)
                    } else {
                        throw .invalidCharacterReference("&#...")
                    }
                }
                _ = input.removeFirst()
            }

            guard hasDigits else {
                throw .invalidCharacterReference(isHex ? "&#x;" : "&#;")
            }

            // Expect ';'
            guard input.first == .ascii.semicolon else {
                throw .expected(";")
            }
            _ = input.removeFirst()

            // Validate and convert to character
            guard let scalar = Unicode.Scalar(value), W3C_XML.isChar(scalar) else {
                throw .invalidCharacterReference("&#\(isHex ? "x" : "")\(value);")
            }

            return String(scalar)
        }

        @inlinable
        func parseEntityRef(_ input: inout Input) throws(Failure) -> String {
            // Parse entity name
            let name = try Name<Input>().parse(&input)

            // Expect ';'
            guard input.first == .ascii.semicolon else {
                throw .expected(";")
            }
            _ = input.removeFirst()

            // Look up predefined entities
            switch name.qualified {
            case "lt": return "<"
            case "gt": return ">"
            case "amp": return "&"
            case "apos": return "'"
            case "quot": return "\""
            default:
                throw .unknownEntity(name.qualified)
            }
        }
    }
}

/// W3C_XML.Parse.Primitives.swift
/// swift-w3c-xml
///
/// Primitive parsers for XML character classes and names.

import ASCII_Decimal_Parser_Primitives
import ASCII_Hexadecimal_Parser_Primitives
public import Byte_Parser_Primitives
public import Input_Primitives
import Parser_Primitives

// MARK: - Whitespace Parser

extension W3C_XML.Parse {
    /// Parses XML whitespace (Production [3]: S).
    ///
    /// Consumes zero or more whitespace characters (space, tab, CR, LF).
    /// Always succeeds, even if no whitespace is present.
    public struct Whitespace<Input: Input_Primitives.Input.Streaming>: Parser_Primitives.Parser.`Protocol`, Sendable
    where Input: Sendable, Input.Element == Byte {
        public typealias Output = Void
        public typealias Failure = Never

        @inlinable
        public init() {}

        @inlinable
        public func parse(_ input: inout Input) {
            while let byte = input.first, W3C_XML.isWhitespace(byte) {
                _ = input.removeFirst()
            }
        }
    }

    /// Parses required XML whitespace (at least one character).
    public struct RequiredWhitespace<Input: Input_Primitives.Input.Streaming>: Parser_Primitives.Parser.`Protocol`, Sendable
    where Input: Sendable, Input.Element == Byte {
        public typealias Output = Void
        public typealias Failure = W3C_XML.Parse.Error

        @inlinable
        public init() {}

        @inlinable
        public func parse(_ input: inout Input) throws(Failure) {
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
    public struct Name<Input: Input_Primitives.Input.Streaming>: Parser_Primitives.Parser.`Protocol`, Sendable
    where Input: Sendable, Input.Element == Byte {
        public typealias Output = W3C_XML.Name
        public typealias Failure = W3C_XML.Parse.Error

        @inlinable
        public init() {}

        @inlinable
        public func parse(_ input: inout Input) throws(Failure) -> Output {
            var bytes: [Byte] = []

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
                    do throws(Failure) {
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
        package func consumeUTF8Scalar(
            _ input: inout Input,
            bytes: inout [Byte],
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
    public struct Reference<Input: Input_Primitives.Input.Streaming>: Parser_Primitives.Parser.`Protocol`, Sendable
    where Input: Sendable, Input.Element == Byte {
        public typealias Output = String
        public typealias Failure = W3C_XML.Parse.Error

        @inlinable
        public init() {}

        @inlinable
        public func parse(_ input: inout Input) throws(Failure) -> Output {
            // Expect '&'
            guard input.first == ASCII.Code.ampersand.byte else {
                throw .expected("&")
            }
            _ = input.removeFirst()

            guard let next = input.first else {
                throw .unexpectedEndOfInput(expected: "entity or character reference")
            }

            if next == ASCII.Code.numberSign.byte {
                // Character reference
                _ = input.removeFirst()
                return try parseCharRef(&input)
            } else {
                // Entity reference
                return try parseEntityRef(&input)
            }
        }

        // `@usableFromInline` (not `@inlinable`): the body references the L1
        // ASCII parser / `Byte.Input` types through internal (default) imports,
        // which an `@inlinable` body may not do under `InternalImportsByDefault`.
        // Keeping it non-inlinable avoids widening this module's re-export
        // surface with `public import`s; the public `@inlinable parse` entry
        // point still calls it.
        @usableFromInline
        func parseCharRef(_ input: inout Input) throws(Failure) -> String {
            var isHex = false

            if input.first == ASCII.Code.x.byte || input.first == ASCII.Code.X.byte {
                isHex = true
                _ = input.removeFirst()
            }

            // Drain the digit run (everything up to ';' or end of input) into a
            // byte buffer, then delegate the numeric decode to the L1 ASCII
            // parser (greedy, no sign — byte-for-byte the historical
            // accumulation, with overflow now reported rather than trapped).
            var digits: [Byte] = []
            while let byte = input.first, byte != ASCII.Code.semicolon.byte {
                digits.append(byte)
                _ = input.removeFirst()
            }

            guard !digits.isEmpty else {
                throw .invalidCharacterReference(isHex ? "&#x;" : "&#;")
            }

            var slice = Byte.Input(digits)
            let value: UInt32
            do {
                if isHex {
                    value = try ASCII.Hexadecimal.Parser<Byte.Input, UInt32>().parse(&slice)
                } else {
                    value = try ASCII.Decimal.Parser<Byte.Input, UInt32>().parse(&slice)
                }
            } catch {
                // No digits, a non-digit byte, or overflow — all map onto the
                // single invalid-character-reference outcome the loop produced.
                throw .invalidCharacterReference(isHex ? "&#x..." : "&#...")
            }
            // A non-digit byte before ';' (e.g. "&#x1g2;") leaves an unconsumed
            // remainder; reject it exactly as the per-byte validation did.
            guard slice.isEmpty else {
                throw .invalidCharacterReference(isHex ? "&#x..." : "&#...")
            }

            // Expect ';'
            guard input.first == ASCII.Code.semicolon.byte else {
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
        package func parseEntityRef(_ input: inout Input) throws(Failure) -> String {
            // Parse entity name
            let name = try Name<Input>().parse(&input)

            // Expect ';'
            guard input.first == ASCII.Code.semicolon.byte else {
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

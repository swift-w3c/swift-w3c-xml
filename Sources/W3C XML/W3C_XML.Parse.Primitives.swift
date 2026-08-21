import ASCII_Decimal_Parser_Primitives
import ASCII_Hexadecimal_Parser_Primitives
public import Byte_Parser_Primitives
public import Input_Primitives
import Parser_Primitives

extension W3C_XML.Parse {

    public struct Whitespace<Input: Input_Primitives.Input.Streaming>: Parser_Primitives.Parser
            .`Protocol`, Sendable
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

    public struct RequiredWhitespace<Input: Input_Primitives.Input.Streaming>: Parser_Primitives
            .Parser.`Protocol`, Sendable
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

extension W3C_XML.Parse {

    public struct Name<Input: Input_Primitives.Input.Streaming>: Parser_Primitives.Parser
            .`Protocol`, Sendable
    where Input: Sendable, Input.Element == Byte {
        public typealias Output = W3C_XML.Name
        public typealias Failure = W3C_XML.Parse.Error

        @inlinable
        public init() {}

        @inlinable
        public func parse(_ input: inout Input) throws(Failure) -> Output {
            var bytes: [Byte] = []

            guard let first = input.first else {
                throw .unexpectedEndOfInput(expected: "name")
            }

            if W3C_XML.isASCIINameStartChar(first) {
                bytes.append(input.removeFirst())
            } else {

                let scalar = try consumeUTF8Scalar(&input, bytes: &bytes, checkStart: true)
                guard W3C_XML.isNameStartChar(scalar) else {
                    throw .invalidName
                }
            }

            while let byte = input.first {
                if W3C_XML.isASCIINameChar(byte) {
                    bytes.append(input.removeFirst())
                } else if byte >= 0x80 {

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

            let qualified = String(decoding: bytes, as: UTF8.self)
            return W3C_XML.Name(qualified)
        }

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

                bytes.append(input.removeFirst())
                return Unicode.Scalar(first)
            } else if first & 0xE0 == 0xC0 {

                byteCount = 2
                value = UInt32(first & 0x1F)
            } else if first & 0xF0 == 0xE0 {

                byteCount = 3
                value = UInt32(first & 0x0F)
            } else if first & 0xF8 == 0xF0 {

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

extension W3C_XML.Parse {

    public struct Reference<Input: Input_Primitives.Input.Streaming>: Parser_Primitives.Parser
            .`Protocol`, Sendable
    where Input: Sendable, Input.Element == Byte {
        public typealias Output = String
        public typealias Failure = W3C_XML.Parse.Error

        @inlinable
        public init() {}

        @inlinable
        public func parse(_ input: inout Input) throws(Failure) -> Output {

            guard input.first == ASCII.Code.ampersand.byte else {
                throw .expected("&")
            }
            _ = input.removeFirst()

            guard let next = input.first else {
                throw .unexpectedEndOfInput(expected: "entity or character reference")
            }

            if next == ASCII.Code.numberSign.byte {

                _ = input.removeFirst()
                return try parseCharRef(&input)
            } else {

                return try parseEntityRef(&input)
            }
        }

        @usableFromInline
        func parseCharRef(_ input: inout Input) throws(Failure) -> String {
            var isHex = false

            if input.first == ASCII.Code.x.byte || input.first == ASCII.Code.X.byte {
                isHex = true
                _ = input.removeFirst()
            }

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

                throw .invalidCharacterReference(isHex ? "&#x..." : "&#...")
            }

            guard slice.isEmpty else {
                throw .invalidCharacterReference(isHex ? "&#x..." : "&#...")
            }

            guard input.first == ASCII.Code.semicolon.byte else {
                throw .expected(";")
            }
            _ = input.removeFirst()

            guard let scalar = Unicode.Scalar(value), W3C_XML.isChar(scalar) else {
                throw .invalidCharacterReference("&#\(isHex ? "x" : "")\(value);")
            }

            return String(scalar)
        }

        @inlinable
        package func parseEntityRef(_ input: inout Input) throws(Failure) -> String {

            let name = try Name<Input>().parse(&input)

            guard input.first == ASCII.Code.semicolon.byte else {
                throw .expected(";")
            }
            _ = input.removeFirst()

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

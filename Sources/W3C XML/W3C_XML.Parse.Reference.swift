import ASCII
import Byte
public import Cursor
import Parser

extension W3C_XML.Parse {
    public struct Reference<Input: Cursor.`Protocol`>: Parser::Parsing, Sendable
    where Input: Sendable, Input.Element == Byte, Input.Failure == Never {
        @inlinable
        public init() {}
    }
}

extension W3C_XML.Parse.Reference {
    public typealias Output = String

    public typealias Failure = W3C_XML.Parse.Error

    @inlinable
    public func parse(_ input: inout Input) throws(Failure) -> Output {
        guard input.xmlPeek() == ASCII.Code.ampersand.byte else {
            throw .expected("&")
        }
        _ = input.next()

        guard let next = input.xmlPeek() else {
            throw .unexpectedEndOfInput(expected: "entity or character reference")
        }

        guard next == ASCII.Code.numberSign.byte else {
            return try parseEntityRef(&input)
        }
        _ = input.next()
        return try parseCharRef(&input)
    }

    @usableFromInline
    func parseCharRef(_ input: inout Input) throws(Failure) -> String {
        var isHex = false

        if input.xmlPeek() == ASCII.Code.x.byte || input.xmlPeek() == ASCII.Code.X.byte {
            isHex = true
            _ = input.next()
        }

        var digits: [Byte] = []
        while let byte = input.xmlPeek(), byte != ASCII.Code.semicolon.byte {
            digits.append(byte)
            _ = input.next()
        }

        guard !digits.isEmpty else {
            throw .invalidCharacterReference(isHex ? "&#x;" : "&#;")
        }

        var slice = digits[...]
        let value: UInt32
        do {
            if isHex {
                value = try ASCII.Hexadecimal.Parser<ArraySlice<Byte>, UInt32>().parse(&slice)
            } else {
                value = try ASCII.Decimal.Parser<ArraySlice<Byte>, UInt32>().parse(&slice)
            }
        } catch {
            throw .invalidCharacterReference(isHex ? "&#x..." : "&#...")
        }

        guard slice.isEmpty else {
            throw .invalidCharacterReference(isHex ? "&#x..." : "&#...")
        }

        guard input.xmlPeek() == ASCII.Code.semicolon.byte else {
            throw .expected(";")
        }
        _ = input.next()

        guard let scalar = Unicode.Scalar(value), W3C_XML.isChar(scalar) else {
            throw .invalidCharacterReference("&#\(isHex ? "x" : "")\(value);")
        }

        return String(scalar)
    }

    @inlinable
    package func parseEntityRef(_ input: inout Input) throws(Failure) -> String {
        let name = try Name<Input>().parse(&input)

        guard input.xmlPeek() == ASCII.Code.semicolon.byte else {
            throw .expected(";")
        }
        _ = input.next()

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

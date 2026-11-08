import ASCII
import Byte
public import Cursor
import Machine
import Parser
import Parser_Machine


extension W3C_XML.Parse {
    public struct Doctype<Input: Cursor.`Protocol`>: Parser::Parsing, Sendable
    where Input: Sendable, Input.Element == Byte, Input.Failure == Never {

        public typealias Output = W3C_XML.Doctype
        public typealias Failure = W3C_XML.Parse.Error

        @inlinable
        public init() {}

        @inlinable
        public func parse(_ input: inout Input) throws(Failure) -> Output {

            try expectLiteral(&input, "<!DOCTYPE")

            try RequiredWhitespace<Input>().parse(&input)

            let name = try Name<Input>().parse(&input)

            var publicID: String? = nil
            var systemID: String? = nil
            var internalSubset: String? = nil

            Whitespace<Input>().parse(&input)

            if matchLiteral(&input, "PUBLIC") {
                try RequiredWhitespace<Input>().parse(&input)
                publicID = try parseQuotedValue(&input)
                try RequiredWhitespace<Input>().parse(&input)
                systemID = try parseQuotedValue(&input)
            } else if matchLiteral(&input, "SYSTEM") {
                try RequiredWhitespace<Input>().parse(&input)
                systemID = try parseQuotedValue(&input)
            }

            Whitespace<Input>().parse(&input)

            if input.xmlPeek() == ASCII.Code.leftBracket.byte {
                _ = input.next()
                var bytes: [Byte] = []
                var depth = 1

                while depth > 0 {
                    guard let byte = input.xmlPeek() else {
                        throw .unexpectedEndOfInput(expected: "]")
                    }
                    if byte == ASCII.Code.leftBracket.byte {
                        depth += 1
                    } else if byte == ASCII.Code.rightBracket.byte {
                        depth -= 1
                        if depth == 0 {
                            _ = input.next()
                            break
                        }
                    }
                    bytes.append(try input.xmlTake(expected: "character"))
                }
                internalSubset = String(decoding: bytes, as: UTF8.self)
            }

            Whitespace<Input>().parse(&input)

            guard input.xmlPeek() == ASCII.Code.greaterThanSign.byte else {
                throw .expected(">")
            }
            _ = input.next()

            return W3C_XML.Doctype(
                name: name.qualified,
                publicID: publicID,
                systemID: systemID,
                internalSubset: internalSubset
            )
        }

        @inlinable
        package func parseQuotedValue(_ input: inout Input) throws(Failure) -> String {
            guard let quote = input.xmlPeek(),
                quote == ASCII.Code.quotationMark.byte || quote == ASCII.Code.apostrophe.byte
            else {
                throw .expected("\" or '")
            }
            _ = input.next()

            var bytes: [Byte] = []
            while let byte = input.xmlPeek(), byte != quote {
                bytes.append(try input.xmlTake(expected: "character"))
            }

            guard input.xmlPeek() == quote else {
                throw .unexpectedEndOfInput(expected: String(UnicodeScalar(quote.bitPattern)))
            }
            _ = input.next()

            return String(decoding: bytes, as: UTF8.self)
        }

        @inlinable
        package func matchLiteral(_ input: inout Input, _ string: StaticString) -> Bool {
            let bytes = string.withUTF8Buffer { unsafe Swift::Array($0) }

            let saved = input.checkpoint
            for expected in bytes {
                guard let actual = input.xmlPeek(), actual.underlying == expected else {
                    input.seek(to: saved)
                    return false
                }
                _ = input.next()
            }
            return true
        }
    }
}

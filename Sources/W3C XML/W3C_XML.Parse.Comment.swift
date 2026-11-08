public import Cursor
import Parser

extension W3C_XML.Parse {
    public struct Comment<Input: Cursor.`Protocol`>: Parser::Parsing, Sendable
    where Input: Sendable, Input.Element == Byte, Input.Failure == Never {
        @inlinable
        public init() {}
    }
}

extension W3C_XML.Parse.Comment {
    public typealias Output = String

    public typealias Failure = W3C_XML.Parse.Error

    @inlinable
    public func parse(_ input: inout Input) throws(Failure) -> Output {
        try expectLiteral(&input, "<!--")

        var bytes: [Byte] = []

        while true {
            guard let byte = input.xmlPeek() else {
                throw .unexpectedEndOfInput(expected: "-->")
            }

            if byte == ASCII.Code.hyphen.byte {
                _ = input.next()
                guard let next = input.xmlPeek() else {
                    throw .unexpectedEndOfInput(expected: "-->")
                }
                if next == ASCII.Code.hyphen.byte {
                    _ = input.next()

                    guard input.xmlPeek() == ASCII.Code.greaterThanSign.byte else {
                        throw .expected("> after --")
                    }
                    _ = input.next()
                    return String(decoding: bytes, as: UTF8.self)
                }

                bytes.append(ASCII.Code.hyphen.byte)
                continue
            }
            bytes.append(try input.xmlTake(expected: "character"))
        }
    }
}

public import Cursor
import Parser


extension W3C_XML.Parse {
    public struct CDATASection<Input: Cursor.`Protocol`>: Parser::Parsing, Sendable
    where Input: Sendable, Input.Element == Byte, Input.Failure == Never {

        public typealias Output = String
        public typealias Failure = W3C_XML.Parse.Error

        @inlinable
        public init() {}

        @inlinable
        public func parse(_ input: inout Input) throws(Failure) -> Output {

            try expectLiteral(&input, "<![CDATA[")

            var bytes: [Byte] = []

            while true {
                guard let byte = input.xmlPeek() else {
                    throw .unexpectedEndOfInput(expected: "]]>")
                }

                if byte == ASCII.Code.rightBracket.byte {
                    _ = input.next()
                    guard let next = input.xmlPeek() else {
                        throw .unexpectedEndOfInput(expected: "]]>")
                    }
                    if next == ASCII.Code.rightBracket.byte {
                        _ = input.next()
                        if input.xmlPeek() == ASCII.Code.greaterThanSign.byte {
                            _ = input.next()
                            return String(decoding: bytes, as: UTF8.self)
                        }

                        bytes.append(ASCII.Code.rightBracket.byte)
                        bytes.append(ASCII.Code.rightBracket.byte)
                        continue
                    }

                    bytes.append(ASCII.Code.rightBracket.byte)
                    continue
                }
                bytes.append(try input.xmlTake(expected: "character"))
            }
        }
    }
}

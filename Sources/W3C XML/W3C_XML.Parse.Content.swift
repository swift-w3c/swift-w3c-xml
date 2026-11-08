public import Cursor
import Parser

extension W3C_XML.Parse {
    public struct CharData<Input: Cursor.`Protocol`>: Parser::Parsing, Sendable
    where Input: Sendable, Input.Element == Byte, Input.Failure == Never {
        @inlinable
        public init() {}
    }
}

extension W3C_XML.Parse.CharData {
    public typealias Output = String

    public typealias Failure = Never

    @inlinable
    public func parse(_ input: inout Input) -> Output {
        var bytes: [Byte] = []

        while let byte = input.xmlPeek() {
            if byte == ASCII.Code.lessThanSign.byte || byte == ASCII.Code.ampersand.byte {
                break
            }

            if byte == ASCII.Code.rightBracket.byte {
                let saved = input.checkpoint
                _ = input.next()
                if input.xmlPeek() == ASCII.Code.rightBracket.byte {
                    _ = input.next()
                    if input.xmlPeek() == ASCII.Code.greaterThanSign.byte {
                        input.seek(to: saved)
                        break
                    }

                    bytes.append(ASCII.Code.rightBracket.byte)
                    bytes.append(ASCII.Code.rightBracket.byte)
                    continue
                }

                bytes.append(ASCII.Code.rightBracket.byte)
                continue
            }
            bytes.append(byte)
            _ = input.next()
        }

        return String(decoding: bytes, as: UTF8.self)
    }
}

extension W3C_XML.Parse {
}

extension W3C_XML.Parse {
}

extension W3C_XML.Parse {
}

extension W3C_XML.Parse {
    @inlinable
    package static func expectLiteral<Input: Cursor.`Protocol`>(
        _ input: inout Input,
        _ string: StaticString
    ) throws(W3C_XML.Parse.Error)
    where Input.Element == Byte, Input.Failure == Never {
        let bytes = string.withUTF8Buffer { unsafe Swift::Array($0) }
        let expectedString = String(decoding: bytes, as: UTF8.self)

        for expected in bytes {
            guard let actual = input.xmlPeek() else {
                throw .unexpectedEndOfInput(expected: expectedString)
            }
            guard actual.underlying == expected else {
                throw .expected(expectedString)
            }
            _ = input.next()
        }
    }
}

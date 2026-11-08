public import Cursor
import Parser

public import Cursor
import Parser

extension W3C_XML.Parse {
    public struct TextContent<Input: Cursor.`Protocol`>: Parser::Parsing, Sendable
    where Input: Sendable, Input.Element == Byte, Input.Failure == Never {
        @inlinable
        public init() {}
    }
}

extension W3C_XML.Parse.TextContent {
    public typealias Output = String

    public typealias Failure = W3C_XML.Parse.Error

    @inlinable
    public func parse(_ input: inout Input) throws(Failure) -> Output {
        var result = ""

        while let byte = input.xmlPeek() {
            if byte == ASCII.Code.lessThanSign.byte {
                break
            } else if byte == ASCII.Code.ampersand.byte {
                let resolved = try Reference<Input>().parse(&input)
                result += resolved
            } else {
                result.append(Character(UnicodeScalar(try input.xmlTake(expected: "character").bitPattern)))
            }
        }

        return result
    }
}

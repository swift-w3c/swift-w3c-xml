import ASCII
import Byte
public import Cursor
import Parser

extension W3C_XML.Parse {
    public struct RequiredWhitespace<Input: Cursor.`Protocol`>: Parser::Parsing, Sendable
    where Input: Sendable, Input.Element == Byte, Input.Failure == Never {
        @inlinable
        public init() {}
    }
}

extension W3C_XML.Parse.RequiredWhitespace {
    public typealias Output = Void

    public typealias Failure = W3C_XML.Parse.Error

    @inlinable
    public func parse(_ input: inout Input) throws(Failure) {
        guard let byte = input.xmlPeek(), W3C_XML.isWhitespace(byte) else {
            throw .expected("whitespace")
        }
        _ = input.next()
        while let byte = input.xmlPeek(), W3C_XML.isWhitespace(byte) {
            _ = input.next()
        }
    }
}

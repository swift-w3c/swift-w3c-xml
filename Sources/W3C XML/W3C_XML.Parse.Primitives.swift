import ASCII
import Byte
public import Cursor
import Parser

extension W3C_XML.Parse {

    public struct Whitespace<Input: Cursor.`Protocol`>: Parser::Parsing, Sendable
    where Input: Sendable, Input.Element == Byte, Input.Failure == Never {

        public typealias Output = Void
        public typealias Failure = Never

        @inlinable
        public init() {}

        @inlinable
        public func parse(_ input: inout Input) {
            while let byte = input.xmlPeek(), W3C_XML.isWhitespace(byte) {
                _ = input.next()
            }
        }
    }

}

extension W3C_XML.Parse {
}

extension W3C_XML.Parse {
}

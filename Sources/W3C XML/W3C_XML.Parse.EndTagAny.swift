public import Cursor
import Machine
import Parser
import Parser_Machine


extension W3C_XML.Parse {
    @usableFromInline
    struct EndTagAny<Input: Cursor.`Protocol`>: Parser::Parsing,
        Sendable
    where Input: Sendable, Input.Element == Byte, Input.Failure == Never {

        @usableFromInline typealias Output = W3C_XML.Name
        @usableFromInline typealias Failure = W3C_XML.Parse.Error

        @usableFromInline
        init() {}

        @usableFromInline
        func parse(_ input: inout Input) throws(Failure) -> W3C_XML.Name {

            guard input.xmlPeek() == ASCII.Code.lessThanSign.byte else {
                throw .expected("</")
            }
            _ = input.next()

            guard input.xmlPeek() == ASCII.Code.solidus.byte else {
                throw .expected("</")
            }
            _ = input.next()

            let endName = try Name<Input>().parse(&input)

            Whitespace<Input>().parse(&input)

            guard input.xmlPeek() == ASCII.Code.greaterThanSign.byte else {
                throw .expected(">")
            }
            _ = input.next()

            return endName
        }
    }
}

public import Cursor
import Machine
import Parser
import Parser_Machine

public import Cursor
import Machine
import Parser
import Parser_Machine

extension W3C_XML.Parse {
    @usableFromInline
    struct StartTag<Input: Cursor.`Protocol`>: Parser::Parsing,
        Sendable
    where Input: Sendable, Input.Element == Byte, Input.Failure == Never {

        @usableFromInline typealias Output = StartTagOutput
        @usableFromInline typealias Failure = W3C_XML.Parse.Error

        @usableFromInline
        init() {}

        @usableFromInline
        func parse(_ input: inout Input) throws(Failure) -> Output {

            guard input.xmlPeek() == ASCII.Code.lessThanSign.byte else {
                throw .expected("<")
            }
            _ = input.next()

            let name = try Name<Input>().parse(&input)

            var attributes: [W3C_XML.Attribute] = []
            var namespaces: [W3C_XML.Namespace] = []
            var seenAttributes: Swift::Set<String> = Swift::Set()

            while true {
                Whitespace<Input>().parse(&input)

                guard let byte = input.xmlPeek() else {
                    throw .unexpectedEndOfInput(expected: "> or />")
                }

                if byte == ASCII.Code.greaterThanSign.byte {
                    _ = input.next()
                    return StartTagOutput(
                        name: name,
                        attributes: attributes,
                        namespaces: namespaces,
                        isEmpty: false
                    )
                }

                if byte == ASCII.Code.solidus.byte {
                    _ = input.next()
                    guard input.xmlPeek() == ASCII.Code.greaterThanSign.byte else {
                        throw .expected(">")
                    }
                    _ = input.next()
                    return StartTagOutput(
                        name: name,
                        attributes: attributes,
                        namespaces: namespaces,
                        isEmpty: true
                    )
                }

                let attr = try Attribute<Input>().parse(&input)

                if attr.name.qualified == "xmlns" {
                    namespaces.append(W3C_XML.Namespace(prefix: nil, uri: attr.value))
                } else if attr.name.prefix == "xmlns" {
                    namespaces.append(W3C_XML.Namespace(prefix: attr.name.local, uri: attr.value))
                } else {

                    guard !seenAttributes.contains(attr.name.qualified) else {
                        throw .duplicateAttribute(name: attr.name.qualified)
                    }
                    seenAttributes.insert(attr.name.qualified)
                    attributes.append(attr)
                }
            }
        }
    }
}

public import Cursor
import Parser

extension W3C_XML.Parse {

    public struct Attribute<Input: Cursor.`Protocol`>: Parser::Parsing, Sendable
    where Input: Sendable, Input.Element == Byte, Input.Failure == Never {
        public typealias Output = W3C_XML.Attribute
        public typealias Failure = W3C_XML.Parse.Error

        @inlinable
        public init() {}

        @inlinable
        public func parse(_ input: inout Input) throws(Failure) -> Output {

            let name = try Name<Input>().parse(&input)

            Whitespace<Input>().parse(&input)

            guard input.xmlPeek() == ASCII.Code.equalsSign.byte else {
                throw .expected("=")
            }
            _ = input.next()

            Whitespace<Input>().parse(&input)

            let value = try parseAttValue(&input)

            return W3C_XML.Attribute(name: name, value: value)
        }

        @inlinable
        package func parseAttValue(_ input: inout Input) throws(Failure) -> String {
            guard let quote = input.xmlPeek(),
                quote == ASCII.Code.quotationMark.byte || quote == ASCII.Code.apostrophe.byte
            else {
                throw .expected("\" or '")
            }
            _ = input.next()

            var result = ""

            while let byte = input.xmlPeek() {
                if byte == quote {
                    _ = input.next()
                    return result
                } else if byte == ASCII.Code.ampersand.byte {

                    let resolved = try Reference<Input>().parse(&input)
                    result += resolved
                } else if byte == ASCII.Code.lessThanSign.byte {

                    throw .expected("valid attribute character (not <)")
                } else {
                    result.append(Character(UnicodeScalar(try input.xmlTake(expected: "character").bitPattern)))
                }
            }

            throw .unexpectedEndOfInput(expected: String(UnicodeScalar(quote.bitPattern)))
        }
    }
}

extension W3C_XML.Parse {

    public struct Element<Input: Cursor.`Protocol`>: Parser::Parsing, Sendable
    where Input: Sendable, Input.Element == Byte, Input.Failure == Never {
        public typealias Output = W3C_XML.Element
        public typealias Failure = W3C_XML.Parse.Error

        @usableFromInline
        let depth: Depth

        @inlinable
        public init(depth: Depth = Depth()) {
            self.depth = depth
        }

        @inlinable
        public func parse(_ input: inout Input) throws(Failure) -> Output {

            guard !depth.isExceeded else {
                throw .depthExceeded(limit: depth.limit)
            }

            guard input.xmlPeek() == ASCII.Code.lessThanSign.byte else {
                throw .expected("<")
            }
            _ = input.next()

            let name = try Name<Input>().parse(&input)

            var attributes: [W3C_XML.Attribute] = []
            var namespaces: [W3C_XML.Namespace] = []
            var seenAttributes: Swift.Set<String> = Swift.Set()

            while true {
                Whitespace<Input>().parse(&input)

                guard let byte = input.xmlPeek() else {
                    throw .unexpectedEndOfInput(expected: "> or />")
                }

                if byte == ASCII.Code.greaterThanSign.byte {
                    _ = input.next()
                    break
                }

                if byte == ASCII.Code.solidus.byte {
                    _ = input.next()
                    guard input.xmlPeek() == ASCII.Code.greaterThanSign.byte else {
                        throw .expected(">")
                    }
                    _ = input.next()

                    return W3C_XML.Element(
                        name: name,
                        attributes: attributes,
                        content: [],
                        namespaces: namespaces
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

            let content = try Content<Input>(depth: depth).parse(&input)

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

            guard name.qualified == endName.qualified else {
                throw .mismatchedTags(open: name.qualified, close: endName.qualified)
            }

            return W3C_XML.Element(
                name: name,
                attributes: attributes,
                content: content,
                namespaces: namespaces
            )
        }
    }
}

extension W3C_XML.Parse {

    public struct Content<Input: Cursor.`Protocol`>: Parser::Parsing, Sendable
    where Input: Sendable, Input.Element == Byte, Input.Failure == Never {
        public typealias Output = [W3C_XML.Content]
        public typealias Failure = W3C_XML.Parse.Error

        @usableFromInline
        let depth: Depth

        @inlinable
        public init(depth: Depth) {
            self.depth = depth
        }

        @inlinable
        public func parse(_ input: inout Input) throws(Failure) -> Output {
            var content: [W3C_XML.Content] = []

            while let byte = input.xmlPeek() {

                if byte == ASCII.Code.lessThanSign.byte {

                    let saved = input.checkpoint
                    _ = input.next()

                    guard let next = input.xmlPeek() else {
                        input.seek(to: saved)
                        throw .unexpectedEndOfInput(expected: "element or end tag")
                    }

                    if next == ASCII.Code.solidus.byte {

                        input.seek(to: saved)
                        return content
                    } else if next == ASCII.Code.exclamationPoint.byte {

                        input.seek(to: saved)
                        if let item = try parseMarkup(&input) {
                            content.append(item)
                        }
                    } else if next == ASCII.Code.questionMark.byte {

                        input.seek(to: saved)
                        let pi = try ProcessingInstruction<Input>().parse(&input)
                        content.append(.instruction(pi))
                    } else {

                        input.seek(to: saved)
                        let element = try Element<Input>(depth: depth.incremented()).parse(&input)
                        content.append(.element(element))
                    }
                } else if byte == ASCII.Code.ampersand.byte {

                    let resolved = try Reference<Input>().parse(&input)
                    appendText(&content, resolved)
                } else {

                    let text = CharData<Input>().parse(&input)
                    if !text.isEmpty {
                        appendText(&content, text)
                    } else {

                        break
                    }
                }
            }

            return content
        }

        @inlinable
        package func parseMarkup(_ input: inout Input) throws(Failure) -> W3C_XML.Content? {

            let saved = input.checkpoint

            guard input.xmlPeek() == ASCII.Code.lessThanSign.byte else {
                return nil
            }
            _ = input.next()

            guard input.xmlPeek() == ASCII.Code.exclamationPoint.byte else {
                input.seek(to: saved)
                return nil
            }
            _ = input.next()

            guard let next = input.xmlPeek() else {
                input.seek(to: saved)
                throw .unexpectedEndOfInput(expected: "comment or CDATA")
            }

            if next == ASCII.Code.hyphen.byte {

                input.seek(to: saved)
                let text = try Comment<Input>().parse(&input)
                return .comment(text)
            } else if next == ASCII.Code.leftBracket.byte {

                input.seek(to: saved)
                let text = try CDATASection<Input>().parse(&input)
                return .cdata(text)
            } else {
                input.seek(to: saved)
                throw .expected("comment or CDATA section")
            }
        }

        @inlinable
        package func appendText(_ content: inout [W3C_XML.Content], _ text: String) {
            if let last = content.last, case .text(let prevText) = last {
                content.removeLast()
                content.append(.text(prevText + text))
            } else {
                content.append(.text(text))
            }
        }
    }
}

public import Cursor
import Parser_Machine
import Parser

extension W3C_XML.Parse {

    @usableFromInline
    struct StartTagOutput: Sendable {
        @usableFromInline let name: W3C_XML.Name
        @usableFromInline let attributes: [W3C_XML.Attribute]
        @usableFromInline let namespaces: [W3C_XML.Namespace]
        @usableFromInline let isEmpty: Bool

        @usableFromInline
        init(
            name: W3C_XML.Name,
            attributes: [W3C_XML.Attribute],
            namespaces: [W3C_XML.Namespace],
            isEmpty: Bool
        ) {
            self.name = name
            self.attributes = attributes
            self.namespaces = namespaces
            self.isEmpty = isEmpty
        }
    }

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
            var seenAttributes: Swift.Set<String> = Swift.Set()

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

extension W3C_XML.Parse {

    @usableFromInline
    struct NonEmptyElementParts: Sendable {
        @usableFromInline let start: StartTagOutput
        @usableFromInline let content: [W3C_XML.Content]
        @usableFromInline let endName: W3C_XML.Name

        @usableFromInline
        init(start: StartTagOutput, content: [W3C_XML.Content], endName: W3C_XML.Name) {
            self.start = start
            self.content = content
            self.endName = endName
        }
    }

    static func machineElement<Input: Cursor.`Protocol`>(
        maxDepth: Int = 10000
    ) -> Parser::Parser.Machine.Parser<Input, W3C_XML.Element, W3C_XML.Parse.Error>
    where Input: Sendable, Input.Element == Byte, Input.Failure == Never {
        typealias Builder = Parser::Parser.Machine.Builder<Input, W3C_XML.Parse.Error>
        typealias Expr<T> = Parser::Parser.Machine.Expression<
            Input, W3C_XML.Parse.Error, T
        >
        typealias Ref<T> = Parser::Parser.Machine.Reference<Input, W3C_XML.Parse.Error, T>

        return Parser::Parser.Machine.recursive(
            maxDepth: maxDepth,
            onDepthExceeded: { W3C_XML.Parse.Error.depthExceeded(limit: $0) },
            { (builder: inout Builder, elementRef: Ref<W3C_XML.Element>) -> Expr<W3C_XML.Element> in

                let startTag: Expr<StartTagOutput> = Parser::Parser.Machine.leaf(
                    StartTag<Input>(),
                    in: &builder
                )

                let comment: Expr<W3C_XML.Content> = Parser::Parser.Machine.leaf(
                    Comment<Input>(),
                    in: &builder
                ).map({ W3C_XML.Content.comment($0) }, in: &builder)

                let cdata: Expr<W3C_XML.Content> = Parser::Parser.Machine.leaf(
                    CDATASection<Input>(),
                    in: &builder
                ).map({ W3C_XML.Content.cdata($0) }, in: &builder)

                let pi: Expr<W3C_XML.Content> = Parser::Parser.Machine.leaf(
                    ProcessingInstruction<Input>(),
                    in: &builder
                ).map({ W3C_XML.Content.instruction($0) }, in: &builder)

                let text: Expr<W3C_XML.Content> = Parser::Parser.Machine.leaf(
                    NonEmptyTextContent<Input>(),
                    in: &builder
                ).map({ W3C_XML.Content.text($0) }, in: &builder)

                let elementContent: Expr<W3C_XML.Content> = elementRef.expression(in: &builder)
                    .map({ W3C_XML.Content.element($0) }, in: &builder)

                let contentItem: Expr<W3C_XML.Content> = Parser::Parser.Machine.oneOf(
                    [elementContent, comment, cdata, pi, text],
                    in: &builder
                )

                let content: Expr<[W3C_XML.Content]> = Parser::Parser.Machine.many(
                    contentItem,
                    in: &builder
                )

                let endTagAny: Expr<W3C_XML.Name> = Parser::Parser.Machine.leaf(
                    EndTagAny<Input>(),
                    in: &builder
                )

                let contentAndEndTag: Expr<([W3C_XML.Content], W3C_XML.Name)> = Parser::Parser.Machine.sequence(
                        content,
                        endTagAny,
                        combine: { ($0, $1) },
                        in: &builder
                    )

                let emptyElement: Expr<W3C_XML.Element> = startTag.tryMap(
                    { start throws(W3C_XML.Parse.Error) -> W3C_XML.Element in
                        guard start.isEmpty else {
                            throw .expected("/>")
                        }
                        return W3C_XML.Element(
                            name: start.name,
                            attributes: start.attributes,
                            content: [],
                            namespaces: start.namespaces
                        )
                    },
                    in: &builder
                )

                let openTag: Expr<StartTagOutput> = startTag.tryMap(
                    { start throws(W3C_XML.Parse.Error) -> StartTagOutput in
                        guard !start.isEmpty else {
                            throw .expected(">")
                        }
                        return start
                    },
                    in: &builder
                )

                let openWithContentEnd: Expr<(StartTagOutput, ([W3C_XML.Content], W3C_XML.Name))> =
                    Parser::Parser.Machine.sequence(
                        openTag,
                        contentAndEndTag,
                        combine: { ($0, $1) },
                        in: &builder
                    )

                let nonEmptyElement: Expr<W3C_XML.Element> = openWithContentEnd.tryMap(
                    { parts throws(W3C_XML.Parse.Error) -> W3C_XML.Element in
                        let (start, contentAndEnd) = parts
                        let (contents, endName) = contentAndEnd

                        guard start.name.qualified == endName.qualified else {
                            throw .mismatchedTags(
                                open: start.name.qualified,
                                close: endName.qualified
                            )
                        }

                        let merged = mergeTextNodes(contents)

                        return W3C_XML.Element(
                            name: start.name,
                            attributes: start.attributes,
                            content: merged,
                            namespaces: start.namespaces
                        )
                    },
                    in: &builder
                )

                return Parser::Parser.Machine.oneOf(
                    [emptyElement, nonEmptyElement],
                    in: &builder
                )
            }
        )
    }

    @usableFromInline
    static func mergeTextNodes(_ content: [W3C_XML.Content]) -> [W3C_XML.Content] {
        var result: [W3C_XML.Content] = []
        for item in content {
            if case .text(let text) = item, case .text(let prev) = result.last {
                result.removeLast()
                result.append(.text(prev + text))
            } else {
                result.append(item)
            }
        }
        return result
    }
}

extension W3C_XML.Parse {

    @usableFromInline
    struct NonEmptyTextContent<Input: Cursor.`Protocol`>: Parser::Parsing, Sendable
    where Input: Sendable, Input.Element == Byte, Input.Failure == Never {
        @usableFromInline typealias Output = String
        @usableFromInline typealias Failure = W3C_XML.Parse.Error

        @usableFromInline
        init() {}

        @usableFromInline
        func parse(_ input: inout Input) throws(Failure) -> String {
            var result: [Byte] = []
            var iterationCount = 0
            let maxIterations = 1_000_000

            while let byte = input.xmlPeek() {
                iterationCount += 1
                precondition(
                    iterationCount < maxIterations,
                    "NonEmptyTextContent: runaway loop detected"
                )

                if byte == ASCII.Code.lessThanSign.byte {

                    break
                } else if byte == ASCII.Code.ampersand.byte {

                    let resolved = try Reference<Input>().parse(&input)
                    result.append(contentsOf: resolved.utf8)
                } else {

                    let text = CharData<Input>().parse(&input)
                    if text.isEmpty {
                        break
                    }
                    result.append(contentsOf: text.utf8)
                }
            }

            guard !result.isEmpty else {
                throw .expected("text content")
            }

            return String(decoding: result, as: UTF8.self)
        }
    }
}

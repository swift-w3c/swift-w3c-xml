import Cursor
import Machine
import Parser
import Parser_Machine

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

}

extension W3C_XML.Parse {
}

extension W3C_XML.Parse {


    static func machineElement<Input: Cursor.`Protocol`>(
        maxDepth: Int = 10000
    ) -> Machine::Machine.Parser.Parser<Input, W3C_XML.Element, W3C_XML.Parse.Error>
    where Input: Sendable, Input.Element == Byte, Input.Failure == Never {
        typealias Builder = Machine::Machine.Parser.Builder<Input, W3C_XML.Parse.Error>
        typealias Expr<T> = Machine::Machine.Parser.Expression<
            Input, W3C_XML.Parse.Error, T
        >
        typealias Ref<T> = Machine::Machine.Parser.Reference<Input, W3C_XML.Parse.Error, T>

        return Machine::Machine.Parser.recursive(
            maxDepth: maxDepth,
            onDepthExceeded: { W3C_XML.Parse.Error.depthExceeded(limit: $0) },
            { (builder: inout Builder, elementRef: Ref<W3C_XML.Element>) -> Expr<W3C_XML.Element> in

                let startTag: Expr<StartTagOutput> = Machine::Machine.Parser.leaf(
                    StartTag<Input>(),
                    in: &builder
                )

                let comment: Expr<W3C_XML.Content> = Machine::Machine.Parser.leaf(
                    Comment<Input>(),
                    in: &builder
                ).map({ W3C_XML.Content.comment($0) }, in: &builder)

                let cdata: Expr<W3C_XML.Content> = Machine::Machine.Parser.leaf(
                    CDATASection<Input>(),
                    in: &builder
                ).map({ W3C_XML.Content.cdata($0) }, in: &builder)

                let pi: Expr<W3C_XML.Content> = Machine::Machine.Parser.leaf(
                    ProcessingInstruction<Input>(),
                    in: &builder
                ).map({ W3C_XML.Content.instruction($0) }, in: &builder)

                let text: Expr<W3C_XML.Content> = Machine::Machine.Parser.leaf(
                    NonEmptyTextContent<Input>(),
                    in: &builder
                ).map({ W3C_XML.Content.text($0) }, in: &builder)

                let elementContent: Expr<W3C_XML.Content> = elementRef.expression(in: &builder)
                    .map({ W3C_XML.Content.element($0) }, in: &builder)

                let contentItem: Expr<W3C_XML.Content> = Machine::Machine.Parser.oneOf(
                    [elementContent, comment, cdata, pi, text],
                    in: &builder
                )

                let content: Expr<[W3C_XML.Content]> = Machine::Machine.Parser.many(
                    contentItem,
                    in: &builder
                )

                let endTagAny: Expr<W3C_XML.Name> = Machine::Machine.Parser.leaf(
                    EndTagAny<Input>(),
                    in: &builder
                )

                let contentAndEndTag: Expr<([W3C_XML.Content], W3C_XML.Name)> = Machine::Machine.Parser.sequence(
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
                    Machine::Machine.Parser.sequence(
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

                return Machine::Machine.Parser.oneOf(
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
}

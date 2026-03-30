/// W3C_XML.Parse.MachineElement.swift
/// swift-w3c-xml
///
/// Stack-safe element parser using Parser.Machine for arbitrary nesting depth.

import Parser_Primitives
import Parser_Machine_Primitives

// MARK: - StartTag Parser

extension W3C_XML.Parse {
    /// Output of the StartTag parser.
    @usableFromInline
    struct StartTagOutput: Sendable {
        @usableFromInline let name: W3C_XML.Name
        @usableFromInline let attributes: [W3C_XML.Attribute]
        @usableFromInline let namespaces: [W3C_XML.Namespace]
        @usableFromInline let isEmpty: Bool

        @usableFromInline
        init(name: W3C_XML.Name, attributes: [W3C_XML.Attribute], namespaces: [W3C_XML.Namespace], isEmpty: Bool) {
            self.name = name
            self.attributes = attributes
            self.namespaces = namespaces
            self.isEmpty = isEmpty
        }
    }

    /// Parses an XML start tag (or empty element tag).
    ///
    /// Returns the element name, attributes, namespaces, and whether it's empty (/>).
    @usableFromInline
    struct StartTag<Input: Parser_Primitives.Parser.Input.Streaming>: Parser_Primitives.Parser.`Protocol`, Sendable
    where Input: Sendable, Input.Element == UInt8 {
        @usableFromInline typealias Output = StartTagOutput
        @usableFromInline typealias Failure = W3C_XML.Parse.Error

        @usableFromInline
        init() {}

        @usableFromInline
        func parse(_ input: inout Input) throws(Failure) -> Output {
            // Expect <
            guard input.first == .ascii.lessThanSign else {
                throw .expected("<")
            }
            _ = input.removeFirst()

            // Parse element name
            let name = try Name<Input>().parse(&input)

            // Parse attributes and namespace declarations
            var attributes: [W3C_XML.Attribute] = []
            var namespaces: [W3C_XML.Namespace] = []
            var seenAttributes: Swift.Set<String> = Swift.Set()

            while true {
                Whitespace<Input>().parse(&input)

                guard let byte = input.first else {
                    throw .unexpectedEndOfInput(expected: "> or />")
                }

                // Check for tag end
                if byte == .ascii.greaterThanSign {
                    _ = input.removeFirst()
                    return StartTagOutput(
                        name: name,
                        attributes: attributes,
                        namespaces: namespaces,
                        isEmpty: false
                    )
                }

                if byte == .ascii.solidus {
                    _ = input.removeFirst()
                    guard input.first == .ascii.greaterThanSign else {
                        throw .expected(">")
                    }
                    _ = input.removeFirst()
                    return StartTagOutput(
                        name: name,
                        attributes: attributes,
                        namespaces: namespaces,
                        isEmpty: true
                    )
                }

                // Parse attribute
                let attr = try Attribute<Input>().parse(&input)

                // Check for namespace declaration
                if attr.name.qualified == "xmlns" {
                    namespaces.append(W3C_XML.Namespace(prefix: nil, uri: attr.value))
                } else if attr.name.prefix == "xmlns" {
                    namespaces.append(W3C_XML.Namespace(prefix: attr.name.local, uri: attr.value))
                } else {
                    // Check for duplicate
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

// MARK: - EndTagAny Parser

extension W3C_XML.Parse {
    /// Parses an XML end tag and returns the tag name (without validation).
    ///
    /// Validation of tag name matching happens in tryMap after parsing.
    @usableFromInline
    struct EndTagAny<Input: Parser_Primitives.Parser.Input.Streaming>: Parser_Primitives.Parser.`Protocol`, Sendable
    where Input: Sendable, Input.Element == UInt8 {
        @usableFromInline typealias Output = W3C_XML.Name
        @usableFromInline typealias Failure = W3C_XML.Parse.Error

        @usableFromInline
        init() {}

        @usableFromInline
        func parse(_ input: inout Input) throws(Failure) -> W3C_XML.Name {
            // Expect </
            guard input.first == .ascii.lessThanSign else {
                throw .expected("</")
            }
            _ = input.removeFirst()

            guard input.first == .ascii.solidus else {
                throw .expected("</")
            }
            _ = input.removeFirst()

            // Parse end tag name
            let endName = try Name<Input>().parse(&input)

            Whitespace<Input>().parse(&input)

            guard input.first == .ascii.greaterThanSign else {
                throw .expected(">")
            }
            _ = input.removeFirst()

            return endName
        }
    }
}

// MARK: - Machine Element Parser

extension W3C_XML.Parse {
    /// Intermediate result for non-empty elements before validation.
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

    /// Creates a stack-safe element parser using Parser.Machine.
    ///
    /// This parser handles arbitrary nesting depth without stack overflow by using
    /// an explicit heap-allocated continuation stack instead of recursive descent.
    ///
    /// - Parameter maxDepth: Maximum nesting depth (default: 10000).
    /// - Returns: A parser for XML elements.
    static func machineElement<Input: Parser_Primitives.Parser.Input.`Protocol`>(
        maxDepth: Int = 10000
    ) -> Parser_Primitives.Parser.Machine.Parser<Input, W3C_XML.Element, W3C_XML.Parse.Error>
    where Input: Sendable, Input.Element == UInt8 {
        typealias Builder = Parser_Primitives.Parser.Machine.Builder<Input, W3C_XML.Parse.Error>
        typealias Expr<T> = Parser_Primitives.Parser.Machine.Expression<Input, W3C_XML.Parse.Error, T>
        typealias Ref<T> = Parser_Primitives.Parser.Machine.Reference<Input, W3C_XML.Parse.Error, T>

        return Parser_Primitives.Parser.Machine.recursive(maxDepth: maxDepth) { (builder: inout Builder, elementRef: Ref<W3C_XML.Element>) -> Expr<W3C_XML.Element> in

            // Leaf: StartTag
            let startTag: Expr<StartTagOutput> = Parser_Primitives.Parser.Machine.leaf(
                StartTag<Input>(),
                in: &builder
            )

            // Leaf: Comment -> Content
            let comment: Expr<W3C_XML.Content> = Parser_Primitives.Parser.Machine.leaf(
                Comment<Input>(),
                in: &builder
            ).map({ W3C_XML.Content.comment($0) }, in: &builder)

            // Leaf: CDATA -> Content
            let cdata: Expr<W3C_XML.Content> = Parser_Primitives.Parser.Machine.leaf(
                CDATASection<Input>(),
                in: &builder
            ).map({ W3C_XML.Content.cdata($0) }, in: &builder)

            // Leaf: ProcessingInstruction -> Content
            let pi: Expr<W3C_XML.Content> = Parser_Primitives.Parser.Machine.leaf(
                ProcessingInstruction<Input>(),
                in: &builder
            ).map({ W3C_XML.Content.instruction($0) }, in: &builder)

            // Leaf: TextContent -> Content (fails if empty)
            let text: Expr<W3C_XML.Content> = Parser_Primitives.Parser.Machine.leaf(
                NonEmptyTextContent<Input>(),
                in: &builder
            ).map({ W3C_XML.Content.text($0) }, in: &builder)

            // Recursive: Element -> Content
            let elementContent: Expr<W3C_XML.Content> = elementRef.expression(in: &builder)
                .map({ W3C_XML.Content.element($0) }, in: &builder)

            // ContentItem: one of the above (element first for proper recursion)
            let contentItem: Expr<W3C_XML.Content> = Parser_Primitives.Parser.Machine.oneOf(
                [elementContent, comment, cdata, pi, text],
                in: &builder
            )

            // Content: many content items
            let content: Expr<[W3C_XML.Content]> = Parser_Primitives.Parser.Machine.many(contentItem, in: &builder)

            // EndTagAny: parse end tag, return name
            let endTagAny: Expr<W3C_XML.Name> = Parser_Primitives.Parser.Machine.leaf(
                EndTagAny<Input>(),
                in: &builder
            )

            // === Build element parsing branches ===

            // Build: sequence(content, endTagAny) -> ([Content], Name)
            let contentAndEndTag: Expr<([W3C_XML.Content], W3C_XML.Name)> = Parser_Primitives.Parser.Machine.sequence(
                content,
                endTagAny,
                combine: { ($0, $1) },
                in: &builder
            )

            // Strategy: Use oneOf with two branches that share the StartTag parser
            // but filter based on isEmpty via tryMap:
            // - emptyElement: startTag -> tryMap (require isEmpty) -> Element
            // - nonEmptyElement: startTag -> tryMap (require !isEmpty) -> sequence(content, endTag) -> tryMap(validate)

            // Empty element: startTag -> tryMap (require isEmpty) -> Element
            let emptyElement: Expr<W3C_XML.Element> = startTag.tryMap({ start throws(W3C_XML.Parse.Error) -> W3C_XML.Element in
                guard start.isEmpty else {
                    throw .expected("/>")  // Not an empty element, fail to try next oneOf
                }
                return W3C_XML.Element(
                    name: start.name,
                    attributes: start.attributes,
                    content: [],
                    namespaces: start.namespaces
                )
            }, in: &builder)

            // Non-empty element: startTag -> tryMap (require !isEmpty) -> StartTagOutput
            let openTag: Expr<StartTagOutput> = startTag.tryMap({ start throws(W3C_XML.Parse.Error) -> StartTagOutput in
                guard !start.isEmpty else {
                    throw .expected(">")  // Is empty element, fail to try next oneOf
                }
                return start
            }, in: &builder)

            // Non-empty: openTag -> sequence(content, endTag) -> tryMap(validate)
            let openWithContentEnd: Expr<(StartTagOutput, ([W3C_XML.Content], W3C_XML.Name))> = Parser_Primitives.Parser.Machine.sequence(
                openTag,
                contentAndEndTag,
                combine: { ($0, $1) },
                in: &builder
            )

            let nonEmptyElement: Expr<W3C_XML.Element> = openWithContentEnd.tryMap({ parts throws(W3C_XML.Parse.Error) -> W3C_XML.Element in
                let (start, contentAndEnd) = parts
                let (contents, endName) = contentAndEnd

                // Validate tag names match
                guard start.name.qualified == endName.qualified else {
                    throw .mismatchedTags(open: start.name.qualified, close: endName.qualified)
                }

                // Merge adjacent text nodes
                let merged = mergeTextNodes(contents)

                return W3C_XML.Element(
                    name: start.name,
                    attributes: start.attributes,
                    content: merged,
                    namespaces: start.namespaces
                )
            }, in: &builder)

            // Final element: try empty first (because /> is more specific), then non-empty
            return Parser_Primitives.Parser.Machine.oneOf([emptyElement, nonEmptyElement], in: &builder)
        }
    }

    /// Merges adjacent text nodes in content.
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

// MARK: - Helper Parsers

extension W3C_XML.Parse {
    /// Parses non-empty text content (character data and/or references).
    /// Fails if the result would be empty.
    @usableFromInline
    struct NonEmptyTextContent<Input: Parser_Primitives.Parser.Input.Streaming>: Parser_Primitives.Parser.`Protocol`, Sendable
    where Input: Sendable, Input.Element == UInt8 {
        @usableFromInline typealias Output = String
        @usableFromInline typealias Failure = W3C_XML.Parse.Error

        @usableFromInline
        init() {}

        @usableFromInline
        func parse(_ input: inout Input) throws(Failure) -> String {
            var result: [UInt8] = []
            var iterationCount = 0
            let maxIterations = 1_000_000 // Safety limit

            while let byte = input.first {
                iterationCount += 1
                precondition(iterationCount < maxIterations, "NonEmptyTextContent: runaway loop detected")

                if byte == .ascii.lessThanSign {
                    // Start of tag or other markup
                    break
                } else if byte == .ascii.ampersand {
                    // Reference - must consume &
                    let resolved = try Reference<Input>().parse(&input)
                    result.append(contentsOf: resolved.utf8)
                } else {
                    // Character data - must consume at least one byte or return empty
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

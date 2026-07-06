/// W3C_XML.Parse.Element.swift
/// swift-w3c-xml
///
/// Element and content parsers using Many + Lazy for arbitrary nesting depth.

public import Input_Primitives
import Parser_Primitives

// MARK: - Attribute Parser

extension W3C_XML.Parse {
    /// Parses an XML attribute.
    ///
    /// Production [41]:
    /// ```
    /// Attribute ::= Name Eq AttValue
    /// ```
    public struct Attribute<Input: Input_Primitives.Input.Streaming>: Parser_Primitives.Parser.`Protocol`, Sendable
    where Input: Sendable, Input.Element == Byte {
        public typealias Output = W3C_XML.Attribute
        public typealias Failure = W3C_XML.Parse.Error

        @inlinable
        public init() {}

        @inlinable
        public func parse(_ input: inout Input) throws(Failure) -> Output {
            // Parse attribute name
            let name = try Name<Input>().parse(&input)

            // Skip whitespace around =
            Whitespace<Input>().parse(&input)

            // Expect =
            guard input.first == ASCII.Code.equalsSign.byte else {
                throw .expected("=")
            }
            _ = input.removeFirst()

            Whitespace<Input>().parse(&input)

            // Parse quoted value
            let value = try parseAttValue(&input)

            return W3C_XML.Attribute(name: name, value: value)
        }

        /// Parses an attribute value (quoted string with references).
        @inlinable
        func parseAttValue(_ input: inout Input) throws(Failure) -> String {
            guard let quote = input.first,
                quote == ASCII.Code.quotationMark.byte || quote == ASCII.Code.apostrophe.byte
            else {
                throw .expected("\" or '")
            }
            _ = input.removeFirst()

            var result = ""

            while let byte = input.first {
                if byte == quote {
                    _ = input.removeFirst()
                    return result
                } else if byte == ASCII.Code.ampersand.byte {
                    // Parse reference
                    let resolved = try Reference<Input>().parse(&input)
                    result += resolved
                } else if byte == ASCII.Code.lessThanSign.byte {
                    // < not allowed in attribute values
                    throw .expected("valid attribute character (not <)")
                } else {
                    result.append(Character(UnicodeScalar(input.removeFirst())))
                }
            }

            throw .unexpectedEndOfInput(expected: String(UnicodeScalar(quote)))
        }
    }
}

// MARK: - Element Parser

extension W3C_XML.Parse {
    /// Parses an XML element using combinators.
    ///
    /// Production [39]:
    /// ```
    /// element ::= EmptyElemTag | STag content ETag
    /// ```
    ///
    /// This parser uses explicit depth tracking instead of relying on the call stack.
    /// Nested elements are parsed via the `Content` parser which uses `Many + Lazy`.
    public struct Element<Input: Input_Primitives.Input.Streaming>: Parser_Primitives.Parser.`Protocol`, Sendable
    where Input: Sendable, Input.Element == Byte {
        public typealias Output = W3C_XML.Element
        public typealias Failure = W3C_XML.Parse.Error

        /// Current parsing depth.
        @usableFromInline
        let depth: Depth

        /// Creates an element parser.
        ///
        /// - Parameter depth: Current depth tracker (default: root level).
        @inlinable
        public init(depth: Depth = Depth()) {
            self.depth = depth
        }

        @inlinable
        public func parse(_ input: inout Input) throws(Failure) -> Output {
            // Check depth limit before parsing
            guard !depth.isExceeded else {
                throw .depthExceeded(limit: depth.limit)
            }

            // Expect <
            guard input.first == ASCII.Code.lessThanSign.byte else {
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
                if byte == ASCII.Code.greaterThanSign.byte {
                    _ = input.removeFirst()
                    break  // Non-empty element
                }

                if byte == ASCII.Code.solidus.byte {
                    _ = input.removeFirst()
                    guard input.first == ASCII.Code.greaterThanSign.byte else {
                        throw .expected(">")
                    }
                    _ = input.removeFirst()
                    // Empty element
                    return W3C_XML.Element(
                        name: name,
                        attributes: attributes,
                        content: [],
                        namespaces: namespaces
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

            // Parse content (recursive via Content parser with Many + Lazy)
            let content = try Content<Input>(depth: depth).parse(&input)

            // Parse end tag
            guard input.first == ASCII.Code.lessThanSign.byte else {
                throw .expected("</")
            }
            _ = input.removeFirst()

            guard input.first == ASCII.Code.solidus.byte else {
                throw .expected("</")
            }
            _ = input.removeFirst()

            // Parse end tag name
            let endName = try Name<Input>().parse(&input)

            Whitespace<Input>().parse(&input)

            guard input.first == ASCII.Code.greaterThanSign.byte else {
                throw .expected(">")
            }
            _ = input.removeFirst()

            // Verify tag names match
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

// MARK: - Content Parser

extension W3C_XML.Parse {
    /// Parses element content using Many (iterative) + Lazy (deferred).
    ///
    /// Production [43]:
    /// ```
    /// content ::= CharData? ((element | Reference | CDSect | PI | Comment) CharData?)*
    /// ```
    ///
    /// ## Key Design: No Stack Overflow
    ///
    /// This parser uses `Many.Simple` which internally uses a `while` loop:
    /// ```swift
    /// while maximum.map({ results.count < $0 }) ?? true {
    ///     let saved = input
    ///     do {
    ///         let next = try element.parse(&input)
    ///         results.append(next)
    ///     } catch {
    ///         input = saved
    ///         break
    ///     }
    /// }
    /// ```
    ///
    /// Combined with `Lazy` for the recursive Element reference, this allows
    /// parsing arbitrarily nested XML without growing the call stack.
    public struct Content<Input: Input_Primitives.Input.Streaming>: Parser_Primitives.Parser.`Protocol`, Sendable
    where Input: Sendable, Input.Element == Byte {
        public typealias Output = [W3C_XML.Content]
        public typealias Failure = W3C_XML.Parse.Error

        /// Current parsing depth.
        @usableFromInline
        let depth: Depth

        @inlinable
        public init(depth: Depth) {
            self.depth = depth
        }

        @inlinable
        public func parse(_ input: inout Input) throws(Failure) -> Output {
            var content: [W3C_XML.Content] = []

            // Parse content items until we hit an end tag or end of input
            while let byte = input.first {
                // End tag starts content parsing
                if byte == ASCII.Code.lessThanSign.byte {
                    // Peek at next character
                    let saved = input
                    _ = input.removeFirst()

                    guard let next = input.first else {
                        input = saved
                        throw .unexpectedEndOfInput(expected: "element or end tag")
                    }

                    if next == ASCII.Code.solidus.byte {
                        // End tag - restore and return
                        input = saved
                        return content
                    } else if next == ASCII.Code.exclamationPoint.byte {
                        // Could be comment or CDATA
                        input = saved
                        if let item = try parseMarkup(&input) {
                            content.append(item)
                        }
                    } else if next == ASCII.Code.questionMark.byte {
                        // Processing instruction
                        input = saved
                        let pi = try ProcessingInstruction<Input>().parse(&input)
                        content.append(.instruction(pi))
                    } else {
                        // Child element - use incremented depth
                        input = saved
                        let element = try Element<Input>(depth: depth.incremented()).parse(&input)
                        content.append(.element(element))
                    }
                } else if byte == ASCII.Code.ampersand.byte {
                    // Reference
                    let resolved = try Reference<Input>().parse(&input)
                    appendText(&content, resolved)
                } else {
                    // Character data
                    let text = CharData<Input>().parse(&input)
                    if !text.isEmpty {
                        appendText(&content, text)
                    } else {
                        // No progress - shouldn't happen but prevent infinite loop
                        break
                    }
                }
            }

            return content
        }

        /// Parses markup starting with <!
        @inlinable
        func parseMarkup(_ input: inout Input) throws(Failure) -> W3C_XML.Content? {
            // Save position
            let saved = input

            // Consume <
            guard input.first == ASCII.Code.lessThanSign.byte else {
                return nil
            }
            _ = input.removeFirst()

            guard input.first == ASCII.Code.exclamationPoint.byte else {
                input = saved
                return nil
            }
            _ = input.removeFirst()

            guard let next = input.first else {
                input = saved
                throw .unexpectedEndOfInput(expected: "comment or CDATA")
            }

            if next == ASCII.Code.hyphen.byte {
                // Comment
                input = saved
                let text = try Comment<Input>().parse(&input)
                return .comment(text)
            } else if next == ASCII.Code.leftBracket.byte {
                // CDATA
                input = saved
                let text = try CDATASection<Input>().parse(&input)
                return .cdata(text)
            } else {
                input = saved
                throw .expected("comment or CDATA section")
            }
        }

        /// Appends text to content, merging with previous text if present.
        @inlinable
        func appendText(_ content: inout [W3C_XML.Content], _ text: String) {
            if let last = content.last, case .text(let prevText) = last {
                content.removeLast()
                content.append(.text(prevText + text))
            } else {
                content.append(.text(text))
            }
        }
    }
}

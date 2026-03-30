/// W3C_XML.Parse.Document.swift
/// swift-w3c-xml
///
/// Document-level parsers including XML declaration and DOCTYPE.

import ASCII_Primitives
import Parser_Primitives
import Parser_Machine

// MARK: - XML Declaration Parser

extension W3C_XML.Parse {
    /// Parses an XML declaration.
    ///
    /// Production [23]-[26]:
    /// ```
    /// XMLDecl ::= '<?xml' VersionInfo EncodingDecl? SDDecl? S? '?>'
    /// VersionInfo ::= S 'version' Eq ("'" VersionNum "'" | '"' VersionNum '"')
    /// ```
    public struct XMLDeclaration<Input: Parser.Input>: Parser.Parser, Sendable
    where Input: Sendable, Input.Element == UInt8 {
        public typealias Output = W3C_XML.Declaration
        public typealias Failure = W3C_XML.Parse.Error

        @inlinable
        public init() {}

        @inlinable
        public func parse(_ input: inout Input) throws(Failure) -> Output {
            // Match <?xml
            try expectLiteral(&input, "<?xml")

            // Required whitespace
            guard let ws = input.first, W3C_XML.isWhitespace(ws) else {
                throw .expected("whitespace after <?xml")
            }
            Whitespace<Input>().parse(&input)

            // Parse version="..."
            try expectLiteral(&input, "version")
            Whitespace<Input>().parse(&input)
            try expectLiteral(&input, "=")
            Whitespace<Input>().parse(&input)

            let versionString = try parseQuotedValue(&input)
            let version: W3C_XML.Declaration.Version
            switch versionString {
            case "1.0": version = .v1_0
            case "1.1": version = .v1_1
            default: throw .expected("valid XML version (1.0 or 1.1)")
            }

            // Optional encoding
            var encoding: String? = nil
            Whitespace<Input>().parse(&input)
            if matchLiteral(&input, "encoding") {
                Whitespace<Input>().parse(&input)
                try expectLiteral(&input, "=")
                Whitespace<Input>().parse(&input)
                encoding = try parseQuotedValue(&input)
            }

            // Optional standalone
            var standalone: Bool? = nil
            Whitespace<Input>().parse(&input)
            if matchLiteral(&input, "standalone") {
                Whitespace<Input>().parse(&input)
                try expectLiteral(&input, "=")
                Whitespace<Input>().parse(&input)
                let value = try parseQuotedValue(&input)
                switch value {
                case "yes": standalone = true
                case "no": standalone = false
                default: throw .expected("'yes' or 'no'")
                }
            }

            Whitespace<Input>().parse(&input)
            try expectLiteral(&input, "?>")

            return W3C_XML.Declaration(
                version: version,
                encoding: encoding,
                standalone: standalone
            )
        }

        /// Parses a quoted value (single or double quotes).
        @inlinable
        func parseQuotedValue(_ input: inout Input) throws(Failure) -> String {
            guard let quote = input.first,
                  quote == .ascii.quotationMark || quote == .ascii.apostrophe else {
                throw .expected("\" or '")
            }
            _ = input.removeFirst()

            var bytes: [UInt8] = []
            while let byte = input.first, byte != quote {
                bytes.append(input.removeFirst())
            }

            guard input.first == quote else {
                throw .unexpectedEndOfInput(expected: String(UnicodeScalar(quote)))
            }
            _ = input.removeFirst()

            return String(decoding: bytes, as: UTF8.self)
        }

        /// Tries to match a literal, returning true if successful.
        @inlinable
        func matchLiteral(_ input: inout Input, _ string: StaticString) -> Bool {
            let bytes = Array(string.utf8Start.withMemoryRebound(
                to: UInt8.self,
                capacity: string.utf8CodeUnitCount
            ) {
                UnsafeBufferPointer(start: $0, count: string.utf8CodeUnitCount)
            })

            let saved = input
            for expected in bytes {
                guard let actual = input.first, actual == expected else {
                    input = saved
                    return false
                }
                _ = input.removeFirst()
            }
            return true
        }
    }
}

// MARK: - DOCTYPE Parser

extension W3C_XML.Parse {
    /// Parses a DOCTYPE declaration.
    ///
    /// Production [28]:
    /// ```
    /// doctypedecl ::= '<!DOCTYPE' S Name (S ExternalID)? S? ('[' intSubset ']' S?)? '>'
    /// ```
    public struct Doctype<Input: Parser.Input>: Parser.Parser, Sendable
    where Input: Sendable, Input.Element == UInt8 {
        public typealias Output = W3C_XML.Doctype
        public typealias Failure = W3C_XML.Parse.Error

        @inlinable
        public init() {}

        @inlinable
        public func parse(_ input: inout Input) throws(Failure) -> Output {
            // Match <!DOCTYPE
            try expectLiteral(&input, "<!DOCTYPE")

            // Required whitespace
            try RequiredWhitespace<Input>().parse(&input)

            // Parse name
            let name = try Name<Input>().parse(&input)

            var publicID: String? = nil
            var systemID: String? = nil
            var internalSubset: String? = nil

            Whitespace<Input>().parse(&input)

            // Check for external ID
            if matchLiteral(&input, "PUBLIC") {
                try RequiredWhitespace<Input>().parse(&input)
                publicID = try parseQuotedValue(&input)
                try RequiredWhitespace<Input>().parse(&input)
                systemID = try parseQuotedValue(&input)
            } else if matchLiteral(&input, "SYSTEM") {
                try RequiredWhitespace<Input>().parse(&input)
                systemID = try parseQuotedValue(&input)
            }

            Whitespace<Input>().parse(&input)

            // Check for internal subset
            if input.first == .ascii.leftBracket {
                _ = input.removeFirst()
                var bytes: [UInt8] = []
                var depth = 1

                while depth > 0 {
                    guard let byte = input.first else {
                        throw .unexpectedEndOfInput(expected: "]")
                    }
                    if byte == .ascii.leftBracket {
                        depth += 1
                    } else if byte == .ascii.rightBracket {
                        depth -= 1
                        if depth == 0 {
                            _ = input.removeFirst()
                            break
                        }
                    }
                    bytes.append(input.removeFirst())
                }
                internalSubset = String(decoding: bytes, as: UTF8.self)
            }

            Whitespace<Input>().parse(&input)

            guard input.first == .ascii.greaterThanSign else {
                throw .expected(">")
            }
            _ = input.removeFirst()

            return W3C_XML.Doctype(
                name: name.qualified,
                publicID: publicID,
                systemID: systemID,
                internalSubset: internalSubset
            )
        }

        /// Parses a quoted value.
        @inlinable
        func parseQuotedValue(_ input: inout Input) throws(Failure) -> String {
            guard let quote = input.first,
                  quote == .ascii.quotationMark || quote == .ascii.apostrophe else {
                throw .expected("\" or '")
            }
            _ = input.removeFirst()

            var bytes: [UInt8] = []
            while let byte = input.first, byte != quote {
                bytes.append(input.removeFirst())
            }

            guard input.first == quote else {
                throw .unexpectedEndOfInput(expected: String(UnicodeScalar(quote)))
            }
            _ = input.removeFirst()

            return String(decoding: bytes, as: UTF8.self)
        }

        /// Tries to match a literal.
        @inlinable
        func matchLiteral(_ input: inout Input, _ string: StaticString) -> Bool {
            let bytes = Array(string.utf8Start.withMemoryRebound(
                to: UInt8.self,
                capacity: string.utf8CodeUnitCount
            ) {
                UnsafeBufferPointer(start: $0, count: string.utf8CodeUnitCount)
            })

            let saved = input
            for expected in bytes {
                guard let actual = input.first, actual == expected else {
                    input = saved
                    return false
                }
                _ = input.removeFirst()
            }
            return true
        }
    }
}

// MARK: - Document Parser

extension W3C_XML.Parse {
    /// Parses a complete XML document.
    ///
    /// Production [1]:
    /// ```
    /// document ::= prolog element Misc*
    /// prolog ::= XMLDecl? Misc* (doctypedecl Misc*)?
    /// ```
    public struct Document<Input: Parser.Input>: Parser.Parser, Sendable
    where Input: Sendable, Input.Element == UInt8 {
        public typealias Output = W3C_XML.Document
        public typealias Failure = W3C_XML.Parse.Error

        /// Maximum nesting depth.
        @usableFromInline
        let maxDepth: Int

        @inlinable
        public init(maxDepth: Int = 512) {
            self.maxDepth = maxDepth
        }

        @inlinable
        public func parse(_ input: inout Input) throws(Failure) -> Output {
            var declaration: W3C_XML.Declaration? = nil
            var doctype: W3C_XML.Doctype? = nil
            var prologue: [W3C_XML.Instruction] = []
            var root: W3C_XML.Element? = nil
            var epilogue: [W3C_XML.Content] = []

            // Skip leading whitespace
            Whitespace<Input>().parse(&input)

            // Parse prolog
            while let byte = input.first {
                if byte == .ascii.lessThanSign {
                    let saved = input
                    _ = input.removeFirst()

                    guard let next = input.first else {
                        input = saved
                        throw .unexpectedEndOfInput(expected: "element")
                    }

                    if next == .ascii.questionMark {
                        // PI or XML declaration
                        input = saved

                        // Check if it's <?xml
                        if isXMLDeclaration(&input) {
                            declaration = try XMLDeclaration<Input>().parse(&input)
                        } else {
                            let pi = try ProcessingInstruction<Input>().parse(&input)
                            if root == nil {
                                prologue.append(pi)
                            } else {
                                epilogue.append(.instruction(pi))
                            }
                        }
                    } else if next == .ascii.exclamationPoint {
                        // Comment or DOCTYPE
                        _ = input.removeFirst()
                        guard let third = input.first else {
                            input = saved
                            throw .unexpectedEndOfInput(expected: "comment or DOCTYPE")
                        }

                        if third == .ascii.hyphen {
                            // Comment
                            input = saved
                            let text = try Comment<Input>().parse(&input)
                            if root != nil {
                                epilogue.append(.comment(text))
                            }
                            // Comments before root are ignored per XML spec
                        } else if third == .ascii.D {
                            // DOCTYPE
                            input = saved
                            doctype = try Doctype<Input>().parse(&input)
                        } else {
                            input = saved
                            throw .expected("comment or DOCTYPE")
                        }
                    } else {
                        // Element
                        input = saved
                        if root != nil {
                            throw .multipleRootElements
                        }
                        root = try Element<Input>(depth: Depth(limit: maxDepth)).parse(&input)
                    }
                } else if W3C_XML.isWhitespace(byte) {
                    Whitespace<Input>().parse(&input)
                } else {
                    throw .expected("< or whitespace")
                }
            }

            guard let rootElement = root else {
                throw .missingRootElement
            }

            return W3C_XML.Document(
                declaration: declaration,
                doctype: doctype,
                root: rootElement,
                prologue: prologue,
                epilogue: epilogue
            )
        }

        /// Checks if input starts with <?xml (for XML declaration detection).
        @inlinable
        func isXMLDeclaration(_ input: inout Input) -> Bool {
            let saved = input

            // Check for <?xml followed by whitespace
            let pattern: [UInt8] = [
                .ascii.lessThanSign,
                .ascii.questionMark,
                .ascii.x, .ascii.m, .ascii.l
            ]

            for expected in pattern {
                guard let actual = input.first, actual == expected else {
                    input = saved
                    return false
                }
                _ = input.removeFirst()
            }

            // Must be followed by whitespace (not just <?xml...?>)
            let result = input.first.map { W3C_XML.isWhitespace($0) } ?? false
            input = saved
            return result
        }
    }
}

// MARK: - Convenience Parse Functions

extension W3C_XML {
    /// Parses an XML document from a string using the stack-safe Machine parser.
    ///
    /// This parser handles arbitrary nesting depth without stack overflow.
    ///
    /// - Parameters:
    ///   - string: The XML string to parse.
    ///   - maxDepth: Maximum nesting depth (default: 10000).
    /// - Returns: The parsed document.
    /// - Throws: `W3C_XML.Parse.Error` if parsing fails.
    /// Parses an XML document from a string using the stack-safe Machine parser.
    ///
    /// This parser handles arbitrary nesting depth without stack overflow.
    /// Use this instead of the deprecated `Parser`-based convenience function.
    ///
    /// - Parameters:
    ///   - string: The XML string to parse.
    ///   - maxDepth: Maximum nesting depth (default: 10000).
    /// - Returns: The parsed document.
    /// - Throws: `W3C_XML.Parse.Error` if parsing fails.
    public static func parse(
        _ string: String,
        maxDepth: Int = 10000
    ) throws(Parse.Error) -> Document {
        var input = Parser.CollectionInput(Array(string.utf8))

        // Skip leading whitespace
        Parse.Whitespace<Parser.CollectionInput<[UInt8]>>().parse(&input)

        // Check for XML declaration
        var declaration: Declaration?
        if let byte = input.first, byte == .ascii.lessThanSign {
            let saved = input
            _ = input.removeFirst()
            if let next = input.first, next == .ascii.questionMark {
                input = saved
                if let decl = try? Parse.XMLDeclaration<Parser.CollectionInput<[UInt8]>>().parse(&input) {
                    declaration = decl
                } else {
                    // XMLDeclaration parsing failed - restore input for prologue parsing
                    input = saved
                }
            } else {
                input = saved
            }
        }

        // Parse prologue (processing instructions and comments before root)
        var prologue: [Instruction] = []
        while true {
            Parse.Whitespace<Parser.CollectionInput<[UInt8]>>().parse(&input)
            guard let byte = input.first, byte == .ascii.lessThanSign else { break }

            let saved = input
            _ = input.removeFirst()
            guard let next = input.first else {
                input = saved
                break
            }

            if next == .ascii.questionMark {
                // Processing instruction
                input = saved
                if let pi = try? Parse.ProcessingInstruction<Parser.CollectionInput<[UInt8]>>().parse(&input) {
                    prologue.append(pi)
                    continue
                }
                input = saved
                break
            } else if next == UInt8.ascii.exclamationPoint {
                // Could be comment (<!--) - skip for now, comments aren't instructions
                input = saved
                // Try to parse comment and discard
                if let _ = try? Parse.Comment<Parser.CollectionInput<[UInt8]>>().parse(&input) {
                    continue
                }
                input = saved
                break
            } else {
                // Start of root element
                input = saved
                break
            }
        }

        // Parse root element using Machine parser
        let machineParser = Parse.machineElement(maxDepth: maxDepth)
            as Parser.Machine.Parser<Parser.CollectionInput<[UInt8]>, Element, Parse.Error>
        let root = try machineParser.parse(&input)

        // Parse epilogue (processing instructions and comments after root)
        var epilogue: [Content] = []
        while true {
            Parse.Whitespace<Parser.CollectionInput<[UInt8]>>().parse(&input)
            guard let byte = input.first, byte == .ascii.lessThanSign else { break }

            let saved = input
            _ = input.removeFirst()
            guard let next = input.first else {
                input = saved
                break
            }

            if next == .ascii.questionMark {
                // Processing instruction
                input = saved
                if let pi = try? Parse.ProcessingInstruction<Parser.CollectionInput<[UInt8]>>().parse(&input) {
                    epilogue.append(.instruction(pi))
                    continue
                }
                input = saved
                break
            } else if next == UInt8.ascii.exclamationPoint {
                // Could be comment (<!--)
                input = saved
                if let comment = try? Parse.Comment<Parser.CollectionInput<[UInt8]>>().parse(&input) {
                    epilogue.append(.comment(comment))
                    continue
                }
                input = saved
                break
            } else {
                // Found another element - multiple root elements not allowed
                input = saved
                throw Parse.Error.expected("end of input (multiple root elements not allowed)")
            }
        }

        // Verify no remaining non-whitespace content
        Parse.Whitespace<Parser.CollectionInput<[UInt8]>>().parse(&input)
        if !input.isEmpty {
            throw Parse.Error.expected("end of input (multiple root elements not allowed)")
        }

        return Document(
            declaration: declaration,
            doctype: nil,
            root: root,
            prologue: prologue,
            epilogue: epilogue
        )
    }

    /// Parses an XML document from UTF-8 bytes using the stack-safe Machine parser.
    ///
    /// This parser handles arbitrary nesting depth without stack overflow.
    ///
    /// - Parameters:
    ///   - bytes: The UTF-8 encoded XML bytes.
    ///   - maxDepth: Maximum nesting depth (default: 10000).
    /// - Returns: The parsed document.
    /// - Throws: `W3C_XML.Parse.Error` if parsing fails.
    @inlinable
    public static func parse<Bytes>(
        _ bytes: Bytes,
        maxDepth: Int = 10000
    ) throws(Parse.Error) -> Document
    where Bytes: Collection<UInt8>, Bytes: Sendable {
        var input = Parser.CollectionInput(Array(bytes))

        // Skip leading whitespace
        Parse.Whitespace<Parser.CollectionInput<[UInt8]>>().parse(&input)

        // Check for XML declaration
        var declaration: Declaration?
        if let byte = input.first, byte == .ascii.lessThanSign {
            let saved = input
            _ = input.removeFirst()
            if let next = input.first, next == .ascii.questionMark {
                input = saved
                if let decl = try? Parse.XMLDeclaration<Parser.CollectionInput<[UInt8]>>().parse(&input) {
                    declaration = decl
                } else {
                    // XMLDeclaration parsing failed - restore input for prologue parsing
                    input = saved
                }
            } else {
                input = saved
            }
        }

        // Skip whitespace before root
        Parse.Whitespace<Parser.CollectionInput<[UInt8]>>().parse(&input)

        // Parse root element using Machine parser
        let machineParser = Parse.machineElement(maxDepth: maxDepth)
            as Parser.Machine.Parser<Parser.CollectionInput<[UInt8]>, Element, Parse.Error>
        let root = try machineParser.parse(&input)

        return Document(
            declaration: declaration,
            doctype: nil,
            root: root,
            prologue: [],
            epilogue: []
        )
    }

    /// Parses an XML fragment (element only, no document wrapper) from a string.
    ///
    /// Uses the stack-safe Machine parser that handles arbitrary nesting depth.
    ///
    /// - Parameters:
    ///   - string: The XML fragment string to parse.
    ///   - maxDepth: Maximum nesting depth (default: 10000).
    /// - Returns: The parsed element.
    /// - Throws: `W3C_XML.Parse.Error` if parsing fails.
    @inlinable
    public static func fragment(
        _ string: String,
        maxDepth: Int = 10000
    ) throws(Parse.Error) -> Element {
        var input = Parser.CollectionInput(Array(string.utf8))
        Parse.Whitespace<Parser.CollectionInput<[UInt8]>>().parse(&input)

        let machineParser = Parse.machineElement(maxDepth: maxDepth)
            as Parser.Machine.Parser<Parser.CollectionInput<[UInt8]>, Element, Parse.Error>
        return try machineParser.parse(&input)
    }
}

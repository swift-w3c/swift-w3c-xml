/// W3C_XML.Parse.Content.swift
/// swift-w3c-xml
///
/// Content parsers for text, comments, CDATA, and processing instructions.

import Parser_Primitives

// MARK: - CharData Parser

extension W3C_XML.Parse {
    /// Parses character data (text content).
    ///
    /// Production [14]:
    /// ```
    /// CharData ::= [^<&]* - ([^<&]* ']]>' [^<&]*)
    /// ```
    ///
    /// Parses text until `<`, `&`, or end of input. Does not consume references.
    /// Returns empty string if no text found (to allow Many to continue).
    public struct CharData<Input: Parser_Primitives.Parser.Input.Streaming>: Parser_Primitives.Parser.`Protocol`, Sendable
    where Input: Sendable, Input.Element == UInt8 {
        public typealias Output = String
        public typealias Failure = Never

        @inlinable
        public init() {}

        @inlinable
        public func parse(_ input: inout Input) -> Output {
            var bytes: [UInt8] = []

            while let byte = input.first {
                // Stop at < or &
                if byte == .ascii.lessThanSign || byte == .ascii.ampersand {
                    break
                }
                // Check for forbidden ]]> sequence
                if byte == .ascii.rightBracket {
                    // Look ahead for ]>
                    let saved = input
                    _ = input.removeFirst()
                    if input.first == .ascii.rightBracket {
                        _ = input.removeFirst()
                        if input.first == .ascii.greaterThanSign {
                            // Found ]]> - restore and stop
                            input = saved
                            break
                        }
                        // Not ]]>, add both ] to bytes
                        bytes.append(.ascii.rightBracket)
                        bytes.append(.ascii.rightBracket)
                        continue
                    }
                    // Single ], add to bytes
                    bytes.append(.ascii.rightBracket)
                    continue
                }
                bytes.append(input.removeFirst())
            }

            return String(decoding: bytes, as: UTF8.self)
        }
    }

    /// Parses character data with entity references.
    ///
    /// Like CharData but also handles entity references (&lt; etc).
    public struct TextContent<Input: Parser_Primitives.Parser.Input.Streaming>: Parser_Primitives.Parser.`Protocol`, Sendable
    where Input: Sendable, Input.Element == UInt8 {
        public typealias Output = String
        public typealias Failure = W3C_XML.Parse.Error

        @inlinable
        public init() {}

        @inlinable
        public func parse(_ input: inout Input) throws(Failure) -> Output {
            var result = ""

            while let byte = input.first {
                if byte == .ascii.lessThanSign {
                    break
                } else if byte == .ascii.ampersand {
                    // Parse reference
                    let resolved = try Reference<Input>().parse(&input)
                    result += resolved
                } else {
                    // Regular character
                    result.append(Character(UnicodeScalar(input.removeFirst())))
                }
            }

            return result
        }
    }
}

// MARK: - Comment Parser

extension W3C_XML.Parse {
    /// Parses an XML comment.
    ///
    /// Production [15]:
    /// ```
    /// Comment ::= '<!--' ((Char - '-') | ('-' (Char - '-')))* '-->'
    /// ```
    ///
    /// Note: Comments cannot contain `--` except at the end.
    public struct Comment<Input: Parser_Primitives.Parser.Input.Streaming>: Parser_Primitives.Parser.`Protocol`, Sendable
    where Input: Sendable, Input.Element == UInt8 {
        public typealias Output = String
        public typealias Failure = W3C_XML.Parse.Error

        @inlinable
        public init() {}

        @inlinable
        public func parse(_ input: inout Input) throws(Failure) -> Output {
            // Match <!--
            try expectLiteral(&input, "<!--")

            var bytes: [UInt8] = []

            while true {
                guard let byte = input.first else {
                    throw .unexpectedEndOfInput(expected: "-->")
                }

                if byte == .ascii.hyphen {
                    _ = input.removeFirst()
                    guard let next = input.first else {
                        throw .unexpectedEndOfInput(expected: "-->")
                    }
                    if next == .ascii.hyphen {
                        _ = input.removeFirst()
                        // Must be followed by >
                        guard input.first == .ascii.greaterThanSign else {
                            throw .expected("> after --")
                        }
                        _ = input.removeFirst()
                        return String(decoding: bytes, as: UTF8.self)
                    }
                    // Single -, add to content
                    bytes.append(.ascii.hyphen)
                    continue
                }
                bytes.append(input.removeFirst())
            }
        }
    }
}

// MARK: - CDATA Section Parser

extension W3C_XML.Parse {
    /// Parses a CDATA section.
    ///
    /// Productions [18]-[21]:
    /// ```
    /// CDSect ::= CDStart CData CDEnd
    /// CDStart ::= '<![CDATA['
    /// CData ::= (Char* - (Char* ']]>' Char*))
    /// CDEnd ::= ']]>'
    /// ```
    public struct CDATASection<Input: Parser_Primitives.Parser.Input.Streaming>: Parser_Primitives.Parser.`Protocol`, Sendable
    where Input: Sendable, Input.Element == UInt8 {
        public typealias Output = String
        public typealias Failure = W3C_XML.Parse.Error

        @inlinable
        public init() {}

        @inlinable
        public func parse(_ input: inout Input) throws(Failure) -> Output {
            // Match <![CDATA[
            try expectLiteral(&input, "<![CDATA[")

            var bytes: [UInt8] = []

            while true {
                guard let byte = input.first else {
                    throw .unexpectedEndOfInput(expected: "]]>")
                }

                if byte == .ascii.rightBracket {
                    _ = input.removeFirst()
                    guard let next = input.first else {
                        throw .unexpectedEndOfInput(expected: "]]>")
                    }
                    if next == .ascii.rightBracket {
                        _ = input.removeFirst()
                        if input.first == .ascii.greaterThanSign {
                            _ = input.removeFirst()
                            return String(decoding: bytes, as: UTF8.self)
                        }
                        // Not end, add both ]
                        bytes.append(.ascii.rightBracket)
                        bytes.append(.ascii.rightBracket)
                        continue
                    }
                    // Single ]
                    bytes.append(.ascii.rightBracket)
                    continue
                }
                bytes.append(input.removeFirst())
            }
        }
    }
}

// MARK: - Processing Instruction Parser

extension W3C_XML.Parse {
    /// Parses a processing instruction.
    ///
    /// Productions [16]-[17]:
    /// ```
    /// PI ::= '<?' PITarget (S (Char* - (Char* '?>' Char*)))? '?>'
    /// PITarget ::= Name - (('X' | 'x') ('M' | 'm') ('L' | 'l'))
    /// ```
    public struct ProcessingInstruction<Input: Parser_Primitives.Parser.Input.Streaming>: Parser_Primitives.Parser.`Protocol`, Sendable
    where Input: Sendable, Input.Element == UInt8 {
        public typealias Output = W3C_XML.Instruction
        public typealias Failure = W3C_XML.Parse.Error

        @inlinable
        public init() {}

        @inlinable
        public func parse(_ input: inout Input) throws(Failure) -> Output {
            // Match <?
            try expectLiteral(&input, "<?")

            // Parse target name
            let target = try Name<Input>().parse(&input)

            // Check for reserved 'xml' target (case-insensitive)
            if target.qualified.lowercased() == "xml" {
                throw .expected("processing instruction target (not 'xml')")
            }

            // Optional whitespace and data
            var data: String? = nil

            if let byte = input.first, W3C_XML.isWhitespace(byte) {
                Whitespace<Input>().parse(&input)

                var bytes: [UInt8] = []

                while true {
                    guard let byte = input.first else {
                        throw .unexpectedEndOfInput(expected: "?>")
                    }

                    if byte == .ascii.questionMark {
                        _ = input.removeFirst()
                        if input.first == .ascii.greaterThanSign {
                            _ = input.removeFirst()
                            if !bytes.isEmpty {
                                data = String(decoding: bytes, as: UTF8.self)
                            }
                            return W3C_XML.Instruction(target: target.qualified, data: data)
                        }
                        // Not end, add ?
                        bytes.append(.ascii.questionMark)
                        continue
                    }
                    bytes.append(input.removeFirst())
                }
            }

            // No data, expect ?>
            try expectLiteral(&input, "?>")

            return W3C_XML.Instruction(target: target.qualified, data: nil)
        }
    }
}

// MARK: - Helper Functions

extension W3C_XML.Parse {
    /// Expects and consumes a literal byte sequence.
    @inlinable
    static func expectLiteral<Input: Parser_Primitives.Parser.Input.Streaming>(
        _ input: inout Input,
        _ string: StaticString
    ) throws(W3C_XML.Parse.Error)
    where Input.Element == UInt8 {
        let bytes = Swift.Array(string.utf8Start.withMemoryRebound(
            to: UInt8.self,
            capacity: string.utf8CodeUnitCount
        ) {
            UnsafeBufferPointer(start: $0, count: string.utf8CodeUnitCount)
        })

        for expected in bytes {
            guard let actual = input.first else {
                throw .unexpectedEndOfInput(expected: String(cString: string.utf8Start))
            }
            guard actual == expected else {
                throw .expected(String(cString: string.utf8Start))
            }
            _ = input.removeFirst()
        }
    }
}

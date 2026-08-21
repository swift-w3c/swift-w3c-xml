public import Input_Primitives
import Parser_Primitives

extension W3C_XML.Parse {

    public struct CharData<Input: Input_Primitives.Input.Streaming>: Parser_Primitives.Parser
            .`Protocol`, Sendable
    where Input: Sendable, Input.Element == Byte {
        public typealias Output = String
        public typealias Failure = Never

        @inlinable
        public init() {}

        @inlinable
        public func parse(_ input: inout Input) -> Output {
            var bytes: [Byte] = []

            while let byte = input.first {

                if byte == ASCII.Code.lessThanSign.byte || byte == ASCII.Code.ampersand.byte {
                    break
                }

                if byte == ASCII.Code.rightBracket.byte {

                    let saved = input
                    _ = input.removeFirst()
                    if input.first == ASCII.Code.rightBracket.byte {
                        _ = input.removeFirst()
                        if input.first == ASCII.Code.greaterThanSign.byte {

                            input = saved
                            break
                        }

                        bytes.append(ASCII.Code.rightBracket.byte)
                        bytes.append(ASCII.Code.rightBracket.byte)
                        continue
                    }

                    bytes.append(ASCII.Code.rightBracket.byte)
                    continue
                }
                bytes.append(input.removeFirst())
            }

            return String(decoding: bytes, as: UTF8.self)
        }
    }

    public struct TextContent<Input: Input_Primitives.Input.Streaming>: Parser_Primitives.Parser
            .`Protocol`, Sendable
    where Input: Sendable, Input.Element == Byte {
        public typealias Output = String
        public typealias Failure = W3C_XML.Parse.Error

        @inlinable
        public init() {}

        @inlinable
        public func parse(_ input: inout Input) throws(Failure) -> Output {
            var result = ""

            while let byte = input.first {
                if byte == ASCII.Code.lessThanSign.byte {
                    break
                } else if byte == ASCII.Code.ampersand.byte {

                    let resolved = try Reference<Input>().parse(&input)
                    result += resolved
                } else {

                    result.append(Character(UnicodeScalar(input.removeFirst())))
                }
            }

            return result
        }
    }
}

extension W3C_XML.Parse {

    public struct Comment<Input: Input_Primitives.Input.Streaming>: Parser_Primitives.Parser
            .`Protocol`, Sendable
    where Input: Sendable, Input.Element == Byte {
        public typealias Output = String
        public typealias Failure = W3C_XML.Parse.Error

        @inlinable
        public init() {}

        @inlinable
        public func parse(_ input: inout Input) throws(Failure) -> Output {

            try expectLiteral(&input, "<!--")

            var bytes: [Byte] = []

            while true {
                guard let byte = input.first else {
                    throw .unexpectedEndOfInput(expected: "-->")
                }

                if byte == ASCII.Code.hyphen.byte {
                    _ = input.removeFirst()
                    guard let next = input.first else {
                        throw .unexpectedEndOfInput(expected: "-->")
                    }
                    if next == ASCII.Code.hyphen.byte {
                        _ = input.removeFirst()

                        guard input.first == ASCII.Code.greaterThanSign.byte else {
                            throw .expected("> after --")
                        }
                        _ = input.removeFirst()
                        return String(decoding: bytes, as: UTF8.self)
                    }

                    bytes.append(ASCII.Code.hyphen.byte)
                    continue
                }
                bytes.append(input.removeFirst())
            }
        }
    }
}

extension W3C_XML.Parse {

    public struct CDATASection<Input: Input_Primitives.Input.Streaming>: Parser_Primitives.Parser
            .`Protocol`, Sendable
    where Input: Sendable, Input.Element == Byte {
        public typealias Output = String
        public typealias Failure = W3C_XML.Parse.Error

        @inlinable
        public init() {}

        @inlinable
        public func parse(_ input: inout Input) throws(Failure) -> Output {

            try expectLiteral(&input, "<![CDATA[")

            var bytes: [Byte] = []

            while true {
                guard let byte = input.first else {
                    throw .unexpectedEndOfInput(expected: "]]>")
                }

                if byte == ASCII.Code.rightBracket.byte {
                    _ = input.removeFirst()
                    guard let next = input.first else {
                        throw .unexpectedEndOfInput(expected: "]]>")
                    }
                    if next == ASCII.Code.rightBracket.byte {
                        _ = input.removeFirst()
                        if input.first == ASCII.Code.greaterThanSign.byte {
                            _ = input.removeFirst()
                            return String(decoding: bytes, as: UTF8.self)
                        }

                        bytes.append(ASCII.Code.rightBracket.byte)
                        bytes.append(ASCII.Code.rightBracket.byte)
                        continue
                    }

                    bytes.append(ASCII.Code.rightBracket.byte)
                    continue
                }
                bytes.append(input.removeFirst())
            }
        }
    }
}

extension W3C_XML.Parse {

    public struct ProcessingInstruction<Input: Input_Primitives.Input.Streaming>: Parser_Primitives
            .Parser.`Protocol`, Sendable
    where Input: Sendable, Input.Element == Byte {
        public typealias Output = W3C_XML.Instruction
        public typealias Failure = W3C_XML.Parse.Error

        @inlinable
        public init() {}

        @inlinable
        public func parse(_ input: inout Input) throws(Failure) -> Output {

            try expectLiteral(&input, "<?")

            let target = try Name<Input>().parse(&input)

            if target.qualified.lowercased() == "xml" {
                throw .expected("processing instruction target (not 'xml')")
            }

            var data: String? = nil

            if let byte = input.first, W3C_XML.isWhitespace(byte) {
                Whitespace<Input>().parse(&input)

                var bytes: [Byte] = []

                while true {
                    guard let byte = input.first else {
                        throw .unexpectedEndOfInput(expected: "?>")
                    }

                    if byte == ASCII.Code.questionMark.byte {
                        _ = input.removeFirst()
                        if input.first == ASCII.Code.greaterThanSign.byte {
                            _ = input.removeFirst()
                            if !bytes.isEmpty {
                                data = String(decoding: bytes, as: UTF8.self)
                            }
                            return W3C_XML.Instruction(target: target.qualified, data: data)
                        }

                        bytes.append(ASCII.Code.questionMark.byte)
                        continue
                    }
                    bytes.append(input.removeFirst())
                }
            }

            try expectLiteral(&input, "?>")

            return W3C_XML.Instruction(target: target.qualified, data: nil)
        }
    }
}

extension W3C_XML.Parse {

    @inlinable
    package static func expectLiteral<Input: Input_Primitives.Input.Streaming>(
        _ input: inout Input,
        _ string: StaticString
    ) throws(W3C_XML.Parse.Error)
    where Input.Element == Byte {
        let bytes = string.withUTF8Buffer { unsafe Swift.Array($0) }
        let expectedString = String(decoding: bytes, as: UTF8.self)

        for expected in bytes {
            guard let actual = input.first else {
                throw .unexpectedEndOfInput(expected: expectedString)
            }
            guard actual.underlying == expected else {
                throw .expected(expectedString)
            }
            _ = input.removeFirst()
        }
    }
}

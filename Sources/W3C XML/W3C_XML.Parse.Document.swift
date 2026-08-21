import ASCII_Primitives
public import Byte_Parser_Primitives
public import Input_Primitives
import Parser_Machine_Primitives
import Parser_Primitives

extension W3C_XML.Parse {

    public struct XMLDeclaration<Input: Input_Primitives.Input.Streaming>: Parser_Primitives.Parser
            .`Protocol`, Sendable
    where Input: Sendable, Input.Element == Byte {
        public typealias Output = W3C_XML.Declaration
        public typealias Failure = W3C_XML.Parse.Error

        @inlinable
        public init() {}

        @inlinable
        public func parse(_ input: inout Input) throws(Failure) -> Output {

            try expectLiteral(&input, "<?xml")

            guard let ws = input.first, W3C_XML.isWhitespace(ws) else {
                throw .expected("whitespace after <?xml")
            }
            Whitespace<Input>().parse(&input)

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

            var encoding: String? = nil
            Whitespace<Input>().parse(&input)
            if matchLiteral(&input, "encoding") {
                Whitespace<Input>().parse(&input)
                try expectLiteral(&input, "=")
                Whitespace<Input>().parse(&input)
                encoding = try parseQuotedValue(&input)
            }

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

        @inlinable
        package func parseQuotedValue(_ input: inout Input) throws(Failure) -> String {
            guard let quote = input.first,
                quote == ASCII.Code.quotationMark.byte || quote == ASCII.Code.apostrophe.byte
            else {
                throw .expected("\" or '")
            }
            _ = input.removeFirst()

            var bytes: [Byte] = []
            while let byte = input.first, byte != quote {
                bytes.append(input.removeFirst())
            }

            guard input.first == quote else {
                throw .unexpectedEndOfInput(expected: String(UnicodeScalar(quote)))
            }
            _ = input.removeFirst()

            return String(decoding: bytes, as: UTF8.self)
        }

        @inlinable
        package func matchLiteral(_ input: inout Input, _ string: StaticString) -> Bool {
            let bytes = string.withUTF8Buffer { unsafe Swift.Array($0) }

            let saved = input
            for expected in bytes {
                guard let actual = input.first, actual.underlying == expected else {
                    input = saved
                    return false
                }
                _ = input.removeFirst()
            }
            return true
        }
    }
}

extension W3C_XML.Parse {

    public struct Doctype<Input: Input_Primitives.Input.Streaming>: Parser_Primitives.Parser
            .`Protocol`, Sendable
    where Input: Sendable, Input.Element == Byte {
        public typealias Output = W3C_XML.Doctype
        public typealias Failure = W3C_XML.Parse.Error

        @inlinable
        public init() {}

        @inlinable
        public func parse(_ input: inout Input) throws(Failure) -> Output {

            try expectLiteral(&input, "<!DOCTYPE")

            try RequiredWhitespace<Input>().parse(&input)

            let name = try Name<Input>().parse(&input)

            var publicID: String? = nil
            var systemID: String? = nil
            var internalSubset: String? = nil

            Whitespace<Input>().parse(&input)

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

            if input.first == ASCII.Code.leftBracket.byte {
                _ = input.removeFirst()
                var bytes: [Byte] = []
                var depth = 1

                while depth > 0 {
                    guard let byte = input.first else {
                        throw .unexpectedEndOfInput(expected: "]")
                    }
                    if byte == ASCII.Code.leftBracket.byte {
                        depth += 1
                    } else if byte == ASCII.Code.rightBracket.byte {
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

            guard input.first == ASCII.Code.greaterThanSign.byte else {
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

        @inlinable
        package func parseQuotedValue(_ input: inout Input) throws(Failure) -> String {
            guard let quote = input.first,
                quote == ASCII.Code.quotationMark.byte || quote == ASCII.Code.apostrophe.byte
            else {
                throw .expected("\" or '")
            }
            _ = input.removeFirst()

            var bytes: [Byte] = []
            while let byte = input.first, byte != quote {
                bytes.append(input.removeFirst())
            }

            guard input.first == quote else {
                throw .unexpectedEndOfInput(expected: String(UnicodeScalar(quote)))
            }
            _ = input.removeFirst()

            return String(decoding: bytes, as: UTF8.self)
        }

        @inlinable
        package func matchLiteral(_ input: inout Input, _ string: StaticString) -> Bool {
            let bytes = string.withUTF8Buffer { unsafe Swift.Array($0) }

            let saved = input
            for expected in bytes {
                guard let actual = input.first, actual.underlying == expected else {
                    input = saved
                    return false
                }
                _ = input.removeFirst()
            }
            return true
        }
    }
}

extension W3C_XML.Parse {

    public struct Document<Input: Input_Primitives.Input.Streaming>: Parser_Primitives.Parser
            .`Protocol`, Sendable
    where Input: Sendable, Input.Element == Byte {
        public typealias Output = W3C_XML.Document
        public typealias Failure = W3C_XML.Parse.Error

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

            Whitespace<Input>().parse(&input)

            while let byte = input.first {
                if byte == ASCII.Code.lessThanSign.byte {
                    let saved = input
                    _ = input.removeFirst()

                    guard let next = input.first else {
                        input = saved
                        throw .unexpectedEndOfInput(expected: "element")
                    }

                    if next == ASCII.Code.questionMark.byte {

                        input = saved

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
                    } else if next == ASCII.Code.exclamationPoint.byte {

                        _ = input.removeFirst()
                        guard let third = input.first else {
                            input = saved
                            throw .unexpectedEndOfInput(expected: "comment or DOCTYPE")
                        }

                        if third == ASCII.Code.hyphen.byte {

                            input = saved
                            let text = try Comment<Input>().parse(&input)
                            if root != nil {
                                epilogue.append(.comment(text))
                            }

                        } else if third == ASCII.Code.D.byte {

                            input = saved
                            doctype = try Doctype<Input>().parse(&input)
                        } else {
                            input = saved
                            throw .expected("comment or DOCTYPE")
                        }
                    } else {

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

        @inlinable
        package func isXMLDeclaration(_ input: inout Input) -> Bool {
            let saved = input

            let pattern: [Byte] = [
                ASCII.Code.lessThanSign.byte,
                ASCII.Code.questionMark.byte,
                ASCII.Code.x.byte, ASCII.Code.m.byte, ASCII.Code.l.byte,
            ]

            for expected in pattern {
                guard let actual = input.first, actual == expected else {
                    input = saved
                    return false
                }
                _ = input.removeFirst()
            }

            let result = input.first.map { W3C_XML.isWhitespace($0) } ?? false
            input = saved
            return result
        }
    }
}

extension W3C_XML {

    public static func parse(
        _ string: String,
        maxDepth: Int = 10000
    ) throws(Parse.Error) -> Document {
        var input = Byte.Input(Swift.Array(string.utf8))

        Parse.Whitespace<Byte.Input>().parse(&input)

        var declaration: Declaration?
        if let byte = input.first, byte == ASCII.Code.lessThanSign.byte {
            let saved = input
            _ = input.removeFirst()
            if let next = input.first, next == ASCII.Code.questionMark.byte {
                input = saved
                do {
                    declaration = try Parse.XMLDeclaration<Byte.Input>().parse(&input)
                } catch {

                    input = saved
                }
            } else {
                input = saved
            }
        }

        var prologue: [Instruction] = []
        while true {
            Parse.Whitespace<Byte.Input>().parse(&input)
            guard let byte = input.first, byte == ASCII.Code.lessThanSign.byte else { break }

            let saved = input
            _ = input.removeFirst()
            guard let next = input.first else {
                input = saved
                break
            }

            if next == ASCII.Code.questionMark.byte {

                input = saved
                do {
                    let pi = try Parse.ProcessingInstruction<Byte.Input>().parse(&input)
                    prologue.append(pi)
                    continue
                } catch {
                    input = saved
                    break
                }
            } else if next == ASCII.Code.exclamationPoint.byte {

                input = saved

                do {
                    _ = try Parse.Comment<Byte.Input>().parse(&input)
                    continue
                } catch {
                    input = saved
                    break
                }
            } else {

                input = saved
                break
            }
        }

        let machineParser =
            Parse.machineElement(maxDepth: maxDepth)
            as Parser_Primitives.Parser.Machine.Parser<Byte.Input, Element, Parse.Error>
        let root = try machineParser.parse(&input)

        var epilogue: [Content] = []
        while true {
            Parse.Whitespace<Byte.Input>().parse(&input)
            guard let byte = input.first, byte == ASCII.Code.lessThanSign.byte else { break }

            let saved = input
            _ = input.removeFirst()
            guard let next = input.first else {
                input = saved
                break
            }

            if next == ASCII.Code.questionMark.byte {

                input = saved
                do {
                    let pi = try Parse.ProcessingInstruction<Byte.Input>().parse(&input)
                    epilogue.append(.instruction(pi))
                    continue
                } catch {
                    input = saved
                    break
                }
            } else if next == ASCII.Code.exclamationPoint.byte {

                input = saved
                do {
                    let comment = try Parse.Comment<Byte.Input>().parse(&input)
                    epilogue.append(.comment(comment))
                    continue
                } catch {
                    input = saved
                    break
                }
            } else {

                input = saved
                throw Parse.Error.expected("end of input (multiple root elements not allowed)")
            }
        }

        Parse.Whitespace<Byte.Input>().parse(&input)
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

    public static func parse<Bytes>(
        _ bytes: Bytes,
        maxDepth: Int = 10000
    ) throws(Parse.Error) -> Document
    where Bytes: Swift.Collection<UInt8>, Bytes: Sendable {
        var input = Byte.Input(Swift.Array(bytes))

        Parse.Whitespace<Byte.Input>().parse(&input)

        var declaration: Declaration?
        if let byte = input.first, byte == ASCII.Code.lessThanSign.byte {
            let saved = input
            _ = input.removeFirst()
            if let next = input.first, next == ASCII.Code.questionMark.byte {
                input = saved
                do {
                    declaration = try Parse.XMLDeclaration<Byte.Input>().parse(&input)
                } catch {

                    input = saved
                }
            } else {
                input = saved
            }
        }

        Parse.Whitespace<Byte.Input>().parse(&input)

        let machineParser =
            Parse.machineElement(maxDepth: maxDepth)
            as Parser_Primitives.Parser.Machine.Parser<Byte.Input, Element, Parse.Error>
        let root = try machineParser.parse(&input)

        return Document(
            declaration: declaration,
            doctype: nil,
            root: root,
            prologue: [],
            epilogue: []
        )
    }

    public static func fragment(
        _ string: String,
        maxDepth: Int = 10000
    ) throws(Parse.Error) -> Element {
        var input = Byte.Input(Swift.Array(string.utf8))
        Parse.Whitespace<Byte.Input>().parse(&input)

        let machineParser =
            Parse.machineElement(maxDepth: maxDepth)
            as Parser_Primitives.Parser.Machine.Parser<Byte.Input, Element, Parse.Error>
        return try machineParser.parse(&input)
    }
}

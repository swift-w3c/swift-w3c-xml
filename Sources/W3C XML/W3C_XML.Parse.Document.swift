public import Machine
import ASCII
import Byte
import Byte
import Cursor
import Cursor
public import Cursor
import Parser_Machine
import Parser

extension W3C_XML.Parse {

    public struct XMLDeclaration<Input: Cursor.`Protocol`>: Parser::Parsing, Sendable
    where Input: Sendable, Input.Element == Byte, Input.Failure == Never {
        public var body: Never {
            borrowing get {
                return fatalError("\(Self.self) is a leaf: implement its conformance requirements directly")
            }
        }

        public typealias Output = W3C_XML.Declaration
        public typealias Failure = W3C_XML.Parse.Error

        @inlinable
        public init() {}

        @inlinable
        public func parse(_ input: inout Input) throws(Failure) -> Output {

            try expectLiteral(&input, "<?xml")

            guard let ws = input.xmlPeek(), W3C_XML.isWhitespace(ws) else {
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
            guard let quote = input.xmlPeek(),
                quote == ASCII.Code.quotationMark.byte || quote == ASCII.Code.apostrophe.byte
            else {
                throw .expected("\" or '")
            }
            _ = input.next()

            var bytes: [Byte] = []
            while let byte = input.xmlPeek(), byte != quote {
                bytes.append(try input.xmlTake(expected: "character"))
            }

            guard input.xmlPeek() == quote else {
                throw .unexpectedEndOfInput(expected: String(UnicodeScalar(quote.bitPattern)))
            }
            _ = input.next()

            return String(decoding: bytes, as: UTF8.self)
        }

        @inlinable
        package func matchLiteral(_ input: inout Input, _ string: StaticString) -> Bool {
            let bytes = string.withUTF8Buffer { unsafe Swift.Array($0) }

            let saved = input.checkpoint
            for expected in bytes {
                guard let actual = input.xmlPeek(), actual.underlying == expected else {
                    input.seek(to: saved)
                    return false
                }
                _ = input.next()
            }
            return true
        }
    }
}

extension W3C_XML.Parse {

    public struct Doctype<Input: Cursor.`Protocol`>: Parser::Parsing, Sendable
    where Input: Sendable, Input.Element == Byte, Input.Failure == Never {
        public var body: Never {
            borrowing get {
                return fatalError("\(Self.self) is a leaf: implement its conformance requirements directly")
            }
        }

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

            if input.xmlPeek() == ASCII.Code.leftBracket.byte {
                _ = input.next()
                var bytes: [Byte] = []
                var depth = 1

                while depth > 0 {
                    guard let byte = input.xmlPeek() else {
                        throw .unexpectedEndOfInput(expected: "]")
                    }
                    if byte == ASCII.Code.leftBracket.byte {
                        depth += 1
                    } else if byte == ASCII.Code.rightBracket.byte {
                        depth -= 1
                        if depth == 0 {
                            _ = input.next()
                            break
                        }
                    }
                    bytes.append(try input.xmlTake(expected: "character"))
                }
                internalSubset = String(decoding: bytes, as: UTF8.self)
            }

            Whitespace<Input>().parse(&input)

            guard input.xmlPeek() == ASCII.Code.greaterThanSign.byte else {
                throw .expected(">")
            }
            _ = input.next()

            return W3C_XML.Doctype(
                name: name.qualified,
                publicID: publicID,
                systemID: systemID,
                internalSubset: internalSubset
            )
        }

        @inlinable
        package func parseQuotedValue(_ input: inout Input) throws(Failure) -> String {
            guard let quote = input.xmlPeek(),
                quote == ASCII.Code.quotationMark.byte || quote == ASCII.Code.apostrophe.byte
            else {
                throw .expected("\" or '")
            }
            _ = input.next()

            var bytes: [Byte] = []
            while let byte = input.xmlPeek(), byte != quote {
                bytes.append(try input.xmlTake(expected: "character"))
            }

            guard input.xmlPeek() == quote else {
                throw .unexpectedEndOfInput(expected: String(UnicodeScalar(quote.bitPattern)))
            }
            _ = input.next()

            return String(decoding: bytes, as: UTF8.self)
        }

        @inlinable
        package func matchLiteral(_ input: inout Input, _ string: StaticString) -> Bool {
            let bytes = string.withUTF8Buffer { unsafe Swift.Array($0) }

            let saved = input.checkpoint
            for expected in bytes {
                guard let actual = input.xmlPeek(), actual.underlying == expected else {
                    input.seek(to: saved)
                    return false
                }
                _ = input.next()
            }
            return true
        }
    }
}

extension W3C_XML.Parse {

    public struct Document<Input: Cursor.`Protocol`>: Parser::Parsing, Sendable
    where Input: Sendable, Input.Element == Byte, Input.Failure == Never {
        public var body: Never {
            borrowing get {
                return fatalError("\(Self.self) is a leaf: implement its conformance requirements directly")
            }
        }

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

            while let byte = input.xmlPeek() {
                if byte == ASCII.Code.lessThanSign.byte {
                    let saved = input.checkpoint
                    _ = input.next()

                    guard let next = input.xmlPeek() else {
                        input.seek(to: saved)
                        throw .unexpectedEndOfInput(expected: "element")
                    }

                    if next == ASCII.Code.questionMark.byte {

                        input.seek(to: saved)

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

                        _ = input.next()
                        guard let third = input.xmlPeek() else {
                            input.seek(to: saved)
                            throw .unexpectedEndOfInput(expected: "comment or DOCTYPE")
                        }

                        if third == ASCII.Code.hyphen.byte {

                            input.seek(to: saved)
                            let text = try Comment<Input>().parse(&input)
                            if root != nil {
                                epilogue.append(.comment(text))
                            }

                        } else if third == ASCII.Code.D.byte {

                            input.seek(to: saved)
                            doctype = try Doctype<Input>().parse(&input)
                        } else {
                            input.seek(to: saved)
                            throw .expected("comment or DOCTYPE")
                        }
                    } else {

                        input.seek(to: saved)
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
            let saved = input.checkpoint

            let pattern: [Byte] = [
                ASCII.Code.lessThanSign.byte,
                ASCII.Code.questionMark.byte,
                ASCII.Code.x.byte, ASCII.Code.m.byte, ASCII.Code.l.byte,
            ]

            for expected in pattern {
                guard let actual = input.xmlPeek(), actual == expected else {
                    input.seek(to: saved)
                    return false
                }
                _ = input.next()
            }

            let result = input.xmlPeek().map { W3C_XML.isWhitespace($0) } ?? false
            input.seek(to: saved)
            return result
        }
    }
}

extension W3C_XML {

    public static func parse(
        _ string: String,
        maxDepth: Int = 10000
    ) throws(Parse.Error) -> Document {
        var input = [Byte](utf8: String(string))[...]

        Parse.Whitespace<ArraySlice<Byte>>().parse(&input)

        var declaration: Declaration?
        if let byte = input.xmlPeek(), byte == ASCII.Code.lessThanSign.byte {
            let saved = input.checkpoint
            _ = input.next()
            if let next = input.xmlPeek(), next == ASCII.Code.questionMark.byte {
                input.seek(to: saved)
                do {
                    declaration = try Parse.XMLDeclaration<ArraySlice<Byte>>().parse(&input)
                } catch {

                    input.seek(to: saved)
                }
            } else {
                input.seek(to: saved)
            }
        }

        var prologue: [Instruction] = []
        while true {
            Parse.Whitespace<ArraySlice<Byte>>().parse(&input)
            guard let byte = input.xmlPeek(), byte == ASCII.Code.lessThanSign.byte else { break }

            let saved = input.checkpoint
            _ = input.next()
            guard let next = input.xmlPeek() else {
                input.seek(to: saved)
                break
            }

            if next == ASCII.Code.questionMark.byte {

                input.seek(to: saved)
                do {
                    let pi = try Parse.ProcessingInstruction<ArraySlice<Byte>>().parse(&input)
                    prologue.append(pi)
                    continue
                } catch {
                    input.seek(to: saved)
                    break
                }
            } else if next == ASCII.Code.exclamationPoint.byte {

                input.seek(to: saved)

                do {
                    _ = try Parse.Comment<ArraySlice<Byte>>().parse(&input)
                    continue
                } catch {
                    input.seek(to: saved)
                    break
                }
            } else {

                input.seek(to: saved)
                break
            }
        }

        let machineParser =
            Parse.machineElement(maxDepth: maxDepth)
            as Machine::Machine.Parser.Parser<ArraySlice<Byte>, Element, Parse.Error>
        let root = try machineParser.parse(&input)

        var epilogue: [Content] = []
        while true {
            Parse.Whitespace<ArraySlice<Byte>>().parse(&input)
            guard let byte = input.xmlPeek(), byte == ASCII.Code.lessThanSign.byte else { break }

            let saved = input.checkpoint
            _ = input.next()
            guard let next = input.xmlPeek() else {
                input.seek(to: saved)
                break
            }

            if next == ASCII.Code.questionMark.byte {

                input.seek(to: saved)
                do {
                    let pi = try Parse.ProcessingInstruction<ArraySlice<Byte>>().parse(&input)
                    epilogue.append(.instruction(pi))
                    continue
                } catch {
                    input.seek(to: saved)
                    break
                }
            } else if next == ASCII.Code.exclamationPoint.byte {

                input.seek(to: saved)
                do {
                    let comment = try Parse.Comment<ArraySlice<Byte>>().parse(&input)
                    epilogue.append(.comment(comment))
                    continue
                } catch {
                    input.seek(to: saved)
                    break
                }
            } else {

                input.seek(to: saved)
                throw Parse.Error.expected("end of input (multiple root elements not allowed)")
            }
        }

        Parse.Whitespace<ArraySlice<Byte>>().parse(&input)
        if !(input.xmlPeek() == nil) {
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
        var input = bytes.map(Byte.init(bitPattern:))[...]

        Parse.Whitespace<ArraySlice<Byte>>().parse(&input)

        var declaration: Declaration?
        if let byte = input.xmlPeek(), byte == ASCII.Code.lessThanSign.byte {
            let saved = input.checkpoint
            _ = input.next()
            if let next = input.xmlPeek(), next == ASCII.Code.questionMark.byte {
                input.seek(to: saved)
                do {
                    declaration = try Parse.XMLDeclaration<ArraySlice<Byte>>().parse(&input)
                } catch {

                    input.seek(to: saved)
                }
            } else {
                input.seek(to: saved)
            }
        }

        Parse.Whitespace<ArraySlice<Byte>>().parse(&input)

        let machineParser =
            Parse.machineElement(maxDepth: maxDepth)
            as Machine::Machine.Parser.Parser<ArraySlice<Byte>, Element, Parse.Error>
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
        var input = [Byte](utf8: String(string))[...]
        Parse.Whitespace<ArraySlice<Byte>>().parse(&input)

        let machineParser =
            Parse.machineElement(maxDepth: maxDepth)
            as Machine::Machine.Parser.Parser<ArraySlice<Byte>, Element, Parse.Error>
        return try machineParser.parse(&input)
    }
}

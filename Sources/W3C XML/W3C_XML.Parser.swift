public import Buffer_Linear_Primitive
public import Buffer_Linear_Primitives
public import Byte_Parser_Primitives
public import Input_Primitives
public import Ownership_Shared_Primitive
import Parser_Primitives

extension W3C_XML {

    public struct Parser<Input: Input_Primitives.Input.Streaming>: ~Copyable
    where Input.Element == Byte {

        @usableFromInline
        internal var lexer: Lexer<Input>

        @usableFromInline
        internal var depth: Int

        @usableFromInline
        internal let maxDepth: Int

        @usableFromInline
        internal var lookahead: Token?

        @inlinable
        public init(_ input: consuming Input, maxDepth: Int = 512) {
            self.lexer = Lexer(input)
            self.depth = 0
            self.maxDepth = maxDepth
            self.lookahead = nil
        }

        public var currentPosition: Position {
            lexer.currentPosition
        }
    }
}

extension W3C_XML.Parser {

    public typealias Error = __W3CXMLParserError
}

extension W3C_XML.Parser {

    @inlinable
    public mutating func parse() throws(Error) -> W3C_XML.Document {
        var declaration: W3C_XML.Declaration?
        var doctype: W3C_XML.Doctype?
        var prologue: [W3C_XML.Instruction] = []
        var root: W3C_XML.Element?
        var epilogue: [W3C_XML.Content] = []

        while let token = try nextToken() {
            switch token {
            case .xmlDeclaration(let decl):
                declaration = decl

            case .doctype(let dt):
                doctype = dt

            case .instruction(let pi):
                if root == nil {
                    prologue.append(pi)
                } else {
                    epilogue.append(.instruction(pi))
                }

            case .comment(let text):
                if root != nil {
                    epilogue.append(.comment(text))
                }

            case .text(let text):

                if !text.allSatisfy({ $0.isWhitespace }) {
                    throw .unexpectedToken(
                        found: .text,
                        expected: "element",
                        at: lexer.currentPosition
                    )
                }

            case .startTagOpen:
                if root != nil {
                    throw .multipleRootElements(at: lexer.currentPosition)
                }
                pushBack(token)
                root = try parseElement()

            default:
                throw .unexpectedToken(
                    found: token.kind,
                    expected: "XML declaration, DOCTYPE, or element",
                    at: lexer.currentPosition
                )
            }
        }

        guard let rootElement = root else {
            throw .missingRootElement(at: lexer.currentPosition)
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
    public mutating func parseFragment() throws(Error) -> W3C_XML.Element {

        while let token = try nextToken() {
            switch token {
            case .text(let text) where text.allSatisfy({ $0.isWhitespace }):
                continue

            case .startTagOpen:
                pushBack(token)
                return try parseElement()

            default:
                throw .unexpectedToken(
                    found: token.kind,
                    expected: "element",
                    at: lexer.currentPosition
                )
            }
        }

        throw .missingRootElement(at: lexer.currentPosition)
    }
}

extension W3C_XML.Parser {

    @inlinable
    package mutating func nextToken() throws(Error) -> W3C_XML.Token? {
        if let token = lookahead {
            lookahead = nil
            return token
        }
        do throws(__W3CXMLLexerError) {
            return try lexer.next()
        } catch {
            throw .lexer(error)
        }
    }

    @inlinable
    package mutating func pushBack(_ token: W3C_XML.Token) {
        precondition(lookahead == nil, "Cannot push back when lookahead is set")
        lookahead = token
    }
}

extension W3C_XML.Parser {

    @inlinable
    package mutating func parseElement() throws(Error) -> W3C_XML.Element {

        depth += 1
        if depth > maxDepth {
            throw .depthExceeded(limit: maxDepth, at: lexer.currentPosition)
        }
        defer { depth -= 1 }

        guard let startToken = try nextToken(),
            case .startTagOpen(let name) = startToken
        else {
            throw .unexpectedEndOfInput(expected: "start tag", at: lexer.currentPosition)
        }

        var attributes: [W3C_XML.Attribute] = []
        var namespaces: [W3C_XML.Namespace] = []
        var seenAttributes: Swift.Set<String> = Swift.Set()

        var isEmpty = false

        parseAttributes: while let token = try nextToken() {
            switch token {
            case .attributeName(let attrName):

                if attrName.qualified == "xmlns" {

                    guard let eqToken = try nextToken(), case .equals = eqToken else {
                        throw .unexpectedToken(
                            found: .attributeName,
                            expected: "'='",
                            at: lexer.currentPosition
                        )
                    }
                    guard let valToken = try nextToken(), case .attributeValue(let uri) = valToken
                    else {
                        throw .unexpectedToken(
                            found: .equals,
                            expected: "attribute value",
                            at: lexer.currentPosition
                        )
                    }
                    namespaces.append(W3C_XML.Namespace(prefix: nil, uri: uri))
                } else if attrName.prefix == "xmlns" {

                    guard let eqToken = try nextToken(), case .equals = eqToken else {
                        throw .unexpectedToken(
                            found: .attributeName,
                            expected: "'='",
                            at: lexer.currentPosition
                        )
                    }
                    guard let valToken = try nextToken(), case .attributeValue(let uri) = valToken
                    else {
                        throw .unexpectedToken(
                            found: .equals,
                            expected: "attribute value",
                            at: lexer.currentPosition
                        )
                    }
                    namespaces.append(W3C_XML.Namespace(prefix: attrName.local, uri: uri))
                } else {

                    let fullName = attrName.qualified
                    if seenAttributes.contains(fullName) {
                        throw .duplicateAttribute(name: fullName, at: lexer.currentPosition)
                    }
                    seenAttributes.insert(fullName)

                    guard let eqToken = try nextToken(), case .equals = eqToken else {
                        throw .unexpectedToken(
                            found: .attributeName,
                            expected: "'='",
                            at: lexer.currentPosition
                        )
                    }
                    guard let valToken = try nextToken(), case .attributeValue(let value) = valToken
                    else {
                        throw .unexpectedToken(
                            found: .equals,
                            expected: "attribute value",
                            at: lexer.currentPosition
                        )
                    }
                    attributes.append(W3C_XML.Attribute(name: attrName, value: value))
                }

            case .tagClose:
                break parseAttributes

            case .emptyTagClose:
                isEmpty = true
                break parseAttributes

            default:
                throw .unexpectedToken(
                    found: token.kind,
                    expected: "attribute, '>', or '/>'",
                    at: lexer.currentPosition
                )
            }
        }

        if isEmpty {
            return W3C_XML.Element(
                name: name,
                attributes: attributes,
                content: [],
                namespaces: namespaces
            )
        }

        let content = try parseContent(endTag: name.qualified)

        return W3C_XML.Element(
            name: name,
            attributes: attributes,
            content: content,
            namespaces: namespaces
        )
    }

    @inlinable
    package mutating func parseContent(endTag: String) throws(Error) -> [W3C_XML.Content] {
        var content: [W3C_XML.Content] = []

        while let token = try nextToken() {
            switch token {
            case .text(let text):

                if let last = content.last, case .text(let prevText) = last {
                    content.removeLast()
                    content.append(.text(prevText + text))
                } else {
                    content.append(.text(text))
                }

            case .cdata(let text):
                content.append(.cdata(text))

            case .comment(let text):
                content.append(.comment(text))

            case .instruction(let pi):
                content.append(.instruction(pi))

            case .startTagOpen:
                pushBack(token)
                let child = try parseElement()
                content.append(.element(child))

            case .endTagOpen(let closeName):

                guard let closeToken = try nextToken(), case .tagClose = closeToken else {
                    throw .unexpectedEndOfInput(expected: "'>'", at: lexer.currentPosition)
                }

                guard closeName.qualified == endTag else {
                    throw .mismatchedTags(
                        open: endTag,
                        close: closeName.qualified,
                        at: lexer.currentPosition
                    )
                }

                return content

            default:
                throw .unexpectedToken(
                    found: token.kind,
                    expected: "content or end tag",
                    at: lexer.currentPosition
                )
            }
        }

        throw .unexpectedEndOfInput(expected: "end tag '</\(endTag)>'", at: lexer.currentPosition)
    }
}

extension W3C_XML {

    @inlinable
    public static func fragment(_ string: String) throws(Parser<Byte.Input>.Error) -> Element {
        let input = Byte.Input(Swift.Array(string.utf8))
        var parser = Parser(consume input)
        return try parser.parseFragment()
    }

}

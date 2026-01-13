/// W3C_XML.Token.swift
/// swift-w3c-xml
///
/// Lexer token types for XML parsing

extension W3C_XML {
    /// Tokens produced by the XML lexer.
    ///
    /// These represent the atomic units of XML syntax. The lexer produces
    /// a stream of these tokens for the parser to consume.
    public enum Token: Sendable, Hashable {
        // MARK: - Tags

        /// Start tag opening: `<name`
        case startTagOpen(Name)

        /// End tag opening: `</name`
        case endTagOpen(Name)

        /// Tag close: `>`
        case tagClose

        /// Empty element tag close: `/>`
        case emptyTagClose

        // MARK: - Attributes

        /// Attribute name
        case attributeName(Name)

        /// Attribute value (after `=`)
        case attributeValue(String)

        /// Equals sign in attribute: `=`
        case equals

        // MARK: - Content

        /// Text content (character data)
        case text(String)

        /// CDATA section content
        case cdata(String)

        /// Comment content
        case comment(String)

        // MARK: - Processing Instructions

        /// Processing instruction: `<?target data?>`
        case instruction(Instruction)

        // MARK: - Declarations

        /// XML declaration: `<?xml ...?>`
        case xmlDeclaration(Declaration)

        /// DOCTYPE declaration
        case doctype(Doctype)
    }
}

// MARK: - Token Kind (for error messages)

extension W3C_XML {
    /// Token kind for error messages.
    ///
    /// Simplified representation used in error reporting.
    public enum TokenKind: Sendable, Hashable {
        case startTag
        case endTag
        case tagClose
        case emptyTagClose
        case attributeName
        case attributeValue
        case equals
        case text
        case cdata
        case comment
        case instruction
        case xmlDeclaration
        case doctype
        case unknown(UInt8)
    }
}

extension W3C_XML.TokenKind: CustomStringConvertible {
    public var description: String {
        switch self {
        case .startTag: return "start tag"
        case .endTag: return "end tag"
        case .tagClose: return "'>'"
        case .emptyTagClose: return "'/>'"
        case .attributeName: return "attribute name"
        case .attributeValue: return "attribute value"
        case .equals: return "'='"
        case .text: return "text"
        case .cdata: return "CDATA section"
        case .comment: return "comment"
        case .instruction: return "processing instruction"
        case .xmlDeclaration: return "XML declaration"
        case .doctype: return "DOCTYPE"
        case .unknown(let byte): return "0x\(String(byte, radix: 16))"
        }
    }
}

// MARK: - Token to TokenKind

extension W3C_XML.Token {
    /// Converts this token to a TokenKind for error reporting.
    public var kind: W3C_XML.TokenKind {
        switch self {
        case .startTagOpen: return .startTag
        case .endTagOpen: return .endTag
        case .tagClose: return .tagClose
        case .emptyTagClose: return .emptyTagClose
        case .attributeName: return .attributeName
        case .attributeValue: return .attributeValue
        case .equals: return .equals
        case .text: return .text
        case .cdata: return .cdata
        case .comment: return .comment
        case .instruction: return .instruction
        case .xmlDeclaration: return .xmlDeclaration
        case .doctype: return .doctype
        }
    }
}

// MARK: - Token CustomStringConvertible

extension W3C_XML.Token: CustomStringConvertible {
    public var description: String {
        switch self {
        case .startTagOpen(let name):
            return "<\(name.qualified)"
        case .endTagOpen(let name):
            return "</\(name.qualified)"
        case .tagClose:
            return ">"
        case .emptyTagClose:
            return "/>"
        case .attributeName(let name):
            return name.qualified
        case .attributeValue(let value):
            return "\"\(value)\""
        case .equals:
            return "="
        case .text(let text):
            return text
        case .cdata(let text):
            return "<![CDATA[\(text)]]>"
        case .comment(let text):
            return "<!--\(text)-->"
        case .instruction(let pi):
            return pi.description
        case .xmlDeclaration(let decl):
            return decl.description
        case .doctype(let dt):
            return dt.description
        }
    }
}

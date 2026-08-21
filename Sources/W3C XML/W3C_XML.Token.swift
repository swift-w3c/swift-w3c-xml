extension W3C_XML {

    public enum Token: Sendable, Hashable {

        case startTagOpen(Name)

        case endTagOpen(Name)

        case tagClose

        case emptyTagClose

        case attributeName(Name)

        case attributeValue(String)

        case equals

        case text(String)

        case cdata(String)

        case comment(String)

        case instruction(Instruction)

        case xmlDeclaration(Declaration)

        case doctype(Doctype)
    }
}

extension W3C_XML {

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
        case unknown(Byte)
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

extension W3C_XML.Token {

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

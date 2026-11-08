
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

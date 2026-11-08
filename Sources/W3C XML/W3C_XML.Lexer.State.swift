import Cursor
import Parser


extension W3C_XML.Lexer {
    @usableFromInline
    internal enum State {

        case content

        case inStartTag

        case inEndTag
    }
}

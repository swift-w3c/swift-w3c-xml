import Byte
import Cursor
import Parser


extension W3C_XML.Parse {
    public enum Error: Swift::Error, Sendable, Hashable {

        case depthExceeded(limit: Int)

        case expected(String)

        case mismatchedTags(open: String, close: String)

        case invalidName

        case invalidCharacterReference(String)

        case unknownEntity(String)

        case unexpectedEndOfInput(expected: String)

        case duplicateAttribute(name: String)

        case multipleRootElements

        case missingRootElement
    }
}

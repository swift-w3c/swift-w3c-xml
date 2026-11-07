public import Cursor
import Machine
import Parser
import Parser_Machine


extension W3C_XML.Parse {
    @usableFromInline
    struct NonEmptyElementParts: Sendable {
        @usableFromInline let start: StartTagOutput
        @usableFromInline let content: [W3C_XML.Content]
        @usableFromInline let endName: W3C_XML.Name

        @usableFromInline
        init(start: StartTagOutput, content: [W3C_XML.Content], endName: W3C_XML.Name) {
            self.start = start
            self.content = content
            self.endName = endName
        }
    }
}

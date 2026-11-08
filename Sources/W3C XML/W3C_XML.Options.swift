
extension W3C_XML {
    public struct Options: Sendable {

        public var prettyPrint: Bool

        public var indent: String

        public var includeDeclaration: Bool

        public var escapeApostrophe: Bool

        public init(
            prettyPrint: Bool = false,
            indent: String = "  ",
            includeDeclaration: Bool = true,
            escapeApostrophe: Bool = false
        ) {
            self.prettyPrint = prettyPrint
            self.indent = indent
            self.includeDeclaration = includeDeclaration
            self.escapeApostrophe = escapeApostrophe
        }
    }
}

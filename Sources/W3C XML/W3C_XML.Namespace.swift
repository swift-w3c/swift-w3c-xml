extension W3C_XML {

    public struct Namespace: Sendable, Hashable {

        public var prefix: String?

        // swift-linter:disable:next raw concept
        // REASON: A namespace name, an attribute value the parser keeps as written and compares as text, with no promise that it resolves; XML 1.1 lets it be an IRI; looked at RFC_3986.URI, which refuses non-ASCII, and swift-rfc-3986 isn't among this package's tight dependencies.
        public var uri: String

        @inlinable
        // swift-linter:disable:next raw concept
        // REASON: A namespace name, an attribute value the parser keeps as written and compares as text, with no promise that it resolves; XML 1.1 lets it be an IRI; looked at RFC_3986.URI, which refuses non-ASCII, and swift-rfc-3986 isn't among this package's tight dependencies.
        public init(prefix: String? = nil, uri: String) {
            self.prefix = prefix
            self.uri = uri
        }
    }
}

extension W3C_XML.Namespace {

    public static let xml = W3C_XML.Namespace(
        prefix: "xml",
        uri: "http://www.w3.org/XML/1998/namespace"
    )

    public static let xmlns = W3C_XML.Namespace(
        prefix: "xmlns",
        uri: "http://www.w3.org/2000/xmlns/"
    )
}

extension W3C_XML.Namespace: CustomStringConvertible {
    public var description: String {
        if let prefix {
            return "xmlns:\(prefix)=\"\(uri)\""
        }
        return "xmlns=\"\(uri)\""
    }
}

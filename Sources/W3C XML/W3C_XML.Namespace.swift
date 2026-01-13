/// W3C_XML.Namespace.swift
/// swift-w3c-xml
///
/// XML Namespace declarations

extension W3C_XML {
    /// A namespace declaration.
    ///
    /// Namespace declarations appear as `xmlns` or `xmlns:prefix` attributes
    /// on elements. They bind a prefix (or the default namespace) to a URI.
    ///
    /// ## Example
    ///
    /// ```swift
    /// // Default namespace declaration
    /// let ns = W3C_XML.Namespace(uri: "http://www.w3.org/1999/xhtml")
    /// // Represents: xmlns="http://www.w3.org/1999/xhtml"
    ///
    /// // Prefixed namespace declaration
    /// let atomNS = W3C_XML.Namespace(prefix: "atom", uri: "http://www.w3.org/2005/Atom")
    /// // Represents: xmlns:atom="http://www.w3.org/2005/Atom"
    /// ```
    ///
    /// ## Reference
    ///
    /// - Namespaces in XML 1.0: https://www.w3.org/TR/xml-names/
    public struct Namespace: Sendable, Hashable {
        /// Namespace prefix (nil for default namespace).
        ///
        /// When `nil`, this is a default namespace declaration (`xmlns="..."`).
        /// When set, this is a prefixed declaration (`xmlns:prefix="..."`).
        public var prefix: String?

        /// Namespace URI.
        ///
        /// The URI that identifies the namespace. Per W3C XML Namespaces,
        /// this is used for namespace comparison, not resolution.
        public var uri: String

        /// Creates a namespace declaration.
        ///
        /// - Parameters:
        ///   - prefix: Optional prefix (nil for default namespace).
        ///   - uri: The namespace URI.
        @inlinable
        public init(prefix: String? = nil, uri: String) {
            self.prefix = prefix
            self.uri = uri
        }
    }
}

// MARK: - Well-Known Namespaces

extension W3C_XML.Namespace {
    /// The XML namespace URI (bound to "xml" prefix).
    ///
    /// Per XML Namespaces specification, this prefix is always bound.
    public static let xml = W3C_XML.Namespace(
        prefix: "xml",
        uri: "http://www.w3.org/XML/1998/namespace"
    )

    /// The XML Namespaces namespace URI (bound to "xmlns" prefix).
    ///
    /// Per XML Namespaces specification, this prefix is always bound.
    public static let xmlns = W3C_XML.Namespace(
        prefix: "xmlns",
        uri: "http://www.w3.org/2000/xmlns/"
    )
}

// MARK: - Namespace CustomStringConvertible

extension W3C_XML.Namespace: CustomStringConvertible {
    public var description: String {
        if let prefix = prefix {
            return "xmlns:\(prefix)=\"\(uri)\""
        }
        return "xmlns=\"\(uri)\""
    }
}

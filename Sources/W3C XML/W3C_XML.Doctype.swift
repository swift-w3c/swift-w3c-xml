/// W3C_XML.Doctype.swift
/// swift-w3c-xml
///
/// XML Document Type Declaration

extension W3C_XML {
    /// Document type declaration.
    ///
    /// Per W3C XML 1.0 Production [28]:
    /// ```
    /// doctypedecl ::= '<!DOCTYPE' S Name (S ExternalID)? S? ('[' intSubset ']' S?)? '>'
    /// ```
    ///
    /// The DOCTYPE declaration identifies the document type and may include
    /// references to external DTD files.
    ///
    /// ## Example
    ///
    /// ```swift
    /// // Simple DOCTYPE
    /// let doctype = W3C_XML.Doctype(name: "html")
    /// // Represents: <!DOCTYPE html>
    ///
    /// // DOCTYPE with public identifier
    /// let xhtml = W3C_XML.Doctype(
    ///     name: "html",
    ///     publicID: "-//W3C//DTD XHTML 1.0 Strict//EN",
    ///     systemID: "http://www.w3.org/TR/xhtml1/DTD/xhtml1-strict.dtd"
    /// )
    /// // Represents: <!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Strict//EN"
    /// //             "http://www.w3.org/TR/xhtml1/DTD/xhtml1-strict.dtd">
    /// ```
    ///
    /// ## Note
    ///
    /// This implementation parses and preserves DOCTYPE declarations but does
    /// not process DTD content. External DTDs are not fetched (security).
    public struct Doctype: Sendable, Hashable {
        /// Root element name.
        public var name: String

        /// Public identifier (for PUBLIC external ID).
        public var publicID: String?

        /// System identifier (URI for external DTD).
        public var systemID: String?

        /// Internal subset content (preserved as string).
        ///
        /// The internal subset contains entity and element declarations
        /// between `[` and `]` in the DOCTYPE. This implementation preserves
        /// the raw content without parsing.
        public var internalSubset: String?

        /// Creates a DOCTYPE declaration.
        ///
        /// - Parameters:
        ///   - name: The root element name.
        ///   - publicID: Optional public identifier.
        ///   - systemID: Optional system identifier.
        ///   - internalSubset: Optional internal subset content.
        @inlinable
        public init(
            name: String,
            publicID: String? = nil,
            systemID: String? = nil,
            internalSubset: String? = nil
        ) {
            self.name = name
            self.publicID = publicID
            self.systemID = systemID
            self.internalSubset = internalSubset
        }
    }
}

// MARK: - Doctype CustomStringConvertible

extension W3C_XML.Doctype: CustomStringConvertible {
    public var description: String {
        var result = "<!DOCTYPE \(name)"

        if let publicID = publicID, let systemID = systemID {
            result += " PUBLIC \"\(publicID)\" \"\(systemID)\""
        } else if let systemID = systemID {
            result += " SYSTEM \"\(systemID)\""
        }

        if let internalSubset = internalSubset {
            result += " [\(internalSubset)]"
        }

        result += ">"
        return result
    }
}

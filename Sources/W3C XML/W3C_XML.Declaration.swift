/// W3C_XML.Declaration.swift
/// swift-w3c-xml
///
/// XML Declaration type

extension W3C_XML {
    /// XML declaration.
    ///
    /// Per W3C XML 1.0 Production [23]:
    /// ```
    /// XMLDecl ::= '<?xml' VersionInfo EncodingDecl? SDDecl? S? '?>'
    /// ```
    ///
    /// The XML declaration appears at the very beginning of an XML document
    /// and specifies the XML version, optional encoding, and standalone status.
    ///
    /// ## Example
    ///
    /// ```swift
    /// // Standard declaration
    /// let decl = W3C_XML.Declaration(version: .v1_0, encoding: "UTF-8")
    /// // Represents: <?xml version="1.0" encoding="UTF-8"?>
    ///
    /// // With standalone attribute
    /// let standalone = W3C_XML.Declaration(
    ///     version: .v1_0,
    ///     encoding: "UTF-8",
    ///     standalone: true
    /// )
    /// // Represents: <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
    /// ```
    public struct Declaration: Sendable, Hashable {
        /// XML version.
        public var version: Version

        /// Character encoding (e.g., "UTF-8", "ISO-8859-1").
        ///
        /// Optional per the spec. When absent, UTF-8 or UTF-16 is assumed
        /// based on the byte-order mark.
        public var encoding: String?

        /// Standalone document declaration.
        ///
        /// - `true`: Document has no external markup declarations
        /// - `false`: Document may have external markup declarations
        /// - `nil`: Not specified
        public var standalone: Bool?

        /// Creates an XML declaration.
        ///
        /// - Parameters:
        ///   - version: The XML version.
        ///   - encoding: Optional encoding name.
        ///   - standalone: Optional standalone flag.
        @inlinable
        public init(
            version: Version = .v1_0,
            encoding: String? = nil,
            standalone: Bool? = nil
        ) {
            self.version = version
            self.encoding = encoding
            self.standalone = standalone
        }
    }
}

// MARK: - Declaration.Version

extension W3C_XML.Declaration {
    /// XML version.
    public enum Version: String, Sendable, Hashable {
        /// XML 1.0
        case v1_0 = "1.0"

        /// XML 1.1
        case v1_1 = "1.1"
    }
}

// MARK: - Declaration CustomStringConvertible

extension W3C_XML.Declaration: CustomStringConvertible {
    public var description: String {
        var result = "<?xml version=\"\(version.rawValue)\""

        if let encoding = encoding {
            result += " encoding=\"\(encoding)\""
        }

        if let standalone = standalone {
            result += " standalone=\"\(standalone ? "yes" : "no")\""
        }

        result += "?>"
        return result
    }
}

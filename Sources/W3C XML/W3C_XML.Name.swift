/// W3C_XML.Name.swift
/// swift-w3c-xml
///
/// XML Name types (NCName, QName)

extension W3C_XML {
    /// An XML name (NCName or QName).
    ///
    /// XML names follow the grammar in W3C XML 1.0 Production [5]:
    /// ```
    /// Name ::= NameStartChar (NameChar)*
    /// ```
    ///
    /// For qualified names with namespaces (QName), the format is `prefix:local`.
    /// Names without a prefix (NCName) have `prefix` as `nil`.
    ///
    /// ## Example
    ///
    /// ```swift
    /// // Unprefixed name
    /// let name = W3C_XML.Name(local: "item")
    /// print(name.qualified)  // "item"
    ///
    /// // Qualified name with prefix
    /// let qname = W3C_XML.Name(local: "link", prefix: "atom")
    /// print(qname.qualified)  // "atom:link"
    /// ```
    public struct Name: Sendable, Hashable {
        /// Local part of the name.
        ///
        /// For unprefixed names, this is the entire name.
        /// For qualified names, this is the part after the colon.
        public var local: String

        /// Namespace prefix (nil for unprefixed names).
        ///
        /// When present, the full qualified name is `prefix:local`.
        public var prefix: String?

        /// Creates a name from local and optional prefix parts.
        ///
        /// - Parameters:
        ///   - local: The local part of the name.
        ///   - prefix: Optional namespace prefix.
        @inlinable
        public init(local: String, prefix: String? = nil) {
            self.local = local
            self.prefix = prefix
        }
    }
}

// MARK: - Name Qualified

extension W3C_XML.Name {
    /// Full qualified name as string.
    ///
    /// Returns `prefix:local` if prefix exists, otherwise just `local`.
    @inlinable
    public var qualified: String {
        if let prefix = prefix {
            return "\(prefix):\(local)"
        }
        return local
    }
}

// MARK: - Name Parsing

extension W3C_XML.Name {
    /// Creates a Name by parsing a qualified name string.
    ///
    /// Splits on the first colon to separate prefix and local parts.
    /// Names without colons have `prefix` as `nil`.
    ///
    /// - Parameter qualified: The qualified name string to parse.
    @inlinable
    public init(_ qualified: String) {
        if let colonIndex = qualified.firstIndex(of: ":") {
            self.prefix = String(qualified[..<colonIndex])
            self.local = String(qualified[qualified.index(after: colonIndex)...])
        } else {
            self.prefix = nil
            self.local = qualified
        }
    }
}

// MARK: - Name CustomStringConvertible

extension W3C_XML.Name: CustomStringConvertible {
    public var description: String {
        qualified
    }
}

// MARK: - Name ExpressibleByStringLiteral

extension W3C_XML.Name: ExpressibleByStringLiteral {
    @inlinable
    public init(stringLiteral value: String) {
        self.init(value)
    }
}

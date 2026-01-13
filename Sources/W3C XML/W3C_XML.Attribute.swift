/// W3C_XML.Attribute.swift
/// swift-w3c-xml
///
/// XML Attribute type

extension W3C_XML {
    /// An XML attribute.
    ///
    /// Attributes appear on elements as `name="value"` or `name='value'`.
    /// For namespaced attributes, the name includes a prefix.
    ///
    /// ## Example
    ///
    /// ```swift
    /// // Simple attribute
    /// let id = W3C_XML.Attribute(name: "id", value: "123")
    /// // Represents: id="123"
    ///
    /// // Namespaced attribute
    /// let lang = W3C_XML.Attribute(
    ///     name: W3C_XML.Name(local: "lang", prefix: "xml"),
    ///     value: "en"
    /// )
    /// // Represents: xml:lang="en"
    /// ```
    ///
    /// ## W3C XML 1.0 Reference
    ///
    /// Per Production [41]:
    /// ```
    /// Attribute ::= Name Eq AttValue
    /// ```
    public struct Attribute: Sendable, Hashable {
        /// Attribute name (may include namespace prefix).
        public var name: Name

        /// Attribute value.
        ///
        /// Entity references and character references in the original
        /// XML have been resolved to their text values.
        public var value: String

        /// Creates an attribute with the given name and value.
        ///
        /// - Parameters:
        ///   - name: The attribute name.
        ///   - value: The attribute value.
        @inlinable
        public init(name: Name, value: String) {
            self.name = name
            self.value = value
        }

        /// Creates an attribute with a string name and value.
        ///
        /// - Parameters:
        ///   - name: The attribute name as a string.
        ///   - value: The attribute value.
        @inlinable
        public init(name: String, value: String) {
            self.name = Name(name)
            self.value = value
        }
    }
}

// MARK: - Attribute CustomStringConvertible

extension W3C_XML.Attribute: CustomStringConvertible {
    public var description: String {
        // Escape special characters in value for display
        var escaped = ""
        escaped.reserveCapacity(value.count)
        for char in value {
            switch char {
            case "&": escaped.append("&amp;")
            case "\"": escaped.append("&quot;")
            case "<": escaped.append("&lt;")
            default: escaped.append(char)
            }
        }
        return "\(name.qualified)=\"\(escaped)\""
    }
}

/// W3C_XML.Instruction.swift
/// swift-w3c-xml
///
/// XML Processing Instruction type

extension W3C_XML {
    /// A processing instruction.
    ///
    /// Per W3C XML 1.0 Production [16]:
    /// ```
    /// PI ::= '<?' PITarget (S (Char* - (Char* '?>' Char*)))? '?>'
    /// ```
    ///
    /// Processing instructions provide a mechanism for applications to embed
    /// instructions in XML documents.
    ///
    /// ## Example
    ///
    /// ```swift
    /// // XML stylesheet processing instruction
    /// let stylesheet = W3C_XML.Instruction(
    ///     target: "xml-stylesheet",
    ///     data: "type=\"text/xsl\" href=\"style.xsl\""
    /// )
    /// // Represents: <?xml-stylesheet type="text/xsl" href="style.xsl"?>
    ///
    /// // PHP processing instruction
    /// let php = W3C_XML.Instruction(
    ///     target: "php",
    ///     data: "echo 'Hello';"
    /// )
    /// // Represents: <?php echo 'Hello';?>
    /// ```
    public struct Instruction: Sendable, Hashable {
        /// Target name (e.g., "xml-stylesheet", "php").
        ///
        /// Per the spec, target names starting with "xml" (case-insensitive)
        /// are reserved. The target "xml" itself is used for the XML declaration.
        public var target: String

        /// Instruction data.
        ///
        /// Everything after the target name and whitespace, up to the closing `?>`.
        /// May be nil if no data follows the target.
        public var data: String?

        /// Creates a processing instruction.
        ///
        /// - Parameters:
        ///   - target: The PI target name.
        ///   - data: Optional data following the target.
        @inlinable
        public init(target: String, data: String? = nil) {
            self.target = target
            self.data = data
        }
    }
}

// MARK: - Instruction CustomStringConvertible

extension W3C_XML.Instruction: CustomStringConvertible {
    public var description: String {
        if let data = data {
            return "<?\(target) \(data)?>"
        }
        return "<?\(target)?>"
    }
}

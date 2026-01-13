/// W3C_XML.Document.swift
/// swift-w3c-xml
///
/// XML Document type

extension W3C_XML {
    /// An XML document.
    ///
    /// Per W3C XML 1.0 Production [1]:
    /// ```
    /// document ::= prolog element Misc*
    /// ```
    ///
    /// A document consists of an optional XML declaration, optional DOCTYPE,
    /// a root element, and optional trailing content (comments, PIs).
    ///
    /// ## Example
    ///
    /// ```swift
    /// // Parse a document
    /// let doc = try W3C_XML.parse("""
    ///     <?xml version="1.0" encoding="UTF-8"?>
    ///     <root>
    ///         <item>First</item>
    ///         <item>Second</item>
    ///     </root>
    ///     """)
    ///
    /// print(doc.declaration?.version)  // Optional(.v1_0)
    /// print(doc.root.name.local)       // "root"
    /// print(doc.root.children.count)   // 2
    /// ```
    public struct Document: Sendable, Hashable {
        /// XML declaration (if present).
        ///
        /// Contains version, optional encoding, and standalone info.
        public var declaration: Declaration?

        /// Document type declaration (if present).
        public var doctype: Doctype?

        /// The root element.
        ///
        /// Every well-formed XML document has exactly one root element.
        public var root: Element

        /// Processing instructions before the root element.
        ///
        /// These appear in the prolog, after the XML declaration and DOCTYPE.
        public var prologue: [Instruction]

        /// Processing instructions and comments after the root element.
        ///
        /// Per the spec, only PIs and comments (whitespace) may appear here.
        public var epilogue: [Content]

        /// Creates a document with the given properties.
        ///
        /// - Parameters:
        ///   - declaration: Optional XML declaration.
        ///   - doctype: Optional DOCTYPE declaration.
        ///   - root: The root element.
        ///   - prologue: Processing instructions before root (default empty).
        ///   - epilogue: Content after root (default empty).
        @inlinable
        public init(
            declaration: Declaration? = nil,
            doctype: Doctype? = nil,
            root: Element,
            prologue: [Instruction] = [],
            epilogue: [Content] = []
        ) {
            self.declaration = declaration
            self.doctype = doctype
            self.root = root
            self.prologue = prologue
            self.epilogue = epilogue
        }
    }
}

// MARK: - Document CustomStringConvertible

extension W3C_XML.Document: CustomStringConvertible {
    public var description: String {
        var result = ""

        if let declaration = declaration {
            result += declaration.description
            result += "\n"
        }

        if let doctype = doctype {
            result += doctype.description
            result += "\n"
        }

        for instruction in prologue {
            result += instruction.description
            result += "\n"
        }

        result += root.description

        for item in epilogue {
            result += "\n"
            result += item.description
        }

        return result
    }
}

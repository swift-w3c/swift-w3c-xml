/// W3C_XML.Content.swift
/// swift-w3c-xml
///
/// XML Content types (element children)

extension W3C_XML {
    /// Content within an element.
    ///
    /// Per W3C XML 1.0 Production [43]:
    /// ```
    /// content ::= CharData? ((element | Reference | CDSect | PI | Comment) CharData?)*
    /// ```
    ///
    /// This enum represents the various types of content that can appear
    /// as children of an element.
    ///
    /// ## Example
    ///
    /// ```swift
    /// // Element content
    /// let content: W3C_XML.Content = .element(childElement)
    ///
    /// // Text content
    /// let text: W3C_XML.Content = .text("Hello, World!")
    ///
    /// // CDATA section
    /// let cdata: W3C_XML.Content = .cdata("<script>alert('hi')</script>")
    ///
    /// // Comment
    /// let comment: W3C_XML.Content = .comment("This is a comment")
    ///
    /// // Processing instruction
    /// let pi: W3C_XML.Content = .instruction(Instruction(target: "php", data: "echo 'hi';"))
    /// ```
    public enum Content: Sendable, Hashable {
        /// Child element.
        case element(Element)

        /// Text content (character data).
        ///
        /// Entity references have been resolved to their text values.
        case text(String)

        /// CDATA section.
        ///
        /// The text is preserved verbatim, without entity processing.
        /// In the original XML, this was enclosed in `<![CDATA[...]]>`.
        case cdata(String)

        /// Comment.
        ///
        /// Comments are preserved for round-trip fidelity.
        /// In the original XML, this was enclosed in `<!--...-->`.
        case comment(String)

        /// Processing instruction.
        case instruction(Instruction)
    }
}

// MARK: - Content Accessors

extension W3C_XML.Content {
    /// Returns the element if this is element content, nil otherwise.
    @inlinable
    public var element: W3C_XML.Element? {
        guard case .element(let e) = self else { return nil }
        return e
    }

    /// Returns the text if this is text content, nil otherwise.
    @inlinable
    public var text: String? {
        guard case .text(let t) = self else { return nil }
        return t
    }

    /// Returns the CDATA text if this is CDATA content, nil otherwise.
    @inlinable
    public var cdata: String? {
        guard case .cdata(let c) = self else { return nil }
        return c
    }

    /// Returns the comment if this is comment content, nil otherwise.
    @inlinable
    public var comment: String? {
        guard case .comment(let c) = self else { return nil }
        return c
    }

    /// Returns the instruction if this is instruction content, nil otherwise.
    @inlinable
    public var instruction: W3C_XML.Instruction? {
        guard case .instruction(let i) = self else { return nil }
        return i
    }
}

// MARK: - Content Type Checking

extension W3C_XML.Content {
    /// Returns true if this is element content.
    @inlinable
    public var isElement: Bool {
        if case .element = self { return true }
        return false
    }

    /// Returns true if this is text content.
    @inlinable
    public var isText: Bool {
        if case .text = self { return true }
        return false
    }

    /// Returns true if this is CDATA content.
    @inlinable
    public var isCDATA: Bool {
        if case .cdata = self { return true }
        return false
    }

    /// Returns true if this is comment content.
    @inlinable
    public var isComment: Bool {
        if case .comment = self { return true }
        return false
    }

    /// Returns true if this is processing instruction content.
    @inlinable
    public var isInstruction: Bool {
        if case .instruction = self { return true }
        return false
    }
}

// MARK: - Content CustomStringConvertible

extension W3C_XML.Content: CustomStringConvertible {
    public var description: String {
        switch self {
        case .element(let e):
            return e.description
        case .text(let t):
            return t
        case .cdata(let c):
            return "<![CDATA[\(c)]]>"
        case .comment(let c):
            return "<!--\(c)-->"
        case .instruction(let i):
            return i.description
        }
    }
}

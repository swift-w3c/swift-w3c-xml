/// W3C_XML.Element.swift
/// swift-w3c-xml
///
/// XML Element type

extension W3C_XML {
    /// An XML element.
    ///
    /// Per W3C XML 1.0 Production [39]:
    /// ```
    /// element ::= EmptyElemTag | STag content ETag
    /// ```
    ///
    /// An element has a name, optional attributes, namespace declarations,
    /// and content (child elements, text, CDATA, comments, or PIs).
    ///
    /// ## Example
    ///
    /// ```swift
    /// // Create an element
    /// let element = W3C_XML.Element(
    ///     name: "item",
    ///     attributes: [
    ///         W3C_XML.Attribute(name: "id", value: "123")
    ///     ],
    ///     content: [
    ///         .text("Hello, World!")
    ///     ]
    /// )
    ///
    /// // Access element properties
    /// print(element.name.local)  // "item"
    /// print(element.attributes.count)  // 1
    /// ```
    public struct Element: Sendable, Hashable {
        /// Element name (may include namespace prefix).
        public var name: Name

        /// Element attributes.
        ///
        /// Does not include namespace declarations (those are in `namespaces`).
        public var attributes: [Attribute]

        /// Element content (children).
        ///
        /// May contain elements, text, CDATA, comments, or processing instructions.
        public var content: [Content]

        /// Namespace declarations on this element.
        ///
        /// Declarations like `xmlns="..."` or `xmlns:prefix="..."`.
        public var namespaces: [Namespace]

        /// Creates an element with the given properties.
        ///
        /// - Parameters:
        ///   - name: The element name.
        ///   - attributes: Element attributes (default empty).
        ///   - content: Element content (default empty).
        ///   - namespaces: Namespace declarations (default empty).
        @inlinable
        public init(
            name: Name,
            attributes: [Attribute] = [],
            content: [Content] = [],
            namespaces: [Namespace] = []
        ) {
            self.name = name
            self.attributes = attributes
            self.content = content
            self.namespaces = namespaces
        }

        /// Creates an element with a string name.
        ///
        /// - Parameters:
        ///   - name: The element name as a string.
        ///   - attributes: Element attributes (default empty).
        ///   - content: Element content (default empty).
        ///   - namespaces: Namespace declarations (default empty).
        @inlinable
        public init(
            name: String,
            attributes: [Attribute] = [],
            content: [Content] = [],
            namespaces: [Namespace] = []
        ) {
            self.name = Name(name)
            self.attributes = attributes
            self.content = content
            self.namespaces = namespaces
        }
    }
}

// MARK: - Element Content Accessors

extension W3C_XML.Element {
    /// Child elements only.
    @inlinable
    public var children: [W3C_XML.Element] {
        content.compactMap { $0.element }
    }

    /// All text content concatenated.
    ///
    /// Includes both text and CDATA content, in document order.
    @inlinable
    public var textContent: String {
        content.reduce(into: "") { result, item in
            switch item {
            case .text(let t):
                result += t
            case .cdata(let c):
                result += c
            default:
                break
            }
        }
    }

    /// Returns the attribute value for the given name, or nil if not found.
    ///
    /// - Parameter name: The attribute name to look up.
    /// - Returns: The attribute value, or nil.
    @inlinable
    public func attribute(_ name: String) -> String? {
        attributes.first { $0.name.qualified == name }?.value
    }

    /// Returns the attribute value for the given name, or nil if not found.
    ///
    /// - Parameter name: The attribute name to look up.
    /// - Returns: The attribute value, or nil.
    @inlinable
    public func attribute(_ name: W3C_XML.Name) -> String? {
        attributes.first { $0.name == name }?.value
    }
}

// MARK: - Element Query

extension W3C_XML.Element {
    /// Finds the first child element with the given name.
    ///
    /// - Parameter name: The element name to find.
    /// - Returns: The first matching child element, or nil.
    @inlinable
    public func child(_ name: String) -> W3C_XML.Element? {
        children.first { $0.name.qualified == name || $0.name.local == name }
    }

    /// Finds all child elements with the given name.
    ///
    /// - Parameter name: The element name to find.
    /// - Returns: All matching child elements.
    @inlinable
    public func children(_ name: String) -> [W3C_XML.Element] {
        children.filter { $0.name.qualified == name || $0.name.local == name }
    }

    /// Finds the first descendant element with the given name (depth-first).
    ///
    /// - Parameter name: The element name to find.
    /// - Returns: The first matching descendant, or nil.
    @inlinable
    public func descendant(_ name: String) -> W3C_XML.Element? {
        for child in children {
            if child.name.qualified == name || child.name.local == name {
                return child
            }
            if let found = child.descendant(name) {
                return found
            }
        }
        return nil
    }

    /// Finds all descendant elements with the given name (depth-first).
    ///
    /// - Parameter name: The element name to find.
    /// - Returns: All matching descendants.
    @inlinable
    public func descendants(_ name: String) -> [W3C_XML.Element] {
        var result: [W3C_XML.Element] = []
        for child in children {
            if child.name.qualified == name || child.name.local == name {
                result.append(child)
            }
            result.append(contentsOf: child.descendants(name))
        }
        return result
    }
}

// MARK: - Element Subscripts

extension W3C_XML.Element {
    /// Accesses the first child element with the given name.
    ///
    /// - Parameter name: The element name to find.
    /// - Returns: The first matching child element, or nil.
    @inlinable
    public subscript(_ name: String) -> W3C_XML.Element? {
        child(name)
    }

    /// Accesses the child element at the given index.
    ///
    /// - Parameter index: The index of the child element.
    /// - Returns: The child element at the index, or nil if out of bounds.
    @inlinable
    public subscript(_ index: Int) -> W3C_XML.Element? {
        let children = self.children
        guard index >= 0 && index < children.count else { return nil }
        return children[index]
    }
}

// MARK: - Element CustomStringConvertible

extension W3C_XML.Element: CustomStringConvertible {
    public var description: String {
        var result = "<\(name.qualified)"

        for ns in namespaces {
            result += " \(ns)"
        }

        for attr in attributes {
            result += " \(attr)"
        }

        if content.isEmpty {
            result += "/>"
        } else {
            result += ">"
            for item in content {
                result += item.description
            }
            result += "</\(name.qualified)>"
        }

        return result
    }
}

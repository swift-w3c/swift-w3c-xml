extension W3C_XML {

    public struct Element: Sendable, Hashable {

        public var name: Name

        public var attributes: [Attribute]

        public var content: [Content]

        public var namespaces: [Namespace]

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

extension W3C_XML.Element {

    @inlinable
    public var children: [W3C_XML.Element] {
        content.compactMap { $0.element }
    }

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

    @inlinable
    public func attribute(_ name: String) -> String? {
        attributes.first { $0.name.qualified == name }?.value
    }

    @inlinable
    public func attribute(_ name: W3C_XML.Name) -> String? {
        attributes.first { $0.name == name }?.value
    }
}

extension W3C_XML.Element {

    @inlinable
    public func child(_ name: String) -> W3C_XML.Element? {
        children.first { $0.name.qualified == name || $0.name.local == name }
    }

    @inlinable
    public func children(_ name: String) -> [W3C_XML.Element] {
        children.filter { $0.name.qualified == name || $0.name.local == name }
    }

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

extension W3C_XML.Element {

    @inlinable
    public subscript(_ name: String) -> W3C_XML.Element? {
        child(name)
    }

    @inlinable
    public subscript(_ index: Int) -> W3C_XML.Element? {
        let children = self.children
        guard index >= 0 && index < children.count else { return nil }
        return children[index]
    }
}

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

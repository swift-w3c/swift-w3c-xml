extension W3C_XML {

    public enum Content: Sendable, Hashable {

        case element(Element)

        case text(String)

        case cdata(String)

        case comment(String)

        case instruction(Instruction)
    }
}

extension W3C_XML.Content {

    @inlinable
    public var element: W3C_XML.Element? {
        guard case .element(let e) = self else { return nil }
        return e
    }

    @inlinable
    public var text: String? {
        guard case .text(let t) = self else { return nil }
        return t
    }

    @inlinable
    public var cdata: String? {
        guard case .cdata(let c) = self else { return nil }
        return c
    }

    @inlinable
    public var comment: String? {
        guard case .comment(let c) = self else { return nil }
        return c
    }

    @inlinable
    public var instruction: W3C_XML.Instruction? {
        guard case .instruction(let i) = self else { return nil }
        return i
    }
}

extension W3C_XML.Content {

    @inlinable
    public var isElement: Bool {
        if case .element = self { return true }
        return false
    }

    @inlinable
    public var isText: Bool {
        if case .text = self { return true }
        return false
    }

    @inlinable
    public var isCDATA: Bool {
        if case .cdata = self { return true }
        return false
    }

    @inlinable
    public var isComment: Bool {
        if case .comment = self { return true }
        return false
    }

    @inlinable
    public var isInstruction: Bool {
        if case .instruction = self { return true }
        return false
    }
}

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

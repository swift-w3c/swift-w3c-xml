extension W3C_XML {

    public struct Name: Sendable, Hashable {

        public var local: String

        public var prefix: String?

        @inlinable
        public init(local: String, prefix: String? = nil) {
            self.local = local
            self.prefix = prefix
        }
    }
}

extension W3C_XML.Name {

    @inlinable
    public var qualified: String {
        if let prefix {
            return "\(prefix):\(local)"
        }
        return local
    }
}

extension W3C_XML.Name {

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

extension W3C_XML.Name: CustomStringConvertible {
    public var description: String {
        qualified
    }
}

extension W3C_XML.Name: ExpressibleByStringLiteral {
    @inlinable
    public init(stringLiteral value: String) {
        self.init(value)
    }
}

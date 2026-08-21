extension W3C_XML {

    public struct Attribute: Sendable, Hashable {

        public var name: Name

        public var value: String

        @inlinable
        public init(name: Name, value: String) {
            self.name = name
            self.value = value
        }

        @inlinable
        public init(name: String, value: String) {
            self.name = Name(name)
            self.value = value
        }
    }
}

extension W3C_XML.Attribute: CustomStringConvertible {
    public var description: String {

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

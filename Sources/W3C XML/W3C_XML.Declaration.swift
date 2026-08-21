extension W3C_XML {

    public struct Declaration: Sendable, Hashable {

        public var version: Version

        public var encoding: String?

        public var standalone: Bool?

        @inlinable
        public init(
            version: Version = .v1_0,
            encoding: String? = nil,
            standalone: Bool? = nil
        ) {
            self.version = version
            self.encoding = encoding
            self.standalone = standalone
        }
    }
}

extension W3C_XML.Declaration {

    public enum Version: String, Sendable, Hashable {

        case v1_0 = "1.0"

        case v1_1 = "1.1"
    }
}

extension W3C_XML.Declaration: CustomStringConvertible {
    public var description: String {
        var result = "<?xml version=\"\(version.rawValue)\""

        if let encoding {
            result += " encoding=\"\(encoding)\""
        }

        if let standalone {
            result += " standalone=\"\(standalone ? "yes" : "no")\""
        }

        result += "?>"
        return result
    }
}

extension W3C_XML {

    public struct Doctype: Sendable, Hashable {

        public var name: String

        public var publicID: String?

        public var systemID: String?

        public var internalSubset: String?

        @inlinable
        public init(
            name: String,
            publicID: String? = nil,
            systemID: String? = nil,
            internalSubset: String? = nil
        ) {
            self.name = name
            self.publicID = publicID
            self.systemID = systemID
            self.internalSubset = internalSubset
        }
    }
}

extension W3C_XML.Doctype: CustomStringConvertible {
    public var description: String {
        var result = "<!DOCTYPE \(name)"

        if let publicID, let systemID {
            result += " PUBLIC \"\(publicID)\" \"\(systemID)\""
        } else if let systemID {
            result += " SYSTEM \"\(systemID)\""
        }

        if let internalSubset {
            result += " [\(internalSubset)]"
        }

        result += ">"
        return result
    }
}

extension W3C_XML {

    public struct Instruction: Sendable, Hashable {

        public var target: String

        public var data: String?

        @inlinable
        public init(target: String, data: String? = nil) {
            self.target = target
            self.data = data
        }
    }
}

extension W3C_XML.Instruction: CustomStringConvertible {
    public var description: String {
        if let data {
            return "<?\(target) \(data)?>"
        }
        return "<?\(target)?>"
    }
}

extension W3C_XML {

    public struct Position: Sendable, Hashable {

        public let offset: Int

        public let line: Int

        public let column: Int

        @inlinable
        public init(offset: Int, line: Int, column: Int) {
            self.offset = offset
            self.line = line
            self.column = column
        }
    }
}

extension W3C_XML.Position {

    public static let start = Self(offset: 0, line: 1, column: 1)
}

extension W3C_XML.Position: CustomStringConvertible {
    public var description: String {
        "line \(line), column \(column) (byte \(offset))"
    }
}

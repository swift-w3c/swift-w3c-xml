/// W3C_XML.Position.swift
/// swift-w3c-xml
///
/// Position tracking for error reporting

extension W3C_XML {
    /// Position within the XML input for error reporting.
    ///
    /// All indices are for the UTF-8 byte representation.
    public struct Position: Sendable, Hashable {
        /// Byte offset from start of input (0-indexed).
        public let offset: Int

        /// Line number (1-indexed).
        public let line: Int

        /// Column number within the line (1-indexed, byte column).
        public let column: Int

        /// Creates a position.
        ///
        /// - Parameters:
        ///   - offset: Byte offset from start.
        ///   - line: Line number (1-indexed).
        ///   - column: Column number (1-indexed).
        @inlinable
        public init(offset: Int, line: Int, column: Int) {
            self.offset = offset
            self.line = line
            self.column = column
        }

        /// The starting position (offset 0, line 1, column 1).
        public static let start = Position(offset: 0, line: 1, column: 1)
    }
}

// MARK: - Position CustomStringConvertible

extension W3C_XML.Position: CustomStringConvertible {
    public var description: String {
        "line \(line), column \(column) (byte \(offset))"
    }
}

extension W3C_XML.Entity {

    /// Bounds on expanding general entities declared in a document's internal DTD subset.
    public struct Limits: Sendable, Hashable {

        /// The deepest nesting of entity references inside replacement text.
        public var depth: Int

        /// The most bytes all entity expansions in one document may produce together.
        public var expandedBytes: Int

        @inlinable
        public init(depth: Int = 16, expandedBytes: Int = 1 << 22) {
            self.depth = depth
            self.expandedBytes = expandedBytes
        }
    }
}

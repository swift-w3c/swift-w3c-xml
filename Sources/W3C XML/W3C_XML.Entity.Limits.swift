extension W3C_XML.Entity {

    /// Bounds on expanding general entities declared in a document's internal DTD subset.
    public struct Limits: Sendable, Hashable {

        /// The deepest nesting of entity references inside replacement text.
        public var depth: Int

        /// The most bytes all entity expansions in one document may produce together.
        public var expandedBytes: Int

        /// Sixteen levels of nesting and 4 MiB of expanded text; set either property to change it.
        @inlinable
        public init() {
            self.depth = 16
            self.expandedBytes = 1 << 22
        }
    }
}
